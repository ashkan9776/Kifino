import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum BudgetPeriodType {
  monthly('monthly', 'ماهانه'),
  weekly('weekly', 'هفتگی'),
  custom('custom', 'سفارشی');

  final String code;
  final String titleFa;
  const BudgetPeriodType(this.code, this.titleFa);

  static BudgetPeriodType fromCode(String code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return BudgetPeriodType.monthly;
  }
}

class BudgetEntity extends Equatable {
  final String id;
  final String name;
  final Money amountLimit;
  final Money amountSpent;
  final BudgetPeriodType periodType;
  final DateTime startDate;
  final DateTime endDate;
  final double alertThresholdPercent;
  final List<String> categoryIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const BudgetEntity({
    required this.id,
    required this.name,
    required this.amountLimit,
    required this.amountSpent,
    this.periodType = BudgetPeriodType.monthly,
    required this.startDate,
    required this.endDate,
    this.alertThresholdPercent = 80.0,
    this.categoryIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  double get usagePercent {
    if (amountLimit.minorUnits <= 0) return 0.0;
    return (amountSpent.minorUnits / amountLimit.minorUnits) * 100;
  }

  Money get remainingAmount {
    final diff = amountLimit.minorUnits - amountSpent.minorUnits;
    return Money.fromMinor(diff, amountLimit.currency);
  }

  bool get isOverBudget => amountSpent > amountLimit;
  bool get isNearLimit =>
      usagePercent >= alertThresholdPercent && !isOverBudget;
  bool get isDeleted => deletedAt != null;

  BudgetEntity copyWith({
    String? id,
    String? name,
    Money? amountLimit,
    Money? amountSpent,
    BudgetPeriodType? periodType,
    DateTime? startDate,
    DateTime? endDate,
    double? alertThresholdPercent,
    List<String>? categoryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return BudgetEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      amountLimit: amountLimit ?? this.amountLimit,
      amountSpent: amountSpent ?? this.amountSpent,
      periodType: periodType ?? this.periodType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      alertThresholdPercent:
          alertThresholdPercent ?? this.alertThresholdPercent,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    amountLimit,
    amountSpent,
    periodType,
    startDate,
    endDate,
    alertThresholdPercent,
    categoryIds,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
