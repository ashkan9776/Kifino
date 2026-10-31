import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_transaction_tile.dart';
import '../bloc/transaction_bloc.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.navActivity),
      ),
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionOperationSuccess && state.deletedTransactionId != null) {
            final deletedId = state.deletedTransactionId!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.isPersian ? 'تراکنش حذف شد' : 'Transaction deleted'),
                action: SnackBarAction(
                  label: l10n.undo,
                  onPressed: () {
                    context.read<TransactionBloc>().add(TransactionRestoreSubmitted(deletedId));
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TransactionLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppSkeleton(height: 50),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 80),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeleton(height: 80),
                ],
              ),
            );
          }

          if (state is TransactionLoaded) {
            final allTransactions = state.transactions;

            final filtered = _searchQuery.isEmpty
                ? allTransactions
                : allTransactions.where((tx) {
                    final normalizedQuery = TextNormalizer.normalizeForSearch(_searchQuery);
                    final desc = TextNormalizer.normalizeForSearch(tx.description);
                    final cat = TextNormalizer.normalizeForSearch(tx.categoryName ?? '');
                    final acc = TextNormalizer.normalizeForSearch(tx.accountName ?? '');
                    return desc.contains(normalizedQuery) ||
                        cat.contains(normalizedQuery) ||
                        acc.contains(normalizedQuery);
                  }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Expanded(
                  child: filtered.isEmpty
                      ? AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _searchQuery.isEmpty ? l10n.noTransactionsYet : 'موردی یافت نشد',
                          description: _searchQuery.isEmpty
                              ? l10n.noTransactionsDesc
                              : 'هیچ تراکنشی مطابق با عبارت جستجو پیدا نشد.',
                          actionLabel: _searchQuery.isEmpty ? l10n.addTransaction : null,
                          onAction: _searchQuery.isEmpty ? () => context.push('/transaction/new') : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final tx = filtered[index];
                            return AppCard(
                              padding: EdgeInsets.zero,
                              child: AppTransactionTile(
                                transaction: tx,
                                onTap: () => context.push('/transaction/new', extra: tx),
                                onDelete: () {
                                  context.read<TransactionBloc>().add(TransactionDeleteSubmitted(tx.id));
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
        ),
      ),
    );
  }
}
