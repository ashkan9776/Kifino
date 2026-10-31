import 'package:equatable/equatable.dart';
import '../../../../core/utils/money.dart';

enum InventoryMovementType {
  purchase('purchase'),
  sale('sale'),
  adjustment('adjustment'),
  returned('return'),
  loss('loss');

  final String code;
  const InventoryMovementType(this.code);

  static InventoryMovementType fromCode(String code) {
    return InventoryMovementType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => InventoryMovementType.adjustment,
    );
  }

  String get titleFa => switch (this) {
        InventoryMovementType.purchase => 'خرید (افزایش موجودی)',
        InventoryMovementType.sale => 'فروش (کاهش موجودی)',
        InventoryMovementType.adjustment => 'اصلاح دستی موجودی',
        InventoryMovementType.returned => 'مرجوعی به انبار',
        InventoryMovementType.loss => 'ضایعات و کسری',
      };
}

class InventoryLogEntity extends Equatable {
  final String id;
  final String productId;
  final String? productName;
  final double changeQuantity;
  final InventoryMovementType movementType;
  final String? referenceId; // invoiceId or orderId
  final Money? costPerUnit;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const InventoryLogEntity({
    required this.id,
    required this.productId,
    this.productName,
    required this.changeQuantity,
    required this.movementType,
    this.referenceId,
    this.costPerUnit,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        changeQuantity,
        movementType,
        referenceId,
        costPerUnit,
        notes,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
