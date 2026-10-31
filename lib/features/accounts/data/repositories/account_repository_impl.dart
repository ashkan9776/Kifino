import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  AccountRepositoryImpl(this._db);

  AccountEntity _toEntity(AccountData data) {
    final currency = Currency.fromCode(data.currency);
    return AccountEntity(
      id: data.id,
      name: data.name,
      type: AccountType.fromCode(data.type),
      currency: currency,
      initialBalance: Money.fromMinor(data.initialBalanceMinor, currency),
      currentBalance: Money.fromMinor(data.currentBalanceMinor, currency),
      cardNumberLastFour: data.cardNumberLastFour,
      bankName: data.bankName,
      colorHex: data.colorHex,
      iconName: data.iconName,
      isArchived: data.isArchived,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!) : null,
      syncStatus: data.syncStatus,
      version: data.version,
    );
  }

  @override
  Stream<List<AccountEntity>> watchAccounts({bool includeArchived = false}) {
    final query = _db.select(_db.accountsTable)
      ..where((tbl) {
        final notDeleted = tbl.deletedAt.isNull();
        if (includeArchived) return notDeleted;
        return notDeleted & tbl.isArchived.equals(false);
      })
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc)]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Stream<AccountEntity?> watchAccountById(String id) {
    final query = _db.select(_db.accountsTable)..where((tbl) => tbl.id.equals(id));
    return query.watchSingleOrNull().map((row) => row != null ? _toEntity(row) : null);
  }

  @override
  Future<Result<List<AccountEntity>>> getAccounts({bool includeArchived = false}) async {
    try {
      final query = _db.select(_db.accountsTable)
        ..where((tbl) {
          final notDeleted = tbl.deletedAt.isNull();
          if (includeArchived) return notDeleted;
          return notDeleted & tbl.isArchived.equals(false);
        });
      final rows = await query.get();
      return Success(rows.map(_toEntity).toList());
    } catch (e) {
      return DatabaseFailure('خواندن حساب‌ها انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<AccountEntity>> createAccount(AccountEntity account) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final companion = AccountsTableCompanion.insert(
        id: account.id.isEmpty ? _uuid.v4() : account.id,
        name: account.name,
        type: account.type.code,
        currency: account.currency.code,
        initialBalanceMinor: Value(account.initialBalance.minorUnits),
        currentBalanceMinor: Value(account.currentBalance.minorUnits),
        cardNumberLastFour: Value(account.cardNumberLastFour),
        bankName: Value(account.bankName),
        colorHex: Value(account.colorHex),
        iconName: Value(account.iconName),
        isArchived: Value(account.isArchived),
        createdAt: now,
        updatedAt: now,
      );

      await _db.into(_db.accountsTable).insert(companion);
      final created = await (_db.select(_db.accountsTable)..where((t) => t.id.equals(companion.id.value))).getSingle();
      return Success(_toEntity(created));
    } catch (e) {
      return DatabaseFailure('ساخت حساب انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<AccountEntity>> updateAccount(AccountEntity account) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.accountsTable)..where((t) => t.id.equals(account.id))).write(
        AccountsTableCompanion(
          name: Value(account.name),
          type: Value(account.type.code),
          cardNumberLastFour: Value(account.cardNumberLastFour),
          bankName: Value(account.bankName),
          colorHex: Value(account.colorHex),
          iconName: Value(account.iconName),
          isArchived: Value(account.isArchived),
          updatedAt: Value(now),
          version: Value(account.version + 1),
        ),
      );

      final updated = await (_db.select(_db.accountsTable)..where((t) => t.id.equals(account.id))).getSingle();
      return Success(_toEntity(updated));
    } catch (e) {
      return DatabaseFailure('ویرایش حساب انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> archiveAccount(String id, bool archive) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.accountsTable)..where((t) => t.id.equals(id))).write(
        AccountsTableCompanion(
          isArchived: Value(archive),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('آرشیو حساب انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteAccount(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.accountsTable)..where((t) => t.id.equals(id))).write(
        AccountsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف حساب انجام نشد.').asFailure();
    }
  }

}
