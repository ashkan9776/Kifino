import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';

import '../../../../core/widgets/app_date_picker.dart';
import '../../data/services/accounting_export_service.dart';
import '../../domain/entities/financial_statement_report.dart';
import '../bloc/financial_statements_bloc.dart';
import '../services/accounting_export_actions.dart';

class FinancialStatementsPage extends StatefulWidget {
  const FinancialStatementsPage({super.key});

  @override
  State<FinancialStatementsPage> createState() =>
      _FinancialStatementsPageState();
}

class _FinancialStatementsPageState extends State<FinancialStatementsPage>
    with AccountingExportActions {
  int _selectedTab = 0; // 0: Balance Sheet, 1: Income Statement
  DateTime _asOfDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadStatements();
  }

  void _loadStatements() {
    final startOfYear = DateTime(_asOfDate.year, 1, 1);
    context.read<FinancialStatementsBloc>().add(
      LoadFinancialStatements(asOfDate: _asOfDate, startDate: startOfYear),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final jalali = JalaliDate.fromDateTime(_asOfDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('صورت‌های مالی استاندارد'),
        centerTitle: true,
        actions: [
          buildExportAction(
            () => _selectedTab == 0
                ? getIt<AccountingExportService>().exportBalanceSheet(
                    asOfDate: _asOfDate,
                  )
                : getIt<AccountingExportService>().exportIncomeStatement(
                    startDate: DateTime(_asOfDate.year, 1, 1),
                    endDate: _asOfDate,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _pickDate(context),
            tooltip: 'انتخاب تاریخ گزارش',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatements,
            tooltip: 'تازه‌سازی',
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented selector & Date header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('ترازنامه (Balance Sheet)'),
                      icon: Icon(Icons.account_balance, size: 18),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('سود و زیان (Income)'),
                      icon: Icon(Icons.trending_up, size: 18),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (set) {
                    setState(() => _selectedTab = set.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'مبنای گزارش: تا تاریخ ${TextNormalizer.toPersianDigits(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.toPersianDigits(jalali.year.toString())}',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child:
                BlocBuilder<FinancialStatementsBloc, FinancialStatementsState>(
                  builder: (context, state) {
                    if (state is FinancialStatementsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is FinancialStatementsLoaded) {
                      return _selectedTab == 0
                          ? _buildBalanceSheetView(state.balanceSheet, colors)
                          : _buildIncomeStatementView(
                              state.incomeStatement,
                              colors,
                            );
                    }

                    if (state is FinancialStatementsError) {
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

  // ─── Balance Sheet View ───

  Widget _buildBalanceSheetView(
    BalanceSheetReport bs,
    KifinoColorsExtension colors,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance Equilibrium Check Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bs.isBalanced
                ? colors.income.withValues(alpha: 0.12)
                : colors.expense.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: bs.isBalanced
                  ? colors.income.withValues(alpha: 0.3)
                  : colors.expense.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                bs.isBalanced
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                color: bs.isBalanced ? colors.income : colors.expense,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bs.isBalanced
                      ? 'معادله اصلی حسابداری برقرار است: دارایی‌ها = بدهی‌ها + سرمایه'
                      : 'هشدار عدم تراز ترازنامه! لطفاً اسناد ثبت شده را بررسی فرمایید.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: bs.isBalanced ? colors.income : colors.expense,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Assets (دارایی‌ها)
        _buildSectionHeader('دارایی‌ها (Assets)', AppColors.primary),
        const SizedBox(height: 8),
        _buildStatementGroupCard(
          title: 'دارایی‌های جاری',
          items: bs.currentAssets,
          total: bs.totalCurrentAssets,
          colors: colors,
        ),
        const SizedBox(height: 10),
        _buildStatementGroupCard(
          title: 'دارایی‌های غیرجاری (ثابت)',
          items: bs.nonCurrentAssets,
          total: bs.totalNonCurrentAssets,
          colors: colors,
        ),
        const SizedBox(height: 8),
        _buildTotalRow('جمع کل دارایی‌ها:', bs.totalAssets, AppColors.primary),
        const Divider(height: 28),

        // 2. Liabilities (بدهی‌ها)
        _buildSectionHeader('بدهی‌ها (Liabilities)', Colors.deepOrange),
        const SizedBox(height: 8),
        _buildStatementGroupCard(
          title: 'بدهی‌های جاری',
          items: bs.currentLiabilities,
          total: bs.totalCurrentLiabilities,
          colors: colors,
        ),
        const SizedBox(height: 8),
        _buildTotalRow(
          'جمع کل بدهی‌ها:',
          bs.totalLiabilities,
          Colors.deepOrange,
        ),
        const Divider(height: 28),

        // 3. Equity (حقوق صاحبان سهام و سرمایه)
        _buildSectionHeader('حقوق صاحبان سهام (Equity)', Colors.teal),
        const SizedBox(height: 8),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...bs.equityItems.map((item) => _buildItemRow(item, colors)),
                _buildRow(
                  'سود (زیان) دوره جاری:',
                  bs.netIncomeForPeriod,
                  colors: colors,
                  isBold: true,
                  color: bs.netIncomeForPeriod.isNegative
                      ? colors.expense
                      : colors.income,
                ),
                const Divider(height: 16),
                _buildSubtotalRow('جمع حقوق صاحبان سهام:', bs.totalEquity),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Grand Total Liabilities & Equity
        _buildTotalRow(
          'جمع کل بدهی‌ها و حقوق صاحبان سهام:',
          bs.totalLiabilitiesAndEquity,
          AppColors.primary,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Income Statement View ───

  Widget _buildIncomeStatementView(
    IncomeStatementReport inc,
    KifinoColorsExtension colors,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Gross Revenues
        _buildStatementGroupCard(
          title: 'درآمد ناخالص فروش و ارائه خدمات',
          items: inc.revenues,
          total: inc.totalGrossRevenue,
          colors: colors,
        ),
        const SizedBox(height: 8),

        // Deductions
        if (inc.salesDiscountsReturns.isNotEmpty) ...[
          _buildStatementGroupCard(
            title: 'کسر می‌شود: برگشت از فروش و تخفیفات',
            items: inc.salesDiscountsReturns,
            total: inc.totalSalesDeductions,
            colors: colors,
            isDeduction: true,
          ),
          const SizedBox(height: 8),
        ],

        _buildTotalRow('درآمد خالص فروش:', inc.netRevenue, AppColors.primary),
        const Divider(height: 24),

        // Cost of Goods Sold (COGS)
        _buildStatementGroupCard(
          title: 'کسر می‌شود: بهای تمام شده کالای فروش رفته (COGS)',
          items: inc.cogsItems,
          total: inc.totalCogs,
          colors: colors,
          isDeduction: true,
        ),
        const SizedBox(height: 8),
        _buildTotalRow('سود (زیان) ناخالص:', inc.grossProfit, Colors.indigo),
        const Divider(height: 24),

        // Operating Expenses
        _buildStatementGroupCard(
          title: 'کسر می‌شود: هزینه‌های عمومی، اداری و توزیع',
          items: inc.operatingExpenses,
          total: inc.totalOperatingExpenses,
          colors: colors,
          isDeduction: true,
        ),
        const SizedBox(height: 8),
        _buildTotalRow(
          'سود (زیان) عملیاتی:',
          inc.operatingProfit,
          Colors.purple,
        ),
        const Divider(height: 24),

        // Other Incomes and Expenses
        if (inc.otherIncomes.isNotEmpty || inc.otherExpenses.isNotEmpty) ...[
          _buildStatementGroupCard(
            title: 'سایر درآمدها و هزینه‌های غیرعملیاتی',
            items: [...inc.otherIncomes, ...inc.otherExpenses],
            total: inc.totalOtherIncome,
            colors: colors,
          ),
          const SizedBox(height: 8),
        ],

        // Final Net Profit / Loss
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: inc.netProfit.isPositive
                ? colors.income.withValues(alpha: 0.15)
                : colors.expense.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inc.netProfit.isPositive
                  ? colors.income.withValues(alpha: 0.4)
                  : colors.expense.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سود (زیان) خالص دوره مالی:',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppMoneyText(
                money: inc.netProfit,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: inc.netProfit.isPositive
                      ? colors.income
                      : colors.expense,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatementGroupCard({
    required String title,
    required List<StatementItem> items,
    required Money total,
    required KifinoColorsExtension colors,
    bool isDeduction = false,
  }) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'بدون گردش',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              ...items.map((item) => _buildItemRow(item, colors)),
            const SizedBox(height: 4),
            _buildSubtotalRow('جمع $title:', total, isDeduction: isDeduction),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(StatementItem item, KifinoColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.title, style: AppTypography.bodyMedium),
          AppMoneyText(money: item.amount, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildRow(
    String title,
    Money amount, {
    required KifinoColorsExtension colors,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          AppMoneyText(
            money: amount,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalRow(
    String title,
    Money total, {
    bool isDeduction = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        AppMoneyText(
          money: total,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String title, Money total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          AppMoneyText(
            money: total,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _asOfDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _asOfDate = picked);
      _loadStatements();
    }
  }
}
