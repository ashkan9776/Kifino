import '../../../../core/database/app_database.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/services/notification_service.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../entities/recurring_rule_entity.dart';
import '../repositories/recurring_repository.dart';

/// Result of one [RecurringService.postDue] pass.
class RecurringRunResult {
  final int posted;
  final int failed;
  const RecurringRunResult({required this.posted, required this.failed});
}

/// Posts due occurrences of recurring rules as real transactions.
///
/// Idempotency: occurrence `n` of rule `r` always becomes transaction
/// `rec_<r>_<n>`. If the app dies between posting and advancing the rule,
/// the next run finds the transaction already there and just advances —
/// an occurrence can never be posted twice.
class RecurringService {
  final AppDatabase _db;
  final RecurringRepository _rules;
  final TransactionRepository _transactions;
  final NotificationService? _notifications;

  /// Upper bound of catch-up posts per rule per run (two months of a daily
  /// rule), so a long-unopened app does not freeze on first launch.
  static const int maxCatchUpPerRule = 62;

  RecurringService({
    required this._db,
    required this._rules,
    required this._transactions,
    this._notifications,
  });

  static String occurrenceTxId(String ruleId, int index) =>
      'rec_${ruleId}_$index';

  bool _running = false;

  /// Posts every due occurrence of every automatic rule.
  Future<RecurringRunResult> postDue({DateTime? now}) async {
    if (_running) return const RecurringRunResult(posted: 0, failed: 0);
    _running = true;
    var posted = 0;
    var failed = 0;
    try {
      final at = now ?? DateTime.now();
      for (final rule in await _rules.getRules()) {
        if (!rule.autoPost) continue;
        var current = rule;
        for (var i = 0; i < maxCatchUpPerRule && current.isDue(at); i++) {
          final ok = await _postCurrent(current);
          if (!ok) {
            failed++;
            break;
          }
          posted++;
          final next = await _rules.getRule(rule.id);
          if (next == null) break;
          current = next;
        }
      }
      await scheduleReminders(now: at);
    } catch (e, st) {
      AppLogger.error('Recurring posting failed', error: e, stackTrace: st);
    } finally {
      _running = false;
    }
    return RecurringRunResult(posted: posted, failed: failed);
  }

  /// Posts the rule's current occurrence now (confirming a reminder-only
  /// rule, or paying a bill early). Returns null on success, else an error.
  Future<String?> postNow(String ruleId) async {
    final rule = await _rules.getRule(ruleId);
    if (rule == null) return 'تراکنش تکراری پیدا نشد.';
    if (rule.isFinished) return 'این مورد به پایان رسیده است.';
    final ok = await _postCurrent(rule);
    if (!ok) return (await _rules.getRule(ruleId))?.lastError;
    await scheduleReminders();
    return null;
  }

  /// Skips the current occurrence without posting anything.
  Future<void> skip(String ruleId) async {
    await _rules.advance(ruleId, posted: false);
    await scheduleReminders();
  }

  Future<bool> _postCurrent(RecurringRuleEntity rule) async {
    final txId = occurrenceTxId(rule.id, rule.nextIndex);
    final existing = await (_db.select(
      _db.transactionsTable,
    )..where((t) => t.id.equals(txId))).getSingleOrNull();

    if (existing == null) {
      final when = rule.nextRunDate;
      final result = await _transactions.createTransaction(
        TransactionEntity(
          id: txId,
          accountId: rule.accountId,
          destinationAccountId: rule.type == TransactionType.transfer
              ? rule.destinationAccountId
              : null,
          categoryId: rule.categoryId,
          amount: rule.amount,
          type: rule.type,
          date: when,
          description: rule.title,
          notes: rule.notes,
          createdAt: when,
          updatedAt: when,
          recurringRuleId: rule.id,
        ),
      );
      if (result.isFailure) {
        final message = result.failureOrNull!.message;
        await _rules.recordError(rule.id, message);
        AppLogger.warning('Recurring rule ${rule.id} not posted: $message');
        return false;
      }
    }
    await _rules.advance(rule.id, posted: true);
    return true;
  }

  /// One reminder per active rule, [RecurringRuleEntity.remindDaysBefore]
  /// days ahead at 9:00. Re-scheduling replaces the previous reminder.
  Future<void> scheduleReminders({DateTime? now}) async {
    final notifications = _notifications;
    if (notifications == null) return;
    final at = now ?? DateTime.now();
    for (final rule in await _rules.getRules()) {
      if (!rule.isActive || rule.isFinished) continue;
      final day = rule.nextRunDate.subtract(
        Duration(days: rule.remindDaysBefore),
      );
      final remindAt = DateTime(day.year, day.month, day.day, 9);
      if (!remindAt.isAfter(at)) continue;
      try {
        await notifications.scheduleNotification(
          title: rule.autoPost
              ? 'ثبت خودکار: ${rule.title}'
              : 'یادآوری پرداخت: ${rule.title}',
          body: rule.autoPost
              ? 'این تراکنش در موعد خودش به‌صورت خودکار ثبت می‌شود.'
              : 'موعد این پرداخت نزدیک است؛ پس از پرداخت آن را تأیید کنید.',
          type: NotificationType.recurringDue,
          referenceId: 'recurring_${rule.id}',
          scheduledFor: remindAt,
        );
      } catch (e) {
        AppLogger.warning('Reminder for ${rule.id} not scheduled: $e');
      }
    }
  }
}
