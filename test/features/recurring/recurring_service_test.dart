import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/date_utils.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:kifino/features/recurring/domain/entities/recurring_rule_entity.dart';
import 'package:kifino/features/recurring/domain/services/recurrence.dart';
import 'package:kifino/features/recurring/domain/services/recurring_service.dart';
import 'package:kifino/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  late AppDatabase db;
  late RecurringRepositoryImpl rules;
  late TransactionRepositoryImpl txRepo;
  late RecurringService service;

  Future<void> seedAccount(String id, {int balance = 10000000}) => db
      .into(db.accountsTable)
      .insert(
        AccountsTableCompanion.insert(
          id: id,
          name: id,
          type: 'bankCard',
          currency: 'TOMAN',
          initialBalanceMinor: Value(balance),
          currentBalanceMinor: Value(balance),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<int> balance(String id) async => (await (db.select(
    db.accountsTable,
  )..where((t) => t.id.equals(id))).getSingle()).currentBalanceMinor;

  Future<List<TransactionData>> txs() => (db.select(
    db.transactionsTable,
  )..where((t) => t.deletedAt.isNull())).get();

  RecurringRuleEntity rule({
    String id = 'rent',
    required DateTime start,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int interval = 1,
    bool autoPost = true,
    int? maxOccurrences,
    TransactionType type = TransactionType.expense,
    String? destination,
    int amount = 5000000,
  }) => RecurringRuleEntity(
    id: id,
    title: 'اجاره خانه',
    type: type,
    accountId: 'acc',
    destinationAccountId: destination,
    amount: Money.fromMinor(amount, Currency.toman),
    frequency: frequency,
    interval: interval,
    startDate: start,
    nextRunDate: start,
    autoPost: autoPost,
    maxOccurrences: maxOccurrences,
    createdAt: start,
    updatedAt: start,
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    rules = RecurringRepositoryImpl(db);
    txRepo = TransactionRepositoryImpl(db);
    service = RecurringService(db: db, rules: rules, transactions: txRepo);
    await seedAccount('acc');
  });

  tearDown(() => db.close());

  group('Recurrence', () {
    test(
      'monthly occurrences keep the Jalali day, even after a short month',
      () {
        final start = JalaliDate(1405, 6, 31).toDateTime(); // 31 Shahrivar
        (int, int, int) at(int i) {
          final j = JalaliDate.fromDateTime(
            Recurrence.occurrence(
              start: start,
              frequency: RecurrenceFrequency.monthly,
              interval: 1,
              index: i,
            ),
          );
          return (j.year, j.month, j.day);
        }

        expect(at(1), (1405, 7, 30)); // Mehr has 30 days
        expect(at(12), (1406, 6, 31)); // back on the 31st a year later
      },
    );

    test('weekly with an interval counts exact days', () {
      expect(
        Recurrence.occurrence(
          start: DateTime(2026, 1, 1),
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          index: 3,
        ),
        DateTime(2026, 2, 12),
      );
    });

    test('describes the schedule in Persian', () {
      expect(Recurrence.describeFa(RecurrenceFrequency.monthly, 1), 'ماهانه');
      expect(Recurrence.describeFa(RecurrenceFrequency.weekly, 2), 'هر 2 هفته');
    });
  });

  group('postDue', () {
    test('posts every missed occurrence and moves the balance', () async {
      final start = DateTime(2026, 1, 5, 9);
      await rules.createRule(rule(start: start));

      final result = await service.postDue(now: DateTime(2026, 3, 10));

      expect(result.posted, 3); // Jan 5 (~), +1 and +2 Jalali months
      final posted = await txs();
      expect(posted, hasLength(3));
      expect(posted.every((t) => t.recurringRuleId == 'rent'), isTrue);
      expect(await balance('acc'), 10000000 - 3 * 5000000);
      final saved = (await rules.getRule('rent'))!;
      expect(saved.postedCount, 3);
      expect(saved.nextIndex, 3);
      expect(saved.nextRunDate.isAfter(DateTime(2026, 3, 10)), isTrue);
    });

    test('is idempotent: running twice never double-posts', () async {
      await rules.createRule(rule(start: DateTime(2026, 1, 5)));
      await service.postDue(now: DateTime(2026, 2, 1));
      await service.postDue(now: DateTime(2026, 2, 1));
      expect(await txs(), hasLength(1));
    });

    test('survives a crash between posting and advancing', () async {
      await rules.createRule(rule(start: DateTime(2026, 1, 5)));
      // Simulate: the transaction for occurrence 0 exists but the rule was
      // never advanced (app killed in between).
      await txRepo.createTransaction(
        TransactionEntity(
          id: RecurringService.occurrenceTxId('rent', 0),
          accountId: 'acc',
          amount: const Money.fromMinor(5000000, Currency.toman),
          type: TransactionType.expense,
          date: DateTime(2026, 1, 5),
          description: 'اجاره خانه',
          createdAt: DateTime(2026, 1, 5),
          updatedAt: DateTime(2026, 1, 5),
          recurringRuleId: 'rent',
        ),
      );

      await service.postDue(now: DateTime(2026, 1, 20));

      expect(await txs(), hasLength(1));
      expect(await balance('acc'), 10000000 - 5000000);
      expect((await rules.getRule('rent'))!.nextIndex, 1);
    });

    test('reminder-only rules are not posted automatically', () async {
      await rules.createRule(
        rule(start: DateTime(2026, 1, 5), autoPost: false),
      );
      final result = await service.postDue(now: DateTime(2026, 3, 1));
      expect(result.posted, 0);
      expect(await txs(), isEmpty);
    });

    test('stops after maxOccurrences', () async {
      await rules.createRule(
        rule(start: DateTime(2026, 1, 5), maxOccurrences: 2),
      );
      await service.postDue(now: DateTime(2026, 12, 1));
      expect(await txs(), hasLength(2));
      expect((await rules.getRule('rent'))!.isFinished, isTrue);
    });

    test('paused rules post nothing; resuming skips the missed ones', () async {
      await rules.createRule(rule(start: DateTime(2026, 1, 5)));
      await rules.setActive('rent', false);
      await service.postDue(now: DateTime(2026, 4, 1));
      expect(await txs(), isEmpty);

      await rules.setActive('rent', true, now: DateTime(2026, 4, 1));
      await service.postDue(now: DateTime(2026, 4, 1));
      expect(await txs(), isEmpty); // nothing back-posted
      final saved = (await rules.getRule('rent'))!;
      expect(saved.nextRunDate.isAfter(DateTime(2026, 3, 31)), isTrue);
    });

    test('a failing rule records why and is retried later', () async {
      await rules.createRule(
        rule(
          start: DateTime(2026, 1, 5),
          type: TransactionType.transfer,
          destination: 'missing-account',
        ),
      );
      final result = await service.postDue(now: DateTime(2026, 1, 6));
      expect(result.failed, 1);
      final saved = (await rules.getRule('rent'))!;
      expect(saved.lastError, isNotNull);
      expect(saved.nextIndex, 0); // still due
    });

    test('transfers move money between two accounts', () async {
      await seedAccount('savings', balance: 0);
      await rules.createRule(
        rule(
          start: DateTime(2026, 1, 5),
          type: TransactionType.transfer,
          destination: 'savings',
          amount: 1000000,
        ),
      );
      await service.postDue(now: DateTime(2026, 1, 6));
      expect(await balance('acc'), 10000000 - 1000000);
      expect(await balance('savings'), 1000000);
    });
  });

  group('manual actions', () {
    test(
      'postNow confirms the current occurrence of a reminder rule',
      () async {
        await rules.createRule(
          rule(start: DateTime(2026, 1, 5), autoPost: false),
        );
        expect(await service.postNow('rent'), isNull);
        expect(await txs(), hasLength(1));
        expect((await rules.getRule('rent'))!.nextIndex, 1);
      },
    );

    test('skip advances without posting', () async {
      await rules.createRule(
        rule(start: DateTime(2026, 1, 5), autoPost: false),
      );
      await service.skip('rent');
      expect(await txs(), isEmpty);
      final saved = (await rules.getRule('rent'))!;
      expect(saved.nextIndex, 1);
      expect(saved.postedCount, 0);
    });

    test(
      'a posted occurrence stays editable (bills differ month to month)',
      () async {
        await rules.createRule(rule(start: DateTime(2026, 1, 5)));
        await service.postDue(now: DateTime(2026, 1, 6));
        final entity = (await txRepo
            .watchTransactionById(RecurringService.occurrenceTxId('rent', 0))
            .first)!;
        final edited = await txRepo.updateTransaction(
          entity.copyWith(
            amount: const Money.fromMinor(4500000, Currency.toman),
          ),
        );
        expect(edited.isSuccess, isTrue);
        expect(await balance('acc'), 10000000 - 4500000);
      },
    );
  });

  group('repository', () {
    test(
      'editing the schedule restarts from today, never back-posts',
      () async {
        await rules.createRule(rule(start: DateTime(2026, 3, 1)));
        final existing = (await rules.getRule('rent'))!;
        await rules.updateRule(
          existing.copyWith(startDate: DateTime(2025, 1, 1)),
          now: DateTime(2026, 3, 1),
        );
        await service.postDue(now: DateTime(2026, 3, 1, 23));
        // At most today's occurrence — not 14 months of back rent.
        expect((await txs()).length, lessThanOrEqualTo(1));
      },
    );

    test('rejects invalid rules', () async {
      final zero = await rules.createRule(
        rule(start: DateTime(2026, 1, 1), amount: 0),
      );
      expect(zero.isFailure, isTrue);
      final selfTransfer = await rules.createRule(
        rule(
          id: 'self',
          start: DateTime(2026, 1, 1),
          type: TransactionType.transfer,
          destination: 'acc',
        ),
      );
      expect(selfTransfer.isFailure, isTrue);
    });

    test('monthly equivalent normalises other frequencies', () {
      final weekly = rule(
        start: DateTime(2026, 1, 1),
        frequency: RecurrenceFrequency.weekly,
        amount: 120,
      );
      expect(weekly.monthlyEquivalent.minorUnits, 520);
      final yearly = rule(
        start: DateTime(2026, 1, 1),
        frequency: RecurrenceFrequency.yearly,
        amount: 1200,
      );
      expect(yearly.monthlyEquivalent.minorUnits, 100);
    });
  });
}
