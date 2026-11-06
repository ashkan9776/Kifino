import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/money.dart';
import '../../../business/domain/entities/invoice_entity.dart';
import '../../../business/domain/entities/product_entity.dart';
import '../../../business/domain/repositories/business_repository.dart';
import '../../../checks/domain/entities/check_entity.dart';
import '../entities/accounting_document_entity.dart';
import '../entities/accounting_transaction_entity.dart';
import '../repositories/accounting_repository.dart';
import 'voucher_settings_service.dart';

class AutoVoucherService {
  final AccountingRepository _accountingRepository;
  final VoucherSettingsService settingsService;
  /// Optional so existing constructions (tests) keep compiling — the app
  /// registers it so sale vouchers can carry the COGS leg.
  final BusinessRepository? businessRepository;
  final Uuid _uuid;

  AutoVoucherService(
    this._accountingRepository, {
    required this.settingsService,
    this.businessRepository,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Weighted-average COGS of a sale invoice: Σ (qty × product avgCostMinor)
  /// over product-backed line items. Products without an avg (never
  /// purchased) contribute 0 — their COGS legs are simply omitted.
  Future<int> _computeCogsMinor(InvoiceEntity invoice) async {
    final repo = businessRepository;
    // Sale AND sales-return both move inventory at the weighted average.
    if (repo == null ||
        (invoice.type != InvoiceType.sale &&
            invoice.type != InvoiceType.salesReturn)) {
      return 0;
    }
    final productIds = invoice.items
        .map((i) => i.productId)
        .whereType<String>()
        .toSet();
    if (productIds.isEmpty) return 0;
    final productsResult = await repo.getProducts();
    final products = productsResult.dataOrNull ?? const <ProductEntity>[];
    int cogs = 0;
    for (final item in invoice.items) {
      final pid = item.productId;
      if (pid == null) continue;
      final product = products.where((p) => p.id == pid).firstOrNull;
      if (product == null) continue;
      cogs += (item.quantity * product.avgCostMinor).round();
    }
    return cogs;
  }

  /// Vouchers are linked to their invoice or check via referenceType+referenceId;
  /// this lookup makes generation idempotent.
  Future<bool> _hasVoucherFor(
    String referenceId, {
    String? referenceType,
  }) async {
    final existing = await _accountingRepository.getDocuments();
    return existing.any(
      (d) =>
          d.referenceId == referenceId &&
          (referenceType != null
              ? d.referenceType == referenceType
              : (d.referenceType == 'invoice' ||
                    d.referenceType == 'cheque' ||
                    (d.referenceType?.startsWith('cheque:') ?? false))),
    );
  }

  Future<String?> _resolveFiscalYearId(DateTime date) async {
    try {
      final years = await _accountingRepository.getFiscalYears();
      for (final fy in years) {
        if (fy.isClosed) continue;
        final endOfLastDay = DateTime(
          fy.endDate.year,
          fy.endDate.month,
          fy.endDate.day,
          23,
          59,
          59,
          999,
        );
        if (!date.isBefore(fy.startDate) && !date.isAfter(endOfLastDay)) {
          return fy.id;
        }
      }
      // Date outside every open year (gap or ahead of the books): attach the
      // document to the ACTIVE year so it stays visible in year-scoped
      // reports and gets closed by the year-end flow instead of floating
      // with a null year.
      final active =
          years.where((y) => y.isActive).firstOrNull ??
          await _accountingRepository.getActiveFiscalYear();
      return active?.id;
    } catch (e, st) {
      AppLogger.warning(
        'خطا در یافتن سال مالی برای تاریخ $date: $e',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  /// Voids (soft-deletes) the voucher linked to a reference (e.g. when the
  /// invoice or check itself is deleted, or a specific event voucher is reverted).
  Future<void> voidVoucherFor(String referenceId, {String? event}) async {
    try {
      final existing = await _accountingRepository.getDocuments();
      final targetType = event != null ? 'cheque:$event' : null;
      for (final doc in existing) {
        if (doc.referenceId == referenceId) {
          final matches = targetType != null
              ? doc.referenceType == targetType
              : (doc.referenceType == 'invoice' ||
                    doc.referenceType == 'cheque' ||
                    (doc.referenceType?.startsWith('cheque:') ?? false));
          if (matches) {
            await _accountingRepository.deleteDocument(doc.id);
          }
        }
      }
    } catch (e, st) {
      AppLogger.warning(
        'خطا در ابطال سند حسابداری برای ارجاع $referenceId: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Automatically generates balanced double-entry accounting document for an invoice
  Future<AccountingDocumentEntity> generateInvoiceVoucher(
    InvoiceEntity invoice, {
    String? fiscalYearId,
  }) async {
    // Idempotency: one invoice ↔ one voucher.
    if (await _hasVoucherFor(invoice.id)) {
      throw StateError('برای این فاکتور قبلاً سند حسابداری صادر شده است.');
    }

    final resolvedFiscalYearId =
        fiscalYearId ?? await _resolveFiscalYearId(invoice.issueDate);
    final cfg = settingsService.load();
    final now = DateTime.now();
    final docId = _uuid.v4();
    final docNumber = await _accountingRepository.getNextDocumentNumber(
      resolvedFiscalYearId,
    );

    // Look up required subjects from the configurable mapping
    final salesSubject =
        await _accountingRepository.getSubjectByCode(cfg.salesCode) ??
        await _accountingRepository.getSubjectByCode('060');
    final customerSubject =
        await _accountingRepository.getSubjectByCode(cfg.receivableCode) ??
        await _accountingRepository.getSubjectByCode('012');
    final vatOutputSubject = await _accountingRepository.getSubjectByCode(
      cfg.vatOutputCode,
    );
    final discountSubject = await _accountingRepository.getSubjectByCode(
      cfg.discountSalesCode,
    );
    final inventorySubject =
        await _accountingRepository.getSubjectByCode(cfg.inventoryCode) ??
        await _accountingRepository.getSubjectByCode('015');

    final supplierSubject =
        await _accountingRepository.getSubjectByCode(cfg.payableCode) ??
        await _accountingRepository.getSubjectByCode('023');
    final vatInputSubject = await _accountingRepository.getSubjectByCode(
      cfg.vatInputCode,
    );
    final purchaseDiscountSubject = await _accountingRepository
        .getSubjectByCode(cfg.purchaseDiscountCode);

    final List<AccountingTransactionEntity> txs = [];
    int order = 1;

    // Required subjects must exist with a Persian message — a raw null-check
    // crash tells the user nothing about what to fix.
    if (invoice.type == InvoiceType.salesReturn) {
      // برگشت از فروش (credit note): mirror of the sale voucher.
      // DR برگشت از فروش(subtotal) + DR VAT(tax) / CR customer(total)
      // + DR inventory(avg) / CR COGS(avg) — stock re-enters at the same
      // weighted average it left at.
      final returnSubject = await _accountingRepository.getSubjectByCode(
        cfg.salesReturnCode,
      );
      if (returnSubject == null) {
        throw StateError(
          'سرفصل برگشت از فروش (${cfg.salesReturnCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
        );
      }
      if (customerSubject == null) {
        throw StateError(
          'سرفصل حساب‌های دریافتنی (${cfg.receivableCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
        );
      }

      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: returnSubject.id,
          subject: returnSubject,
          debit: invoice.subtotal,
          credit: const Money.zero(),
          description:
              'برگشت از فروش طبق فاکتور شماره ${invoice.invoiceNumber}',
          rowOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (invoice.tax.minorUnits > 0 && vatOutputSubject != null) {
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: vatOutputSubject.id,
            subject: vatOutputSubject,
            debit: invoice.tax,
            credit: const Money.zero(),
            description:
                'برگشت مالیات ارزش افزوده فاکتور شماره ${invoice.invoiceNumber}',
            rowOrder: order++,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: customerSubject.id,
          subject: customerSubject,
          detailSubjectId: invoice.contactId,
          detailSubjectName: invoice.contactName,
          debit: const Money.zero(),
          credit: invoice.total,
          description:
              'بستانکاری مشتری بابت برگشت فاکتور شماره ${invoice.invoiceNumber}',
          rowOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Stock re-entry legs at the weighted-average cost.
      final cogsMinor = await _computeCogsMinor(invoice);
      if (cogsMinor > 0 && inventorySubject != null) {
        final cogsSubject = await _accountingRepository.getSubjectByCode(
          cfg.cogsCode,
        );
        if (cogsSubject != null) {
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: inventorySubject.id,
              subject: inventorySubject,
              debit: Money.fromMinor(cogsMinor),
              credit: const Money.zero(),
              description:
                  'بازگشت کالا به موجودی طبق برگشت فاکتور شماره ${invoice.invoiceNumber}',
              rowOrder: order++,
              createdAt: now,
              updatedAt: now,
            ),
          );
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: cogsSubject.id,
              subject: cogsSubject,
              debit: const Money.zero(),
              credit: Money.fromMinor(cogsMinor),
              description:
                  'برگشت بهای تمام‌شده طبق برگشت فاکتور شماره ${invoice.invoiceNumber}',
              rowOrder: order++,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }

      final doc = AccountingDocumentEntity(
        id: docId,
        number: docNumber,
        date: invoice.issueDate,
        title: 'سند برگشت از فروش شماره ${invoice.invoiceNumber}',
        status: DocumentStatus.approved,
        isManual: false,
        referenceType: 'invoice',
        referenceId: invoice.id,
        fiscalYearId: resolvedFiscalYearId,
        approvedAt: now,
        transactions: txs,
        createdAt: now,
        updatedAt: now,
      );
      return _accountingRepository.createDocument(doc);
    }

    if (invoice.type == InvoiceType.sale) {
      if (customerSubject == null) {
        throw StateError(
          'سرفصل حساب‌های دریافتنی (${cfg.receivableCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
        );
      }
      if (salesSubject == null) {
        throw StateError(
          'سرفصل فروش (${cfg.salesCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
        );
      }
      // 1. Customer (Debit) - Total net amount payable
      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: customerSubject.id,
          subject: customerSubject,
          detailSubjectId: invoice.contactId,
          detailSubjectName: invoice.contactName,
          debit: invoice.total,
          credit: const Money.zero(),
          description:
              'فاکتور فروش شماره ${invoice.invoiceNumber} - ${invoice.contactName}',
          rowOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Sales Discount (Debit if any)
      if (invoice.discount.minorUnits > 0 && discountSubject != null) {
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: discountSubject.id,
            subject: discountSubject,
            debit: invoice.discount,
            credit: const Money.zero(),
            description: 'تخفیف فاکتور فروش شماره ${invoice.invoiceNumber}',
            rowOrder: order++,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // 3. Sales Revenue (Credit) - Subtotal
      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: salesSubject.id,
          subject: salesSubject,
          debit: const Money.zero(),
          credit: invoice.subtotal,
          description:
              'فروش کالا/خدمات طبق فاکتور شماره ${invoice.invoiceNumber}',
          rowOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 4. VAT Output (Credit if any)
      if (invoice.tax.minorUnits > 0 && vatOutputSubject != null) {
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: vatOutputSubject.id,
            subject: vatOutputSubject,
            debit: const Money.zero(),
            credit: invoice.tax,
            description:
                'مالیات بر ارزش افزوده فاکتور فروش شماره ${invoice.invoiceNumber}',
            rowOrder: order++,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // 5+6. COGS pair — the sale posts a COMPLETE pair: DR بهای تمام‌شده /
      // CR موجودی کالا at the weighted-average cost. Without it the
      // inventory account never moves on sales and the P&L has no cost of
      // goods. Omitted when the product has never been purchased (avg 0).
      final cogsMinor = await _computeCogsMinor(invoice);
      if (cogsMinor > 0 && inventorySubject != null) {
        final cogsSubject = await _accountingRepository.getSubjectByCode(
          cfg.cogsCode,
        );
        if (cogsSubject != null) {
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: cogsSubject.id,
              subject: cogsSubject,
              debit: Money.fromMinor(cogsMinor),
              credit: const Money.zero(),
              description:
                  'بهای تمام‌شده کالای فروش‌رفته طبق فاکتور شماره ${invoice.invoiceNumber}',
              rowOrder: order++,
              createdAt: now,
              updatedAt: now,
            ),
          );
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: inventorySubject.id,
              subject: inventorySubject,
              debit: const Money.zero(),
              credit: Money.fromMinor(cogsMinor),
              description:
                  'خروج کالا از موجودی طبق فاکتور شماره ${invoice.invoiceNumber}',
              rowOrder: order++,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    } else {
      // Purchase Invoice
      if (inventorySubject == null) {
        throw StateError(
          'سرفصل موجودی کالا (${cfg.inventoryCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
        );
      }
      if (supplierSubject == null) {
        throw StateError(
          'سرفصل حساب‌های پرداختنی (${cfg.payableCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
        );
      }
      // 1. Inventory / Purchase (Debit)
      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: inventorySubject.id,
          subject: inventorySubject,
          debit: invoice.subtotal,
          credit: const Money.zero(),
          description:
              'خرید کالا طبق فاکتور خرید شماره ${invoice.invoiceNumber}',
          rowOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. VAT Input / Tax Credit (Debit if any)
      if (invoice.tax.minorUnits > 0 && vatInputSubject != null) {
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: vatInputSubject.id,
            subject: vatInputSubject,
            debit: invoice.tax,
            credit: const Money.zero(),
            description:
                'مالیات بر ارزش افزوده فاکتور خرید شماره ${invoice.invoiceNumber}',
            rowOrder: order++,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // 3. Purchase Discount (Credit if any)
      if (invoice.discount.minorUnits > 0 && purchaseDiscountSubject != null) {
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: purchaseDiscountSubject.id,
            subject: purchaseDiscountSubject,
            debit: const Money.zero(),
            credit: invoice.discount,
            description: 'تخفیف فاکتور خرید شماره ${invoice.invoiceNumber}',
            rowOrder: order++,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // 4. Supplier / Accounts Payable (Credit)
      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: supplierSubject.id,
          subject: supplierSubject,
          detailSubjectId: invoice.contactId,
          detailSubjectName: invoice.contactName,
          debit: const Money.zero(),
          credit: invoice.total,
          description:
              'بستانکاری تأمین‌کننده طبق فاکتور خرید شماره ${invoice.invoiceNumber}',
          rowOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final doc = AccountingDocumentEntity(
      id: docId,
      number: docNumber,
      date: invoice.issueDate,
      title:
          'سند فاکتور ${invoice.type.titleFa} شماره ${invoice.invoiceNumber}',
      status: DocumentStatus.approved,
      isManual: false,
      referenceType: 'invoice',
      referenceId: invoice.id,
      fiscalYearId: resolvedFiscalYearId,
      approvedAt: now,
      transactions: txs,
      createdAt: now,
      updatedAt: now,
    );

    return _accountingRepository.createDocument(doc);
  }

  /// Automatically generates balanced double-entry accounting document for Cheque state transitions.
  /// [eventDate] is WHEN the transition happened (e.g. وصول today) — the
  /// voucher is dated and year-resolved at the event, not at the check's
  /// creation, so journals and year-end closure land in the right period.
  Future<AccountingDocumentEntity?> generateChequeVoucher(
    CheckEntity cheque,
    String event, {
    String? fiscalYearId,
    String? bankSubjectId,
    DateTime? eventDate,
  }) async {
    final refType = 'cheque:$event';
    if (await _hasVoucherFor(cheque.id, referenceType: refType)) {
      final existing = await _accountingRepository.getDocuments();
      return existing
          .where(
            (d) => d.referenceId == cheque.id && d.referenceType == refType,
          )
          .firstOrNull;
    }

    final occurredAt = eventDate ?? cheque.createdAt;
    final resolvedFiscalYearId =
        fiscalYearId ?? await _resolveFiscalYearId(occurredAt);
    final now = DateTime.now();
    final docId = _uuid.v4();
    final docNumber = await _accountingRepository.getNextDocumentNumber(
      resolvedFiscalYearId,
    );

    final cfg = settingsService.load();
    final notesReceivable = await _accountingRepository.getSubjectByCode(
      cfg.notesReceivableCode,
    );
    final notesInCollection = await _accountingRepository.getSubjectByCode(
      cfg.notesInCollectionCode,
    );
    final notesPayable = await _accountingRepository.getSubjectByCode(
      cfg.notesPayableCode,
    );
    final customerSubject = await _accountingRepository.getSubjectByCode(
      cfg.receivableCode,
    );
    final supplierSubject = await _accountingRepository.getSubjectByCode(
      cfg.payableCode,
    );
    final bankSubject = bankSubjectId != null
        ? await _accountingRepository.getSubjectById(bankSubjectId)
        : (await _accountingRepository.getSubjectByCode(cfg.bankCode) ??
              await _accountingRepository.getSubjectByCode('010'));

    final List<AccountingTransactionEntity> txs = [];
    String title = '';

    final serial = cheque.checkNumber.isNotEmpty
        ? cheque.checkNumber
        : (cheque.sayadiId ?? '');

    switch (event) {
      case 'register': // دریافت چک از مشتری
        if (notesReceivable == null) {
          throw StateError(
            'سرفصل اسناد دریافتنی (${cfg.notesReceivableCode}) تنظیم نشده است.',
          );
        }
        if (customerSubject == null) {
          throw StateError(
            'سرفصل حساب‌های دریافتنی (${cfg.receivableCode}) تنظیم نشده است.',
          );
        }
        title = 'دریافت چک به شماره $serial از ${cheque.partyName}';
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: notesReceivable.id,
            subject: notesReceivable,
            debit: cheque.amount,
            credit: const Money.zero(),
            description: title,
            rowOrder: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: customerSubject.id,
            subject: customerSubject,
            detailSubjectName: cheque.partyName,
            debit: const Money.zero(),
            credit: cheque.amount,
            description: title,
            rowOrder: 2,
            createdAt: now,
            updatedAt: now,
          ),
        );
        break;

      case 'deposit': // خواباندن چک به حساب / در جریان وصول
        if (notesInCollection == null) {
          throw StateError(
            'سرفصل اسناد در جریان وصول (${cfg.notesInCollectionCode}) تنظیم نشده است.',
          );
        }
        if (notesReceivable == null) {
          throw StateError(
            'سرفصل اسناد دریافتنی (${cfg.notesReceivableCode}) تنظیم نشده است.',
          );
        }
        title = 'واگذاری چک صیادی $serial به بانک جهت وصول';
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: notesInCollection.id,
            subject: notesInCollection,
            debit: cheque.amount,
            credit: const Money.zero(),
            description: title,
            rowOrder: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: notesReceivable.id,
            subject: notesReceivable,
            debit: const Money.zero(),
            credit: cheque.amount,
            description: title,
            rowOrder: 2,
            createdAt: now,
            updatedAt: now,
          ),
        );
        break;

      case 'clear': // وصول چک
        if (cheque.type == CheckType.received) {
          if (bankSubject == null) {
            throw StateError('سرفصل بانک (${cfg.bankCode}) تنظیم نشده است.');
          }
          if (notesInCollection == null) {
            throw StateError(
              'سرفصل اسناد در جریان وصول (${cfg.notesInCollectionCode}) تنظیم نشده است.',
            );
          }
          title = 'وصول چک صیادی $serial و واریز به حساب بانکی';
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: bankSubject.id,
              subject: bankSubject,
              debit: cheque.amount,
              credit: const Money.zero(),
              description: title,
              rowOrder: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: notesInCollection.id,
              subject: notesInCollection,
              debit: const Money.zero(),
              credit: cheque.amount,
              description: title,
              rowOrder: 2,
              createdAt: now,
              updatedAt: now,
            ),
          );
        } else {
          // چک صادره پاس شد
          if (notesPayable == null) {
            throw StateError(
              'سرفصل اسناد پرداختنی (${cfg.notesPayableCode}) تنظیم نشده است.',
            );
          }
          if (bankSubject == null) {
            throw StateError('سرفصل بانک (${cfg.bankCode}) تنظیم نشده است.');
          }
          title = 'پاس شدن چک صادره شماره $serial از حساب بانکی';
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: notesPayable.id,
              subject: notesPayable,
              debit: cheque.amount,
              credit: const Money.zero(),
              description: title,
              rowOrder: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
          txs.add(
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: bankSubject.id,
              subject: bankSubject,
              debit: const Money.zero(),
              credit: cheque.amount,
              description: title,
              rowOrder: 2,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        break;

      case 'issue': // صدور چک پرداختنی به شخص
        if (supplierSubject == null) {
          throw StateError(
            'سرفصل بستانکاران تجاری (${cfg.payableCode}) تنظیم نشده است.',
          );
        }
        if (notesPayable == null) {
          throw StateError(
            'سرفصل اسناد پرداختنی (${cfg.notesPayableCode}) تنظیم نشده است.',
          );
        }
        title = 'صدور چک پرداختنی شماره $serial در وجه ${cheque.partyName}';
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: supplierSubject.id,
            subject: supplierSubject,
            detailSubjectName: cheque.partyName,
            debit: cheque.amount,
            credit: const Money.zero(),
            description: title,
            rowOrder: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        txs.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: docId,
            subjectId: notesPayable.id,
            subject: notesPayable,
            debit: const Money.zero(),
            credit: cheque.amount,
            description: title,
            rowOrder: 2,
            createdAt: now,
            updatedAt: now,
          ),
        );
        break;

      default:
        return null;
    }

    final doc = AccountingDocumentEntity(
      id: docId,
      number: docNumber,
      date: occurredAt,
      title: title,
      status: DocumentStatus.approved,
      isManual: false,
      referenceType: refType,
      referenceId: cheque.id,
      fiscalYearId: resolvedFiscalYearId,
      approvedAt: now,
      transactions: txs,
      createdAt: now,
      updatedAt: now,
    );

    return _accountingRepository.createDocument(doc);
  }

  /// Double-entry voucher for a payment settled against an invoice.
  ///
  /// The sale/purchase voucher debited/credited the counterparty for the FULL
  /// total — without this voucher the receivable/payable subject would stay
  /// outstanding in the ledger forever, even after full payment.
  /// Sale payment:  DR bank/cash — CR accounts receivable.
  /// Purchase payment: DR accounts payable — CR bank/cash.
  /// Multiple partial payments produce multiple vouchers (one per settlement);
  /// invoice deletion voids them all via [voidInvoicePaymentVouchers].
  Future<void> generateInvoicePaymentVoucher(
    InvoiceEntity invoice, {
    required Money amount,
    DateTime? eventDate,
  }) async {
    if (amount.minorUnits <= 0) return;
    final occurredAt = eventDate ?? DateTime.now();
    final resolvedFiscalYearId = await _resolveFiscalYearId(occurredAt);
    final cfg = settingsService.load();
    final now = DateTime.now();

    final isSale = invoice.type == InvoiceType.sale;
    final bankSubject =
        await _accountingRepository.getSubjectByCode(cfg.bankCode) ??
        await _accountingRepository.getSubjectByCode('010');
    final counterpartySubject = isSale
        ? (await _accountingRepository.getSubjectByCode(cfg.receivableCode) ??
              await _accountingRepository.getSubjectByCode('012'))
        : (await _accountingRepository.getSubjectByCode(cfg.payableCode) ??
              await _accountingRepository.getSubjectByCode('023'));

    if (bankSubject == null) {
      throw StateError(
        'سرفصل موجودی بانک/صندوق (${cfg.bankCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
      );
    }
    if (counterpartySubject == null) {
      throw StateError(
        isSale
            ? 'سرفصل حساب‌های دریافتنی (${cfg.receivableCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.'
            : 'سرفصل حساب‌های پرداختنی (${cfg.payableCode}) یافت نشد. کدینگ حسابداری را بازبینی کنید.',
      );
    }

    final docId = _uuid.v4();
    final docNumber = await _accountingRepository.getNextDocumentNumber(
      resolvedFiscalYearId,
    );
    final verb = isSale ? 'دریافت' : 'پرداخت';
    final rows = isSale
        ? [
            // DR bank/cash — money came in
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: bankSubject.id,
              subject: bankSubject,
              debit: amount,
              credit: const Money.zero(),
              description:
                  '$verb بابت فاکتور فروش شماره ${invoice.invoiceNumber}',
              rowOrder: 1,
              createdAt: now,
              updatedAt: now,
            ),
            // CR receivable — settles the customer's debt
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: counterpartySubject.id,
              subject: counterpartySubject,
              detailSubjectId: invoice.contactId,
              detailSubjectName: invoice.contactName,
              debit: const Money.zero(),
              credit: amount,
              description:
                  'تسویه حساب ${invoice.contactName} بابت فاکتور شماره ${invoice.invoiceNumber}',
              rowOrder: 2,
              createdAt: now,
              updatedAt: now,
            ),
          ]
        : [
            // DR payable — settles our debt to the supplier
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: counterpartySubject.id,
              subject: counterpartySubject,
              detailSubjectId: invoice.contactId,
              detailSubjectName: invoice.contactName,
              debit: amount,
              credit: const Money.zero(),
              description:
                  'تسویه حساب ${invoice.contactName} بابت فاکتور شماره ${invoice.invoiceNumber}',
              rowOrder: 1,
              createdAt: now,
              updatedAt: now,
            ),
            // CR bank/cash — money went out
            AccountingTransactionEntity(
              id: _uuid.v4(),
              documentId: docId,
              subjectId: bankSubject.id,
              subject: bankSubject,
              debit: const Money.zero(),
              credit: amount,
              description:
                  '$verb بابت فاکتور خرید شماره ${invoice.invoiceNumber}',
              rowOrder: 2,
              createdAt: now,
              updatedAt: now,
            ),
          ];

    final doc = AccountingDocumentEntity(
      id: docId,
      number: docNumber,
      date: occurredAt,
      title: 'سند $verb فاکتور شماره ${invoice.invoiceNumber}',
      status: DocumentStatus.approved,
      isManual: false,
      referenceType: 'invoice-payment',
      referenceId: invoice.id,
      fiscalYearId: resolvedFiscalYearId,
      approvedAt: now,
      transactions: rows,
      createdAt: now,
      updatedAt: now,
    );

    await _accountingRepository.createDocument(doc);
  }

  /// Voids every payment voucher issued against [invoiceId] (used when the
  /// invoice itself is deleted or re-vouchered).
  Future<void> voidInvoicePaymentVouchers(String invoiceId) async {
    final existing = await _accountingRepository.getDocuments();
    for (final doc in existing) {
      if (doc.referenceId == invoiceId &&
          doc.referenceType == 'invoice-payment') {
        await _accountingRepository.deleteDocument(doc.id);
      }
    }
  }
}
