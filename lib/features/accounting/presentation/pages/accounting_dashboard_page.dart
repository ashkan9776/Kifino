import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../business/domain/entities/invoice_entity.dart';
import '../../../business/domain/repositories/business_repository.dart';
import '../../domain/entities/accounting_document_entity.dart';
import '../../domain/entities/financial_statement_report.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../bloc/accounting_document_bloc.dart';
import '../bloc/trial_balance_bloc.dart';

class AccountingDashboardPage extends StatefulWidget {
  const AccountingDashboardPage({super.key});

  @override
  State<AccountingDashboardPage> createState() => _AccountingDashboardPageState();
}

class _AccountingDashboardPageState extends State<AccountingDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<AccountingDocumentBloc>().add(const LoadAccountingDocuments());
    context.read<TrialBalanceBloc>().add(const LoadTrialBalance());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final jalaliNow = JalaliDate.fromDateTime(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('کنسول حسابداری مالی'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AccountingDocumentBloc>().add(const LoadAccountingDocuments());
              context.read<TrialBalanceBloc>().add(const LoadTrialBalance());
            },
            tooltip: 'تازه‌سازی',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<AccountingDocumentBloc>().add(const LoadAccountingDocuments());
          context.read<TrialBalanceBloc>().add(const LoadTrialBalance());
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Top Fiscal Year Badge & Quick Hero
            _buildFiscalYearBanner(colors, jalaliNow),
            const SizedBox(height: 16),

            // Modules Grid (هلو / سپیدار modules)
            Text('ماژول‌های حسابداری دوبل', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            _buildModulesGrid(context, colors),
            const SizedBox(height: 20),

            // Quick Access: Phase-1 tools (audit, floating details, fiscal years)
            Text('ابزارهای تکمیلی', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            _buildQuickAccessGrid(context, colors),
            const SizedBox(height: 20),

            // Quick Trial Balance Equilibrium Card
            _buildEquilibriumCard(colors),
            const SizedBox(height: 20),

            // Current Period P&L Card (Phase-4)
            _buildPeriodPnlCard(colors),
            const SizedBox(height: 20),

            // Overdue Invoices Section (Phase-4)
            _buildOverdueInvoicesSection(context, colors),
            const SizedBox(height: 20),

            // Recent Documents Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('آخرین اسناد حسابداری', style: AppTypography.titleMedium),
                TextButton(
                  onPressed: () => context.push('/accounting/documents'),
                  child: const Text('مشاهده همه'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecentDocuments(colors),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounting/documents/create'),
        icon: const Icon(Icons.add),
        label: const Text('ثبت سند جدید'),
      ),
    );
  }

  Widget _buildFiscalYearBanner(KifinoColorsExtension colors, JalaliDate jalaliNow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سیستم حسابداری دوبل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'سال مالی فعال',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'امروز: ${TextNormalizer.toPersianDigits(jalaliNow.day.toString())} ${jalaliNow.monthName} ${TextNormalizer.toPersianDigits(jalaliNow.year.toString())} هجری شمسی',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'مبتنی بر استانداردهای حسابداری مصوب ایران و سیستم‌های مالی یکپارچه',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesGrid(BuildContext context, KifinoColorsExtension colors) {
    final modules = [
      _ModuleItem(
        title: 'اسناد حسابداری',
        subtitle: 'فهرست، ویرایش و تأیید اسناد',
        icon: Icons.receipt_long,
        color: Colors.indigo,
        route: '/accounting/documents',
      ),
      _ModuleItem(
        title: 'کدینگ سرفصل‌ها',
        subtitle: 'کل، معین و تفصیلی',
        icon: Icons.account_tree_outlined,
        color: Colors.teal,
        route: '/accounting/chart-of-accounts',
      ),
      _ModuleItem(
        title: 'دفتر روزنامه',
        subtitle: 'ثبت ترتیبی تراکنش‌ها',
        icon: Icons.menu_book,
        color: Colors.blueGrey,
        route: '/accounting/journal',
      ),
      _ModuleItem(
        title: 'دفتر کل و معین',
        subtitle: 'گردش و مانده با تشخیص بد/بس',
        icon: Icons.chrome_reader_mode,
        color: Colors.purple,
        route: '/accounting/ledger',
      ),
      _ModuleItem(
        title: 'تراز آزمایشی',
        subtitle: 'تراز ۴ و ۸ ستونی گردش و مانده',
        icon: Icons.balance,
        color: Colors.deepOrange,
        route: '/accounting/trial-balance',
      ),
      _ModuleItem(
        title: 'ترازنامه و سود/زیان',
        subtitle: 'صورت‌های مالی اساسی',
        icon: Icons.pie_chart_outline,
        color: Colors.teal,
        route: '/accounting/financial-statements',
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final item = modules[index];
        return AppCard(
          onTap: () => context.push(item.route),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, KifinoColorsExtension colors) {
    final items = [
      const _ModuleItem(
        title: 'لاگ حسابرسی',
        subtitle: 'تاریخچه تغییرات اسناد',
        icon: Icons.history,
        color: Colors.blueGrey,
        route: '/accounting/audit-logs',
      ),
      const _ModuleItem(
        title: 'تفصیلی شناور',
        subtitle: 'تعریف ابعاد تحلیلی و مقادیر',
        icon: Icons.category_outlined,
        color: Colors.teal,
        route: '/accounting/detail-ledgers',
      ),
      const _ModuleItem(
        title: 'گزارش تفصیلی',
        subtitle: 'گردش و مانده به تفکیک مقدار',
        icon: Icons.assessment_outlined,
        color: Colors.indigo,
        route: '/accounting/detail-ledgers/report',
      ),
      const _ModuleItem(
        title: 'سال مالی',
        subtitle: 'بستن دوره و سند افتتاحیه',
        icon: Icons.calendar_month,
        color: Colors.deepPurple,
        route: '/accounting/fiscal-years',
      ),
      const _ModuleItem(
        title: 'حساب‌های سند خودکار',
        subtitle: 'تنظیم حساب‌های طرف مقابل فاکتور',
        icon: Icons.tune,
        color: Colors.blue,
        route: '/accounting/voucher-settings',
      ),
      const _ModuleItem(
        title: 'خزانه',
        subtitle: 'موجودی نقد و بانک و مغایرت‌گیری چک',
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.teal,
        route: '/accounting/treasury',
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return AppCard(
          onTap: () => context.push(item.route),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEquilibriumCard(KifinoColorsExtension colors) {
    return BlocBuilder<TrialBalanceBloc, TrialBalanceState>(
      builder: (context, state) {
        if (state is TrialBalanceLoading) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (state is TrialBalanceLoaded) {
          final isBalanced = state.report.isBalanced;
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: isBalanced ? colors.income : colors.expense,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('تراز کل سیستم مالی', style: AppTypography.titleSmall),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isBalanced ? colors.income : colors.expense).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isBalanced ? 'کاملاً تراز است' : 'دارای اختلاف',
                          style: TextStyle(
                            color: isBalanced ? colors.income : colors.expense,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مجموع گردش بدهکار:', style: AppTypography.bodySmall),
                          const SizedBox(height: 4),
                          AppMoneyText(money: state.report.sumTotalDebit),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('مجموع گردش بستانکار:', style: AppTypography.bodySmall),
                          const SizedBox(height: 4),
                          AppMoneyText(money: state.report.sumTotalCredit),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// «سود و زیان دوره» — figures for the current month (first of the current
  /// Gregorian month until now). Hidden entirely on error / empty data.
  Widget _buildPeriodPnlCard(KifinoColorsExtension colors) {
    final now = DateTime.now();
    final monthStart = startOfJalaliMonth(now);

    return FutureBuilder<IncomeStatementReport>(
      future: sl<AccountingRepository>().getIncomeStatementReport(
            startDate: monthStart,
            endDate: now,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final report = snapshot.data;
        if (report == null) return const SizedBox.shrink(); // error → hide

        final revenue = Money.fromMinor(
          report.netRevenue.minorUnits + report.totalOtherIncome.minorUnits,
        );
        final expense = Money.fromMinor(
          report.totalSalesDeductions.minorUnits +
              report.totalCogs.minorUnits +
              report.totalOperatingExpenses.minorUnits +
              report.totalOtherExpenses.minorUnits,
        );
        final net = report.netProfit;
        final netColor = net.isNegative ? colors.expense : colors.income;

        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سود و زیان دوره',
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: netColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ماه جاری',
                        style: TextStyle(
                          color: netColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('درآمد:', style: AppTypography.bodySmall),
                        const SizedBox(height: 4),
                        AppMoneyText(money: revenue),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('هزینه:', style: AppTypography.bodySmall),
                        const SizedBox(height: 4),
                        AppMoneyText(money: expense),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('سود (زیان) خالص:',
                            style: AppTypography.bodySmall),
                        const SizedBox(height: 4),
                        AppMoneyText(
                          money: net,
                          style: AppTypography.moneyTile
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// «فاکتورهای سررسیدشده» — up to 5 overdue business invoices. Rendered
  /// only when there is at least one overdue invoice.
  Widget _buildOverdueInvoicesSection(
      BuildContext context, KifinoColorsExtension colors) {
    return FutureBuilder<Result<List<InvoiceEntity>>>(
      future: sl<BusinessRepository>().getInvoices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final invoices = snapshot.data?.dataOrNull ?? const <InvoiceEntity>[];
        final overdue = invoices.where((inv) => inv.isOverdue).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        if (overdue.isEmpty) return const SizedBox.shrink();

        final shown = overdue.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.deepOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text('فاکتورهای سررسیدشده',
                        style: AppTypography.titleMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.expense.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        TextNormalizer.toPersianDigits(overdue.length.toString()),
                        style: TextStyle(
                          color: colors.expense,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/business'),
                  child: const Text('مشاهده همه'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...shown.map((inv) => _buildOverdueInvoiceTile(context, inv, colors)),
          ],
        );
      },
    );
  }

  Widget _buildOverdueInvoiceTile(
      BuildContext context, InvoiceEntity invoice, KifinoColorsExtension colors) {
    final daysOverdue = DateTime.now().difference(invoice.dueDate).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.push('/business'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.receipt_long, color: colors.expense, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invoice.type.titleFa} #${TextNormalizer.toPersianDigits(invoice.invoiceNumber)}',
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.contactName ?? 'بدون طرف حساب',
                      style: AppTypography.bodySmall
                          .copyWith(color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppMoneyText(
                      money: invoice.remainingBalance,
                      style: AppTypography.moneyTile),
                  const SizedBox(height: 4),
                  Text(
                    '${TextNormalizer.toPersianDigits(daysOverdue.toString())} روز تأخیر',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.expense,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDocuments(KifinoColorsExtension colors) {
    return BlocBuilder<AccountingDocumentBloc, AccountingDocumentState>(
      builder: (context, state) {
        if (state is AccountingDocumentLoading) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (state is AccountingDocumentLoaded) {
          final docs = state.documents.take(5).toList();
          if (docs.isEmpty) {
            return AppCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 40, color: colors.textSecondary),
                      const SizedBox(height: 8),
                      Text('هنوز سند حسابداری ثبت نشده است', style: AppTypography.bodyMedium),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/accounting/documents/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('ثبت اولین سند حسابداری'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            children: docs.map((doc) => _buildDocTile(context, doc, colors)).toList(),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDocTile(BuildContext context, AccountingDocumentEntity doc, KifinoColorsExtension colors) {
    final jalali = JalaliDate.fromDateTime(doc.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _showDocumentDetailsModal(context, doc, colors),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (doc.isBalanced ? colors.primary : colors.expense).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${doc.number}',
                  style: TextStyle(
                    color: doc.isBalanced ? colors.primary : colors.expense,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${jalali.day} ${jalali.monthName} ${jalali.year} • ${doc.transactions.length} آرتیکل',
                      style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppMoneyText(money: doc.totalDebit, style: AppTypography.moneyTile),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: doc.status == DocumentStatus.approved
                          ? colors.income.withValues(alpha: 0.15)
                          : colors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      doc.status.titleFa,
                      style: TextStyle(
                        fontSize: 10,
                        color: doc.status == DocumentStatus.approved
                            ? colors.income
                            : colors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentDetailsModal(BuildContext context, AccountingDocumentEntity doc, KifinoColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final jalali = JalaliDate.fromDateTime(doc.date);
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('سند حسابداری #${TextNormalizer.toPersianDigits(doc.number.toString())}', style: AppTypography.titleLarge),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: doc.isBalanced
                              ? colors.income.withValues(alpha: 0.15)
                              : colors.expense.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          doc.isBalanced ? 'متوازن' : 'نامتوازن',
                          style: TextStyle(
                            color: doc.isBalanced ? colors.income : colors.expense,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('شرح کلی: ${doc.title}', style: AppTypography.bodyMedium),
                  Text('تاریخ: ${TextNormalizer.toPersianDigits(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.toPersianDigits(jalali.year.toString())}',
                      style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
                  const Divider(height: 24),

                  Text('آرتیکل‌های سند (تراکنش‌های دوبل):', style: AppTypography.titleSmall),
                  const SizedBox(height: 8),

                  ...doc.transactions.map((tx) {
                    final isDeb = tx.debit.minorUnits > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDeb
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDeb ? 'بدهکار' : 'بستانکار',
                              style: TextStyle(
                                color: isDeb ? Colors.red : Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.subject != null ? tx.subject!.formattedName : tx.subjectId,
                                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (tx.description.isNotEmpty)
                                  Text(
                                    tx.description,
                                    style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          AppMoneyText(
                            money: isDeb ? tx.debit : tx.credit,
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('جمع بدهکار:'),
                          AppMoneyText(money: doc.totalDebit),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('جمع بستانکار:'),
                          AppMoneyText(money: doc.totalCredit),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ModuleItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

extension ColorExt on Colors {
  static const Color emeraldGreen = Color(0xFF10B981);
}
