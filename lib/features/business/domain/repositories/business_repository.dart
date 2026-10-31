import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../entities/business_metrics_entity.dart';
import '../entities/contact_entity.dart';
import '../entities/inventory_log_entity.dart';
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
  Future<Result<InvoiceEntity>> getInvoiceById(String id);
  Future<Result<InvoiceEntity>> createInvoice(InvoiceEntity invoice);
  Future<Result<void>> updateInvoiceStatus(String id, InvoiceStatus status);
  Future<Result<void>> recordInvoicePayment(String id, Money paymentAmount);
  Future<Result<void>> deleteInvoice(String id);

  // Metrics
  Stream<BusinessMetricsEntity> watchBusinessMetrics();

  // Seeding

  /// کاردکس — chronological stock card with running balance.
  Future<List<ProductCardEntry>> getProductCard(String productId);
}
