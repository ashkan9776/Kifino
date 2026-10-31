import 'package:equatable/equatable.dart';

import 'inventory_log_entity.dart';

/// One row of the کاردکس (stock card): chronological movements of a product
/// with the running balance after each movement.
class ProductCardEntry extends Equatable {
  final DateTime date;
  final InventoryMovementType movementType;
  final String description;
  final double inQuantity;
  final double outQuantity;
  final double balance;
  final String? referenceId;

  const ProductCardEntry({
    required this.date,
    required this.movementType,
    required this.description,
    required this.inQuantity,
    required this.outQuantity,
    required this.balance,
    this.referenceId,
  });

  @override
  List<Object?> get props => [
        date, movementType, description, inQuantity, outQuantity, balance, referenceId,
      ];
}
