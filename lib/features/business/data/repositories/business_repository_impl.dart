import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/business_metrics_entity.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/inventory_log_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/product_card_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/business_repository.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  BusinessRepositoryImpl(this._db);

  // ----------------------------------------------------
  // MAPPERS
  // ----------------------------------------------------
  ContactEntity _toContactEntity(BusinessContactData data) {
    final currency = Currency.fromCode(AppConstants.defaultCurrencyCode);
    return ContactEntity(
      id: data.id,
      name: data.name,
      companyName: data.companyName,
      type: ContactType.fromCode(data.type),
      phone: data.phone,
      email: data.email,
      address: data.address,
      taxNumber: data.taxNumber,
      outstandingBalance: Money.fromMinor(
        data.outstandingBalanceMinor,
        currency,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
    );
  }

  ProductEntity _toProductEntity(ProductData data, {String? supplierName}) {
    final currency = Currency.fromCode(data.currency);
    return ProductEntity(
      id: data.id,
      name: data.name,
      sku: data.sku,
      barcode: data.barcode,
      description: data.description,
      unit: data.unit,
      secondaryUnit: data.secondaryUnit,
      conversionFactor: data.conversionFactor,
      purchasePrice: Money.fromMinor(data.purchasePriceMinor, currency),
      sellingPrice: Money.fromMinor(data.sellingPriceMinor, currency),
      currentStock: data.currentStock,
      lowStockThreshold: data.lowStockThreshold,
      supplierId: data.supplierId,
      supplierName: supplierName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
    );
  }

  InventoryLogEntity _toLogEntity(
    InventoryLogData data, {
    String? productName,
  }) {
    final currency = Currency.fromCode(AppConstants.defaultCurrencyCode);
    return InventoryLogEntity(
      id: data.id,
      productId: data.productId,
      productName: productName,
      changeQuantity: data.changeQuantity,
      movementType: InventoryMovementType.fromCode(data.movementType),
      referenceId: data.referenceId,
      costPerUnit: data.costPerUnitMinor != null
          ? Money.fromMinor(data.costPerUnitMinor!, currency)
          : null,
      notes: data.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
    );
  }

  InvoiceEntity _toInvoiceEntity(
    InvoiceData data, {
    String? contactName,
    List<InvoiceItemEntity> items = const [],
  }) {
    final currency = Currency.fromCode(data.currency);
    return InvoiceEntity(
      id: data.id,
      invoiceNumber: data.invoiceNumber,
      contactId: data.contactId,
      contactName: contactName,
      type: InvoiceType.fromCode(data.type),
      status: InvoiceStatus.fromCode(data.status),
      issueDate: DateTime.fromMillisecondsSinceEpoch(data.issueDate),
      dueDate: DateTime.fromMillisecondsSinceEpoch(data.dueDate),
      subtotal: Money.fromMinor(data.subtotalMinor, currency),
      discount: Money.fromMinor(data.discountMinor, currency),
      tax: Money.fromMinor(data.taxMinor, currency),
      total: Money.fromMinor(data.totalMinor, currency),
      paidAmount: Money.fromMinor(data.paidMinor, currency),
      notes: data.notes,
      terms: data.terms,
      items: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
    );
  }

  InvoiceItemEntity _toItemEntity(InvoiceItemData data, Currency currency) {
    return InvoiceItemEntity(
      id: data.id,
      invoiceId: data.invoiceId,
      productId: data.productId,
      description: data.description,
      quantity: data.quantity,
      unitPrice: Money.fromMinor(data.unitPriceMinor, currency),
      discount: Money.fromMinor(data.discountMinor, currency),
      tax: Money.fromMinor(data.taxMinor, currency),
      total: Money.fromMinor(data.totalMinor, currency),
    );
  }

  // ----------------------------------------------------
  // CONTACTS
  // ----------------------------------------------------
  @override
  Stream<List<ContactEntity>> watchContacts({ContactType? type}) {
    final query = _db.select(_db.businessContactsTable)
      ..where((tbl) {
        Expression<bool> predicate = tbl.deletedAt.isNull();
        if (type != null) {
          predicate =
              predicate &
              (tbl.type.equals(type.code) |
                  tbl.type.equals(ContactType.both.code));
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    return query.watch().map((rows) => rows.map(_toContactEntity).toList());
  }

  @override
  Future<Result<List<ContactEntity>>> getContacts({ContactType? type}) async {
    try {
      final query = _db.select(_db.businessContactsTable)
        ..where((tbl) {
          Expression<bool> predicate = tbl.deletedAt.isNull();
          if (type != null) {
            predicate =
                predicate &
                (tbl.type.equals(type.code) |
                    tbl.type.equals(ContactType.both.code));
          }
          return predicate;
        })
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      final rows = await query.get();
      return Success(rows.map(_toContactEntity).toList());
    } catch (e) {
      return DatabaseFailure('خواندن مشتریان انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<ContactEntity>> createContact(ContactEntity contact) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cId = contact.id.isEmpty ? _uuid.v4() : contact.id;

      await _db
          .into(_db.businessContactsTable)
          .insert(
            BusinessContactsTableCompanion.insert(
              id: cId,
              name: contact.name,
              companyName: Value(contact.companyName),
              type: contact.type.code,
              phone: Value(contact.phone),
              email: Value(contact.email),
              address: Value(contact.address),
              taxNumber: Value(contact.taxNumber),
              outstandingBalanceMinor: Value(
                contact.outstandingBalance.minorUnits,
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _db
          .into(_db.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'business_contacts',
              entityId: cId,
              operation: 'INSERT',
              payloadJson: '{"id":"$cId","name":"${contact.name}"}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return Success(contact.copyWith(id: cId));
    } catch (e) {
      return DatabaseFailure('ثبت مشتری انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateContact(ContactEntity contact) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.businessContactsTable,
      )..where((t) => t.id.equals(contact.id))).write(
        BusinessContactsTableCompanion(
          name: Value(contact.name),
          companyName: Value(contact.companyName),
          type: Value(contact.type.code),
          phone: Value(contact.phone),
          email: Value(contact.email),
          address: Value(contact.address),
          taxNumber: Value(contact.taxNumber),
          outstandingBalanceMinor: Value(contact.outstandingBalance.minorUnits),
          updatedAt: Value(now),
        ),
      );

      await _db
          .into(_db.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'business_contacts',
              entityId: contact.id,
              operation: 'UPDATE',
              payloadJson: '{"id":"${contact.id}","name":"${contact.name}"}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش مشتری انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteContact(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.businessContactsTable,
      )..where((t) => t.id.equals(id))).write(
        BusinessContactsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف مشتری انجام نشد.').asFailure();
    }
  }

  // ----------------------------------------------------
  // PRODUCTS & INVENTORY
  // ----------------------------------------------------
  @override
  Stream<List<ProductEntity>> watchProducts() {
    final query =
        _db.select(_db.productsTable).join([
            leftOuterJoin(
              _db.businessContactsTable,
              _db.businessContactsTable.id.equalsExp(
                _db.productsTable.supplierId,
              ),
            ),
          ])
          ..where(_db.productsTable.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(_db.productsTable.name)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final p = row.readTable(_db.productsTable);
        final c = row.readTableOrNull(_db.businessContactsTable);
        return _toProductEntity(p, supplierName: c?.name);
      }).toList();
    });
  }

  @override
  Future<Result<List<ProductEntity>>> getProducts() async {
    try {
      final query =
          _db.select(_db.productsTable).join([
              leftOuterJoin(
                _db.businessContactsTable,
                _db.businessContactsTable.id.equalsExp(
                  _db.productsTable.supplierId,
                ),
              ),
            ])
            ..where(_db.productsTable.deletedAt.isNull())
            ..orderBy([OrderingTerm.asc(_db.productsTable.name)]);

      final rows = await query.get();
      return Success(
        rows.map((row) {
          final p = row.readTable(_db.productsTable);
          final c = row.readTableOrNull(_db.businessContactsTable);
          return _toProductEntity(p, supplierName: c?.name);
        }).toList(),
      );
    } catch (e) {
      return DatabaseFailure('خواندن محصولات انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<ProductEntity>> createProduct(ProductEntity product) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pId = product.id.isEmpty ? _uuid.v4() : product.id;

      await _db
          .into(_db.productsTable)
          .insert(
            ProductsTableCompanion.insert(
              id: pId,
              name: product.name,
              sku: Value(product.sku),
              barcode: Value(product.barcode),
              description: Value(product.description),
              unit: Value(product.unit),
              secondaryUnit: Value(product.secondaryUnit),
              conversionFactor: Value(product.conversionFactor),
              purchasePriceMinor: Value(product.purchasePrice.minorUnits),
              sellingPriceMinor: product.sellingPrice.minorUnits,
              currency: product.sellingPrice.currency.code,
              currentStock: Value(product.currentStock),
              lowStockThreshold: Value(product.lowStockThreshold),
              supplierId: Value(product.supplierId),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _db
          .into(_db.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'products',
              entityId: pId,
              operation: 'INSERT',
              payloadJson: '{"id":"$pId","name":"${product.name}"}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return Success(product.copyWith(id: pId));
    } catch (e) {
      return DatabaseFailure('ثبت محصول انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateProduct(ProductEntity product) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.productsTable,
      )..where((t) => t.id.equals(product.id))).write(
        ProductsTableCompanion(
          name: Value(product.name),
          sku: Value(product.sku),
          barcode: Value(product.barcode),
          description: Value(product.description),
          unit: Value(product.unit),
          secondaryUnit: Value(product.secondaryUnit),
          conversionFactor: Value(product.conversionFactor),
          purchasePriceMinor: Value(product.purchasePrice.minorUnits),
          sellingPriceMinor: Value(product.sellingPrice.minorUnits),
          currency: Value(product.sellingPrice.currency.code),
          currentStock: Value(product.currentStock),
          lowStockThreshold: Value(product.lowStockThreshold),
          supplierId: Value(product.supplierId),
          updatedAt: Value(now),
        ),
      );

      await _db
          .into(_db.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'products',
              entityId: product.id,
              operation: 'UPDATE',
              payloadJson: '{"id":"${product.id}","name":"${product.name}"}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش محصول انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> adjustStock({
    required String productId,
    required double changeQuantity,
    required InventoryMovementType type,
    String? notes,
    String? referenceId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final product = await (_db.select(
          _db.productsTable,
        )..where((t) => t.id.equals(productId))).getSingleOrNull();
        if (product == null) throw Exception('Product not found');

        final updatedStock = (product.currentStock + changeQuantity).clamp(
          0.0,
          99999999.0,
        );

        await (_db.update(
          _db.productsTable,
        )..where((t) => t.id.equals(productId))).write(
          ProductsTableCompanion(
            currentStock: Value(updatedStock),
            updatedAt: Value(now),
          ),
        );

        final logId = _uuid.v4();
        await _db
            .into(_db.inventoryLogsTable)
            .insert(
              InventoryLogsTableCompanion.insert(
                id: logId,
                productId: productId,
                changeQuantity: changeQuantity,
                movementType: type.code,
                referenceId: Value(referenceId),
                costPerUnitMinor: Value(product.purchasePriceMinor),
                notes: Value(notes),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'inventory_logs',
                entityId: logId,
                operation: 'INSERT',
                payloadJson:
                    '{"productId":"$productId","change":$changeQuantity,"type":"${type.code}"}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('اصلاح موجودی انجام نشد.').asFailure();
    }
  }

  @override
  Stream<List<InventoryLogEntity>> watchInventoryLogs({String? productId}) {
    final query = _db.select(_db.inventoryLogsTable).join([
      leftOuterJoin(
        _db.productsTable,
        _db.productsTable.id.equalsExp(_db.inventoryLogsTable.productId),
      ),
    ])..where(_db.inventoryLogsTable.deletedAt.isNull());

    if (productId != null) {
      query.where(_db.inventoryLogsTable.productId.equals(productId));
    }

    query.orderBy([OrderingTerm.desc(_db.inventoryLogsTable.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final l = row.readTable(_db.inventoryLogsTable);
        final p = row.readTableOrNull(_db.productsTable);
        return _toLogEntity(l, productName: p?.name);
      }).toList();
    });
  }

  // ----------------------------------------------------
  // INVOICES & INVOICE ITEMS
  // ----------------------------------------------------
  @override
  Stream<List<InvoiceEntity>> watchInvoices({InvoiceType? type}) {
    final query = _db.select(_db.invoicesTable).join([
      leftOuterJoin(
        _db.businessContactsTable,
        _db.businessContactsTable.id.equalsExp(_db.invoicesTable.contactId),
      ),
    ])..where(_db.invoicesTable.deletedAt.isNull());

    if (type != null) {
      query.where(_db.invoicesTable.type.equals(type.code));
    }

    query.orderBy([OrderingTerm.desc(_db.invoicesTable.issueDate)]);

    return query.watch().asyncMap((rows) async {
      final list = <InvoiceEntity>[];
      for (final row in rows) {
        final inv = row.readTable(_db.invoicesTable);
        final c = row.readTableOrNull(_db.businessContactsTable);
        final cur = Currency.fromCode(inv.currency);

        final itemsData =
            await (_db.select(_db.invoiceItemsTable)..where(
                  (t) => t.invoiceId.equals(inv.id) & t.deletedAt.isNull(),
                ))
                .get();

        final items = itemsData.map((it) => _toItemEntity(it, cur)).toList();
        list.add(_toInvoiceEntity(inv, contactName: c?.name, items: items));
      }
      return list;
    });
  }

  @override
  Future<Result<List<InvoiceEntity>>> getInvoices({InvoiceType? type}) async {
    try {
      final query = _db.select(_db.invoicesTable).join([
        leftOuterJoin(
          _db.businessContactsTable,
          _db.businessContactsTable.id.equalsExp(_db.invoicesTable.contactId),
        ),
      ])..where(_db.invoicesTable.deletedAt.isNull());

      if (type != null) {
        query.where(_db.invoicesTable.type.equals(type.code));
      }

      query.orderBy([OrderingTerm.desc(_db.invoicesTable.issueDate)]);

      final rows = await query.get();
      final list = <InvoiceEntity>[];
      for (final row in rows) {
        final inv = row.readTable(_db.invoicesTable);
        final c = row.readTableOrNull(_db.businessContactsTable);
        final cur = Currency.fromCode(inv.currency);

        final itemsData =
            await (_db.select(_db.invoiceItemsTable)..where(
                  (t) => t.invoiceId.equals(inv.id) & t.deletedAt.isNull(),
                ))
                .get();

        final items = itemsData.map((it) => _toItemEntity(it, cur)).toList();
        list.add(_toInvoiceEntity(inv, contactName: c?.name, items: items));
      }

      return Success(list);
    } catch (e) {
      return DatabaseFailure('خواندن فاکتورها انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<InvoiceEntity>> getInvoiceById(String id) async {
    try {
      final invRow = await (_db.select(_db.invoicesTable).join([
        leftOuterJoin(
          _db.businessContactsTable,
          _db.businessContactsTable.id.equalsExp(_db.invoicesTable.contactId),
        ),
      ])..where(_db.invoicesTable.id.equals(id))).getSingleOrNull();

      if (invRow == null) {
        return NotFoundFailure('Invoice not found').asFailure();
      }

      final inv = invRow.readTable(_db.invoicesTable);
      final c = invRow.readTableOrNull(_db.businessContactsTable);
      final cur = Currency.fromCode(inv.currency);

      final itemsData = await (_db.select(
        _db.invoiceItemsTable,
      )..where((t) => t.invoiceId.equals(inv.id) & t.deletedAt.isNull())).get();

      final items = itemsData.map((it) => _toItemEntity(it, cur)).toList();
      return Success(_toInvoiceEntity(inv, contactName: c?.name, items: items));
    } catch (e) {
      return DatabaseFailure('خواندن فاکتور انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<InvoiceEntity>> createInvoice(InvoiceEntity invoice) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final invId = invoice.id.isEmpty ? _uuid.v4() : invoice.id;

      await _db.transaction(() async {
        // 1. Insert invoice header
        await _db
            .into(_db.invoicesTable)
            .insert(
              InvoicesTableCompanion.insert(
                id: invId,
                invoiceNumber: invoice.invoiceNumber,
                contactId: invoice.contactId,
                type: invoice.type.code,
                status: invoice.status.code,
                issueDate: invoice.issueDate.millisecondsSinceEpoch,
                dueDate: invoice.dueDate.millisecondsSinceEpoch,
                subtotalMinor: invoice.subtotal.minorUnits,
                discountMinor: Value(invoice.discount.minorUnits),
                taxMinor: Value(invoice.tax.minorUnits),
                totalMinor: invoice.total.minorUnits,
                paidMinor: Value(invoice.paidAmount.minorUnits),
                currency: invoice.total.currency.code,
                notes: Value(invoice.notes),
                terms: Value(invoice.terms),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 2. Insert invoice line items
        for (final item in invoice.items) {
          final itemId = item.id.isEmpty ? _uuid.v4() : item.id;
          await _db
              .into(_db.invoiceItemsTable)
              .insert(
                InvoiceItemsTableCompanion.insert(
                  id: itemId,
                  invoiceId: invId,
                  productId: Value(item.productId),
                  description: item.description,
                  quantity: item.quantity,
                  unitPriceMinor: item.unitPrice.minorUnits,
                  discountMinor: Value(item.discount.minorUnits),
                  taxMinor: Value(item.tax.minorUnits),
                  totalMinor: item.total.minorUnits,
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          // 3. Stock movement: sale deducts, purchase adds
          if (invoice.type == InvoiceType.purchase && item.productId != null) {
            final product = await (_db.select(
              _db.productsTable,
            )..where((t) => t.id.equals(item.productId!))).getSingleOrNull();
            if (product != null) {
              final newStock = (product.currentStock + item.quantity).clamp(
                0.0,
                99999999.0,
              );
              await (_db.update(
                _db.productsTable,
              )..where((t) => t.id.equals(product.id))).write(
                ProductsTableCompanion(
                  currentStock: Value(newStock),
                  updatedAt: Value(now),
                ),
              );

              await _db
                  .into(_db.inventoryLogsTable)
                  .insert(
                    InventoryLogsTableCompanion.insert(
                      id: _uuid.v4(),
                      productId: product.id,
                      changeQuantity: item.quantity,
                      movementType: InventoryMovementType.purchase.code,
                      referenceId: Value(invId),
                      costPerUnitMinor: Value(item.unitPrice.minorUnits),
                      notes: Value('فاکتور خرید $invId'),
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
            }
          }

          // 3b. Deduct product inventory if sale invoice
          if (invoice.type == InvoiceType.sale && item.productId != null) {
            final product = await (_db.select(
              _db.productsTable,
            )..where((t) => t.id.equals(item.productId!))).getSingleOrNull();
            if (product != null) {
              final newStock = (product.currentStock - item.quantity).clamp(
                0.0,
                99999999.0,
              );
              await (_db.update(
                _db.productsTable,
              )..where((t) => t.id.equals(product.id))).write(
                ProductsTableCompanion(
                  currentStock: Value(newStock),
                  updatedAt: Value(now),
                ),
              );

              await _db
                  .into(_db.inventoryLogsTable)
                  .insert(
                    InventoryLogsTableCompanion.insert(
                      id: _uuid.v4(),
                      productId: product.id,
                      changeQuantity: -item.quantity,
                      movementType: InventoryMovementType.sale.code,
                      referenceId: Value(invId),
                      costPerUnitMinor: Value(product.purchasePriceMinor),
                      notes: Value('فاکتور فروش $invId'),
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
            }
          }
        }

        // 4. Update contact balance if sale invoice
        if (invoice.type == InvoiceType.sale &&
            invoice.remainingBalance.minorUnits > 0) {
          final contact = await (_db.select(
            _db.businessContactsTable,
          )..where((t) => t.id.equals(invoice.contactId))).getSingleOrNull();
          if (contact != null) {
            final newBalance =
                contact.outstandingBalanceMinor +
                invoice.remainingBalance.minorUnits;
            await (_db.update(
              _db.businessContactsTable,
            )..where((t) => t.id.equals(contact.id))).write(
              BusinessContactsTableCompanion(
                outstandingBalanceMinor: Value(newBalance),
                updatedAt: Value(now),
              ),
            );
          }
        }

        // 5. Outbox Sync Record
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'invoices',
                entityId: invId,
                operation: 'INSERT',
                payloadJson:
                    '{"id":"$invId","number":"${invoice.invoiceNumber}","total":${invoice.total.minorUnits}}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return Success(invoice.copyWith(id: invId));
    } catch (e) {
      return DatabaseFailure('ثبت فاکتور انجام نشد.').asFailure();
    }
  }

  // ── Invoice side-effects unification (P0-3) ──
  Future<void> _voidLinkedVouchers(String invoiceId, int now) async {
    // Invoice voucher + every payment voucher issued against the invoice
    // (referenceType 'invoice-payment', referenceId = invoice id).
    final vouchers =
        await (_db.select(_db.accountingDocumentsTable)..where(
              (t) =>
                  t.referenceId.equals(invoiceId) &
                  t.referenceType.isIn(const ['invoice', 'invoice-payment']) &
                  t.deletedAt.isNull(),
            ))
            .get();
    for (final v in vouchers) {
      await (_db.update(
        _db.accountingDocumentsTable,
      )..where((t) => t.id.equals(v.id))).write(
        AccountingDocumentsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (_db.delete(
        _db.accountingDocumentDetailLinksTable,
      )..where((t) => t.documentId.equals(v.id))).go();
      await _db
          .into(_db.accountingAuditLogsTable)
          .insert(
            AccountingAuditLogsTableCompanion.insert(
              id: _uuid.v4(),
              entityType: 'document',
              entityId: v.id,
              action: 'delete',
              beforeJson: Value('{"invoiceId":"$invoiceId"}'),
              description: Value('ابطال خودکار سند فاکتور $invoiceId'),
              performedAt: now,
              createdAt: now,
            ),
          );
    }
  }

  Future<void> _reverseInvoiceEffects({
    required String invoiceId,
    required String invoiceType,
    required String contactId,
    required int totalMinor,
    required int paidMinor,
    required List<InvoiceItemData> items,
    required int now,
    String reason = 'برگشت فاکتور',
  }) async {
    if (invoiceType == InvoiceType.sale.code) {
      for (final item in items) {
        if (item.productId == null) continue;
        final product = await (_db.select(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(item.productId!))).getSingleOrNull();
        if (product == null) continue;

        final restored = (product.currentStock + item.quantity).clamp(
          0.0,
          99999999.0,
        );
        await (_db.update(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(product.id))).write(
          ProductsTableCompanion(
            currentStock: Value(restored),
            updatedAt: Value(now),
          ),
        );
        await _db
            .into(_db.inventoryLogsTable)
            .insert(
              InventoryLogsTableCompanion.insert(
                id: _uuid.v4(),
                productId: product.id,
                changeQuantity: item.quantity,
                movementType: InventoryMovementType.returned.code,
                referenceId: Value(invoiceId),
                costPerUnitMinor: Value(product.purchasePriceMinor),
                notes: Value('$reason فروش'),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final unpaid = (totalMinor - paidMinor).clamp(0, 1 << 62);
      if (unpaid > 0) {
        final contact = await (_db.select(
          _db.businessContactsTable,
        )..where((tbl) => tbl.id.equals(contactId))).getSingleOrNull();
        if (contact != null) {
          final reverted = (contact.outstandingBalanceMinor - unpaid).clamp(
            0,
            double.maxFinite.toInt(),
          );
          await (_db.update(
            _db.businessContactsTable,
          )..where((tbl) => tbl.id.equals(contact.id))).write(
            BusinessContactsTableCompanion(
              outstandingBalanceMinor: Value(reverted),
              updatedAt: Value(now),
            ),
          );
        }
      }
    } else if (invoiceType == InvoiceType.purchase.code) {
      for (final item in items) {
        if (item.productId == null) continue;
        final product = await (_db.select(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(item.productId!))).getSingleOrNull();
        if (product == null) continue;

        final restored = (product.currentStock - item.quantity).clamp(
          0.0,
          99999999.0,
        );
        await (_db.update(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(product.id))).write(
          ProductsTableCompanion(
            currentStock: Value(restored),
            updatedAt: Value(now),
          ),
        );
        await _db
            .into(_db.inventoryLogsTable)
            .insert(
              InventoryLogsTableCompanion.insert(
                id: _uuid.v4(),
                productId: product.id,
                changeQuantity: -item.quantity,
                movementType: InventoryMovementType.returned.code,
                referenceId: Value(invoiceId),
                costPerUnitMinor: Value(product.purchasePriceMinor),
                notes: Value('$reason خرید'),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    }

    await _voidLinkedVouchers(invoiceId, now);
  }

  Future<void> _applyInvoiceEffects({
    required String invoiceId,
    required InvoiceType type,
    required String contactId,
    required int remainingMinor,
    required List<InvoiceItemEntity> items,
    required int now,
    String reason = 'فاکتور',
  }) async {
    if (type == InvoiceType.sale) {
      for (final item in items) {
        if (item.productId == null) continue;
        final product = await (_db.select(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(item.productId!))).getSingleOrNull();
        if (product == null) continue;

        final newStock = (product.currentStock - item.quantity).clamp(
          0.0,
          99999999.0,
        );
        await (_db.update(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(product.id))).write(
          ProductsTableCompanion(
            currentStock: Value(newStock),
            updatedAt: Value(now),
          ),
        );
        await _db
            .into(_db.inventoryLogsTable)
            .insert(
              InventoryLogsTableCompanion.insert(
                id: _uuid.v4(),
                productId: product.id,
                changeQuantity: -item.quantity,
                movementType: InventoryMovementType.sale.code,
                referenceId: Value(invoiceId),
                costPerUnitMinor: Value(product.purchasePriceMinor),
                notes: Value('$reason فروش'),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      if (remainingMinor > 0) {
        final contact = await (_db.select(
          _db.businessContactsTable,
        )..where((tbl) => tbl.id.equals(contactId))).getSingleOrNull();
        if (contact != null) {
          await (_db.update(
            _db.businessContactsTable,
          )..where((tbl) => tbl.id.equals(contact.id))).write(
            BusinessContactsTableCompanion(
              outstandingBalanceMinor: Value(
                contact.outstandingBalanceMinor + remainingMinor,
              ),
              updatedAt: Value(now),
            ),
          );
        }
      }
    } else if (type == InvoiceType.purchase) {
      for (final item in items) {
        if (item.productId == null) continue;
        final product = await (_db.select(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(item.productId!))).getSingleOrNull();
        if (product == null) continue;

        final newStock = (product.currentStock + item.quantity).clamp(
          0.0,
          99999999.0,
        );
        await (_db.update(
          _db.productsTable,
        )..where((tbl) => tbl.id.equals(product.id))).write(
          ProductsTableCompanion(
            currentStock: Value(newStock),
            updatedAt: Value(now),
          ),
        );
        await _db
            .into(_db.inventoryLogsTable)
            .insert(
              InventoryLogsTableCompanion.insert(
                id: _uuid.v4(),
                productId: product.id,
                changeQuantity: item.quantity,
                movementType: InventoryMovementType.purchase.code,
                referenceId: Value(invoiceId),
                costPerUnitMinor: Value(item.unitPrice.minorUnits),
                notes: Value('$reason خرید'),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    }
  }

  @override
  /// Full invoice EDIT (اصلاح فاکتور): reverses ALL side effects of the old
  /// version (stock returns, customer balance, purchase quantities), replaces line items,
  /// then applies the new version's effects. Payment state (paidMinor/status) is
  /// preserved — payments are a separate flow.
  Future<Result<InvoiceEntity>> updateInvoice(InvoiceEntity invoice) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final old = await (_db.select(
          _db.invoicesTable,
        )..where((tbl) => tbl.id.equals(invoice.id))).getSingleOrNull();
        if (old == null || old.deletedAt != null) {
          throw StateError('فاکتور پیدا نشد.');
        }

        // ── 1. Reverse the OLD side effects (if old was not cancelled) ──
        if (old.status != InvoiceStatus.cancelled.code) {
          final oldItems =
              await (_db.select(_db.invoiceItemsTable)..where(
                    (tbl) =>
                        tbl.invoiceId.equals(invoice.id) &
                        tbl.deletedAt.isNull(),
                  ))
                  .get();
          await _reverseInvoiceEffects(
            invoiceId: invoice.id,
            invoiceType: old.type,
            contactId: old.contactId,
            totalMinor: old.totalMinor,
            paidMinor: old.paidMinor,
            items: oldItems,
            now: now,
            reason: 'اصلاح فاکتور',
          );
        }

        // ── 2. Replace line items ──
        await (_db.delete(
          _db.invoiceItemsTable,
        )..where((tbl) => tbl.invoiceId.equals(invoice.id))).go();

        // ── 3. Apply the NEW side effects (if new is not cancelled) ──
        if (invoice.status != InvoiceStatus.cancelled) {
          await _applyInvoiceEffects(
            invoiceId: invoice.id,
            type: invoice.type,
            contactId: invoice.contactId,
            remainingMinor: invoice.remainingBalance.minorUnits,
            items: invoice.items,
            now: now,
            reason: 'اصلاح فاکتور',
          );
        }

        // ── 4. Update header ──
        await (_db.update(
          _db.invoicesTable,
        )..where((tbl) => tbl.id.equals(invoice.id))).write(
          InvoicesTableCompanion(
            invoiceNumber: Value(invoice.invoiceNumber),
            contactId: Value(invoice.contactId),
            type: Value(invoice.type.code),
            issueDate: Value(invoice.issueDate.millisecondsSinceEpoch),
            dueDate: Value(invoice.dueDate.millisecondsSinceEpoch),
            subtotalMinor: Value(invoice.subtotal.minorUnits),
            discountMinor: Value(invoice.discount.minorUnits),
            taxMinor: Value(invoice.tax.minorUnits),
            totalMinor: Value(invoice.total.minorUnits),
            notes: Value(invoice.notes),
            terms: Value(invoice.terms),
            updatedAt: Value(now),
          ),
        );

        // ── 5. Insert new line items ──
        for (final item in invoice.items) {
          final itemId = item.id.isEmpty ? _uuid.v4() : item.id;
          await _db
              .into(_db.invoiceItemsTable)
              .insert(
                InvoiceItemsTableCompanion.insert(
                  id: itemId,
                  invoiceId: invoice.id,
                  productId: Value(item.productId),
                  description: item.description,
                  quantity: item.quantity,
                  unitPriceMinor: item.unitPrice.minorUnits,
                  discountMinor: Value(item.discount.minorUnits),
                  taxMinor: Value(item.tax.minorUnits),
                  totalMinor: item.total.minorUnits,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        // ── 6. Outbox ──
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'invoices',
                entityId: invoice.id,
                operation: 'UPDATE',
                payloadJson:
                    '{"id":"${invoice.id}","total":${invoice.total.minorUnits},"edited":true}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      final updated = await getInvoiceById(invoice.id);
      final entity = updated.dataOrNull;
      if (entity == null) {
        return DatabaseFailure('خواندن فاکتور اصلاح‌شده انجام نشد.')
            .asFailure();
      }
      return Success(entity);
    } catch (e) {
      if (e is StateError) {
        return DatabaseFailure(e.message).asFailure();
      }
      return DatabaseFailure('اصلاح فاکتور انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateInvoiceStatus(
    String id,
    InvoiceStatus status,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        final invoice = await (_db.select(
          _db.invoicesTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (invoice == null || invoice.deletedAt != null) {
          throw StateError('فاکتور پیدا نشد.');
        }

        final oldStatus = invoice.status;
        if (oldStatus == status.code) return;

        // When changing to cancelled: reverse stock and contact balance and void voucher!
        if (status == InvoiceStatus.cancelled &&
            oldStatus != InvoiceStatus.cancelled.code) {
          final items = await (_db.select(
            _db.invoiceItemsTable,
          )..where((t) => t.invoiceId.equals(id) & t.deletedAt.isNull())).get();
          await _reverseInvoiceEffects(
            invoiceId: id,
            invoiceType: invoice.type,
            contactId: invoice.contactId,
            totalMinor: invoice.totalMinor,
            paidMinor: invoice.paidMinor,
            items: items,
            now: now,
            reason: 'لغو فاکتور',
          );
        } else if (oldStatus == InvoiceStatus.cancelled.code &&
            status != InvoiceStatus.cancelled) {
          // Re-activating from cancelled: re-apply effects
          final cur = Currency.fromCode(invoice.currency);
          final itemsData = await (_db.select(
            _db.invoiceItemsTable,
          )..where((t) => t.invoiceId.equals(id) & t.deletedAt.isNull())).get();
          final items = itemsData.map((it) => _toItemEntity(it, cur)).toList();
          final remainingMinor = (invoice.totalMinor - invoice.paidMinor).clamp(
            0,
            1 << 62,
          );
          await _applyInvoiceEffects(
            invoiceId: id,
            type: InvoiceType.fromCode(invoice.type),
            contactId: invoice.contactId,
            remainingMinor: remainingMinor,
            items: items,
            now: now,
            reason: 'فعال‌سازی مجدد فاکتور',
          );
        }

        await (_db.update(
          _db.invoicesTable,
        )..where((t) => t.id.equals(id))).write(
          InvoicesTableCompanion(
            status: Value(status.code),
            updatedAt: Value(now),
          ),
        );

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'invoices',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: '{"id":"$id","status":"${status.code}"}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش وضعیت فاکتور انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> recordInvoicePayment(
    String id,
    Money paymentAmount,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final invoice = await (_db.select(
          _db.invoicesTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (invoice == null) throw Exception('Invoice not found');

        final newPaid = invoice.paidMinor + paymentAmount.minorUnits;
        final isCompleted = newPaid >= invoice.totalMinor;
        final newStatus = isCompleted
            ? InvoiceStatus.paid.code
            : InvoiceStatus.partiallyPaid.code;

        await (_db.update(
          _db.invoicesTable,
        )..where((t) => t.id.equals(id))).write(
          InvoicesTableCompanion(
            paidMinor: Value(newPaid),
            status: Value(newStatus),
            updatedAt: Value(now),
          ),
        );

        // Reduce contact outstanding balance
        final contact = await (_db.select(
          _db.businessContactsTable,
        )..where((t) => t.id.equals(invoice.contactId))).getSingleOrNull();
        if (contact != null) {
          final newContactBalance =
              (contact.outstandingBalanceMinor - paymentAmount.minorUnits)
                  .clamp(0, double.maxFinite.toInt());
          await (_db.update(
            _db.businessContactsTable,
          )..where((t) => t.id.equals(contact.id))).write(
            BusinessContactsTableCompanion(
              outstandingBalanceMinor: Value(newContactBalance),
              updatedAt: Value(now),
            ),
          );
        }

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'invoices',
                entityId: id,
                operation: 'UPDATE',
                payloadJson:
                    '{"id":"$id","payment":${paymentAmount.minorUnits},"newPaid":$newPaid}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ثبت پرداخت انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<void>> deleteInvoice(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final invoice = await (_db.select(
          _db.invoicesTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (invoice == null || invoice.deletedAt != null) return;

        await (_db.update(
          _db.invoicesTable,
        )..where((t) => t.id.equals(id))).write(
          InvoicesTableCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );

        await (_db.update(
          _db.invoiceItemsTable,
        )..where((t) => t.invoiceId.equals(id))).write(
          InvoiceItemsTableCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // Reverse side effects (stock + customer balance) if invoice was not already cancelled
        if (invoice.status != InvoiceStatus.cancelled.code) {
          final items = await (_db.select(
            _db.invoiceItemsTable,
          )..where((t) => t.invoiceId.equals(id))).get();
          await _reverseInvoiceEffects(
            invoiceId: id,
            invoiceType: invoice.type,
            contactId: invoice.contactId,
            totalMinor: invoice.totalMinor,
            paidMinor: invoice.paidMinor,
            items: items,
            now: now,
            reason: 'حذف فاکتور',
          );
        } else {
          await _voidLinkedVouchers(id, now);
        }

        // Outbox DELETE sync record
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'invoices',
                entityId: id,
                operation: 'DELETE',
                payloadJson: '{"id":"$id"}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف فاکتور انجام نشد.').asFailure();
    }
  }

  // ----------------------------------------------------
  // METRICS STREAM
  // ----------------------------------------------------
  @override
  /// کاردکس — chronological stock card for one product with running balance.
  Future<List<ProductCardEntry>> getProductCard(String productId) async {
    try {
      final logs =
          await (_db.select(_db.inventoryLogsTable)..where(
                (tbl) =>
                    tbl.productId.equals(productId) & tbl.deletedAt.isNull(),
              ))
              .get();
      final sorted = logs..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      double running = 0;

      final entries = <ProductCardEntry>[];
      for (final log in sorted) {
        running += log.changeQuantity;
        entries.add(
          ProductCardEntry(
            date: DateTime.fromMillisecondsSinceEpoch(log.createdAt),
            movementType: InventoryMovementType.fromCode(log.movementType),
            description: log.notes ?? '',
            inQuantity: log.changeQuantity > 0 ? log.changeQuantity : 0,
            outQuantity: log.changeQuantity < 0 ? -log.changeQuantity : 0,
            balance: running,
            referenceId: log.referenceId,
          ),
        );
      }
      return entries;
    } catch (e) {
      throw StateError('خواندن کاردکس انجام نشد.');
    }
  }

  @override
  Stream<BusinessMetricsEntity> watchBusinessMetrics() {
    final currency = Currency.fromCode(AppConstants.defaultCurrencyCode);

    return Rx.combineLatest2(
      watchInvoices(type: InvoiceType.sale),
      watchProducts(),
      (List<InvoiceEntity> salesInvoices, List<ProductEntity> products) {
        int totalSalesMinor = 0;
        int unpaidMinor = 0;

        for (final inv in salesInvoices) {
          totalSalesMinor += inv.total.minorUnits;
          unpaidMinor += inv.remainingBalance.minorUnits;
        }

        final lowStock = products.where((p) => p.isLowStock).toList();

        return BusinessMetricsEntity(
          totalSales: Money.fromMinor(totalSalesMinor, currency),
          unpaidReceivables: Money.fromMinor(unpaidMinor, currency),
          activeProductsCount: products.length,
          lowStockCount: lowStock.length,
          totalInvoicesCount: salesInvoices.length,
          lowStockProducts: lowStock,
        );
      },
    );
  }

  // ----------------------------------------------------
  // SEED DEFAULT BUSINESS DATA
  // ----------------------------------------------------
}
