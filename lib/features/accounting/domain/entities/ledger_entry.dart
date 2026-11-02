import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import 'accounting_subject_entity.dart';

class LedgerEntry extends Equatable {
  final int rowIndex;
  final String transactionId;
  final String documentId;
  final int documentNumber;
  final DateTime date;
  final String description;
  final Money debit;
  final Money credit;
  final Money runningBalance;
  final String balanceSide; // 'بد' (بدهکار), 'بس' (بستانکار), or '-'

  const LedgerEntry({
    required this.rowIndex,
    required this.transactionId,
    required this.documentId,
    required this.documentNumber,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    required this.balanceSide,
  });

  @override
  List<Object?> get props => [
    rowIndex,
    transactionId,
    documentId,
    documentNumber,
    date,
    description,
    debit,
    credit,
    runningBalance,
    balanceSide,
  ];
}

class LedgerReport extends Equatable {
  final AccountingSubjectEntity subject;
  final Money openingBalance;
  final String openingSide; // 'بد' or 'بس'
  final List<LedgerEntry> entries;
  final DateTime? startDate;
  final DateTime? endDate;

  const LedgerReport({
    required this.subject,
    required this.openingBalance,
    required this.openingSide,
    required this.entries,
    this.startDate,
    this.endDate,
  });

  Money get sumDebit =>
      Money.fromMinor(entries.fold(0, (sum, e) => sum + e.debit.minorUnits));

  Money get sumCredit =>
      Money.fromMinor(entries.fold(0, (sum, e) => sum + e.credit.minorUnits));

  Money get closingBalance =>
      entries.isNotEmpty ? entries.last.runningBalance : openingBalance;

  String get closingSide =>
      entries.isNotEmpty ? entries.last.balanceSide : openingSide;

  @override
  List<Object?> get props => [
    subject,
    openingBalance,
    openingSide,
    entries,
    startDate,
    endDate,
  ];
}
