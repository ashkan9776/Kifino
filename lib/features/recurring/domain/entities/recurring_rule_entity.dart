import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../services/recurrence.dart';

/// A scheduled money movement: rent, salary, a subscription, a bill.
class RecurringRuleEntity extends Equatable {
  final String id;
  final String title;
  final TransactionType type; // income, expense or transfer
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final Money amount;
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime startDate;

  /// First occurrence (0-based) not yet posted or skipped.
  final int nextIndex;
  final DateTime nextRunDate;
  final DateTime? endDate;
  final int? maxOccurrences;
  final int postedCount;

  /// True: posted automatically when due. False: the user confirms each one.
  final bool autoPost;
  final int remindDaysBefore;
  final bool isActive;
  final String? notes;

  /// Why the last automatic post failed (e.g. the account was deleted).
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringRuleEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    required this.amount,
    this.frequency = RecurrenceFrequency.monthly,
    this.interval = 1,
    required this.startDate,
    this.nextIndex = 0,
    required this.nextRunDate,
    this.endDate,
    this.maxOccurrences,
    this.postedCount = 0,
    this.autoPost = true,
    this.remindDaysBefore = 1,
    this.isActive = true,
    this.notes,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True once the rule has no further occurrence (end date or count hit).
  bool get isFinished =>
      (maxOccurrences != null && nextIndex >= maxOccurrences!) ||
      (endDate != null && nextRunDate.isAfter(endDate!));

  bool isDue(DateTime now) =>
      isActive && !isFinished && !nextRunDate.isAfter(now);

  /// Rough monthly cost/income, for the "fixed monthly commitments" total.
  Money get monthlyEquivalent {
    final perOccurrence = amount.minorUnits.toDouble();
    final step = interval < 1 ? 1 : interval;
    final perMonth = switch (frequency) {
      RecurrenceFrequency.daily => perOccurrence * 30 / step,
      RecurrenceFrequency.weekly => perOccurrence * 52 / 12 / step,
      RecurrenceFrequency.monthly => perOccurrence / step,
      RecurrenceFrequency.yearly => perOccurrence / 12 / step,
    };
    return Money.fromMinor(perMonth.round(), amount.currency);
  }

  String get scheduleLabelFa => Recurrence.describeFa(frequency, interval);

  RecurringRuleEntity copyWith({
    String? id,
    String? title,
    TransactionType? type,
    String? accountId,
    String? destinationAccountId,
    String? categoryId,
    Money? amount,
    RecurrenceFrequency? frequency,
    int? interval,
    DateTime? startDate,
    int? nextIndex,
    DateTime? nextRunDate,
    DateTime? endDate,
    int? maxOccurrences,
    int? postedCount,
    bool? autoPost,
    int? remindDaysBefore,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringRuleEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      nextIndex: nextIndex ?? this.nextIndex,
      nextRunDate: nextRunDate ?? this.nextRunDate,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      postedCount: postedCount ?? this.postedCount,
      autoPost: autoPost ?? this.autoPost,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      lastError: lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    accountId,
    destinationAccountId,
    categoryId,
    amount,
    frequency,
    interval,
    startDate,
    nextIndex,
    nextRunDate,
    endDate,
    maxOccurrences,
    postedCount,
    autoPost,
    remindDaysBefore,
    isActive,
    notes,
    lastError,
  ];
}
