import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../domain/entities/accounting_subject_entity.dart';
import '../../domain/entities/trial_balance_entry.dart';
import '../bloc/trial_balance_bloc.dart';

class TrialBalancePage extends StatefulWidget {
  const TrialBalancePage({super.key});

  @override
  State<TrialBalancePage> createState() => _TrialBalancePageState();
}

class _TrialBalancePageState extends State<TrialBalancePage> {
  bool _isEightColumn = false;
  AccountingSubjectLevel _selectedLevel = AccountingSubjectLevel.kol;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<TrialBalanceBloc>().add(
          LoadTrialBalance(
            level: _selectedLevel,
            startDate: _startDate,
            endDate: _endDate,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تراز آزمایشی استاندارد'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _pickDateRange(context),
            tooltip: 'فیلتر تاریخ',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تازه‌سازی',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode and Level Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 4 or 8 column toggle
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('۴ ستونی')),
                      ButtonSegment(value: true, label: Text('۸ ستونی')),
                    ],
                    selected: {_isEightColumn},
                    onSelectionChanged: (set) {
                      setState(() => _isEightColumn = set.first);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Kol / Moein toggle
                SegmentedButton<AccountingSubjectLevel>(
                  segments: const [
                    ButtonSegment(
                        value: AccountingSubjectLevel.kol, label: Text('کل')),
                    ButtonSegment(
                        value: AccountingSubjectLevel.moein, label: Text('معین')),
                  ],
                  selected: {_selectedLevel},
                  onSelectionChanged: (set) {
                    setState(() => _selectedLevel = set.first);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Table Area
          Expanded(
            child: BlocBuilder<TrialBalanceBloc, TrialBalanceState>(
              builder: (context, state) {
                if (state is TrialBalanceLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is TrialBalanceLoaded) {
                  final report = state.report;
                  if (report.entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.balance, size: 56, color: colors.textSecondary),
                          const SizedBox(height: 10),
                          Text('ترازی برای نمایش وجود ندارد',
                              style: AppTypography.titleMedium),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Horizontal scrollable table
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _isEightColumn
                                ? _buildEightColumnTable(report, colors)
                                : _buildFourColumnTable(report, colors),
                          ),
                        ),
                      ),

                      // Equilibrium Footer
                      _buildFooterEquilibrium(report, colors),
                    ],
                  );
                }

                if (state is TrialBalanceError) {
                  return Center(child: Text(state.message));
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourColumnTable(TrialBalanceReport report, KifinoColorsExtension colors) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.1)),
      columnSpacing: 16,
      horizontalMargin: 12,
      columns: const [
        DataColumn(label: Text('کد', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('نام حساب', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
          label: Text('گردش بدهکار',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          numeric: true,
        ),
        DataColumn(
          label: Text('گردش بستانکار',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          numeric: true,
        ),
        DataColumn(
          label: Text('مانده بدهکار',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          numeric: true,
        ),
        DataColumn(
          label: Text('مانده بستانکار',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          numeric: true,
        ),
      ],
      rows: report.entries.map((entry) {
        return DataRow(
          cells: [
            DataCell(Text(entry.subject.formattedCode,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(entry.subject.name,
                style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text(entry.totalDebit.minorUnits > 0
                ? entry.totalDebit.formatted
                : '-')),
            DataCell(Text(entry.totalCredit.minorUnits > 0
                ? entry.totalCredit.formatted
                : '-')),
            DataCell(Text(entry.endingDebit.minorUnits > 0
                ? entry.endingDebit.formatted
                : '-')),
            DataCell(Text(entry.endingCredit.minorUnits > 0
                ? entry.endingCredit.formatted
                : '-')),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEightColumnTable(TrialBalanceReport report, KifinoColorsExtension colors) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.1)),
      columnSpacing: 14,
      horizontalMargin: 10,
      columns: const [
        DataColumn(label: Text('کد', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('نام حساب', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('ابتدای بد', style: TextStyle(fontSize: 11)), numeric: true),
        DataColumn(label: Text('ابتدای بس', style: TextStyle(fontSize: 11)), numeric: true),
        DataColumn(label: Text('دوره بد', style: TextStyle(fontSize: 11)), numeric: true),
        DataColumn(label: Text('دوره بس', style: TextStyle(fontSize: 11)), numeric: true),
        DataColumn(label: Text('مجموع بد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), numeric: true),
        DataColumn(label: Text('مجموع بس', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), numeric: true),
        DataColumn(label: Text('پایان بد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), numeric: true),
        DataColumn(label: Text('پایان بس', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), numeric: true),
      ],
      rows: report.entries.map((entry) {
        return DataRow(
          cells: [
            DataCell(Text(entry.subject.formattedCode,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
            DataCell(Text(entry.subject.name,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
            DataCell(Text(entry.openingDebit.minorUnits > 0 ? entry.openingDebit.formatted : '-')),
            DataCell(Text(entry.openingCredit.minorUnits > 0 ? entry.openingCredit.formatted : '-')),
            DataCell(Text(entry.periodDebit.minorUnits > 0 ? entry.periodDebit.formatted : '-')),
            DataCell(Text(entry.periodCredit.minorUnits > 0 ? entry.periodCredit.formatted : '-')),
            DataCell(Text(entry.totalDebit.minorUnits > 0 ? entry.totalDebit.formatted : '-')),
            DataCell(Text(entry.totalCredit.minorUnits > 0 ? entry.totalCredit.formatted : '-')),
            DataCell(Text(entry.endingDebit.minorUnits > 0 ? entry.endingDebit.formatted : '-')),
            DataCell(Text(entry.endingCredit.minorUnits > 0 ? entry.endingCredit.formatted : '-')),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFooterEquilibrium(TrialBalanceReport report, KifinoColorsExtension colors) {
    final isBalanced = report.isBalanced;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.25))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isBalanced ? colors.income : colors.expense,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBalanced
                          ? 'تراز آزمایشی کاملاً متعادل است'
                          : 'عدم تطبیق تراز آزمایشی!',
                      style: TextStyle(
                        color: isBalanced ? colors.income : colors.expense,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  'تعداد سرفصل‌ها: ${report.entries.length}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('مجموع گردش: ', style: AppTypography.bodySmall),
                    AppMoneyText(
                      money: report.sumTotalDebit,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('مجموع مانده نهایی: ', style: AppTypography.bodySmall),
                    AppMoneyText(
                      money: report.sumEndingDebit,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }
}
