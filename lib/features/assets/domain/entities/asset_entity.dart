import 'package:equatable/equatable.dart';
import '../../../../core/utils/money.dart';

enum AssetCategory {
  gold('gold', 'طلا و سکه'),
  currency('currency', 'ارز نقدی'),
  crypto('crypto', 'رمزارز'),
  stock('stock', 'بورس و سهام'),
  property('property', 'ملک و زمین'),
  vehicle('vehicle', 'خودرو'),
  other('other', 'سایر دارایی‌ها');

  final String code;
  final String titleFa;
  const AssetCategory(this.code, this.titleFa);

  static AssetCategory fromCode(String code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return AssetCategory.other;
  }
}

class AssetEntity extends Equatable {
  final String id;
  final String name;
  final AssetCategory category;
  final double quantity;
  final String unit; // gram, coin, usd, piece, etc.
  final Money costBasis; // Cost of acquisition
  final Money currentValue; // Current market valuation
  final DateTime purchaseDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const AssetEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.costBasis,
    required this.currentValue,
    required this.purchaseDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Money get profitLossMoney {
    final diff = currentValue.minorUnits - costBasis.minorUnits;
    return Money.fromMinor(diff, currentValue.currency);
  }

  double get profitLossPercent {
    if (costBasis.minorUnits <= 0) return 0.0;
    final diff = currentValue.minorUnits - costBasis.minorUnits;
    return (diff / costBasis.minorUnits) * 100;
  }

  bool get isProfitable => currentValue >= costBasis;

  bool get isDeleted => deletedAt != null;

  AssetEntity copyWith({
    String? id,
    String? name,
    AssetCategory? category,
    double? quantity,
    String? unit,
    Money? costBasis,
    Money? currentValue,
    DateTime? purchaseDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return AssetEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      costBasis: costBasis ?? this.costBasis,
      currentValue: currentValue ?? this.currentValue,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        quantity,
        unit,
        costBasis,
        currentValue,
        purchaseDate,
        notes,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
