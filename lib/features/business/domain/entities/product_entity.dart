import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

class ProductEntity extends Equatable {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String unit;
  final String? secondaryUnit;
  final int conversionFactor;
  final Money purchasePrice;
  final Money sellingPrice;
  final double currentStock;
  final double lowStockThreshold;
  final String? supplierId;
  final String? supplierName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const ProductEntity({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.unit = 'عدد',
    this.secondaryUnit,
    this.conversionFactor = 1,
    required this.purchasePrice,
    required this.sellingPrice,
    this.currentStock = 0.0,
    this.lowStockThreshold = 5.0,
    this.supplierId,
    this.supplierName,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isLowStock => currentStock <= lowStockThreshold;

  Money get profitMargin => sellingPrice - purchasePrice;

  double get marginPercentage {
    if (purchasePrice.minorUnits == 0) return 100.0;
    return ((sellingPrice.minorUnits - purchasePrice.minorUnits) /
            purchasePrice.minorUnits) *
        100.0;
  }

  ProductEntity copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    String? unit,
    Money? purchasePrice,
    Money? sellingPrice,
    double? currentStock,
    double? lowStockThreshold,
    String? supplierId,
    String? supplierName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      secondaryUnit: secondaryUnit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    sku,
    barcode,
    description,
    unit,
    purchasePrice,
    sellingPrice,
    currentStock,
    lowStockThreshold,
    supplierId,
    supplierName,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
