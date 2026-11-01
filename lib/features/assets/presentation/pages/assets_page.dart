import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/asset_entity.dart';
import '../bloc/asset_bloc.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  AssetCategory? _selectedCategory;

  void _showAddAssetDialog(BuildContext context) {
    final l10n = context.l10n;
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: 'گرم');
    final costController = TextEditingController();
    final valueController = TextEditingController();
    final customTypeController = TextEditingController();
    AssetCategory category = _selectedCategory ?? AssetCategory.gold;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppBottomSheet(
              child: Container(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSheetHeader(
                        title: l10n.isPersian ? 'ثبت دارایی جدید' : 'New Asset',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<AssetCategory>(
                        initialValue: category,
                        decoration: InputDecoration(
                          labelText: l10n.assetType,
                          prefixIcon: const Icon(Icons.category_outlined),
                        ),
                        items: AssetCategory.values.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat.titleFa),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => category = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (category == AssetCategory.other) ...[
                        TextField(
                          controller: customTypeController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.isPersian
                                ? 'نوع دارایی (مثلاً فرش دستباف، طلای آب‌شده)'
                                : 'Asset type (e.g. handwoven carpet)',
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.isPersian ? 'نام دارایی (مثلاً سکه امامی)' : 'Asset Name',
                          prefixIcon: const Icon(Icons.label_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                PersianDigitsTextInputFormatter(enabled: isFaLocale(context)),
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.isPersian ? 'تعداد / مقدار' : 'Quantity',
                                prefixIcon: const Icon(Icons.numbers_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextField(
                              controller: unitController,
                              decoration: InputDecoration(
                                labelText: l10n.isPersian ? 'واحد (گرم، عدد، سهم)' : 'Unit',
                                prefixIcon: const Icon(Icons.straighten_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          PersianThousandsSeparatorTextInputFormatter(enabled: isFaLocale(context)),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.purchasePrice,
                          prefixIcon: const Icon(Icons.shopping_cart_outlined),
                          suffixText: l10n.isPersian ? 'تومان' : '',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: valueController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          PersianThousandsSeparatorTextInputFormatter(enabled: isFaLocale(context)),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.currentValuation,
                          prefixIcon: const Icon(Icons.trending_up_rounded),
                          suffixText: l10n.isPersian ? 'تومان' : '',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: l10n.save,
                        onPressed: () {
                          final name = nameController.text.trim();
                          final qty = double.tryParse(normalizeDecimalInput(quantityController.text)) ?? 1.0;
                          final unit = unitController.text.trim();
                          final costVal = int.tryParse(normalizeNumericInput(costController.text)) ?? 0;
                          final curVal = int.tryParse(normalizeNumericInput(valueController.text)) ?? costVal;

                          if (name.isNotEmpty && costVal > 0) {
                            final now = DateTime.now();
                            context.read<AssetBloc>().add(
                                  AssetCreateSubmitted(
                                    AssetEntity(
                                      id: '',
                                      name: name,
                                      category: category,
                                      quantity: qty,
                                      unit: unit.isNotEmpty ? unit : 'واحد',
                                      costBasis: Money.fromMinor(costVal, Currency.irr),
                                      currentValue: Money.fromMinor(curVal, Currency.irr),
                                      purchaseDate: now,
                                      createdAt: now,
                                      updatedAt: now,
                                    ),
                                  ),
                                );
                            Navigator.pop(bottomSheetContext);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUpdateValuationDialog(BuildContext context, AssetEntity asset) {
    final l10n = context.l10n;
    final valueController = TextEditingController(
      text: formatNumberWithSeparators(
        asset.currentValue.minorUnits,
        toPersian: isFaLocale(context),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AppBottomSheet(
          child: Container(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(
                  title:
                      '${l10n.isPersian ? 'بروزرسانی ارزش روز' : 'Update Valuation'}: ${asset.name}',
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    PersianThousandsSeparatorTextInputFormatter(enabled: isFaLocale(context)),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.currentValuation,
                    prefixIcon: const Icon(Icons.trending_up_rounded),
                    suffixText: l10n.isPersian ? 'تومان' : '',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.save,
                  onPressed: () {
                    final newVal = int.tryParse(normalizeNumericInput(valueController.text)) ?? 0;
                    if (newVal > 0) {
                      context.read<AssetBloc>().add(
                            AssetValuationUpdated(
                              id: asset.id,
                              currentValue: Money.fromMinor(newVal, asset.currentValue.currency),
                            ),
                          );
                      Navigator.pop(bottomSheetContext);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.assets),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAssetDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<AssetBloc, AssetState>(
        builder: (context, state) {
          if (state is AssetLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppSkeleton(height: 140, borderRadius: AppSpacing.borderRadiusLg),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 80, borderRadius: AppSpacing.borderRadiusMd),
                ],
              ),
            );
          }

          if (state is! AssetLoaded) {
            return AppEmptyState(
              icon: Icons.savings_outlined,
              title: l10n.assets,
              description: l10n.isPersian
                  ? 'ثبت دارایی‌های غیرنقدی مانند طلا، سکه، رمزارز، ملک و سهام.'
                  : 'Track non-liquid assets like gold, real estate, and crypto.',
            );
          }

          final assets = state.assets;
          final isPnlPositive = state.totalProfitLoss.minorUnits >= 0;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Portfolio Valuation Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.isPersian ? 'ارزش روز دارایی‌ها' : 'Portfolio Valuation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isPnlPositive ? AppColors.income : AppColors.expense).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            TextNormalizer.auto(
                              '${isPnlPositive ? '+' : ''}${state.profitLossPercent.toStringAsFixed(1)}%',
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isPnlPositive ? AppColors.income : AppColors.expense,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AppMoneyText(
                      money: state.totalCurrentValuation,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.purchasePrice,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                ),
                              ),
                              AppMoneyText(
                                money: state.totalCostBasis,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l10n.profitLoss,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                ),
                              ),
                              AppMoneyText(
                                money: state.totalProfitLoss.abs(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isPnlPositive ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (assets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppEmptyState(
                    icon: Icons.savings_outlined,
                    title: l10n.isPersian ? 'دارایی ثبت نشده است' : 'No assets found',
                    description: l10n.isPersian
                        ? 'طلا، ارز، خودرو یا سهام خود را با زدن دکمه + اضافه کنید.'
                        : 'Tap + to add your gold, vehicle, stock, or crypto.',
                  ),
                )
              else
                ...assets.map((asset) {
                  final isPositive = asset.isProfitable;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: () => _showUpdateValuationDialog(context, asset),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.savings_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  TextNormalizer.auto('${asset.quantity} ${asset.unit} · ${asset.displayType}'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppMoneyText(
                                money: asset.currentValue,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TextNormalizer.auto(
                                  '${isPositive ? '+' : ''}${asset.profitLossPercent.toStringAsFixed(1)}%',
                                ),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isPositive ? AppColors.income : AppColors.expense,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
        ),
      ),
    );
  }
}
