import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/category_repository.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../../domain/services/recurrence.dart';
import '../cubit/recurring_cubit.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Arguments for opening the editor: an existing rule to edit, or a
/// template (title + type) to prefill a new one.
class RecurringEditorArgs {
  final RecurringRuleEntity? rule;
  final String? templateTitle;
  final TransactionType? templateType;
  final int? templateIconCodePoint;

  const RecurringEditorArgs({
    this.rule,
    this.templateTitle,
    this.templateType,
    this.templateIconCodePoint,
  });
}

class RecurringEditorPage extends StatefulWidget {
  final RecurringEditorArgs args;

  const RecurringEditorPage({
    super.key,
    this.args = const RecurringEditorArgs(),
  });

  @override
  State<RecurringEditorPage> createState() => _RecurringEditorPageState();
}

class _RecurringEditorPageState extends State<RecurringEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late TransactionType _type;
  late int _amountMinor;
  late RecurrenceFrequency _frequency;
  late int _interval;
  late DateTime _start;
  late bool _autoPost;
  late int _remindDaysBefore;
  int? _maxOccurrences;
  String? _accountId;
  String? _destinationId;
  String? _categoryId;
  bool _saving = false;

  bool get _isNew => widget.args.rule == null;

  @override
  void initState() {
    super.initState();
    final r = widget.args.rule;
    _title = TextEditingController(
      text: r?.title ?? widget.args.templateTitle ?? '',
    );
    _notes = TextEditingController(text: r?.notes ?? '');
    _type = r?.type ?? widget.args.templateType ?? TransactionType.expense;
    _amountMinor = r?.amount.minorUnits ?? 0;
    _frequency = r?.frequency ?? RecurrenceFrequency.monthly;
    _interval = r?.interval ?? 1;
    final now = DateTime.now();
    _start = r?.startDate ?? DateTime(now.year, now.month, now.day, 9);
    _autoPost = r?.autoPost ?? true;
    _remindDaysBefore = r?.remindDaysBefore ?? 1;
    _maxOccurrences = r?.maxOccurrences;
    _accountId = r?.accountId;
    _destinationId = r?.destinationAccountId;
    _categoryId = r?.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Currency get _currency {
    final accounts = _accounts(context);
    for (final a in accounts) {
      if (a.id == _accountId) return a.currency;
    }
    return widget.args.rule?.amount.currency ?? AppCurrency.base;
  }

  List<AccountEntity> _accounts(BuildContext context) {
    final state = context.read<AccountsBloc>().state;
    return state is AccountsLoaded
        ? state.accounts.where((a) => !a.isArchived).toList()
        : const [];
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    String? problem;
    if (_title.text.trim().isEmpty) {
      problem = 'یک عنوان بنویسید؛ مثلاً «اجاره».';
    }
    if (_amountMinor <= 0) problem ??= 'مبلغ را وارد کنید.';
    if (_accountId == null) problem ??= 'حساب را انتخاب کنید.';
    if (_type == TransactionType.transfer &&
        (_destinationId == null || _destinationId == _accountId)) {
      problem ??= 'حساب مقصد را انتخاب کنید.';
    }
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.args.rule;
    final rule = RecurringRuleEntity(
      id: existing?.id ?? '',
      title: _title.text.trim(),
      type: _type,
      accountId: _accountId!,
      destinationAccountId: _type == TransactionType.transfer
          ? _destinationId
          : null,
      categoryId: _type == TransactionType.transfer ? null : _categoryId,
      amount: Money.fromMinor(_amountMinor, _currency),
      frequency: _frequency,
      interval: _interval,
      startDate: _start,
      nextIndex: existing?.nextIndex ?? 0,
      nextRunDate: existing?.nextRunDate ?? _start,
      maxOccurrences: _maxOccurrences,
      postedCount: existing?.postedCount ?? 0,
      autoPost: _autoPost,
      remindDaysBefore: _remindDaysBefore,
      isActive: existing?.isActive ?? true,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final ok = await context.read<RecurringCubit>().save(rule, isNew: _isNew);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final accounts = context.watch<AccountsBloc>().state is AccountsLoaded
        ? _accounts(context)
        : const <AccountEntity>[];
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;

    final typeColor = switch (_type) {
      TransactionType.income => colors.income,
      TransactionType.transfer => colors.transfer,
      _ => colors.expense,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'تراکنش تکراری جدید' : 'ویرایش تراکنش تکراری'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(_isNew ? 'ذخیره و فعال‌سازی' : 'ذخیره تغییرات'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('هزینه'),
                icon: Icon(Icons.north_east_rounded, size: 18),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('درآمد'),
                icon: Icon(Icons.south_west_rounded, size: 18),
              ),
              ButtonSegment(
                value: TransactionType.transfer,
                label: Text('انتقال'),
                icon: Icon(Icons.swap_horiz_rounded, size: 18),
              ),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مبلغ هر نوبت', style: _label(colors)),
                const SizedBox(height: AppSpacing.xs),
                AppAmountField(
                  currency: _currency,
                  initialAmountMinor: _amountMinor,
                  autoFocus: _isNew && widget.args.templateTitle != null,
                  signColor: typeColor,
                  onAmountMinorChanged: (v) => _amountMinor = v,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'عنوان',
                    hintText: 'مثلاً اجاره خانه، حقوق، اینترنت',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AccountPicker(
            label: _type == TransactionType.income
                ? 'واریز به حساب'
                : 'برداشت از حساب',
            accounts: accounts,
            selectedId: _accountId,
            onChanged: (id) => setState(() => _accountId = id),
          ),
          if (_type == TransactionType.transfer) ...[
            const SizedBox(height: AppSpacing.md),
            _AccountPicker(
              label: 'به حساب',
              accounts: accounts.where((a) => a.id != _accountId).toList(),
              selectedId: _destinationId,
              onChanged: (id) => setState(() => _destinationId = id),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            _CategoryPicker(
              type: _type == TransactionType.income
                  ? CategoryType.income
                  : CategoryType.expense,
              selectedId: _categoryId,
              onChanged: (id) => setState(() => _categoryId = id),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تکرار', style: _label(colors)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final f in RecurrenceFrequency.values)
                      ChoiceChip(
                        label: Text(f.titleFa),
                        selected: _frequency == f,
                        onSelected: (_) => setState(() => _frequency = f),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _interval == 1
                            ? 'هر ${_frequency.unitFa}'
                            : TextNormalizer.auto(
                                'هر $_interval ${_frequency.unitFa}',
                              ),
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'کمتر',
                      onPressed: _interval > 1
                          ? () => setState(() => _interval--)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.outlined(
                      tooltip: 'بیشتر',
                      onPressed: _interval < 12
                          ? () => setState(() => _interval++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                _RowButton(
                  icon: Icons.event_rounded,
                  title: _isNew ? 'اولین نوبت' : 'تاریخ شروع',
                  value: AppDateFormatter.format(_start, locale: 'fa'),
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(
                        () => _start = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          9,
                        ),
                      );
                    }
                  },
                ),
                if (_isNew &&
                    _start.isBefore(
                      DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ),
                    ))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'نوبت‌های گذشته از این تاریخ تا امروز هم ثبت می‌شوند.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.warning,
                      ),
                    ),
                  ),
                const Divider(height: AppSpacing.lg),
                _RowButton(
                  icon: Icons.flag_outlined,
                  title: 'پایان',
                  value: _maxOccurrences == null
                      ? 'بدون پایان'
                      : TextNormalizer.auto('بعد از $_maxOccurrences نوبت'),
                  onTap: _pickEnd,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                SwitchListTile(
                  value: _autoPost,
                  onChanged: (v) => setState(() => _autoPost = v),
                  title: const Text('ثبت خودکار'),
                  subtitle: Text(
                    _autoPost
                        ? 'در موعد، خودش در حساب ثبت می‌شود.'
                        : 'فقط یادآوری می‌کند؛ پرداخت را خودتان تأیید می‌کنید.',
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('یادآوری', style: AppTypography.titleSmall),
                      ),
                      for (final days in const [0, 1, 3])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: ChoiceChip(
                            label: Text(
                              days == 0
                                  ? 'همان روز'
                                  : TextNormalizer.auto('$days روز قبل'),
                            ),
                            selected: _remindDaysBefore == days,
                            onSelected: (_) =>
                                setState(() => _remindDaysBefore = days),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'یادداشت (اختیاری)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _pickEnd() async {
    final choice = await showAppModalSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive_rounded),
              title: const Text('بدون پایان'),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            for (final n in const [3, 6, 12, 24, 36])
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(TextNormalizer.auto('بعد از $n نوبت')),
                onTap: () => Navigator.pop(ctx, n),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    setState(() => _maxOccurrences = choice == 0 ? null : choice);
  }

  TextStyle _label(KifinoColorsExtension colors) =>
      AppTypography.labelLarge.copyWith(color: colors.textSecondary);
}

class _RowButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _RowButton({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTypography.titleSmall)),
            Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  final String label;
  final List<AccountEntity> accounts;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  const _AccountPicker({
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm, right: 4),
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        if (accounts.isEmpty)
          Text(
            'اول یک حساب بسازید.',
            style: AppTypography.bodyMedium.copyWith(color: colors.expense),
          )
        else
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final a = accounts[i];
                return ChoiceChip(
                  avatar: Icon(
                    a.type == AccountType.cashWallet
                        ? Icons.payments_outlined
                        : Icons.credit_card_rounded,
                    size: 18,
                  ),
                  label: Text(a.name),
                  selected: a.id == selectedId,
                  onSelected: (_) => onChanged(a.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final CategoryType type;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _CategoryPicker({
    required this.type,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    return StreamBuilder<List<CategoryEntity>>(
      stream: sl<CategoryRepository>().watchCategories(type: type),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <CategoryEntity>[];
        if (categories.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm, right: 4),
              child: Text(
                'دسته‌بندی',
                style: AppTypography.labelLarge.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final c = categories[i];
                  final selected = c.id == selectedId;
                  return ChoiceChip(
                    avatar: Icon(
                      IconUtils.getIconData(c.iconCodePoint),
                      size: 18,
                    ),
                    label: Text(c.name),
                    selected: selected,
                    onSelected: (_) => onChanged(selected ? null : c.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
