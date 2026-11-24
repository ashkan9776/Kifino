import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/checks/domain/entities/check_entity.dart';
import 'package:kifino/features/dashboard/domain/upcoming.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';
import 'package:kifino/features/recurring/domain/entities/recurring_rule_entity.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  final now = DateTime(2026, 11, 24, 12);
  const toman = Currency.toman;

  RecurringRuleEntity rule(String id, DateTime next, {bool auto = true}) =>
      RecurringRuleEntity(
        id: id,
        title: id,
        type: TransactionType.expense,
        accountId: 'acc',
        amount: const Money.fromMinor(100, toman),
        startDate: next,
        nextRunDate: next,
        autoPost: auto,
        createdAt: now,
        updatedAt: now,
      );

  test('merges sources, overdue first, then by date', () {
    final items = buildUpcoming(
      now: now,
      recurring: [
        rule('internet', DateTime(2026, 11, 30)),
        rule('rent-manual', DateTime(2026, 11, 20), auto: false),
      ],
      installments: [
        InstallmentEntity(
          id: 'loan',
          title: 'وام',
          accountId: 'acc',
          totalAmount: const Money.fromMinor(1000, toman),
          numberOfInstallments: 10,
          installmentAmount: const Money.fromMinor(100, toman),
          startDate: now,
          nextDueDate: DateTime(2026, 11, 26),
          createdAt: now,
          updatedAt: now,
        ),
      ],
      checks: [
        CheckEntity(
          id: 'chk',
          checkNumber: '1',
          bankName: 'ملت',
          type: CheckType.received,
          amount: const Money.fromMinor(500, toman),
          partyName: 'علی',
          dueDate: DateTime(2026, 11, 25),
          status: CheckStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(items.map((i) => i.id), ['rent-manual', 'chk', 'loan', 'internet']);
    expect(items.first.overdue, isTrue);
    expect(items.first.needsConfirmation, isTrue);
    expect(items[1].incoming, isTrue); // received check
  });

  test('drops items outside the window and auto rules already due', () {
    final items = buildUpcoming(
      now: now,
      recurring: [
        rule('far', DateTime(2027, 1, 1)),
        rule('auto-due', DateTime(2026, 11, 24, 9)), // the engine posts it
      ],
    );
    expect(items, isEmpty);
  });
}
