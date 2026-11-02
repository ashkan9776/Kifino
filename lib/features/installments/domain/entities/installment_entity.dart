import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum InstallmentStatus {
  ongoing('ongoing', 'در حال پرداخت'),
  completed('completed', 'تکمیل شده'),
  overdue('overdue', 'دارای قسط معوق');

  final String code;
  final String titleFa;
  const InstallmentStatus(this.code, this.titleFa);

  static InstallmentStatus fromCode(String code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return InstallmentStatus.ongoing;
  }
}

class InstallmentEntity extends Equatable {
  final String id;
  final String title;
  final String accountId;
  final Money totalAmount;
  final int numberOfInstallments;
  final int paidInstallmentsCount;
  final Money installmentAmount;
  final DateTime startDate;
  final int recurrenceIntervalDays;
  final DateTime nextDueDate;
  final InstallmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const InstallmentEntity({
    required this.id,
    required this.title,
    required this.accountId,
    required this.totalAmount,
    required this.numberOfInstallments,
    this.paidInstallmentsCount = 0,
    required this.installmentAmount,
    required this.startDate,
    this.recurrenceIntervalDays = 30,
    required this.nextDueDate,
    this.status = InstallmentStatus.ongoing,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  int get remainingInstallmentsCount =>
      (numberOfInstallments - paidInstallmentsCount).clamp(
        0,
        numberOfInstallments,
      );

  Money get paidAmount {
    final paidMinor = paidInstallmentsCount * installmentAmount.minorUnits;
    return Money.fromMinor(paidMinor, totalAmount.currency);
  }

  Money get remainingAmount {
    final remMinor = totalAmount.minorUnits - paidAmount.minorUnits;
    return Money.fromMinor(remMinor > 0 ? remMinor : 0, totalAmount.currency);
  }

  double get progressPercent {
    if (numberOfInstallments <= 0) return 100.0;
    return ((paidInstallmentsCount / numberOfInstallments) * 100).clamp(
      0.0,
      100.0,
    );
  }

  bool get isCompleted =>
      status == InstallmentStatus.completed ||
      paidInstallmentsCount >= numberOfInstallments;

  bool get isDeleted => deletedAt != null;

  InstallmentEntity copyWith({
    String? id,
    String? title,
    String? accountId,
    Money? totalAmount,
    int? numberOfInstallments,
    int? paidInstallmentsCount,
    Money? installmentAmount,
    DateTime? startDate,
    int? recurrenceIntervalDays,
    DateTime? nextDueDate,
    InstallmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return InstallmentEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      accountId: accountId ?? this.accountId,
      totalAmount: totalAmount ?? this.totalAmount,
      numberOfInstallments: numberOfInstallments ?? this.numberOfInstallments,
      paidInstallmentsCount:
          paidInstallmentsCount ?? this.paidInstallmentsCount,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      startDate: startDate ?? this.startDate,
      recurrenceIntervalDays:
          recurrenceIntervalDays ?? this.recurrenceIntervalDays,
      nextDueDate: nextDueDate ?? this.nextDueDate,
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
    title,
    accountId,
    totalAmount,
    numberOfInstallments,
    paidInstallmentsCount,
    installmentAmount,
    startDate,
    recurrenceIntervalDays,
    nextDueDate,
    status,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
