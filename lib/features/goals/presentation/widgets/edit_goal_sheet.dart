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
import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';

/// Edit sheet for an existing savings goal. Current amount (progress) is
/// managed by the contribute flow and is never touched here.
class EditGoalSheet extends StatefulWidget {
  final GoalEntity goal;

  const EditGoalSheet({super.key, required this.goal});

  static Future<void> show(BuildContext context, GoalEntity goal) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditGoalSheet(goal: goal),
    );
  }

  @override
  State<EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<EditGoalSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _notesController;
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal.name);
    _targetController = TextEditingController(
      text: goal.targetAmount.minorUnits.toString(),
    );
    _notesController = TextEditingController(text: goal.notes ?? '');
    _targetDate = goal.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_saving) return;
    final name = _nameController.text.trim();
    final targetMinor =
        int.tryParse(normalizeNumericInput(_targetController.text)) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian ? 'نام هدف را وارد کنید.' : 'Enter the goal name.',
          ),
        ),
      );
      return;
    }
    if (targetMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'مبلغ هدف را درست وارد کنید.'
                : 'Enter a valid target amount.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final old = widget.goal;
    final notes = _notesController.text.trim();

    final updated = GoalEntity(
      id: old.id,
      name: name,
      targetAmount: Money.fromMinor(targetMinor, old.targetAmount.currency),
      currentAmount: old.currentAmount,
      status: old.status,
      targetDate: _targetDate,
      notes: notes.isEmpty ? null : notes,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: old.deletedAt,
      syncStatus: old.syncStatus,
      version: old.version,
    );

    final result = await sl<GoalRepository>().updateGoal(updated);
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
    final goal = widget.goal;

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
              AppSheetHeader(title: isFa ? 'ویرایش هدف' : 'Edit Goal'),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: isFa ? 'نام هدف' : 'Goal name',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PersianThousandsSeparatorTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'مبلغ هدف' : 'Target amount',
                  prefixIcon: const Icon(Icons.savings_outlined),
                  suffixText: isFa ? 'تومان' : '',
                ),
              ),
              if (goal.currentAmount.minorUnits > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      isFa ? 'پس‌انداز شده تاکنون: ' : 'Saved so far: ',
                      style: theme.textTheme.bodySmall,
                    ),
                    AppMoneyText(
                      money: goal.currentAmount,
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
                    initialDate:
                        _targetDate ?? now.add(const Duration(days: 365)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setState(() => _targetDate = picked);
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
                          const Icon(Icons.event_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(isFa ? 'تاریخ هدف' : 'Target date'),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _targetDate != null
                                ? AppDateFormatter.formatShort(
                                    _targetDate!,
                                    locale: context.l10n.localeName,
                                  )
                                : (isFa ? 'بدون تاریخ' : 'No date'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.income,
                            ),
                          ),
                          if (_targetDate != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () =>
                                  setState(() => _targetDate = null),
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
