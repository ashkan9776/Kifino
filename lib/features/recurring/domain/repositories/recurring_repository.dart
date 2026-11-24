import '../../../../core/errors/result.dart';
import '../entities/recurring_rule_entity.dart';

abstract interface class RecurringRepository {
  Stream<List<RecurringRuleEntity>> watchRules();
  Future<List<RecurringRuleEntity>> getRules();
  Future<RecurringRuleEntity?> getRule(String id);
  Future<Result<RecurringRuleEntity>> createRule(RecurringRuleEntity rule);

  /// Saves edits. When the schedule changes, the next occurrence restarts
  /// from today so an edited start date never back-posts old occurrences.
  Future<Result<void>> updateRule(RecurringRuleEntity rule, {DateTime? now});
  Future<Result<void>> deleteRule(String id);

  /// Pausing keeps the rule; resuming skips occurrences missed while paused.
  Future<Result<void>> setActive(String id, bool active, {DateTime? now});

  /// Moves past the current occurrence; [posted] counts it as paid.
  Future<void> advance(String id, {required bool posted});
  Future<void> recordError(String id, String? message);
}
