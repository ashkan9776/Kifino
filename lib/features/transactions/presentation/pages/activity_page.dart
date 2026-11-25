import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_kit.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_responsive_container.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_transaction_tile.dart';
import '../../domain/entities/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';

enum _Filter { all, expense, income, transfer }

/// «تراکنش‌ها»: search, type filter, a totals strip for what is shown, and
/// the list grouped by day with each day's net.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(TransactionEntity tx) {
    final typeOk = switch (_filter) {
      _Filter.all => true,
      _Filter.expense => tx.type == TransactionType.expense,
      _Filter.income => tx.type == TransactionType.income,
      _Filter.transfer => tx.type == TransactionType.transfer,
    };
    if (!typeOk) return false;
    if (_query.isEmpty) return true;
    final q = TextNormalizer.normalizeForSearch(_query);
    return [
      tx.description,
      tx.categoryName ?? '',
      tx.accountName ?? '',
      tx.notes ?? '',
    ].any((f) => TextNormalizer.normalizeForSearch(f).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navActivity)),
      body: AppResponsiveContainer.feed(
        child: BlocConsumer<TransactionBloc, TransactionState>(
          listener: _listen,
          builder: (context, state) {
            if (state is TransactionLoading || state is TransactionInitial) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    AppSkeleton(height: 48),
                    SizedBox(height: AppSpacing.md),
                    AppSkeleton(height: 80),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(height: 220),
                  ],
                ),
              );
            }
            if (state is! TransactionLoaded) return const SizedBox.shrink();

            if (state.transactions.isEmpty) {
              return AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: l10n.noTransactionsYet,
                description: l10n.noTransactionsDesc,
                actionLabel: l10n.addTransaction,
                onAction: () => context.push('/transaction/new'),
              );
            }

            final visible = state.transactions.where(_matches).toList();
            final groups = _groupByDay(visible);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.isPersian
                            ? 'جستجو در شرح، دسته، حساب…'
                            : l10n.search,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.isPersian ? 'پاک کردن' : 'Clear',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _searchController.clear,
                              ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AppFilterBar<_Filter>(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    options: [
                      (_Filter.all, l10n.isPersian ? 'همه' : 'All'),
                      (_Filter.expense, l10n.expense),
                      (_Filter.income, l10n.income),
                      (_Filter.transfer, l10n.transfer),
                    ],
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: _TotalsStrip(transactions: visible),
                  ),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: l10n.isPersian ? 'موردی پیدا نشد' : 'No results',
                      description: l10n.isPersian
                          ? 'عبارت یا فیلتر دیگری را امتحان کنید.'
                          : 'Try another search or filter.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    sliver: SliverList.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, i) => _DayGroup(group: groups[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _listen(BuildContext context, TransactionState state) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (state is TransactionFailure) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.message)));
      return;
    }
    if (state is TransactionOperationSuccess &&
        state.deletedTransactionId != null) {
      final id = state.deletedTransactionId!;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.isPersian ? 'تراکنش حذف شد' : 'Transaction deleted',
            ),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => context.read<TransactionBloc>().add(
                TransactionRestoreSubmitted(id),
              ),
            ),
          ),
        );
    }
  }

  static List<_Day> _groupByDay(List<TransactionEntity> txs) {
    final groups = <_Day>[];
    for (final tx in txs) {
      final day = DateUtils.dateOnly(tx.date);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(_Day(day, []));
      }
      groups.last.items.add(tx);
    }
    return groups;
  }
}

class _Day {
  final DateTime day;
  final List<TransactionEntity> items;
  _Day(this.day, this.items);
}

/// Income / expense of everything currently listed, in the base currency.
class _TotalsStrip extends StatelessWidget {
  final List<TransactionEntity> transactions;

  const _TotalsStrip({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final base = AppCurrency.base;
    var income = 0;
    var expense = 0;
    for (final tx in transactions) {
      if (!tx.amount.isCompatibleWith(base)) continue;
      final minor = tx.amount.normalizeTo(base).minorUnits;
      if (tx.type == TransactionType.income) income += minor;
      if (tx.type == TransactionType.expense) expense += minor;
    }
    final count = TextNormalizer.auto('${transactions.length} تراکنش');

    Widget cell(String label, int minor, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          AppMoneyText(
            money: Money.fromMinor(minor, base),
            style: AppTypography.moneySub.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
            usePersianDigits: true,
          ),
        ],
      ),
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          cell('درآمد', income, colors.income),
          Container(width: 1, height: 32, color: colors.surfaceBorder),
          const SizedBox(width: 12),
          cell('هزینه', expense, colors.expense),
          Text(
            count,
            style: AppTypography.labelMedium.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final _Day group;

  const _DayGroup({required this.group});

  static const _weekdays = {
    DateTime.saturday: 'شنبه',
    DateTime.sunday: 'یکشنبه',
    DateTime.monday: 'دوشنبه',
    DateTime.tuesday: 'سه‌شنبه',
    DateTime.wednesday: 'چهارشنبه',
    DateTime.thursday: 'پنجشنبه',
    DateTime.friday: 'جمعه',
  };

  String _title() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (group.day == today) return 'امروز';
    if (group.day == today.subtract(const Duration(days: 1))) return 'دیروز';
    final j = JalaliDate.fromDateTime(group.day);
    final sameYear = j.year == JalaliDate.fromDateTime(today).year;
    return TextNormalizer.auto(
      '${_weekdays[group.day.weekday]} ${j.day} ${j.monthName}${sameYear ? '' : ' ${j.year}'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final base = AppCurrency.base;
    var net = 0;
    for (final tx in group.items) {
      if (!tx.amount.isCompatibleWith(base)) continue;
      final minor = tx.amount.normalizeTo(base).minorUnits;
      if (tx.type == TransactionType.income) net += minor;
      if (tx.type == TransactionType.expense) net -= minor;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title(),
                    style: AppTypography.labelLarge.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (net != 0)
                  AppMoneyText(
                    money: Money.fromMinor(net, base),
                    sign: MoneyDisplaySign.positiveNegative,
                    style: AppTypography.labelLarge.copyWith(
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                    usePersianDigits: true,
                  ),
              ],
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, tx) in group.items.indexed) ...[
                  if (i > 0) const Divider(indent: 70),
                  AppTransactionTile(
                    transaction: tx,
                    showTimeOnly: true,
                    onTap: () => context.push('/transaction/new', extra: tx),
                    onDelete: tx.isOwnedByModule
                        ? null
                        : () => context.read<TransactionBloc>().add(
                            TransactionDeleteSubmitted(tx.id),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
