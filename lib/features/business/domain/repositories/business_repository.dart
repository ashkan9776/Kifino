import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../entities/business_metrics_entity.dart';
import '../entities/contact_entity.dart';
import '../entities/inventory_log_entity.dart';
import '../entities/aging_report_entity.dart';
import '../entities/invoice_entity.dart';
import '../entities/product_card_entity.dart';
import '../entities/product_entity.dart';

abstract interface class BusinessRepository {
  // Contacts
  Stream<List<ContactEntity>> watchContacts({ContactType? type});
  Future<Result<List<ContactEntity>>> getContacts({ContactType? type});
  Future<Result<ContactEntity>> createContact(ContactEntity contact);
  Future<Result<void>> updateContact(ContactEntity contact);
  Future<Result<void>> deleteContact(String id);

  // Products
  Stream<List<ProductEntity>> watchProducts();
  Future<Result<List<ProductEntity>>> getProducts();
  Future<Result<ProductEntity>> createProduct(ProductEntity product);
  Future<Result<void>> updateProduct(ProductEntity product);
  Future<Result<void>> adjustStock({
    required String productId,
    required double changeQuantity,
    required InventoryMovementType type,
    String? notes,
    String? referenceId,
  });
  Stream<List<InventoryLogEntity>> watchInventoryLogs({String? productId});

  // Invoices
  Stream<List<InvoiceEntity>> watchInvoices({InvoiceType? type});
  Future<Result<List<InvoiceEntity>>> getInvoices({InvoiceType? type});

  /// Converts a quote (پیش‌فاکتور) into a real SALE invoice: header copied,
  /// items re-created, effects (stock + customer balance) applied via the
  /// regular sale path, quote left intact for reference.
  Future<Result<InvoiceEntity>> convertQuoteToInvoice(String quoteId);

  /// گزارش سنی — open invoices bucketed by days past due, per contact.
  /// [receivables] true → sale invoices (what customers owe); false →
  /// purchase invoices (what we owe suppliers).
  Future<Result<List<ContactAgingEntry>>> getAgingReport({
    required bool receivables,
  });
  Future<Result<InvoiceEntity>> getInvoiceById(String id);
  Future<Result<InvoiceEntity>> createInvoice(InvoiceEntity invoice);
  Future<Result<InvoiceEntity>> updateInvoice(InvoiceEntity invoice);

  Future<Result<void>> updateInvoiceStatus(String id, InvoiceStatus status);
  Future<Result<void>> recordInvoicePayment(String id, Money paymentAmount);
  Future<Result<void>> deleteInvoice(String id);

  // Metrics
  Stream<BusinessMetricsEntity> watchBusinessMetrics();

  // Seeding

  /// کاردکس — chronological stock card with running balance.
  Future<List<ProductCardEntry>> getProductCard(String productId);
}
