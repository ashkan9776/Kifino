import 'package:drift/drift.dart';

import '../utils/money.dart';
import 'app_database.dart';

/// Adds [delta] to an account's current balance, converting Toman↔Rial when
/// the amount and the account use different Iranian units.
///
/// Every module that moves money without going through the transaction
/// repository (installments, checks) must use this, so balances never get a
/// raw amount in the wrong unit. Throws [StateError] for currencies that
/// cannot be converted without an exchange rate. Returns false when the
/// account does not exist.
Future<bool> applyAccountBalanceDelta(
  AppDatabase db, {
  required String accountId,
  required Money delta,
  required int now,
}) async {
  final account = await (db.select(
    db.accountsTable,
  )..where((t) => t.id.equals(accountId))).getSingleOrNull();
  if (account == null) return false;

  final accountCurrency = Currency.fromCode(account.currency);
  var effective = delta;
  if (effective.currency != accountCurrency) {
    if (!effective.isCompatibleWith(accountCurrency)) {
      throw StateError(
        'ارز مبلغ (${delta.currency.code}) با ارز حساب '
        '(${accountCurrency.code}) سازگار نیست.',
      );
    }
    effective = effective.normalizeTo(accountCurrency);
  }

  await (db.update(
    db.accountsTable,
  )..where((t) => t.id.equals(accountId))).write(
    AccountsTableCompanion(
      currentBalanceMinor: Value(
        account.currentBalanceMinor + effective.minorUnits,
      ),
      updatedAt: Value(now),
    ),
  );
  return true;
}
