import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../domain/entities/debt_entity.dart';
import '../../domain/repositories/debt_repository.dart';

/// Edit sheet for an existing debt/receivable. Paid amount and status are
/// managed by the payment flow and are never touched here.
class EditDebtSheet extends StatefulWidget {
  final DebtEntity debt;

  const EditDebtSheet({super.key, required this.debt});

  static Future<void> show(BuildContext context, DebtEntity debt) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditDebtSheet(debt: debt),
    );
  }

  @override
  State<EditDebtSheet> createState() => _EditDebtSheetState();
}

class _EditDebtSheetState extends State<EditDebtSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _nameController = TextEditingController(text: debt.contactName);
    _phoneController = TextEditingController(text: debt.contactPhone ?? '');
    _amountController = TextEditingController(
      text: debt.totalAmount.minorUnits.toString(),
    );
    _notesController = TextEditingController(text: debt.notes ?? '');
    _dueDate = debt.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_saving) return;
    final name = _nameController.text.trim();
    final amountMinor =
        int.tryParse(normalizeNumericInput(_amountController.text)) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'نام طرف حساب را وارد کنید.'
                : 'Enter the counterparty name.',
          ),
        ),
      );
      return;
    }
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'مبلغ را درست وارد کنید.'
                : 'Enter a valid amount.',
          ),
        ),
      );
      return;
    }
    if (amountMinor < widget.debt.paidAmount.minorUnits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'مبلغ جدید نمی‌تواند کمتر از مبلغ پرداخت‌شده باشد.'
                : 'New amount cannot be less than the paid amount.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final old = widget.debt;
    final phone = _phoneController.text.trim();
    final notes = _notesController.text.trim();

    final updated = DebtEntity(
      id: old.id,
      contactName: name,
      contactPhone: phone.isEmpty ? null : phone,
      type: old.type,
      totalAmount: Money.fromMinor(amountMinor, old.totalAmount.currency),
      paidAmount: old.paidAmount,
      dueDate: _dueDate,
      status: old.status,
      notes: notes.isEmpty ? null : notes,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: old.deletedAt,
    );

    final result = await sl<DebtRepository>().updateDebt(updated);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(),
      onFailure: (failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFa = context.l10n.isPersian;
    final debt = widget.debt;

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
              AppSheetHeader(
                title: isFa
                    ? (debt.type == DebtType.receivable
                          ? 'ویرایش طلب'
                          : 'ویرایش بدهی')
                    : (debt.type == DebtType.receivable
                          ? 'Edit Receivable'
                          : 'Edit Debt'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: isFa ? 'نام طرف حساب' : 'Counterparty name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  PersianDigitsTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'شماره تماس (اختیاری)' : 'Phone (optional)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PersianThousandsSeparatorTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'مبلغ کل' : 'Total amount',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: isFa ? 'تومان' : '',
                ),
              ),
              if (debt.paidAmount.minorUnits > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      isFa ? 'پرداخت‌شده تاکنون: ' : 'Paid so far: ',
                      style: theme.textTheme.bodySmall,
                    ),
                    AppMoneyText(
                      money: debt.paidAmount,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showAppDatePicker(
                    context: context,
                    initialDate: _dueDate ?? now.add(const Duration(days: 30)),
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
                          Text(isFa ? 'تاریخ سررسید' : 'Due date'),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _dueDate != null
                                ? AppDateFormatter.formatShort(
                                    _dueDate!,
                                    locale: context.l10n.localeName,
                                  )
                                : (isFa ? 'بدون سررسید' : 'No due date'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.income,
                            ),
                          ),
                          if (_dueDate != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _dueDate = null),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: isFa ? 'یادداشت (اختیاری)' : 'Notes (optional)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: isFa ? 'ذخیره تغییرات' : 'Save changes',
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
