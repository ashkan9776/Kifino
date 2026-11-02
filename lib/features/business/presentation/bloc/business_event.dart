import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/business_metrics_entity.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/inventory_log_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/product_entity.dart';

sealed class BusinessEvent extends Equatable {
  const BusinessEvent();

  @override
  List<Object?> get props => [];
}

final class WatchBusinessDataStarted extends BusinessEvent {
  const WatchBusinessDataStarted();
}

final class BusinessDataUpdated extends BusinessEvent {
  final BusinessMetricsEntity metrics;
  final List<InvoiceEntity> invoices;
  final List<ProductEntity> products;
  final List<ContactEntity> contacts;

  const BusinessDataUpdated({
    required this.metrics,
    required this.invoices,
    required this.products,
    required this.contacts,
  });

  @override
  List<Object?> get props => [metrics, invoices, products, contacts];
}

final class BusinessContactCreateSubmitted extends BusinessEvent {
  final ContactEntity contact;
  const BusinessContactCreateSubmitted(this.contact);

  @override
  List<Object?> get props => [contact];
}

final class BusinessProductCreateSubmitted extends BusinessEvent {
  final ProductEntity product;
  const BusinessProductCreateSubmitted(this.product);

  @override
  List<Object?> get props => [product];
}

final class BusinessStockAdjustSubmitted extends BusinessEvent {
  final String productId;
  final double changeQuantity;
  final InventoryMovementType type;
  final String? notes;

  const BusinessStockAdjustSubmitted({
    required this.productId,
    required this.changeQuantity,
    required this.type,
    this.notes,
  });

  @override
  List<Object?> get props => [productId, changeQuantity, type, notes];
}

final class BusinessInvoiceCreateSubmitted extends BusinessEvent {
  final InvoiceEntity invoice;
  const BusinessInvoiceCreateSubmitted(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

final class BusinessInvoicePaymentSubmitted extends BusinessEvent {
  final String invoiceId;
  final Money paymentAmount;

  const BusinessInvoicePaymentSubmitted({
    required this.invoiceId,
    required this.paymentAmount,
  });

  @override
  List<Object?> get props => [invoiceId, paymentAmount];
}

final class BusinessInvoiceStatusUpdated extends BusinessEvent {
  final String invoiceId;
  final InvoiceStatus status;

  const BusinessInvoiceStatusUpdated({
    required this.invoiceId,
    required this.status,
  });

  @override
  List<Object?> get props => [invoiceId, status];
}
