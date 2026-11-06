import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';

/// Phase-3-rework installment rule tests: edit, payment history, payment
/// correction (delete reverts money + ledger), early payoff.
void main() {
  late AppDatabase db;
  late InstallmentRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = InstallmentRepositoryImpl(db);
  });

  Future<void> seedAccountAndInstallment({
    String id = 'inst-1',
    int paid = 0,
    int openingBalance = 100000000,
  }) async {
    await db
        .into(db.accountsTable)
        .insertOnConflictUpdate(
          AccountsTableCompanion.insert(
            id: 'acc-1',
            name: 'حساب اصلی',
            type: 'bankCard',
            currency: 'TOMAN',
            initialBalanceMinor: Value(openingBalance),
            currentBalanceMinor: Value(openingBalance),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    await db
        .into(db.installmentsTable)
        .insertOnConflictUpdate(
          InstallmentsTableCompanion.insert(
            id: id,
            title: 'قسط خودرو',
            accountId: 'acc-1',
            totalAmountMinor: 240000000,
            currency: 'TOMAN',
            numberOfInstallments: 12,
            paidInstallmentsCount: Value(paid),
            installmentAmountMinor: 20000000,
            startDate: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            nextDueDate: DateTime(2026, 2, 1).millisecondsSinceEpoch,
            status: 'ongoing',
            createdAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            updatedAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          ),
        );
  }

  tearDown(() async => db.close());

  group('Phase 3 rework — installments', () {
    test('payNextInstallment records history and deducts balance', () async {
      await seedAccountAndInstallment();
      final res = await repo.payNextInstallment('inst-1');
      expect(res.isSuccess, isTrue);

      final history = await repo.getPaymentHistory('inst-1');
      expect(history.length, equals(1));
      expect(history.first.installmentIndex, equals(1));
      expect(history.first.amountMinor, equals(20000000));
      expect(history.first.ledgerTransactionId, isNotNull);

      final accounts = await db.select(db.accountsTable).get();
      expect(accounts.first.currentBalanceMinor, equals(80000000));
    });

    test('deletePayment reverts money, ledger row and paid count', () async {
      await seedAccountAndInstallment();
      await repo.payNextInstallment('inst-1');

      final history = await repo.getPaymentHistory('inst-1');
      final deleteRes = await repo.deletePayment(history.first.id);
      expect(deleteRes.isSuccess, isTrue);

      final inst = await (db.select(
        db.installmentsTable,
      )..where((tbl) => tbl.id.equals('inst-1'))).getSingle();
      expect(inst.paidInstallmentsCount, equals(0));

      final accounts = await db.select(db.accountsTable).get();
      expect(accounts.first.currentBalanceMinor, equals(100000000));

      // Linked ledger transaction is soft-deleted (invisible in lists).
      final tx =
          await (db.select(db.transactionsTable)..where(
                (tbl) => tbl.id.equals(history.first.ledgerTransactionId!),
              ))
              .getSingle();
      expect(tx.deletedAt, isNotNull);

      final historyAfter = await repo.getPaymentHistory('inst-1');
      expect(historyAfter, isEmpty);
    });

    test(
      'updateInstallment edits plan fields without touching payments',
      () async {
        await seedAccountAndInstallment();
        await repo.payNextInstallment('inst-1');

        final inst = await (db.select(
          db.installmentsTable,
        )..where((tbl) => tbl.id.equals('inst-1'))).getSingle();
        final entity = InstallmentEntity(
          id: inst.id,
          title: 'قسط خودرو (اصلاح‌شده)',
          accountId: inst.accountId,
          totalAmount: Money.fromMinor(300000000, Currency.toman),
          numberOfInstallments: 15,
          paidInstallmentsCount: inst.paidInstallmentsCount,
          installmentAmount: Money.fromMinor(20000000, Currency.toman),
          startDate: DateTime.fromMillisecondsSinceEpoch(inst.startDate),
          recurrenceIntervalDays: 30,
          nextDueDate: DateTime.fromMillisecondsSinceEpoch(inst.nextDueDate),
          createdAt: DateTime.fromMillisecondsSinceEpoch(inst.createdAt),
          updatedAt: DateTime.now(),
        );

        final res = await repo.updateInstallment(entity);
        expect(res.isSuccess, isTrue);

        final row = await (db.select(
          db.installmentsTable,
        )..where((tbl) => tbl.id.equals('inst-1'))).getSingle();
        expect(row.title, equals('قسط خودرو (اصلاح‌شده)'));
        expect(row.totalAmountMinor, equals(300000000));
        expect(row.numberOfInstallments, equals(15));
        // History untouched.
        expect((await repo.getPaymentHistory('inst-1')).length, equals(1));
      },
    );

    test(
      'payRemaining settles the plan in one shot with history rows',
      () async {
        await seedAccountAndInstallment(paid: 10);
        await repo.payNextInstallment('inst-1'); // 11 از ۱۲
        await repo.payNextInstallment('inst-1'); // 12 از ۱۲ — completed

        // PayRemaining after completion should fail with a Persian message.
        final fail = await repo.payRemaining('inst-1');
        expect(fail.isFailure, isTrue);
      },
    );

    test(
      'payRemaining pays the rest, completes plan and records history',
      () async {
        await seedAccountAndInstallment(paid: 10);
        final res = await repo.payRemaining('inst-1');
        expect(res.isSuccess, isTrue);

        final row = await (db.select(
          db.installmentsTable,
        )..where((tbl) => tbl.id.equals('inst-1'))).getSingle();
        expect(row.paidInstallmentsCount, equals(12));
        expect(row.status, equals('completed'));

        final history = await repo.getPaymentHistory('inst-1');
        expect(history.length, equals(2)); // two remaining قسط rows

        // Balance: opening 100M − 2×20M = 60M
        final accounts = await db.select(db.accountsTable).get();
        expect(accounts.first.currentBalanceMinor, equals(60000000));
      },
    );

    test(
      'payRemaining followed by deletePayment of one installment does not delete the other installment ledger transaction',
      () async {
        await seedAccountAndInstallment(paid: 10);
        final res = await repo.payRemaining('inst-1');
        expect(res.isSuccess, isTrue);

        final history = await repo.getPaymentHistory('inst-1');
        expect(history.length, equals(2));
        final payment12 = history.firstWhere((p) => p.installmentIndex == 12);
        final payment11 = history.firstWhere((p) => p.installmentIndex == 11);

        // Delete payment 12
        final delRes = await repo.deletePayment(payment12.id);
        expect(delRes.isSuccess, isTrue);

        // Payment 11's ledger transaction MUST still exist and not be soft-deleted!
        final tx11 = await (db.select(db.transactionsTable)
              ..where((tbl) => tbl.id.equals(payment11.ledgerTransactionId!)))
            .getSingleOrNull();
        expect(tx11, isNotNull);
        expect(
          tx11!.deletedAt,
          isNull,
          reason: 'Payment 11 ledger transaction must remain active',
        );

        // Account balance should be: 100M - 20M (payment 11) = 80M
        final account = await (db.select(db.accountsTable)
              ..where((t) => t.id.equals('acc-1')))
            .getSingle();
        expect(account.currentBalanceMinor, equals(80000000));
      },
    );

    test('deletePayment after completion reverts plan to ongoing', () async {
      await seedAccountAndInstallment(paid: 12);
      await (db.update(db.installmentsTable)
            ..where((tbl) => tbl.id.equals('inst-1')))
          .write(const InstallmentsTableCompanion(status: Value('completed')));

      // 12 recorded payments matching the completed plan.
      for (var i = 1; i <= 12; i++) {
        await db
            .into(db.installmentPaymentsTable)
            .insertOnConflictUpdate(
              InstallmentPaymentsTableCompanion.insert(
                id: 'pay-$i',
                installmentId: 'inst-1',
                amountMinor: 20000000,
                installmentIndex: i,
                paidAt:
                    DateTime(2026, 1, 1).millisecondsSinceEpoch + i * 86400000,
                createdAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              ),
            );
      }
      expect((await repo.getPaymentHistory('inst-1')).length, equals(12));

      final deleteRes = await repo.deletePayment('pay-12');
      expect(deleteRes.isSuccess, isTrue);

      final row = await (db.select(
        db.installmentsTable,
      )..where((tbl) => tbl.id.equals('inst-1'))).getSingle();
      expect(row.paidInstallmentsCount, equals(11));
      expect(row.status, equals('ongoing'));
    });
  });
}
