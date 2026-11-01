import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/money.dart';
import '../../../business/domain/entities/invoice_entity.dart';
import '../../../checks/domain/entities/check_entity.dart';
import '../entities/accounting_document_entity.dart';
import '../entities/accounting_transaction_entity.dart';
import '../repositories/accounting_repository.dart';
import 'voucher_settings_service.dart';

class AutoVoucherService {
  final AccountingRepository _accountingRepository;
  final VoucherSettingsService settingsService;
  final Uuid _uuid;

  AutoVoucherService(
    this._accountingRepository, {
    required this.settingsService,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

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
        if (!fy.isClosed &&
            !date.isBefore(fy.startDate) &&
            !date.isAfter(fy.endDate.add(const Duration(days: 1)))) {
          return fy.id;
        }
      }
    } catch (_) {}
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

    if (invoice.type == InvoiceType.sale) {
      // 1. Customer (Debit) - Total net amount payable
      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: customerSubject!.id,
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
          subjectId: salesSubject!.id,
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
    } else {
      // Purchase Invoice
      // 1. Inventory / Purchase (Debit)
      txs.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: docId,
          subjectId: inventorySubject!.id,
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
          subjectId: supplierSubject!.id,
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

  /// Automatically generates balanced double-entry accounting document for Cheque state transitions
  Future<AccountingDocumentEntity?> generateChequeVoucher(
    CheckEntity cheque,
    String event, {
    String? fiscalYearId,
    String? bankSubjectId,
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

    final resolvedFiscalYearId =
        fiscalYearId ?? await _resolveFiscalYearId(cheque.createdAt);
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
      date: cheque.createdAt,
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
}
