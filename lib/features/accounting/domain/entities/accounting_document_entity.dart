import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import 'accounting_transaction_entity.dart';

enum DocumentStatus {
  draft('draft'),
  approved('approved'),
  posted('posted');

  final String code;
  const DocumentStatus(this.code);

  static DocumentStatus fromCode(String code) {
    return DocumentStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => DocumentStatus.draft,
    );
  }

  String get titleFa => switch (this) {
    DocumentStatus.draft => 'پیش‌نویس / موقت',
    DocumentStatus.approved => 'تأیید شده',
    DocumentStatus.posted => 'ثبت قطعی / دائم',
  };
}

class AccountingDocumentEntity extends Equatable {
  final String id;
  final int number;
  final DateTime date;
  final String title;
  final DocumentStatus status;
  final bool isManual;
  final String? referenceType;
  final String? referenceId;
  final String? fiscalYearId;
  final DateTime? approvedAt;
  final List<AccountingTransactionEntity> transactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountingDocumentEntity({
    required this.id,
    required this.number,
    required this.date,
    required this.title,
    this.status = DocumentStatus.draft,
    this.isManual = true,
    this.referenceType,
    this.referenceId,
    this.fiscalYearId,
    this.approvedAt,
    this.transactions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Money get totalDebit {
    int total = 0;
    for (final tx in transactions) {
      total += tx.debit.minorUnits;
    }
    return Money.fromMinor(total);
  }

  Money get totalCredit {
    int total = 0;
    for (final tx in transactions) {
      total += tx.credit.minorUnits;
    }
    return Money.fromMinor(total);
  }

  bool get isBalanced => totalDebit.minorUnits == totalCredit.minorUnits;

  Money get imbalanceDifference {
    return Money.fromMinor(
      (totalDebit.minorUnits - totalCredit.minorUnits).abs(),
    );
  }

  AccountingDocumentEntity copyWith({
    String? id,
    int? number,
    DateTime? date,
    String? title,
    DocumentStatus? status,
    bool? isManual,
    String? referenceType,
    String? referenceId,
    String? fiscalYearId,
    DateTime? approvedAt,
    List<AccountingTransactionEntity>? transactions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountingDocumentEntity(
      id: id ?? this.id,
      number: number ?? this.number,
      date: date ?? this.date,
      title: title ?? this.title,
      status: status ?? this.status,
      isManual: isManual ?? this.isManual,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      fiscalYearId: fiscalYearId ?? this.fiscalYearId,
      approvedAt: approvedAt ?? this.approvedAt,
      transactions: transactions ?? this.transactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    number,
    date,
    title,
    status,
    isManual,
    referenceType,
    referenceId,
    fiscalYearId,
    approvedAt,
    transactions,
  ];
}
