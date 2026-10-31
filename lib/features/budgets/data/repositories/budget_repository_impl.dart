import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  BudgetRepositoryImpl(this._db);

  Future<int> _calculateSpentMinor(
    String budgetId,
    int startEpoch,
    int endEpoch,
    List<String> catIds,
    Currency budgetCurrency,
  ) async {
    if (catIds.isEmpty) return 0;

    final query = _db.select(_db.transactionsTable)
      ..where((tbl) =>
          tbl.deletedAt.isNull() &
          tbl.type.equals('expense') &
          tbl.transactionDate.isBiggerOrEqualValue(startEpoch) &
          tbl.transactionDate.isSmallerOrEqualValue(endEpoch) &
          tbl.categoryId.isIn(catIds));

    final rows = await query.get();
    int spent = 0;
    for (final r in rows) {
      // Normalize Iranian pairs into the budget's currency so mixed rows
      // never corrupt the spent total; foreign rows are excluded.
      final rowCurrency = Currency.fromCode(r.currency);
      if (!rowCurrency.isCompatibleWith(budgetCurrency)) continue;
      spent += rowCurrency == budgetCurrency
          ? r.amountMinor
          : Money.fromMinor(r.amountMinor, rowCurrency).normalizeTo(budgetCurrency).minorUnits;
    }
    return spent;
  }

  @override
  Stream<List<BudgetEntity>> watchActiveBudgets({DateTime? forDate}) {
    final targetDate = forDate ?? DateTime.now();
    final epoch = targetDate.millisecondsSinceEpoch;

    // Join with categories junction table
    final budgetQuery = _db.select(_db.budgetsTable)
      ..where((tbl) =>
          tbl.deletedAt.isNull() &
          tbl.startDate.isSmallerOrEqualValue(epoch) &
          tbl.endDate.isBiggerOrEqualValue(epoch));

    return budgetQuery.watch().asyncMap((budgets) async {
      final List<BudgetEntity> list = [];

      for (final b in budgets) {
        final catQuery = _db.select(_db.budgetCategoriesTable)
          ..where((t) => t.budgetId.equals(b.id));
        final catRows = await catQuery.get();
        final catIds = catRows.map((r) => r.categoryId).toList();

        final spentMinor = await _calculateSpentMinor(b.id, b.startDate, b.endDate, catIds, Currency.fromCode(b.currency));
        final currency = Currency.fromCode(b.currency);

        list.add(BudgetEntity(
          id: b.id,
          name: b.name,
          amountLimit: Money.fromMinor(b.amountLimitMinor, currency),
          amountSpent: Money.fromMinor(spentMinor, currency),
          periodType: BudgetPeriodType.fromCode(b.periodType),
          startDate: DateTime.fromMillisecondsSinceEpoch(b.startDate),
          endDate: DateTime.fromMillisecondsSinceEpoch(b.endDate),
          alertThresholdPercent: b.alertThresholdPercent,
          categoryIds: catIds,
          createdAt: DateTime.fromMillisecondsSinceEpoch(b.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(b.updatedAt),
          deletedAt: b.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(b.deletedAt!) : null,
        ));
      }

      return list;
    });
  }

  @override
  Future<Result<List<BudgetEntity>>> getActiveBudgets({DateTime? forDate}) async {
    try {
      final targetDate = forDate ?? DateTime.now();
      final epoch = targetDate.millisecondsSinceEpoch;

      final budgetQuery = _db.select(_db.budgetsTable)
        ..where((tbl) =>
            tbl.deletedAt.isNull() &
            tbl.startDate.isSmallerOrEqualValue(epoch) &
            tbl.endDate.isBiggerOrEqualValue(epoch));

      final budgets = await budgetQuery.get();
      final List<BudgetEntity> list = [];

      for (final b in budgets) {
        final catQuery = _db.select(_db.budgetCategoriesTable)..where((t) => t.budgetId.equals(b.id));
        final catRows = await catQuery.get();
        final catIds = catRows.map((r) => r.categoryId).toList();

        final spentMinor = await _calculateSpentMinor(b.id, b.startDate, b.endDate, catIds, Currency.fromCode(b.currency));
        final currency = Currency.fromCode(b.currency);

        list.add(BudgetEntity(
          id: b.id,
          name: b.name,
          amountLimit: Money.fromMinor(b.amountLimitMinor, currency),
          amountSpent: Money.fromMinor(spentMinor, currency),
          periodType: BudgetPeriodType.fromCode(b.periodType),
          startDate: DateTime.fromMillisecondsSinceEpoch(b.startDate),
          endDate: DateTime.fromMillisecondsSinceEpoch(b.endDate),
          alertThresholdPercent: b.alertThresholdPercent,
          categoryIds: catIds,
          createdAt: DateTime.fromMillisecondsSinceEpoch(b.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(b.updatedAt),
          deletedAt: b.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(b.deletedAt!) : null,
        ));
      }

      return Success(list);
    } catch (e) {
      return DatabaseFailure('خواندن بودجه‌های فعال انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<BudgetEntity>> createBudget(BudgetEntity budget) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final bId = budget.id.isEmpty ? _uuid.v4() : budget.id;

      await _db.transaction(() async {
        final companion = BudgetsTableCompanion.insert(
          id: bId,
          name: budget.name,
          amountLimitMinor: budget.amountLimit.minorUnits,
          currency: budget.amountLimit.currency.code,
          periodType: budget.periodType.code,
          startDate: budget.startDate.millisecondsSinceEpoch,
          endDate: budget.endDate.millisecondsSinceEpoch,
          alertThresholdPercent: Value(budget.alertThresholdPercent),
          createdAt: now,
          updatedAt: now,
        );

        await _db.into(_db.budgetsTable).insert(companion);

        for (final catId in budget.categoryIds) {
          await _db.into(_db.budgetCategoriesTable).insert(
                BudgetCategoriesTableCompanion.insert(
                  budgetId: bId,
                  categoryId: catId,
                ),
              );
        }
      });

      return Success(budget.copyWith(id: bId));
    } catch (e) {
      return DatabaseFailure('ساخت بودجه انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<BudgetEntity>> updateBudget(BudgetEntity budget) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.budgetsTable)..where((t) => t.id.equals(budget.id))).write(
        BudgetsTableCompanion(
          name: Value(budget.name),
          amountLimitMinor: Value(budget.amountLimit.minorUnits),
          alertThresholdPercent: Value(budget.alertThresholdPercent),
          updatedAt: Value(now),
        ),
      );
      return Success(budget);
    } catch (e) {
      return DatabaseFailure('ویرایش بودجه انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteBudget(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.budgetsTable)..where((t) => t.id.equals(id))).write(
        BudgetsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف بودجه انجام نشد.').asFailure();
    }
  }

}
