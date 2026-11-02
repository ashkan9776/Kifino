import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class CategorySpendingItem {
  final String categoryName;
  final Color color;
  final Money totalAmount;
  final double percentage;

  const CategorySpendingItem({
    required this.categoryName,
    required this.color,
    required this.totalAmount,
    required this.percentage,
  });
}

class CategorySpendingChart extends StatefulWidget {
  final List<TransactionEntity> transactions;
  final List<CategoryEntity> categories;
  final Currency currency;

  const CategorySpendingChart({
    super.key,
    required this.transactions,
    required this.categories,
    required this.currency,
  });

  @override
  State<CategorySpendingChart> createState() => _CategorySpendingChartState();
}

class _CategorySpendingChartState extends State<CategorySpendingChart> {
  int _touchedIndex = -1;

  static const List<Color> _chartColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
  ];

  List<CategorySpendingItem> _calculateSpending() {
    final Map<String, int> expenseByCategory = {};
    int totalExpenseMinor = 0;

    for (final tx in widget.transactions) {
      if (tx.type == TransactionType.expense && !tx.isDeleted) {
        final catId = tx.categoryId ?? 'uncategorized';
        expenseByCategory[catId] =
            (expenseByCategory[catId] ?? 0) + tx.amount.minorUnits;
        totalExpenseMinor += tx.amount.minorUnits;
      }
    }

    if (totalExpenseMinor <= 0) return [];

    final categoryMap = {for (final c in widget.categories) c.id: c};
    final items = <CategorySpendingItem>[];

    int colorIdx = 0;
    final sortedEntries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      final category = categoryMap[entry.key];
      final name = category?.name ?? 'سایر';
      final color = _chartColors[colorIdx % _chartColors.length];
      colorIdx++;

      final percent = (entry.value / totalExpenseMinor) * 100;
      items.add(
        CategorySpendingItem(
          categoryName: name,
          color: color,
          totalAmount: Money.fromMinor(entry.value, widget.currency),
          percentage: percent,
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final spendingItems = _calculateSpending();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.donut_large_rounded,
                  size: 20,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.categorySpending,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (spendingItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  l10n.noTransactionsYet,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                  ),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse
                            .touchedSection!
                            .touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  sections: spendingItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isTouched = index == _touchedIndex;
                    final radius = isTouched ? 38.0 : 32.0;

                    return PieChartSectionData(
                      color: item.color,
                      value: item.percentage,
                      title: isTouched
                          ? TextNormalizer.auto(
                              '${item.percentage.toStringAsFixed(0)}%',
                            )
                          : '',
                      radius: radius,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Legend
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: spendingItems.length > 5 ? 5 : spendingItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = spendingItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.categoryName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        TextNormalizer.auto(
                          '${item.percentage.toStringAsFixed(1)}% ',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      AppMoneyText(
                        money: item.totalAmount,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
