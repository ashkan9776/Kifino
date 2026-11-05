import 'package:equatable/equatable.dart';

import '../../domain/entities/business_metrics_entity.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/product_entity.dart';

sealed class BusinessState extends Equatable {
  const BusinessState();

  @override
  List<Object?> get props => [];
}

final class BusinessInitial extends BusinessState {
  const BusinessInitial();
}

final class BusinessLoading extends BusinessState {
  const BusinessLoading();
}

final class BusinessLoaded extends BusinessState {
  final BusinessMetricsEntity metrics;
  final List<InvoiceEntity> invoices;
  final List<ProductEntity> products;
  final List<ContactEntity> contacts;

  const BusinessLoaded({
    required this.metrics,
    required this.invoices,
    required this.products,
    required this.contacts,
  });

  @override
  List<Object?> get props => [metrics, invoices, products, contacts];
}

final class BusinessError extends BusinessState {
  final String message;
  const BusinessError(this.message);

  @override
  List<Object?> get props => [message];
}

/// The business data is loaded, but the accounting voucher for [invoice]
/// could not be issued (e.g. closed fiscal period, missing subject).
/// EXTENDS [BusinessLoaded] so every consumer keeps rendering the full hub
/// data — the failure must never blank the screen; the warning is surfaced
/// by the hub's listener as a non-blocking snack.
final class BusinessInvoiceVoucherPending extends BusinessLoaded {
  final InvoiceEntity invoice;
  final String warningMessage;

  const BusinessInvoiceVoucherPending({
    required this.invoice,
    required this.warningMessage,
    required super.metrics,
    required super.invoices,
    required super.products,
    required super.contacts,
  });

  @override
  List<Object?> get props => [...super.props, invoice, warningMessage];
}
