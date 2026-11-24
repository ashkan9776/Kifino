import '../../../core/utils/money.dart';
import '../../checks/domain/entities/check_entity.dart';
import '../../debts/domain/entities/debt_entity.dart';
import '../../installments/domain/entities/installment_entity.dart';
import '../../recurring/domain/entities/recurring_rule_entity.dart';
import '../../transactions/domain/entities/transaction_entity.dart';

enum UpcomingKind { recurring, installment, check, debt, receivable }

/// One thing that will move money soon — the "پیش رو" list on the dashboard.
class UpcomingItem {
  final UpcomingKind kind;
  final String id;
  final String title;
  final DateTime date;
  final Money amount;

  /// True when money comes in (salary, received check, receivable).
  final bool incoming;

  /// Past due and still waiting for the user (never auto-resolved).
  final bool overdue;

  /// For reminder-only recurring rules: the user confirms the payment.
  final bool needsConfirmation;
  final String route;

  const UpcomingItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.incoming,
    required this.overdue,
    this.needsConfirmation = false,
    required this.route,
  });
}

/// Merges every scheduled money movement due within [horizon] (plus anything
/// overdue) into one list, soonest first.
List<UpcomingItem> buildUpcoming({
  required DateTime now,
  Duration horizon = const Duration(days: 14),
  List<RecurringRuleEntity> recurring = const [],
  List<InstallmentEntity> installments = const [],
  List<CheckEntity> checks = const [],
  List<DebtEntity> debts = const [],
}) {
  final today = DateTime(now.year, now.month, now.day);
  final until = today.add(horizon).add(const Duration(days: 1));
  bool inWindow(DateTime d) => d.isBefore(until);
  bool past(DateTime d) => d.isBefore(today);

  final items = <UpcomingItem>[];

  for (final r in recurring) {
    if (!r.isActive || r.isFinished || !inWindow(r.nextRunDate)) continue;
    // Automatic rules that are already due get posted by the engine; only
    // the manual ones linger as overdue.
    if (r.autoPost && !r.nextRunDate.isAfter(now)) continue;
    items.add(
      UpcomingItem(
        kind: UpcomingKind.recurring,
        id: r.id,
        title: r.title,
        date: r.nextRunDate,
        amount: r.amount,
        incoming: r.type == TransactionType.income,
        overdue: !r.autoPost && past(r.nextRunDate),
        needsConfirmation: !r.autoPost,
        route: '/recurring',
      ),
    );
  }

  for (final i in installments) {
    if (i.isCompleted || i.deletedAt != null || !inWindow(i.nextDueDate)) {
      continue;
    }
    items.add(
      UpcomingItem(
        kind: UpcomingKind.installment,
        id: i.id,
        title: 'قسط ${i.title}',
        date: i.nextDueDate,
        amount: i.installmentAmount,
        incoming: false,
        overdue: past(i.nextDueDate),
        route: '/installments',
      ),
    );
  }

  for (final c in checks) {
    if (c.status != CheckStatus.pending || !inWindow(c.dueDate)) continue;
    final incoming = c.type == CheckType.received;
    items.add(
      UpcomingItem(
        kind: UpcomingKind.check,
        id: c.id,
        title: incoming ? 'وصول چک ${c.partyName}' : 'چک ${c.partyName}',
        date: c.dueDate,
        amount: c.amount,
        incoming: incoming,
        overdue: past(c.dueDate),
        route: '/checks',
      ),
    );
  }

  for (final d in debts) {
    final due = d.dueDate;
    if (due == null || d.isSettled || !inWindow(due)) continue;
    final incoming = d.type == DebtType.receivable;
    items.add(
      UpcomingItem(
        kind: incoming ? UpcomingKind.receivable : UpcomingKind.debt,
        id: d.id,
        title: incoming
            ? 'طلب از ${d.contactName}'
            : 'بدهی به ${d.contactName}',
        date: due,
        amount: d.remainingAmount,
        incoming: incoming,
        overdue: past(due),
        route: '/debts',
      ),
    );
  }

  items.sort((a, b) {
    if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
    return a.date.compareTo(b.date);
  });
  return items;
}
