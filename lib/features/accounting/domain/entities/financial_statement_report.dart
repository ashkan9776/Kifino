import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import 'accounting_subject_entity.dart';

class StatementItem extends Equatable {
  final AccountingSubjectEntity? subject;
  final String title;
  final Money amount;
  final bool isNegative;
  final int depth;

  const StatementItem({
    this.subject,
    required this.title,
    required this.amount,
    this.isNegative = false,
    this.depth = 0,
  });

  @override
  List<Object?> get props => [subject, title, amount, isNegative, depth];
}

class BalanceSheetReport extends Equatable {
  final DateTime asOfDate;
  final List<StatementItem> currentAssets;
  final List<StatementItem> nonCurrentAssets;
  final List<StatementItem> currentLiabilities;
  final List<StatementItem> nonCurrentLiabilities;
  final List<StatementItem> equityItems;
  final Money netIncomeForPeriod;

  const BalanceSheetReport({
    required this.asOfDate,
    required this.currentAssets,
    required this.nonCurrentAssets,
    required this.currentLiabilities,
    required this.nonCurrentLiabilities,
    required this.equityItems,
    required this.netIncomeForPeriod,
  });

  Money get totalCurrentAssets => Money.fromMinor(
    currentAssets.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get totalNonCurrentAssets => Money.fromMinor(
    nonCurrentAssets.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get totalAssets => Money.fromMinor(
    totalCurrentAssets.minorUnits + totalNonCurrentAssets.minorUnits,
  );

  Money get totalCurrentLiabilities => Money.fromMinor(
    currentLiabilities.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get totalNonCurrentLiabilities => Money.fromMinor(
    nonCurrentLiabilities.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get totalLiabilities => Money.fromMinor(
    totalCurrentLiabilities.minorUnits + totalNonCurrentLiabilities.minorUnits,
  );

  Money get totalEquity => Money.fromMinor(
    equityItems.fold(
          0,
          (sum, item) =>
              sum +
              (item.isNegative
                  ? -item.amount.minorUnits
                  : item.amount.minorUnits),
        ) +
        netIncomeForPeriod.minorUnits,
  );

  Money get totalLiabilitiesAndEquity =>
      Money.fromMinor(totalLiabilities.minorUnits + totalEquity.minorUnits);

  bool get isBalanced =>
      totalAssets.minorUnits == totalLiabilitiesAndEquity.minorUnits;

  @override
  List<Object?> get props => [
    asOfDate,
    currentAssets,
    nonCurrentAssets,
    currentLiabilities,
    nonCurrentLiabilities,
    equityItems,
    netIncomeForPeriod,
  ];
}

class IncomeStatementReport extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final List<StatementItem> revenues;
  final List<StatementItem> salesDiscountsReturns;
  final List<StatementItem> cogsItems;
  final List<StatementItem> operatingExpenses;
  final List<StatementItem> otherIncomes;
  final List<StatementItem> otherExpenses;

  const IncomeStatementReport({
    required this.startDate,
    required this.endDate,
    required this.revenues,
    required this.salesDiscountsReturns,
    required this.cogsItems,
    required this.operatingExpenses,
    required this.otherIncomes,
    required this.otherExpenses,
  });

  Money get totalGrossRevenue => Money.fromMinor(
    revenues.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get totalSalesDeductions => Money.fromMinor(
    salesDiscountsReturns.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get netRevenue => Money.fromMinor(
    totalGrossRevenue.minorUnits - totalSalesDeductions.minorUnits,
  );

  Money get totalCogs => Money.fromMinor(
    cogsItems.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get grossProfit =>
      Money.fromMinor(netRevenue.minorUnits - totalCogs.minorUnits);

  Money get totalOperatingExpenses => Money.fromMinor(
    operatingExpenses.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get operatingProfit => Money.fromMinor(
    grossProfit.minorUnits - totalOperatingExpenses.minorUnits,
  );

  Money get totalOtherIncome => Money.fromMinor(
    otherIncomes.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get totalOtherExpenses => Money.fromMinor(
    otherExpenses.fold(0, (sum, item) => sum + item.amount.minorUnits),
  );

  Money get netProfit => Money.fromMinor(
    operatingProfit.minorUnits +
        totalOtherIncome.minorUnits -
        totalOtherExpenses.minorUnits,
  );

  @override
  List<Object?> get props => [
    startDate,
    endDate,
    revenues,
    salesDiscountsReturns,
    cogsItems,
    operatingExpenses,
    otherIncomes,
    otherExpenses,
  ];
}
