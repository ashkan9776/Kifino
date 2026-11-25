import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_kit.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_responsive_container.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../ai_assistant/domain/entities/parsed_transaction_draft.dart';
import '../../../ai_assistant/domain/services/iranian_bank_sms_parser.dart';
import '../../../ai_assistant/domain/services/persian_nlp_transaction_parser.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../bloc/transaction_bloc.dart';
import '../widgets/category_icon_color_picker.dart';

class FastAddTransactionPage extends StatefulWidget {
  /// Quick-add type preset pushed as `extra`: 'income' | 'expense' | 'transfer'.
  final String? initialType;

  /// When non-null the page runs in edit mode for this transaction.
  final TransactionEntity? editTransaction;

  const FastAddTransactionPage({
    super.key,
    this.initialType,
    this.editTransaction,
  });

  @override
  State<FastAddTransactionPage> createState() => _FastAddTransactionPageState();
}

class _FastAddTransactionPageState extends State<FastAddTransactionPage> {
  int _selectedTypeIndex = 0; // 0: Expense, 1: Income, 2: Transfer
  int _amountMinor = 0;
  late final ValueNotifier<int> _amountNotifier = ValueNotifier<int>(
    _amountMinor,
  );
  DateTime _selectedDate = DateTime.now();
  String? _selectedAccountId;
  String? _selectedDestAccountId;
  String? _selectedCategoryId;
  final TextEditingController _noteController = TextEditingController();

  List<AccountEntity> _accounts = [];
  List<CategoryEntity> _categories = [];
  bool _isLoadingDeps = true;

