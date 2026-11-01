import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_money_text.dart';

import '../../../../core/widgets/app_date_picker.dart';import '../../domain/entities/installment_entity.dart';
import '../bloc/installment_bloc.dart';

/// Phase 3 rework — edit sheet for an existing installment plan.
/// Prefills every field from the entity; saving dispatches
/// [InstallmentUpdateSubmitted]. Past payments are never touched by the
/// repository, only the plan fields change.
class EditInstallmentSheet extends StatefulWidget {
  final InstallmentEntity installment;

  const EditInstallmentSheet({super.key, required this.installment});

  /// Convenience opener so pages cannot forget the scroll-controlled flag
  /// (the sheet must resize above the keyboard).
  static Future<void> show(
    BuildContext context,
    InstallmentEntity installment,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditInstallmentSheet(installment: installment),
    );
  }

  @override
  State<EditInstallmentSheet> createState() => _EditInstallmentSheetState();
}

class _EditInstallmentSheetState extends State<EditInstallmentSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _countController;
  late final TextEditingController _intervalController;
  late final TextEditingController _notesController;
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    final inst = widget.installment;
    final fa = isFaLocale(context);
    _titleController = TextEditingController(text: inst.title);
    _amountController = TextEditingController(
      text: formatNumberWithSeparators(
        inst.installmentAmount.minorUnits,
        toPersian: fa,
      ),
    );
    _countController = TextEditingController(
      text: TextNormalizer.auto('${inst.numberOfInstallments}'),
    );
    _intervalController = TextEditingController(
      text: TextNormalizer.auto('${inst.recurrenceIntervalDays}'),
    );
    _notesController = TextEditingController(text: inst.notes ?? '');
    _dueDate = inst.nextDueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _countController.dispose();
    _intervalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _parsedCount =>
      int.tryParse(normalizeNumericInput(_countController.text)) ?? 0;
  int get _parsedAmount =>
      int.tryParse(normalizeNumericInput(_amountController.text)) ?? 0;

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty &&
      _parsedAmount > 0 &&
      _parsedCount > 0;

  void _submit(BuildContext sheetContext) {
    final l10n = context.l10n;
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'عنوان، مبلغ قسط و تعداد اقساط را کامل کنید.'
                : 'Fill in title, installment amount and count.',
          ),
        ),
      );
      return;
    }

    final inst = widget.installment;
    final now = DateTime.now();
    final updated = inst.copyWith(
      title: _titleController.text.trim(),
      installmentAmount: Money.fromMinor(
        _parsedAmount,
        inst.installmentAmount.currency,
      ),
      totalAmount: Money.fromMinor(
        _parsedAmount * _parsedCount,
        inst.totalAmount.currency,
      ),
      numberOfInstallments: _parsedCount,
      recurrenceIntervalDays:
          int.tryParse(normalizeNumericInput(_intervalController.text)) ??
          inst.recurrenceIntervalDays,
      nextDueDate: _dueDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      updatedAt: now,
    );

    context.read<InstallmentBloc>().add(InstallmentUpdateSubmitted(updated));
    Navigator.of(sheetContext).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final inst = widget.installment;

    return AppBottomSheet(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(title: isFa ? 'ویرایش قسط' : 'Edit Installment'),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _titleController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: isFa ? 'عنوان وام / کالا' : 'Title',
                  prefixIcon: const Icon(Icons.title_rounded),
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PersianThousandsSeparatorTextInputFormatter(
                    enabled: isFaLocale(context),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'مبلغ هر قسط' : 'Installment Amount',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: isFa ? 'تومان' : '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        PersianDigitsTextInputFormatter(
                          enabled: isFaLocale(context),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: isFa ? 'تعداد کل اقساط' : 'Total Count',
                        prefixIcon: const Icon(
                          Icons.format_list_numbered_rounded,
                        ),
                        suffixText: isFa ? 'قسط' : '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        PersianDigitsTextInputFormatter(
                          enabled: isFaLocale(context),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: isFa ? 'فاصله (روز)' : 'Interval (days)',
                        prefixIcon: const Icon(Icons.date_range_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Next due date — Jalali display when the locale is Persian.
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showAppDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(isFa ? 'سررسید قسط بعدی' : 'Next due date'),
                        ],
                      ),
                      Text(
                        AppDateFormatter.formatShort(
                          _dueDate,
                          locale: l10n.localeName,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isFa ? 'یادداشت (اختیاری)' : 'Notes (optional)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Computed totals preview — same derivation the create flow uses
              // (total = قسط × تعداد). Already-paid installments are untouched.
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurfaceVariant)
                          .withValues(alpha: 0.6),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFa ? 'مبلغ کل طرح' : 'Plan total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext,
                      ),
                    ),
                    AppMoneyText(
                      money: Money.fromMinor(
                        _parsedAmount * _parsedCount,
                        inst.totalAmount.currency,
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: l10n.save, onPressed: () => _submit(context)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
