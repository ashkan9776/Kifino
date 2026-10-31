import 'package:equatable/equatable.dart';
import '../../../../core/utils/money.dart';
import 'accounting_subject_entity.dart';

class TrialBalanceEntry extends Equatable {
  final AccountingSubjectEntity subject;
  final Money openingDebit;
  final Money openingCredit;
  final Money periodDebit;
  final Money periodCredit;

  const TrialBalanceEntry({
    required this.subject,
    required this.openingDebit,
    required this.openingCredit,
    required this.periodDebit,
    required this.periodCredit,
  });

  /// Total Debit Turnover = openingDebit + periodDebit
  Money get totalDebit => Money.fromMinor(openingDebit.minorUnits + periodDebit.minorUnits);

  /// Total Credit Turnover = openingCredit + periodCredit
  Money get totalCredit => Money.fromMinor(openingCredit.minorUnits + periodCredit.minorUnits);

  /// Net balance in minor units (Debit - Credit)
  int get netMinorUnits => totalDebit.minorUnits - totalCredit.minorUnits;

  /// Ending Debit Balance (مانده بدهکار پایان دوره)
  Money get endingDebit => Money.fromMinor(netMinorUnits > 0 ? netMinorUnits : 0);

  /// Ending Credit Balance (مانده بستانکار پایان دوره)
  Money get endingCredit => Money.fromMinor(netMinorUnits < 0 ? -netMinorUnits : 0);

  /// Period net balance (مانده گردش طی دوره)
  int get periodNetMinorUnits => periodDebit.minorUnits - periodCredit.minorUnits;
  Money get periodRemainingDebit => Money.fromMinor(periodNetMinorUnits > 0 ? periodNetMinorUnits : 0);
  Money get periodRemainingCredit => Money.fromMinor(periodNetMinorUnits < 0 ? -periodNetMinorUnits : 0);

  @override
  List<Object?> get props => [
        subject,
        openingDebit,
        openingCredit,
        periodDebit,
        periodCredit,
      ];
}

class TrialBalanceReport extends Equatable {
  final List<TrialBalanceEntry> entries;
  final DateTime? startDate;
  final DateTime? endDate;
  final AccountingSubjectLevel level;

  const TrialBalanceReport({
    required this.entries,
    this.startDate,
    this.endDate,
    this.level = AccountingSubjectLevel.kol,
  });

  Money get sumOpeningDebit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.openingDebit.minorUnits),
      );

  Money get sumOpeningCredit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.openingCredit.minorUnits),
      );

  Money get sumPeriodDebit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.periodDebit.minorUnits),
      );

  Money get sumPeriodCredit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.periodCredit.minorUnits),
      );

  Money get sumTotalDebit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.totalDebit.minorUnits),
      );

  Money get sumTotalCredit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.totalCredit.minorUnits),
      );

  Money get sumEndingDebit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.endingDebit.minorUnits),
      );

  Money get sumEndingCredit => Money.fromMinor(
        entries.fold(0, (sum, e) => sum + e.endingCredit.minorUnits),
      );

  /// Verify trial balance equilibrium
  bool get isBalanced =>
      sumTotalDebit.minorUnits == sumTotalCredit.minorUnits &&
      sumEndingDebit.minorUnits == sumEndingCredit.minorUnits;

  @override
  List<Object?> get props => [entries, startDate, endDate, level];
}
