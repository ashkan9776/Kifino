import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import 'product_entity.dart';

class BusinessMetricsEntity extends Equatable {
  final Money totalSales;
  final Money unpaidReceivables;
  final int activeProductsCount;
  final int lowStockCount;
  final int totalInvoicesCount;
  final List<ProductEntity> lowStockProducts;

  const BusinessMetricsEntity({
    required this.totalSales,
    required this.unpaidReceivables,
    required this.activeProductsCount,
    required this.lowStockCount,
    required this.totalInvoicesCount,
    this.lowStockProducts = const [],
  });

  @override
  List<Object?> get props => [
    totalSales,
    unpaidReceivables,
    activeProductsCount,
    lowStockCount,
    totalInvoicesCount,
    lowStockProducts,
  ];
}