  static const List<int> _quickChipsToman = [50000, 100000, 200000, 500000];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedTypeIndex = switch (widget.initialType) {
        'income' => 1,
        'transfer' => 2,
        _ => 0, // 'expense'
      };
    }
    _loadDependencies();
  }

  String? _defaultCategoryIdFor(int typeIndex) {
    final filtered = _categories.where((cat) {
      if (typeIndex == 0) return cat.type == CategoryType.expense;
      if (typeIndex == 1) return cat.type == CategoryType.income;
      return false;
    }).toList();
    return filtered.isNotEmpty ? filtered.first.id : null;
  }

  Future<void> _loadDependencies() async {
    final accsResult = await sl<AccountRepository>().getAccounts();
    final catsResult = await sl<CategoryRepository>().getCategories();
    if (mounted) {
      setState(() {
        _accounts = accsResult.dataOrNull ?? [];
        _categories = catsResult.dataOrNull ?? [];
        final editTx = widget.editTransaction;

        if (_accounts.isNotEmpty) {
          if (editTx != null &&
              _accounts.any((a) => a.id == editTx.accountId)) {
            _selectedAccountId = editTx.accountId;
          } else {
            _selectedAccountId = _accounts.first.id;
          }
          if (_accounts.length > 1) {
            final editDestinationId = editTx?.destinationAccountId;
            if (editDestinationId != null &&
                editDestinationId != _selectedAccountId &&
                _accounts.any((a) => a.id == editDestinationId)) {
              _selectedDestAccountId = editDestinationId;
            } else {
              _selectedDestAccountId = _accounts
                  .firstWhere(
                    (a) => a.id != _selectedAccountId,
                    orElse: () => _accounts.last,
                  )
                  .id;
            }
          }
        }

        if (editTx != null) {
          _amountMinor = editTx.amount.minorUnits;
          _amountNotifier.value = _amountMinor;
          _noteController.text = editTx.notes ?? '';
          _selectedDate = editTx.date;
          _selectedTypeIndex = switch (editTx.type) {
            TransactionType.income => 1,
            TransactionType.transfer => 2,
            _ => 0, // expense and any other type maps to expense
          };
        }

        if (_categories.isNotEmpty) {
          final editCategoryId = editTx?.categoryId;
          if (editCategoryId != null &&
              _categories.any((c) => c.id == editCategoryId)) {
            _selectedCategoryId = editCategoryId;
          } else {
            _selectedCategoryId = _defaultCategoryIdFor(_selectedTypeIndex);
          }
        }
        _isLoadingDeps = false;
      });
    }
  }

  Future<void> _pasteBankSms() async {
    final l10n = context.l10n;
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = clipData?.text?.trim() ?? '';
    if (!mounted) return;

    if (raw.isNotEmpty) {
      final parsed =
          IranianBankSmsParser.parse(raw, accounts: _accounts) ??
          PersianNlpTransactionParser.parse(raw, accounts: _accounts);
      if (parsed != null) {
        _applyParsedDraft(parsed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isPersian
                  ? 'اطلاعات پیامک بانکی با موفقیت جایگذاری شد'
                  : 'Bank SMS fields populated from clipboard',
            ),
            backgroundColor: AppColors.incomeLight,
          ),
        );
        return;
      }
    }

    await _showManualSmsDialog(initialText: raw);
  }

  Future<void> _showManualSmsDialog({String initialText = ''}) async {
    final l10n = context.l10n;
    final smsController = TextEditingController(text: initialText);
    try {
      final submitted = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            l10n.isPersian ? 'چسباندن پیامک بانکی' : 'Paste Bank SMS',
          ),
          content: TextField(
            controller: smsController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: l10n.isPersian
                  ? 'متن پیامک تراکنش بانکی (برداشت/واریز) را اینجا وارد کنید...'
                  : 'Paste bank transaction SMS here...',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(smsController.text.trim()),
              child: Text(
                l10n.isPersian ? 'تحلیل و پر کردن فرم' : 'Parse & Fill',
              ),
            ),
          ],
        ),
      );

      if (!mounted || submitted == null || submitted.isEmpty) return;

      final parsed =
          IranianBankSmsParser.parse(submitted, accounts: _accounts) ??
          PersianNlpTransactionParser.parse(submitted, accounts: _accounts);

      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isPersian
                  ? 'مبلغ معتبری در متن پیامک پیدا نشد.'
                  : 'Could not extract a valid transaction from text.',
            ),
            backgroundColor: AppColors.expenseLight,
          ),
        );
        return;
      }

      _applyParsedDraft(parsed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'اطلاعات پیامک بانکی با موفقیت جایگذاری شد'
                : 'Bank SMS fields populated',
          ),
          backgroundColor: AppColors.incomeLight,
        ),
      );
    } finally {
      smsController.dispose();
    }
  }

  void _applyParsedDraft(ParsedTransactionDraft draft) {
    final nextTypeIndex = switch (draft.type) {
      TransactionType.income => 1,
      TransactionType.transfer => 2,
      _ => 0,
    };

    String? nextAccountId = _selectedAccountId;
    if (draft.matchedAccountId != null &&
        _accounts.any((a) => a.id == draft.matchedAccountId)) {
      nextAccountId = draft.matchedAccountId;
    }
    nextAccountId ??= _accounts.isNotEmpty ? _accounts.first.id : null;

    AccountEntity? targetAcc;
    if (nextAccountId != null) {
      targetAcc = _accounts.where((a) => a.id == nextAccountId).firstOrNull;
    }

    Money resolvedMoney = draft.amount;
    if (targetAcc != null &&
        resolvedMoney.currency != targetAcc.currency &&
        resolvedMoney.isCompatibleWith(targetAcc.currency)) {
      resolvedMoney = resolvedMoney.normalizeTo(targetAcc.currency);
    }

    String? matchedCatId;
    if (nextTypeIndex != 2) {
      final catType = nextTypeIndex == 0
          ? CategoryType.expense
          : CategoryType.income;
      final hint = draft.suggestedCategory?.trim();
      if (hint != null && hint.isNotEmpty) {
        for (final cat in _categories) {
          if (cat.type == catType &&
              (cat.name == hint || cat.name.contains(hint))) {
            matchedCatId = cat.id;
            break;
          }
        }
      }
      matchedCatId ??= _defaultCategoryIdFor(nextTypeIndex);
    }

    setState(() {
      _selectedTypeIndex = nextTypeIndex;
      _selectedAccountId = nextAccountId;
      _selectedCategoryId = matchedCatId;
      _selectedDate = draft.date;
      _amountMinor = resolvedMoney.minorUnits;
      _amountNotifier.value = _amountMinor;
      _noteController.text = draft.description;
    });
    HapticFeedback.lightImpact();
  }

  /// Refreshes categories after returning from the custom-categories manager,
  /// keeping the current selection when it is still valid for the active type.
  Future<void> _reloadCategories() async {
    final catsResult = await sl<CategoryRepository>().getCategories();
    if (!mounted) return;
    setState(() {
      _categories = catsResult.dataOrNull ?? _categories;
      final activeType = _selectedTypeIndex == 0
          ? CategoryType.expense
          : CategoryType.income;
      final stillValid = _categories.any(
        (c) => c.id == _selectedCategoryId && c.type == activeType,
      );
      if (!stillValid) {
        _selectedCategoryId = _defaultCategoryIdFor(_selectedTypeIndex);
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onSave() {
    final l10n = context.l10n;

    if (_amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.amountRequired),
          backgroundColor: AppColors.expenseLight,
        ),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.accountRequired),
          backgroundColor: AppColors.expenseLight,
        ),
      );
      return;
    }

    final txType = switch (_selectedTypeIndex) {
      0 => TransactionType.expense,
      1 => TransactionType.income,
      _ => TransactionType.transfer,
    };

    final sourceAccount = _accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
    );
    final currency = sourceAccount.currency;
    final noteText = _noteController.text.trim();

    final editTx = widget.editTransaction;
    if (editTx != null) {
      // Edit mode: update the existing transaction in place (same
      // id/createdAt/version), never create a new one.
      final updated = TransactionEntity(
        id: editTx.id,
        accountId: _selectedAccountId!,
        destinationAccountId: txType == TransactionType.transfer
            ? _selectedDestAccountId
            : null,
        categoryId: txType != TransactionType.transfer
            ? _selectedCategoryId
            : null,
        amount: Money.fromMinor(_amountMinor, currency),
        type: txType,
        date: _selectedDate,
        description: noteText.isNotEmpty ? noteText : editTx.description,
        notes: noteText.isNotEmpty ? noteText : null,
        isBusiness: editTx.isBusiness,
        attachmentUri: editTx.attachmentUri,
        createdAt: editTx.createdAt,
        updatedAt: DateTime.now(),
        deletedAt: editTx.deletedAt,
        syncStatus: editTx.syncStatus,
        version: editTx.version,
      );

      context.read<TransactionBloc>().add(TransactionUpdateSubmitted(updated));
      HapticFeedback.mediumImpact();
      context.pop();
      return;
    }

    final tx = TransactionEntity(
      id: const Uuid().v4(),
      accountId: _selectedAccountId!,
      destinationAccountId: txType == TransactionType.transfer
          ? _selectedDestAccountId
          : null,
      categoryId: txType != TransactionType.transfer
          ? _selectedCategoryId
          : null,
      amount: Money.fromMinor(_amountMinor, currency),
      type: txType,
      date: _selectedDate,
      // Without a note, the category name is the most useful title.
      description: noteText.isNotEmpty
          ? noteText
          : (_categories
                    .where((c) => c.id == _selectedCategoryId)
                    .firstOrNull
                    ?.name ??
                (txType == TransactionType.expense
                    ? 'هزینه'
                    : (txType == TransactionType.income ? 'درآمد' : 'انتقال'))),
      notes: noteText.isNotEmpty ? noteText : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.read<TransactionBloc>().add(TransactionCreateSubmitted(tx));
    HapticFeedback.mediumImpact();
    context.pop();
  }

  // ─── Kifino 2 layout ──────────────────────────────────────────────────

  TransactionType get _type => switch (_selectedTypeIndex) {
    0 => TransactionType.expense,
    1 => TransactionType.income,
    _ => TransactionType.transfer,
  };

  /// Auto-generated rows (installment/check/debt/goal) keep their money
  /// fields locked: they must be changed in the owning module.
  bool get _moneyLocked => widget.editTransaction?.isAutoGenerated ?? false;

  void _setType(int index) {
    if (_moneyLocked || index == _selectedTypeIndex) return;
    setState(() {
      _selectedTypeIndex = index;
      _selectedCategoryId = _defaultCategoryIdFor(index);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _confirmDelete() async {
    final tx = widget.editTransaction;
    if (tx == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این تراکنش؟'),
        content: const Text('مانده حساب به حالت قبل برمی‌گردد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.customColors.expense,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<TransactionBloc>().add(TransactionDeleteSubmitted(tx.id));
    HapticFeedback.mediumImpact();
    context.pop();
  }

  Future<void> _pickAccount({required bool destination}) async {
    final colors = context.customColors;
    final options = destination
        ? _accounts.where((a) => a.id != _selectedAccountId).toList()
        : _accounts;
    final current = destination ? _selectedDestAccountId : _selectedAccountId;
    final picked = await showAppSheet<String>(
      context: context,
      title: destination ? 'به حساب' : 'انتخاب حساب',
      builder: (ctx) => Column(
        children: [
          for (final a in options)
            AppListRow(
              icon: _accountIcon(a.type),
              iconColor: Theme.of(context).colorScheme.primary,
              title: a.name,
              subtitle: a.currentBalance.format(usePersianDigits: true),
              showChevron: false,
              trailing: a.id == current
                  ? Icon(Icons.check_circle_rounded, color: colors.income)
                  : null,
              onTap: () => Navigator.pop(ctx, a.id),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (destination) {
        _selectedDestAccountId = picked;
      } else {
        _selectedAccountId = picked;
        if (_selectedDestAccountId == picked) {
          _selectedDestAccountId = _accounts
              .where((a) => a.id != picked)
              .firstOrNull
              ?.id;
        }
      }
    });
  }

  Future<void> _showAllCategories(List<CategoryEntity> categories) async {
    final picked = await showAppSheet<String>(
      context: context,
      title: context.l10n.selectCategory,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppChoiceGrid<String>(
            choices: [for (final c in categories) _categoryChoice(c)],
            selected: _selectedCategoryId,
            onSelected: (id) => Navigator.pop(ctx, id),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.push('/categories');
              if (mounted) await _reloadCategories();
            },
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('مدیریت دسته‌بندی‌ها'),
          ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCategoryId = picked);
    }
  }

  AppChoice<String> _categoryChoice(CategoryEntity c) => AppChoice<String>(
    value: c.id,
    label: c.name,
    icon: CategoryIconAssets.resolve(c.iconCodePoint),
    color: parseHexColor(c.colorHex) ?? Theme.of(context).colorScheme.primary,
  );

  static IconData _accountIcon(AccountType type) => switch (type) {
    AccountType.bankCard => Icons.credit_card_rounded,
    AccountType.cashWallet => Icons.payments_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.credit => Icons.credit_score_rounded,
    AccountType.investment => Icons.trending_up_rounded,
    AccountType.crypto => Icons.currency_bitcoin_rounded,
  };

  String _dateLabel(BuildContext context) {
    final today = DateTime.now();
    final d = DateUtils.dateOnly(_selectedDate);
    final t = DateUtils.dateOnly(today);
    if (d == t) return 'امروز';
    if (d == t.subtract(const Duration(days: 1))) return 'دیروز';
    return AppDateFormatter.format(
      _selectedDate,
      locale: context.l10n.localeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.customColors;
    final isEditing = widget.editTransaction != null;
    final editTx = widget.editTransaction;

    final typeColor = switch (_selectedTypeIndex) {
      0 => colors.expense,
      1 => colors.income,
      _ => colors.transfer,
    };

    final selectedAccount = _accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
    final destAccount = _accounts
        .where((a) => a.id == _selectedDestAccountId)
        .firstOrNull;
    final currentCurrency = selectedAccount?.currency ?? Currency.toman;

    final typeCategories = _categories.where((cat) {
      if (_selectedTypeIndex == 0) return cat.type == CategoryType.expense;
      if (_selectedTypeIndex == 1) return cat.type == CategoryType.income;
      return false;
    }).toList();
    // Show the first seven, keep the selected one visible, then «همه».
    final shown = typeCategories.take(7).toList();
    final selectedCat = typeCategories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    if (selectedCat != null && !shown.contains(selectedCat)) {
      shown
        ..removeLast()
        ..add(selectedCat);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? (l10n.isPersian ? 'ویرایش تراکنش' : 'Edit transaction')
              : l10n.addTransaction,
        ),
        leading: IconButton(
          tooltip: l10n.isPersian ? 'بستن' : 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isEditing)
            IconButton(
              tooltip: l10n.isPersian ? 'خواندن پیامک بانکی' : 'Read bank SMS',
              icon: const Icon(Icons.sms_outlined),
              onPressed: _accounts.isEmpty ? null : _pasteBankSms,
            ),
          if (isEditing && !(editTx?.isOwnedByModule ?? false))
            IconButton(
              tooltip: l10n.isPersian ? 'حذف' : 'Delete',
              icon: Icon(Icons.delete_outline_rounded, color: colors.expense),
              onPressed: _confirmDelete,
            ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: _isLoadingDeps || _accounts.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _onSave,
                child: Text(
                  isEditing
                      ? (l10n.isPersian ? 'ذخیره تغییرات' : 'Save changes')
                      : switch (_type) {
                          TransactionType.income => 'ثبت درآمد',
                          TransactionType.transfer => 'ثبت انتقال',
                          _ => 'ثبت هزینه',
                        },
                ),
              ),
            ),
      body: _isLoadingDeps
          ? const Center(child: AppSkeleton(width: 200, height: 40))
          : _accounts.isEmpty
          ? AppEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: l10n.isPersian ? 'هنوز حسابی ندارید' : 'No accounts yet',
              description: l10n.isPersian
                  ? 'برای ثبت تراکنش، ابتدا یک حساب اضافه کنید.'
                  : 'Create an account first to start recording transactions.',
              actionLabel: l10n.isPersian ? 'افزودن حساب' : 'Add an account',
              onAction: () => context.push('/accounts'),
            )
          : AppResponsiveContainer.form(
              maxWidth: 640,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                children: [
                  if (_moneyLocked) ...[
                    AppNotice(
                      icon: Icons.link_rounded,
                      message:
                          'این تراکنش خودکار از بخش «${editTx!.source!.moduleTitleFa}» آمده؛ مبلغ، نوع و حساب را از همان بخش تغییر دهید. توضیح، تاریخ و دسته قابل ویرایش است.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _TypeTabs(
                    selected: _selectedTypeIndex,
                    enabled: !_moneyLocked,
                    onChanged: _setType,
                    labels: [l10n.expense, l10n.income, l10n.transfer],
                    colors: [colors.expense, colors.income, colors.transfer],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppAmountField(
                    framed: false,
                    enabled: !_moneyLocked,
                    autoFocus: !isEditing,
                    currency: currentCurrency,
                    amountNotifier: _amountNotifier,
                    signColor: typeColor,
                    onAmountMinorChanged: (value) {
                      setState(() => _amountMinor = value);
                    },
                  ),
                  if (!_moneyLocked) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final chip in _quickChipsToman)
                            ActionChip(
                              label: Text(
                                '+ ${Money.fromMinor(chip, currentCurrency).formatCompact(isPersianLocale: l10n.isPersian)}',
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _amountMinor += chip;
                                  _amountNotifier.value = _amountMinor;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (_type != TransactionType.transfer) ...[
                    AppSectionHeader(
                      title: l10n.selectCategory,
                      actionLabel: typeCategories.length > shown.length
                          ? (l10n.isPersian ? 'همه' : 'All')
                          : (l10n.isPersian ? 'مدیریت' : 'Manage'),
                      onAction: () async {
                        if (typeCategories.length > shown.length) {
                          await _showAllCategories(typeCategories);
                        } else {
                          await context.push('/categories');
                          if (mounted) await _reloadCategories();
                        }
                      },
                    ),
                    if (typeCategories.isEmpty)
                      AppNotice(
                        message: 'هنوز دسته‌ای برای این نوع ندارید.',
                        actionLabel: 'ساخت دسته',
                        onAction: () async {
                          await context.push('/categories');
                          if (mounted) await _reloadCategories();
                        },
                      )
                    else
                      AppChoiceGrid<String>(
                        choices: [
                          for (final c in shown) _categoryChoice(c),
                          if (typeCategories.length > shown.length)
                            AppChoice<String>(
                              label: l10n.isPersian ? 'بیشتر' : 'More',
                              icon: Icons.more_horiz_rounded,
                              color: colors.textSecondary,
                              onTap: () => _showAllCategories(typeCategories),
                            ),
                        ],
                        selected: _selectedCategoryId,
                        onSelected: (id) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategoryId = id);
                        },
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppListGroup(
                    children: [
                      AppListRow(
                        icon: _accountIcon(
                          selectedAccount?.type ?? AccountType.bankCard,
                        ),
                        title: _type == TransactionType.transfer
                            ? 'از حساب'
                            : (_type == TransactionType.income
                                  ? 'واریز به'
                                  : 'پرداخت از'),
                        subtitle: selectedAccount == null
                            ? null
                            : '${selectedAccount.name} · ${selectedAccount.currentBalance.format(usePersianDigits: true)}',
                        enabled: !_moneyLocked,
                        onTap: () => _pickAccount(destination: false),
                      ),
                      if (_type == TransactionType.transfer)
                        AppListRow(
                          icon: Icons.south_rounded,
                          iconColor: colors.transfer,
                          title: 'به حساب',
                          subtitle: destAccount?.name ?? 'یک حساب دیگر بسازید',
                          enabled: !_moneyLocked && _accounts.length > 1,
                          onTap: () => _pickAccount(destination: true),
                        ),
                      AppListRow(
                        icon: Icons.event_outlined,
                        iconColor: colors.textSecondary,
                        title: 'تاریخ',
                        value: _dateLabel(context),
                        onTap: () async {
                          final picked = await showAppDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _noteController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: l10n.isPersian
                          ? 'توضیح (اختیاری) — مثلاً خرید هفتگی'
                          : l10n.notePlaceholder,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Three colour-coded tabs for expense / income / transfer.
class _TypeTabs extends StatelessWidget {
  final int selected;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  final List<Color> colors;

  const _TypeTabs({
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.labels,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.customColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusPill,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: GestureDetector(
                  onTap: enabled ? () => onChanged(i) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? Theme.of(context).colorScheme.surface
                          : Colors.transparent,
                      borderRadius: AppSpacing.borderRadiusPill,
                      border: i == selected
                          ? Border.all(color: colors[i].withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      style: AppTypography.labelLarge.copyWith(
                        color: i == selected ? colors[i] : c.textSecondary,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
