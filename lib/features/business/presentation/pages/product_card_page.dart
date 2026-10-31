import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/inventory_log_entity.dart';
import '../../domain/entities/product_card_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/business_repository.dart';
import '../bloc/business_bloc.dart';
import '../bloc/business_state.dart';

/// کاردکس انبار — chronological stock ledger for a single product.
///
/// Read-only view over [BusinessRepository.getProductCard]: every inventory
/// movement (invoices, manual adjustments) with the running balance after it.
class ProductCardPage extends StatefulWidget {
  final String productId;

  const ProductCardPage({super.key, required this.productId});

  @override
  State<ProductCardPage> createState() => _ProductCardPageState();
}

class _ProductCardPageState extends State<ProductCardPage> {
  late final BusinessRepository _repository;
  Future<List<ProductCardEntry>>? _cardFuture;

  @override
  void initState() {
    super.initState();
    _repository = getIt<BusinessRepository>();
    _cardFuture = _loadCard();
  }

  Future<List<ProductCardEntry>> _loadCard() {
    return _repository.getProductCard(widget.productId);
  }

  void _reload() {
    setState(() => _cardFuture = _loadCard());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFa ? 'کاردکس کالا' : 'Product Card'),
        centerTitle: true,
      ),
      body: BlocBuilder<BusinessBloc, BusinessState>(
        builder: (context, state) {
          if (state is BusinessLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppSkeleton(
                    height: 110,
                    borderRadius: AppSpacing.borderRadiusLg,
                  ),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(
                    height: 80,
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(
                    height: 80,
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                ],
              ),
            );
          }

          ProductEntity? product;
          if (state is BusinessLoaded) {
            for (final p in state.products) {
              if (p.id == widget.productId) {
                product = p;
                break;
              }
            }
          }

          if (product == null) {
            return AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: isFa ? 'کالا یافت نشد' : 'Product not found',
              description: isFa
                  ? 'این کالا حذف شده یا در دسترس نیست.'
                  : 'This product was deleted or is unavailable.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<ProductCardEntry>>(
              future: _cardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        AppSkeleton(
                          height: 110,
                          borderRadius: AppSpacing.borderRadiusLg,
                        ),
                        SizedBox(height: AppSpacing.md),
                        AppSkeleton(
                          height: 80,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                        SizedBox(height: AppSpacing.md),
                        AppSkeleton(
                          height: 80,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return AppEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: isFa
                        ? 'خطا در خواندن کاردکس'
                        : 'Failed to load product card',
                    description: isFa
                        ? 'برای تلاش مجدد، صفحه را به پایین بکشید.'
                        : 'Pull down to retry.',
                  );
                }

                final entries = snapshot.data ?? const <ProductCardEntry>[];

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  children: [
                    _buildHeaderCard(context, product!, isDark),
                    const SizedBox(height: AppSpacing.md),
                    if (entries.isEmpty)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: AppEmptyState(
                          icon: Icons.swap_vert_outlined,
                          title: isFa ? 'گردشی ثبت نشده' : 'No movements yet',
                          description: isFa
                              ? 'با ثبت فاکتور خرید/فروش یا اصلاح موجودی، کاردکس این کالا پر می‌شود.'
                              : 'Purchase/sale invoices and stock adjustments will appear here.',
                        ),
                      )
                    else ...[
                      ...entries.reversed.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _buildEntryRow(context, e, isDark),
                        ),
                      ),
                      _buildTotalsRow(context, entries, isDark),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // HEADER: product summary
  // ----------------------------------------------------
  Widget _buildHeaderCard(
    BuildContext context,
    ProductEntity product,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isFa = context.l10n.isPersian;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: product.isLowStock
                    ? AppColors.danger.withValues(alpha: 0.12)
                    : AppColors.income.withValues(alpha: 0.12),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 22,
                  color: product.isLowStock
                      ? AppColors.danger
                      : AppColors.income,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.sku != null)
                      Text(
                        'SKU: ${product.sku}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: product.isLowStock
                  ? AppColors.danger.withValues(alpha: 0.08)
                  : AppColors.income.withValues(alpha: 0.08),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isFa ? 'موجودی فعلی' : 'Current stock',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                  ),
                ),
                Text(
                  '${TextNormalizer.auto(_formatQuantity(product.currentStock))} ${product.unit}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: product.isLowStock
                        ? AppColors.danger
                        : AppColors.income,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ROW: one movement
  // ----------------------------------------------------
  Widget _buildEntryRow(
    BuildContext context,
    ProductCardEntry entry,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isFa = l10n.isPersian;

    final (IconData icon, Color color) = switch (entry.movementType) {
      InventoryMovementType.purchase => (
        Icons.add_shopping_cart_outlined,
        AppColors.income,
      ),
      InventoryMovementType.sale => (Icons.sell_outlined, AppColors.primary),
      InventoryMovementType.returned => (Icons.undo_outlined, AppColors.info),
      InventoryMovementType.loss => (
        Icons.delete_sweep_outlined,
        AppColors.danger,
      ),
      InventoryMovementType.adjustment => (
        Icons.tune_outlined,
        AppColors.warning,
      ),
    };

    final hasIn = entry.inQuantity > 0;
    final hasOut = entry.outQuantity > 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _movementTitleFa(entry.movementType),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppDateFormatter.formatShort(
                            entry.date,
                            locale: l10n.localeName,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                          ),
                        ),
                      ],
                    ),
                    if (entry.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _QuantityCell(
                  label: isFa ? 'ورود' : 'In',
                  value: hasIn ? '+${_formatQuantity(entry.inQuantity)}' : '—',
                  color: hasIn
                      ? AppColors.income
                      : (isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext),
                ),
              ),
              Expanded(
                child: _QuantityCell(
                  label: isFa ? 'خروج' : 'Out',
                  value: hasOut
                      ? '-${_formatQuantity(entry.outQuantity)}'
                      : '—',
                  color: hasOut
                      ? AppColors.danger
                      : (isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext),
                ),
              ),
              Expanded(
                child: _QuantityCell(
                  label: isFa ? 'مانده' : 'Balance',
                  value: _formatQuantity(entry.balance),
                  color: null,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TOTALS
  // ----------------------------------------------------
  Widget _buildTotalsRow(
    BuildContext context,
    List<ProductCardEntry> entries,
    bool isDark,
  ) {
    final isFa = context.l10n.isPersian;

    double totalIn = 0;
    double totalOut = 0;
    for (final e in entries) {
      totalIn += e.inQuantity;
      totalOut += e.outQuantity;
    }
    final finalBalance = entries.isEmpty ? 0.0 : entries.last.balance;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuantityCell(
              label: isFa ? 'جمع ورود' : 'Total in',
              value: '+${_formatQuantity(totalIn)}',
              color: AppColors.income,
              bold: true,
            ),
          ),
          Expanded(
            child: _QuantityCell(
              label: isFa ? 'جمع خروج' : 'Total out',
              value: '-${_formatQuantity(totalOut)}',
              color: AppColors.danger,
              bold: true,
            ),
          ),
          Expanded(
            child: _QuantityCell(
              label: isFa ? 'مانده نهایی' : 'Final balance',
              value: _formatQuantity(finalBalance),
              color: null,
              bold: true,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // HELPERS
  // ----------------------------------------------------

  /// Short Persian titles for the dense card rows.
  String _movementTitleFa(InventoryMovementType type) => switch (type) {
    InventoryMovementType.purchase => 'خرید',
    InventoryMovementType.sale => 'فروش',
    InventoryMovementType.adjustment => 'اصلاح',
    InventoryMovementType.returned => 'مرجوعی',
    InventoryMovementType.loss => 'ضایعات',
  };

  /// Trims trailing zeros so 10.0 → 10 and 2.5 → 2.5, in Persian digits.
  String _formatQuantity(double qty) {
    final fixed = qty.toStringAsFixed(2);
    final trimmed = fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3)
        : (fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed);
    return TextNormalizer.auto(trimmed);
  }
}

/// Small labelled quantity cell used in the card rows and the totals bar.
class _QuantityCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _QuantityCell({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedColor =
        color ?? (isDark ? AppColors.darkSubtext : AppColors.lightSubtext);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: resolvedColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
