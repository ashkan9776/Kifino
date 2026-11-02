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
import '../../domain/entities/check_entity.dart';
import '../../domain/repositories/check_repository.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';

/// Edit sheet for an existing check. The STATUS is deliberately not editable
/// here — status changes go through the consequence-aware flow (voucher
/// reconciliation + audit log) via `تغییر وضعیت`.
class EditCheckSheet extends StatefulWidget {
  final CheckEntity check;

  const EditCheckSheet({super.key, required this.check});

  static Future<void> show(BuildContext context, CheckEntity check) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCheckSheet(check: check),
    );
  }

  @override
  State<EditCheckSheet> createState() => _EditCheckSheetState();
}

class _EditCheckSheetState extends State<EditCheckSheet> {
  late final TextEditingController _numberController;
  late final TextEditingController _sayadiController;
  late final TextEditingController _bankController;
  late final TextEditingController _amountController;
  late final TextEditingController _partyController;
  late final TextEditingController _notesController;
  late DateTime _dueDate;
  String? _accountId;
  List<AccountEntity> _accounts = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final check = widget.check;
    _numberController = TextEditingController(text: check.checkNumber);
    _sayadiController = TextEditingController(text: check.sayadiId ?? '');
    _bankController = TextEditingController(text: check.bankName);
    _amountController = TextEditingController(
      text: check.amount.minorUnits.toString(),
    );
    _partyController = TextEditingController(text: check.partyName);
    _notesController = TextEditingController(text: check.notes ?? '');
    _dueDate = check.dueDate;
    _accountId = check.accountId;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final result = await sl<AccountRepository>().getAccounts();
    if (!mounted) return;
    result.fold(
      onSuccess: (accounts) {
        // Cash/bank accounts only make sense for a check's settlement account.
        setState(() => _accounts = accounts);
      },
      onFailure: (_) {},
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _sayadiController.dispose();
    _bankController.dispose();
    _amountController.dispose();
    _partyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_saving) return;
    final number = _numberController.text.trim();
    final bank = _bankController.text.trim();
    final party = _partyController.text.trim();
    final amountMinor =
        int.tryParse(normalizeNumericInput(_amountController.text)) ?? 0;

    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'شماره چک را وارد کنید.'
                : 'Enter the check number.',
          ),
        ),
      );
      return;
    }
    if (bank.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian ? 'نام بانک را وارد کنید.' : 'Enter the bank name.',
          ),
        ),
      );
      return;
    }
    if (party.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'نام طرف چک را وارد کنید.'
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
                ? 'مبلغ چک را درست وارد کنید.'
                : 'Enter a valid amount.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final old = widget.check;
    final sayadi = _sayadiController.text.trim();
    final notes = _notesController.text.trim();

    final updated = CheckEntity(
      id: old.id,
      checkNumber: number,
      sayadiId: sayadi.isEmpty ? null : sayadi,
      bankName: bank,
      type: old.type,
      amount: Money.fromMinor(amountMinor, old.amount.currency),
      partyName: party,
      dueDate: _dueDate,
      accountId: _accountId,
      status: old.status,
      frontImagePath: old.frontImagePath,
      backImagePath: old.backImagePath,
      notes: notes.isEmpty ? null : notes,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: old.deletedAt,
    );

    final result = await sl<CheckRepository>().updateCheck(updated);
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
    final check = widget.check;

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
                    ? (check.type == CheckType.received
                          ? 'ویرایش چک دریافتی'
                          : 'ویرایش چک صادره')
                    : (check.type == CheckType.received
                          ? 'Edit received check'
                          : 'Edit issued check'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isFa
                    ? 'وضعیت چک از این بخش تغییر نمی‌کند؛ برای تغییر وضعیت از دکمه «تغییر وضعیت» استفاده کنید.'
                    : 'Status is not changed here; use "Change status" for that.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.darkSubtext
                      : AppColors.lightSubtext,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PersianDigitsTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'شماره چک' : 'Check number',
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _sayadiController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PersianDigitsTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'شناسه صیادی (اختیاری)'
                      : 'Sayadi ID (optional)',
                  prefixIcon: const Icon(Icons.qr_code_2_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _bankController,
                decoration: InputDecoration(
                  labelText: isFa ? 'نام بانک' : 'Bank name',
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _partyController,
                decoration: InputDecoration(
                  labelText: isFa
                      ? (check.type == CheckType.received
                            ? 'نام پرداخت‌کننده'
                            : 'نام دریافت‌کننده')
                      : 'Counterparty',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
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
                  labelText: isFa ? 'مبلغ چک' : 'Amount',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: isFa ? 'تومان' : '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _pickDate,
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
                          const Icon(Icons.event_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(isFa ? 'تاریخ سررسید' : 'Due date'),
                        ],
                      ),
                      Text(
                        AppDateFormatter.formatShort(
                          _dueDate,
                          locale: context.l10n.localeName,
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
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      isFa ? 'بدون حساب تسویه' : 'No settlement account',
                    ),
                  ),
                  ..._accounts.map(
                    (acc) =>
                        DropdownMenuItem(value: acc.id, child: Text(acc.name)),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'حساب تسویه (اختیاری)'
                      : 'Settlement account (optional)',
                  prefixIcon: const Icon(Icons.wallet_outlined),
                ),
                onChanged: (val) => setState(() => _accountId = val),
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
