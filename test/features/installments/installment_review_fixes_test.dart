import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/date_utils.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';
import 'package:kifino/features/installments/domain/services/installment_schedule.dart';

void main() {
  group('addJalaliMonths', () {
    test('keeps the Jalali day of month', () {
      final start = JalaliDate(1405, 1, 5).toDateTime(); // 5 Farvardin
      final next = JalaliDate.fromDateTime(addJalaliMonths(start, 1));
      expect((next.year, next.month, next.day), (1405, 2, 5));
      final year = JalaliDate.fromDateTime(addJalaliMonths(start, 12));
      expect((year.year, year.month, year.day), (1406, 1, 5));
    });

    test('clamps 31 Shahrivar to the last day of Mehr', () {
      final d = JalaliDate(1405, 6, 31).toDateTime();
      final next = JalaliDate.fromDateTime(addJalaliMonths(d, 1));
      expect((next.year, next.month, next.day), (1405, 7, 30));
    });

    test('goes backwards across a year boundary', () {
      final d = JalaliDate(1405, 1, 10).toDateTime();
      final prev = JalaliDate.fromDateTime(addJalaliMonths(d, -1));
      expect((prev.year, prev.month, prev.day), (1404, 12, 10));
    });
  });

  group('InstallmentSchedule', () {
    test('monthly plans do not drift over a year', () {
      final first = JalaliDate(1405, 1, 5).toDateTime();
      final twelfth = InstallmentSchedule.dueDateFor(
        firstDue: first,
        intervalDays: 30,
        index: 13,
      );
      final j = JalaliDate.fromDateTime(twelfth);
      // Old 30-day arithmetic landed on ~29 Esfand 1405 / 1 Farvardin
      // instead of the 5th.
      expect((j.year, j.month, j.day), (1406, 1, 5));
    });

    test('non-monthly intervals are exact days', () {
      final first = DateTime(2026, 3, 1);
      expect(
        InstallmentSchedule.dueDateFor(
          firstDue: first,
          intervalDays: 7,
          index: 3,
        ),
        DateTime(2026, 3, 15),
      );
    });

    test('inferFirstDue inverts dueDateFor', () {
      final first = JalaliDate(1405, 6, 31).toDateTime();
      final next = InstallmentSchedule.dueDateFor(
        firstDue: first,
        intervalDays: 30,
        index: 4,
      );
      // Clamping in short months loses the 31st, so the inferred anchor is
      // on or just before the real one — never in a different month.
      final inferred = JalaliDate.fromDateTime(
        InstallmentSchedule.inferFirstDue(
          nextDue: next,
          intervalDays: 30,
          paidCount: 3,
        ),
      );
      expect((inferred.year, inferred.month), (1405, 6));
    });
  });

  group('InstallmentRepository', () {
    late AppDatabase db;
    late InstallmentRepositoryImpl repo;
    final firstDue = JalaliDate(1405, 2, 10).toDateTime();

    Future<void> seed({
      String planCurrency = 'TOMAN',
      String accountCurrency = 'TOMAN',
      int count = 3,
    }) async {
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: 'acc',
              name: 'acc',
              type: 'bankCard',
              currency: accountCurrency,
              initialBalanceMinor: const Value(10000000),
              currentBalanceMinor: const Value(10000000),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final c = Currency.fromCode(planCurrency);
      await repo.createInstallment(
        InstallmentEntity(
          id: 'plan',
          title: 'وام',
          accountId: 'acc',
          totalAmount: Money.fromMinor(100000 * count, c),
          numberOfInstallments: count,
          installmentAmount: Money.fromMinor(100000, c),
          // Created well before the first due date, as in the real form.
          startDate: firstDue.subtract(const Duration(days: 20)),
          nextDueDate: firstDue,
          createdAt: firstDue,
          updatedAt: firstDue,
        ),
      );
    }

    Future<InstallmentData> plan() =>
        db.select(db.installmentsTable).getSingle();
    Future<int> balance() async =>
        (await db.select(db.accountsTable).getSingle()).currentBalanceMinor;
    (int, int, int) jalaliOf(int epoch) {
      final j = JalaliDate.fromDateTime(
        DateTime.fromMillisecondsSinceEpoch(epoch),
      );
      return (j.year, j.month, j.day);
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = InstallmentRepositoryImpl(db);
    });
    tearDown(() => db.close());

    test(
      'refuses to pay a completed plan (double tap / stale screen)',
      () async {
        await seed(count: 1);
        expect((await repo.payNextInstallment('plan')).isSuccess, isTrue);
        final balanceAfterFirst = await balance();

        final second = await repo.payNextInstallment('plan');

        expect(second.isFailure, isTrue);
        expect(await balance(), balanceAfterFirst);
        expect((await plan()).paidInstallmentsCount, 1);
        expect(
          await db.select(db.installmentPaymentsTable).get(),
          hasLength(1),
        );
      },
    );

    test(
      'a Rial plan paid from a Toman account deducts the Toman amount',
      () async {
        await seed(planCurrency: 'IRR', accountCurrency: 'TOMAN');
        await repo.payNextInstallment('plan');
        // 100,000 Rial = 10,000 Toman (the bug deducted 100,000 Toman).
        expect(await balance(), 10000000 - 10000);

        await repo.payRemaining('plan');
        expect(await balance(), 10000000 - 30000);
      },
    );

    test('monthly due dates follow the Jalali calendar day', () async {
      await seed(count: 6);
      for (var i = 0; i < 4; i++) {
        await repo.payNextInstallment('plan');
      }
      // Installment #5 is due on 10 Shahrivar (4 months after 10 Ordibehesht).
      expect(jalaliOf((await plan()).nextDueDate), (1405, 6, 10));
    });

    test('deleting a payment moves the due date back to that installment '
        '(not to the plan creation date)', () async {
      await seed();
      await repo.payNextInstallment('plan');
      await repo.payNextInstallment('plan');
      final history = await repo.getPaymentHistory('plan');
      final latest = history.firstWhere((p) => p.installmentIndex == 2);

      await repo.deletePayment(latest.id);

      expect((await plan()).paidInstallmentsCount, 1);
      expect(jalaliOf((await plan()).nextDueDate), (1405, 3, 10));
      expect(await balance(), 10000000 - 100000);
    });

    test('plans created before v10 (no stored first due date) still step '
        'correctly', () async {
      await seed();
      await (db.update(db.installmentsTable))
          .write(const InstallmentsTableCompanion(firstDueDate: Value(null)));
      await repo.payNextInstallment('plan');
      expect(jalaliOf((await plan()).nextDueDate), (1405, 3, 10));
    });
  });
}
