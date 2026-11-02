import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum GoalStatus {
  active('active'),
  achieved('achieved'),
  cancelled('cancelled');

  final String code;
  const GoalStatus(this.code);

  static GoalStatus fromCode(String code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return GoalStatus.active;
  }
}

class GoalEntity extends Equatable {
  final String id;
  final String name;
  final Money targetAmount;
  final Money currentAmount;
  final GoalStatus status;
  final DateTime? targetDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncStatus;
  final int version;

  const GoalEntity({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = const Money.zero(Currency.toman),
    this.status = GoalStatus.active,
    this.targetDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = 0,
    this.version = 1,
  });

  Money get remainingAmount {
    final diff = targetAmount.minorUnits - currentAmount.minorUnits;
    return Money.fromMinor(diff, targetAmount.currency);
  }

  /// 0-100, clamped.
  double get progressPercent {
    if (targetAmount.minorUnits <= 0) return 0.0;
    final percent = (currentAmount.minorUnits / targetAmount.minorUnits) * 100;
    return percent.clamp(0.0, 100.0);
  }

  bool get isAchieved => status == GoalStatus.achieved;
  bool get isDeleted => deletedAt != null;

  GoalEntity copyWith({
    String? id,
    String? name,
    Money? targetAmount,
    Money? currentAmount,
    GoalStatus? status,
    DateTime? targetDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncStatus,
    int? version,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      status: status ?? this.status,
      targetDate: targetDate ?? this.targetDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    targetAmount,
    currentAmount,
    status,
    targetDate,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
