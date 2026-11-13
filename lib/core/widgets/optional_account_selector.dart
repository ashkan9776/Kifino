import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../features/accounts/domain/entities/account_entity.dart';
import '../errors/result.dart';
import '../utils/money.dart';

/// Shared optional account dropdown used in payment / contribution sheets to
/// optionally update a compatible bank account balance.
class OptionalAccountSelector extends StatelessWidget {
  final Future<Result<List<AccountEntity>>> accountsFuture;
  final Currency compatibleCurrency;
  final String? selectedAccountId;
  final ValueChanged<String?> onChanged;
  final String label;

  const OptionalAccountSelector({
    super.key,
    required this.accountsFuture,
    required this.compatibleCurrency,
    required this.selectedAccountId,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<Result<List<AccountEntity>>>(
      future: accountsFuture,
      builder: (context, snapshot) {
        final rawAccounts =
            snapshot.data?.dataOrNull ?? const <AccountEntity>[];
        final compatible = rawAccounts
            .where(
              (a) =>
                  !a.isDeleted &&
                  !a.isArchived &&
                  a.currency.isCompatibleWith(compatibleCurrency),
            )
            .toList();

        if (compatible.isEmpty) {
          return const SizedBox.shrink();
        }

        final safeValue =
            selectedAccountId != null &&
                compatible.any((a) => a.id == selectedAccountId)
            ? selectedAccountId
            : null;

        return DropdownButtonFormField<String?>(
          initialValue: safeValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                l10n.isPersian
                    ? 'بدون تغییر موجودی حساب'
                    : 'No account balance change',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...compatible.map(
              (acc) => DropdownMenuItem<String?>(
                value: acc.id,
                child: Text(
                  '${acc.name} (${acc.currentBalance.format(usePersianDigits: l10n.isPersian)})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
