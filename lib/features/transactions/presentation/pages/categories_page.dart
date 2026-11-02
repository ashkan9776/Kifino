import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../bloc/category_cubit.dart';
import '../widgets/category_icon_color_picker.dart';

/// Custom-categories manager: create / rename / re-icon / delete categories
/// per type (expense | income). Deleting a category never deletes money —
/// its transactions survive as uncategorized.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CategoryCubit>(),
      child: const _CategoriesView(),
    );
  }
}

class _CategoriesView extends StatelessWidget {
  const _CategoriesView();

  // ----------------------------------------------------
  // CREATE / EDIT SHEET
  // ----------------------------------------------------
  void _showCategorySheet(BuildContext context, {CategoryEntity? existing}) {
    final cubit = context.read<CategoryCubit>();
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    // Type is fixed by the active tab; only name/icon/color are editable.
    final type = existing?.type ?? cubit.state.selectedType;

    final nameController = TextEditingController(text: existing?.name ?? '');
    int selectedCodePoint =
        existing?.iconCodePoint ??
        (type == CategoryType.expense
            ? Icons.shopping_bag_rounded.codePoint
            : Icons.payments_rounded.codePoint);

    final existingHex = existing != null
        ? CategoryIconAssets.normalizeHex(existing.colorHex)
        : null;
    String selectedHex = CategoryIconAssets.presetHexes.contains(existingHex)
        ? existingHex!
        : (type == CategoryType.expense ? 'FF5C6C' : '25C997');

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
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSheetHeader(
                        title: existing == null
                            ? (isFa ? 'دسته جدید' : 'New category')
                            : (isFa ? 'ویرایش دسته' : 'Edit category'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Read-only type indicator (fixed by the active tab).
                      Row(
                        children: [
                          Icon(
                            type == CategoryType.expense
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 16,
                            color: type == CategoryType.expense
                                ? AppColors.expense
                                : AppColors.income,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFa
                                ? 'نوع: ${type == CategoryType.expense ? 'هزینه' : 'درآمد'}'
                                : 'Type: ${type == CategoryType.expense ? 'Expense' : 'Income'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: nameController,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: isFa ? 'نام دسته' : 'Category name',
                          prefixIcon: const Icon(Icons.label_outline_rounded),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isFa ? 'آیکون' : 'Icon',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CategoryIconGrid(
                        selectedCodePoint: selectedCodePoint,
                        onSelect: (codePoint) =>
                            setModalState(() => selectedCodePoint = codePoint),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isFa ? 'رنگ' : 'Color',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CategoryColorPalette(
                        selectedHex: selectedHex,
                        onSelect: (hex) =>
                            setModalState(() => selectedHex = hex),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: l10n.save,
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFa
                                      ? 'نام دسته را وارد کنید.'
                                      : 'Enter a category name.',
                                ),
                                backgroundColor: AppColors.expenseLight,
                              ),
                            );
                            return;
                          }
                          // Stored with a leading '#', matching seeded rows.
                          final colorHex = '#$selectedHex';
                          if (existing == null) {
                            cubit.createCategory(
                              name: name,
                              iconCodePoint: selectedCodePoint,
                              colorHex: colorHex,
                            );
                          } else {
                            cubit.updateCategory(
                              category: existing,
                              name: name,
                              iconCodePoint: selectedCodePoint,
                              colorHex: colorHex,
                            );
                          }
                          HapticFeedback.mediumImpact();
                          Navigator.pop(bottomSheetContext);
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

  // ----------------------------------------------------
  // DELETE CONFIRMATION
  // ----------------------------------------------------
  Future<void> _confirmDelete(
    BuildContext context,
    CategoryEntity category,
  ) async {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;

    final count = await sl<CategoryRepository>().countTransactionsUsing(
      category.id,
    );
    if (!context.mounted) return;

    final countText = TextNormalizer.auto('$count');
    final content = count > 0
        ? (isFa
              ? '$countText تراکنش با این دسته ثبت شده؛ پس از حذف، بدون دسته می‌شوند.'
              : '$count transactions use this category; they become uncategorized after deletion.')
        : (isFa
              ? 'هیچ تراکنشی با این دسته ثبت نشده است.'
              : 'No transactions use this category.');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isFa ? 'حذف «${category.name}»' : 'Delete "${category.name}"',
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<CategoryCubit>().deleteCategory(category.id);
    }
  }

  // ----------------------------------------------------
  // CATEGORY ROW
  // ----------------------------------------------------
  Widget _buildCategoryRow(BuildContext context, CategoryEntity category) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = CategoryIconAssets.colorFromHex(category.colorHex);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                CategoryIconAssets.resolve(category.iconCodePoint),
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                category.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showCategorySheet(context, existing: category),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.danger,
              ),
              onPressed: () => _confirmDelete(context, category),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PAGE
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isFa = l10n.isPersian;

    return BlocListener<CategoryCubit, CategoryState>(
      listener: (context, state) {
        if (state.successOp != null) {
          final message = switch (state.successOp) {
            'create' => isFa ? 'دسته جدید ساخته شد' : 'Category created',
            'update' => isFa ? 'تغییرات ذخیره شد' : 'Changes saved',
            'delete' =>
              isFa
                  ? 'دسته حذف شد؛ تراکنش‌هایش بدون دسته شدند'
                  : 'Category deleted; its transactions are uncategorized',
            _ => isFa ? 'انجام شد' : 'Done',
          };
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
          context.read<CategoryCubit>().clearNotifications();
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppColors.expenseLight,
            ),
          );
          context.read<CategoryCubit>().clearNotifications();
        }
      },
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Scaffold(
            appBar: AppBar(
              title: Text(isFa ? 'دسته‌بندی‌های سفارشی' : 'Custom categories'),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showCategorySheet(context),
              child: const Icon(Icons.add),
            ),
            body: BlocBuilder<CategoryCubit, CategoryState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        AppSkeleton(
                          height: 68,
                          borderRadius: AppSpacing.borderRadiusLg,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        AppSkeleton(
                          height: 68,
                          borderRadius: AppSpacing.borderRadiusLg,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        AppSkeleton(
                          height: 68,
                          borderRadius: AppSpacing.borderRadiusLg,
                        ),
                      ],
                    ),
                  );
                }

                final categories = state.categories;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: SegmentedButton<CategoryType>(
                        segments: [
                          ButtonSegment(
                            value: CategoryType.expense,
                            label: Text(isFa ? 'هزینه‌ها' : 'Expenses'),
                          ),
                          ButtonSegment(
                            value: CategoryType.income,
                            label: Text(isFa ? 'درآمدها' : 'Incomes'),
                          ),
                        ],
                        selected: {state.selectedType},
                        onSelectionChanged: (selection) {
                          context.read<CategoryCubit>().selectType(
                            selection.first,
                          );
                          HapticFeedback.selectionClick();
                        },
                        showSelectedIcon: false,
                      ),
                    ),
                    Expanded(
                      child: categories.isEmpty
                          ? AppEmptyState(
                              icon: Icons.category_outlined,
                              title: isFa
                                  ? 'هنوز دسته‌ای ثبت نشده است'
                                  : 'No categories yet',
                              description: isFa
                                  ? 'با دکمه + دسته‌های دلخواه خود را با آیکون و رنگ اختصاصی بسازید.'
                                  : 'Tap + to build your own categories with a custom icon and color.',
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.xxl,
                              ),
                              children: categories
                                  .map(
                                    (category) =>
                                        _buildCategoryRow(context, category),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
