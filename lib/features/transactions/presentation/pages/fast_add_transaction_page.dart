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
import '../../../../core/utils/icon_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../bloc/transaction_bloc.dart';

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
  late final ValueNotifier<int> _amountNotifier = ValueNotifier<int>(_amountMinor);
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
        date: editTx.date,
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
      date: DateTime.now(),
      description: noteText.isNotEmpty
          ? noteText
          : (txType == TransactionType.expense
                ? 'هزینه'
                : (txType == TransactionType.income ? 'درآمد' : 'انتقال')),
      notes: noteText.isNotEmpty ? noteText : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.read<TransactionBloc>().add(TransactionCreateSubmitted(tx));
    HapticFeedback.mediumImpact();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.customColors;
    final isEditing = widget.editTransaction != null;

    final typeColor = switch (_selectedTypeIndex) {
      0 => colors.expense,
      1 => colors.income,
      _ => colors.transfer,
    };

    final currentCurrency = _accounts.isNotEmpty && _selectedAccountId != null
        ? _accounts.firstWhere((a) => a.id == _selectedAccountId).currency
        : Currency.toman;

    final filteredCategories = _categories.where((cat) {
      if (_selectedTypeIndex == 0) return cat.type == CategoryType.expense;
      if (_selectedTypeIndex == 1) return cat.type == CategoryType.income;
      return false;
    }).toList();

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? (l10n.isPersian ? 'ویرایش تراکنش' : 'Edit transaction')
              : l10n.addTransaction,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
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
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        // Segmented Control
                        SegmentedButton<int>(
                          segments: [
                            ButtonSegment(
                              value: 0,
                              label: Text(l10n.expense),
                              icon: const Icon(Icons.arrow_upward_rounded),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text(l10n.income),
                              icon: const Icon(Icons.arrow_downward_rounded),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text(l10n.transfer),
                              icon: const Icon(Icons.swap_horiz_rounded),
                            ),
                          ],
                          selected: {_selectedTypeIndex},
                          onSelectionChanged: (set) {
                            setState(() {
                              _selectedTypeIndex = set.first;
                              final newFiltered = _categories.where((cat) {
                                if (_selectedTypeIndex == 0) {
                                  return cat.type == CategoryType.expense;
                                }
                                if (_selectedTypeIndex == 1) {
                                  return cat.type == CategoryType.income;
                                }
                                return false;
                              }).toList();
                              if (newFiltered.isNotEmpty) {
                                _selectedCategoryId = newFiltered.first.id;
                              }
                            });
                            HapticFeedback.selectionClick();
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Amount Field
                        AppAmountField(
                          currency: currentCurrency,
                          amountNotifier: _amountNotifier,
                          signColor: typeColor,
                          prefixSign: _selectedTypeIndex == 0
                              ? '-'
                              : (_selectedTypeIndex == 1 ? '+' : ''),
                          onAmountMinorChanged: (value) {
                            setState(() => _amountMinor = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Quick Chips
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: _quickChipsToman.map((chipAmount) {
                            final money = Money.fromMinor(
                              chipAmount,
                              currentCurrency,
                            );
                            return ActionChip(
                              label: Text(
                                money.format(
                                  includeSymbol: false,
                                  usePersianDigits: l10n.isPersian,
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _amountMinor += chipAmount;
                                  _amountNotifier.value = _amountMinor;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Category Selector (if not transfer)
                        if (_selectedTypeIndex != 2 &&
                            filteredCategories.isNotEmpty) ...[
                          Text(
                            l10n.selectCategory,
                            style: AppTypography.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: filteredCategories.map((cat) {
                              final isSelected = _selectedCategoryId == cat.id;
                              return ChoiceChip(
                                avatar: Icon(
                                  IconUtils.getIconData(cat.iconCodePoint),
                                  size: 18,
                                ),
                                label: Text(cat.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(
                                      () => _selectedCategoryId = cat.id,
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Account Selector
                        Text(
                          _selectedTypeIndex == 2
                              ? 'از حساب مبدأ'
                              : l10n.selectAccount,
                          style: AppTypography.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: _accounts.map((acc) {
                            final isSelected = _selectedAccountId == acc.id;
                            return ChoiceChip(
                              label: Text(
                                '${acc.name} (${acc.currentBalance.format()})',
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedAccountId = acc.id);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Destination Account Selector (Transfer only)
                        if (_selectedTypeIndex == 2) ...[
                          Text(
                            l10n.destinationAccount,
                            style: AppTypography.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: _accounts
                                .where((a) => a.id != _selectedAccountId)
                                .map((acc) {
                                  final isSelected =
                                      _selectedDestAccountId == acc.id;
                                  return ChoiceChip(
                                    label: Text(acc.name),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(
                                          () => _selectedDestAccountId = acc.id,
                                        );
                                      }
                                    },
                                  );
                                })
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Note Field
                        TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: l10n.note,
                            hintText: l10n.notePlaceholder,
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppButton(
                      label: isEditing
                          ? (l10n.isPersian ? 'ذخیره تغییرات' : 'Save changes')
                          : l10n.save,
                      onPressed: _onSave,
                      width: double.infinity,
                      variant: AppButtonVariant.primary,
                    ),
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }
}
