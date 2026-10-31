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
