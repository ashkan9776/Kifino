import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../../domain/repositories/recurring_repository.dart';
import '../../domain/services/recurrence.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  RecurringRepositoryImpl(this._db);

  RecurringRuleEntity _toEntity(RecurringRuleData r) => RecurringRuleEntity(
    id: r.id,
    title: r.title,
    type: TransactionType.fromCode(r.type),
    accountId: r.accountId,
    destinationAccountId: r.destinationAccountId,
    categoryId: r.categoryId,
    amount: Money.fromMinor(r.amountMinor, Currency.fromCode(r.currency)),
    frequency: RecurrenceFrequency.fromCode(r.frequency),
    interval: r.intervalCount,
    startDate: DateTime.fromMillisecondsSinceEpoch(r.startDate),
    nextIndex: r.nextIndex,
    nextRunDate: DateTime.fromMillisecondsSinceEpoch(r.nextRunDate),
    endDate: r.endDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.endDate!),
    maxOccurrences: r.maxOccurrences,
    postedCount: r.postedCount,
    autoPost: r.autoPost,
    remindDaysBefore: r.remindDaysBefore,
    isActive: r.isActive,
    notes: r.notes,
    lastError: r.lastError,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );

  DateTime _dateOf(RecurringRuleData r, int index) => Recurrence.occurrence(
    start: DateTime.fromMillisecondsSinceEpoch(r.startDate),
    frequency: RecurrenceFrequency.fromCode(r.frequency),
    interval: r.intervalCount,
    index: index,
  );

  /// First occurrence index on or after the start of [now]'s day.
  int _firstIndexFrom(
    DateTime start,
    RecurrenceFrequency frequency,
    int interval,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    var index = 0;
    // Bounded walk: even a daily rule from 20 years ago is ~7k steps.
    while (index < 20000 &&
        Recurrence.occurrence(
          start: start,
          frequency: frequency,
          interval: interval,
          index: index,
        ).isBefore(today)) {
      index++;
    }
    return index;
  }

  SimpleSelectStatement<$RecurringRulesTableTable, RecurringRuleData>
  _active() =>
      _db.select(_db.recurringRulesTable)..where((t) => t.deletedAt.isNull());

  @override
  Stream<List<RecurringRuleEntity>> watchRules() {
    final q = _active()..orderBy([(t) => OrderingTerm.asc(t.nextRunDate)]);
    return q.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<List<RecurringRuleEntity>> getRules() async {
    final q = _active()..orderBy([(t) => OrderingTerm.asc(t.nextRunDate)]);
    return (await q.get()).map(_toEntity).toList();
  }

  @override
  Future<RecurringRuleEntity?> getRule(String id) async {
    final row = await (_db.select(
      _db.recurringRulesTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  String? _validate(RecurringRuleEntity rule) {
    if (rule.title.trim().isEmpty) return 'عنوان را وارد کنید.';
    if (rule.amount.minorUnits <= 0) return 'مبلغ باید بیشتر از صفر باشد.';
    if (rule.type == TransactionType.transfer &&
        (rule.destinationAccountId == null ||
            rule.destinationAccountId == rule.accountId)) {
      return 'برای انتقال، حساب مقصد متفاوتی انتخاب کنید.';
    }
    if (rule.type != TransactionType.income &&
        rule.type != TransactionType.expense &&
        rule.type != TransactionType.transfer) {
      return 'نوع تراکنش تکراری پشتیبانی نمی‌شود.';
    }
    return null;
  }

  @override
  Future<Result<RecurringRuleEntity>> createRule(
    RecurringRuleEntity rule,
  ) async {
    final error = _validate(rule);
    if (error != null) return DatabaseFailure(error).asFailure();
    try {
      final id = rule.id.isEmpty ? _uuid.v4() : rule.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.recurringRulesTable)
          .insert(
            RecurringRulesTableCompanion.insert(
              id: id,
              title: rule.title.trim(),
              type: rule.type.code,
              accountId: rule.accountId,
              destinationAccountId: Value(rule.destinationAccountId),
              categoryId: Value(rule.categoryId),
              amountMinor: rule.amount.minorUnits,
              currency: rule.amount.currency.code,
              frequency: rule.frequency.code,
              intervalCount: Value(rule.interval < 1 ? 1 : rule.interval),
              startDate: rule.startDate.millisecondsSinceEpoch,
              nextIndex: const Value(0),
              nextRunDate: rule.startDate.millisecondsSinceEpoch,
              endDate: Value(rule.endDate?.millisecondsSinceEpoch),
              maxOccurrences: Value(rule.maxOccurrences),
              autoPost: Value(rule.autoPost),
              remindDaysBefore: Value(rule.remindDaysBefore),
              isActive: Value(rule.isActive),
              notes: Value(rule.notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Success((await getRule(id))!);
    } catch (e) {
      return DatabaseFailure('ذخیره تراکنش تکراری انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateRule(
    RecurringRuleEntity rule, {
    DateTime? now,
  }) async {
    final error = _validate(rule);
    if (error != null) return DatabaseFailure(error).asFailure();
    try {
      final existing = await (_db.select(
        _db.recurringRulesTable,
      )..where((t) => t.id.equals(rule.id))).getSingleOrNull();
      if (existing == null) {
        return DatabaseFailure('تراکنش تکراری پیدا نشد.').asFailure();
      }
      final scheduleChanged =
          existing.startDate != rule.startDate.millisecondsSinceEpoch ||
          existing.frequency != rule.frequency.code ||
          existing.intervalCount != rule.interval;

      var nextIndex = existing.nextIndex;
      if (scheduleChanged) {
        nextIndex = _firstIndexFrom(
          rule.startDate,
          rule.frequency,
          rule.interval,
          now ?? DateTime.now(),
        );
      }
      final nextRun = Recurrence.occurrence(
        start: rule.startDate,
        frequency: rule.frequency,
        interval: rule.interval,
        index: nextIndex,
      );

      await (_db.update(
        _db.recurringRulesTable,
      )..where((t) => t.id.equals(rule.id))).write(
        RecurringRulesTableCompanion(
          title: Value(rule.title.trim()),
          type: Value(rule.type.code),
          accountId: Value(rule.accountId),
          destinationAccountId: Value(rule.destinationAccountId),
          categoryId: Value(rule.categoryId),
          amountMinor: Value(rule.amount.minorUnits),
          currency: Value(rule.amount.currency.code),
          frequency: Value(rule.frequency.code),
          intervalCount: Value(rule.interval < 1 ? 1 : rule.interval),
          startDate: Value(rule.startDate.millisecondsSinceEpoch),
          nextIndex: Value(nextIndex),
          nextRunDate: Value(nextRun.millisecondsSinceEpoch),
          endDate: Value(rule.endDate?.millisecondsSinceEpoch),
          maxOccurrences: Value(rule.maxOccurrences),
          autoPost: Value(rule.autoPost),
          remindDaysBefore: Value(rule.remindDaysBefore),
          notes: Value(rule.notes),
          lastError: const Value(null),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          version: Value(existing.version + 1),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش تراکنش تکراری انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteRule(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.recurringRulesTable,
      )..where((t) => t.id.equals(id))).write(
        RecurringRulesTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف تراکنش تکراری انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> setActive(
    String id,
    bool active, {
    DateTime? now,
  }) async {
    try {
      final row = await (_db.select(
        _db.recurringRulesTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return DatabaseFailure('تراکنش تکراری پیدا نشد.').asFailure();
      }
      var nextIndex = row.nextIndex;
      if (active && !row.isActive) {
        // Resuming must not back-post everything missed while paused.
        final fromToday = _firstIndexFrom(
          DateTime.fromMillisecondsSinceEpoch(row.startDate),
          RecurrenceFrequency.fromCode(row.frequency),
          row.intervalCount,
          now ?? DateTime.now(),
        );
        if (fromToday > nextIndex) nextIndex = fromToday;
      }
      await (_db.update(
        _db.recurringRulesTable,
      )..where((t) => t.id.equals(id))).write(
        RecurringRulesTableCompanion(
          isActive: Value(active),
          nextIndex: Value(nextIndex),
          nextRunDate: Value(_dateOf(row, nextIndex).millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('تغییر وضعیت انجام نشد.').asFailure();
    }
  }

  @override
  Future<void> advance(String id, {required bool posted}) async {
    final row = await (_db.select(
      _db.recurringRulesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final next = row.nextIndex + 1;
    await (_db.update(
      _db.recurringRulesTable,
    )..where((t) => t.id.equals(id))).write(
      RecurringRulesTableCompanion(
        nextIndex: Value(next),
        nextRunDate: Value(_dateOf(row, next).millisecondsSinceEpoch),
        postedCount: Value(row.postedCount + (posted ? 1 : 0)),
        lastError: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> recordError(String id, String? message) async {
    await (_db.update(_db.recurringRulesTable)..where((t) => t.id.equals(id)))
        .write(RecurringRulesTableCompanion(lastError: Value(message)));
  }
}
