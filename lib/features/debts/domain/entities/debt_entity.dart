import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum DebtType {
  debt('debt', 'بدهی من'),
  receivable('receivable', 'طلب من');

  final String code;
  final String titleFa;
  const DebtType(this.code, this.titleFa);

  static DebtType fromCode(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return DebtType.debt;
  }
}

enum DebtStatus {
  active('active', 'جاری'),
  settled('settled', 'تسویه شده'),
  overdue('overdue', 'سررسید گذشته'),
  writtenOff('writtenOff', 'سوخت شده');

  final String code;
  final String titleFa;
  const DebtStatus(this.code, this.titleFa);

  static DebtStatus fromCode(String code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return DebtStatus.active;
  }
}

class DebtEntity extends Equatable {
  final String id;
  final String contactName;
  final String? contactPhone;
  final DebtType type;
  final Money totalAmount;
  final Money paidAmount;
  final DateTime? dueDate;
  final DebtStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const DebtEntity({
    required this.id,
    required this.contactName,
    this.contactPhone,
    required this.type,
    required this.totalAmount,
    this.paidAmount = const Money.zero(Currency.irr),
    this.dueDate,
    this.status = DebtStatus.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Money get remainingAmount {
    final remainingMinor = totalAmount.minorUnits - paidAmount.minorUnits;
    return Money.fromMinor(
      remainingMinor > 0 ? remainingMinor : 0,
      totalAmount.currency,
    );
  }

  double get progressPercent {
    if (totalAmount.minorUnits <= 0) return 100.0;
    return ((paidAmount.minorUnits / totalAmount.minorUnits) * 100).clamp(
      0.0,
      100.0,
    );
  }

  bool get isSettled =>
      status == DebtStatus.settled || paidAmount >= totalAmount;

  bool get isOverdue {
    if (isSettled || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isDeleted => deletedAt != null;

  DebtEntity copyWith({
    String? id,
    String? contactName,
    String? contactPhone,
    DebtType? type,
    Money? totalAmount,
    Money? paidAmount,
    DateTime? dueDate,
    DebtStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DebtEntity(
      id: id ?? this.id,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      type: type ?? this.type,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    contactName,
    contactPhone,
    type,
    totalAmount,
    paidAmount,
    dueDate,
    status,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
