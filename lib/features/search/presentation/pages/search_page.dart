import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_transaction_tile.dart';
import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../../business/presentation/bloc/business_bloc.dart';
import '../../../business/presentation/bloc/business_state.dart';
import '../../../checks/presentation/bloc/check_bloc.dart';
import '../../../debts/presentation/bloc/debt_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';

/// Global search across transactions, accounts, contacts, products, debts and
/// checks — all read from app-level bloc states (no extra data plumbing).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPersian = l10n.isPersian;
    final needle = TextNormalizer.normalizeForSearch(_query);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm, left: AppSpacing.sm),
          child: TextField(
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: isPersian
                  ? 'جستجو در تراکنش‌ها، حساب‌ها، مشتریان…'
                  : 'Search transactions, accounts, customers…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => setState(() => _query = ''),
                    ),
              filled: true,
              isDense: true,
            ),
          ),
        ),
      ),
      body: _query.trim().isEmpty
          ? _RecentTransactionsSection(isPersian: isPersian)
          : _SearchResults(query: _query, needle: needle, isPersian: isPersian),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final String needle;
  final bool isPersian;

  const _SearchResults({
    required this.query,
    required this.needle,
    required this.isPersian,
  });

  @override
  Widget build(BuildContext context) {
    final transactionState = context.watch<TransactionBloc>().state;
    final accountState = context.watch<AccountsBloc>().state;
    final businessState = context.watch<BusinessBloc>().state;
    final debtState = context.watch<DebtBloc>().state;
    final checkState = context.watch<CheckBloc>().state;

    final transactions = transactionState is TransactionLoaded
        ? transactionState.transactions
            .where((tx) => _matchAll(
                  needle,
                  [tx.description, tx.categoryName, tx.accountName],
                ))
            .toList()
        : const [];

    final accounts = accountState is AccountsLoaded
        ? accountState.accounts
            .where((a) => _matchAll(needle, [a.name, a.bankName]))
            .toList()
        : const [];

    final contacts = businessState is BusinessLoaded
        ? businessState.contacts
            .where((c) => _matchAll(needle, [c.name, c.companyName, c.phone]))
            .toList()
        : const [];

    final products = businessState is BusinessLoaded
        ? businessState.products
            .where((p) => _matchAll(needle, [p.name, p.sku, p.barcode]))
            .toList()
        : const [];

    final debts = debtState is DebtLoaded
        ? debtState.debts
            .where((d) => _matchAll(needle, [d.contactName, d.notes]))
            .toList()
        : const [];

    final checks = checkState is CheckLoaded
        ? checkState.checks
            .where((c) => _matchAll(needle, [c.checkNumber, c.partyName, c.bankName, c.sayadiId]))
            .toList()
        : const [];

    final isEmpty = transactions.isEmpty &&
        accounts.isEmpty &&
        contacts.isEmpty &&
        products.isEmpty &&
        debts.isEmpty &&
        checks.isEmpty;

    if (isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: isPersian ? 'نتیجه‌ای یافت نشد' : 'No results',
          description: isPersian
              ? 'برای «$query» چیزی پیدا نشد. عبارت دیگری را امتحان کن.'
              : 'Nothing found for "$query". Try another term.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (transactions.isNotEmpty)
          _Section(
            title: isPersian ? 'تراکنش‌ها' : 'Transactions',
            count: transactions.length,
            children: [
              for (final tx in transactions.take(10))
                AppTransactionTile(transaction: tx),
            ],
          ),
        if (accounts.isNotEmpty)
          _Section(
            title: isPersian ? 'حساب‌ها' : 'Accounts',
            count: accounts.length,
            children: [
              for (final account in accounts)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: Text(account.name),
                  subtitle: account.bankName != null ? Text(account.bankName!) : null,
                  trailing: AppMoneyText(money: account.currentBalance, usePersianDigits: true),
                ),
            ],
          ),
        if (contacts.isNotEmpty)
          _Section(
            title: isPersian ? 'مشتریان و تأمین‌کنندگان' : 'Customers & suppliers',
            count: contacts.length,
            children: [
              for (final contact in contacts)
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(contact.name),
                  subtitle: contact.companyName != null ? Text(contact.companyName!) : null,
                ),
            ],
          ),
        if (products.isNotEmpty)
          _Section(
            title: isPersian ? 'محصولات' : 'Products',
            count: products.length,
            children: [
              for (final product in products)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product.name),
                  subtitle: product.sku != null ? Text(product.sku!) : null,
                  trailing: AppMoneyText(money: product.sellingPrice, usePersianDigits: true),
                ),
            ],
          ),
        if (debts.isNotEmpty)
          _Section(
            title: isPersian ? 'بدهی‌ها و طلب‌ها' : 'Debts & receivables',
            count: debts.length,
            children: [
              for (final debt in debts)
                ListTile(
                  leading: const Icon(Icons.handshake_outlined),
                  title: Text(debt.contactName),
                  trailing: AppMoneyText(money: debt.remainingAmount, usePersianDigits: true),
                ),
            ],
          ),
        if (checks.isNotEmpty)
          _Section(
            title: isPersian ? 'چک‌ها' : 'Checks',
            count: checks.length,
            children: [
              for (final check in checks)
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text('${check.partyName} • ${check.checkNumber}'),
                  subtitle: Text(check.bankName),
                  trailing: AppMoneyText(money: check.amount, usePersianDigits: true),
                ),
            ],
          ),
      ],
    );
  }

  static bool _matchAll(String needle, List<String?> fields) {
    if (needle.isEmpty) return true;
    return fields
        .whereType<String>()
        .any((field) => TextNormalizer.normalizeForSearch(field).contains(needle));
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  final bool isPersian;

  const _RecentTransactionsSection({required this.isPersian});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionBloc>().state;

    if (state is! TransactionLoaded || state.transactions.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.search_rounded,
          title: isPersian ? 'جستجوی سراسری' : 'Global search',
          description: isPersian
              ? 'تراکنش‌ها، حساب‌ها، مشتریان، محصولات، بدهی‌ها و چک‌ها را از همین‌جا پیدا کن.'
              : 'Find transactions, accounts, customers, products, debts and checks in one place.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _Section(
          title: isPersian ? 'تراکنش‌های اخیر' : 'Recent transactions',
          count: 5,
          children: [
            for (final tx in state.transactions.take(5))
              AppTransactionTile(transaction: tx),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TextNormalizer.auto('$title ($count)'),
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
