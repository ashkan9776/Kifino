import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/checks/data/repositories/check_repository_impl.dart';
import 'package:kifino/features/checks/domain/entities/check_entity.dart';
import 'package:kifino/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:kifino/features/debts/domain/entities/debt_entity.dart';
import 'package:kifino/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:kifino/features/goals/domain/entities/goal_entity.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';
import 'package:kifino/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

/// Auto-generated transactions (installments, checks, debts, goals) are
/// linked to their owner, so editing or deleting them from the activity list
/// can no longer leave the owning module out of step with the ledger.
void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl txRepo;
  late InstallmentRepositoryImpl instRepo;
  late CheckRepositoryImpl checkRepo;

  Future<void> seedAccount(
    String id, {
    String currency = 'TOMAN',
    int balance = 1000000,
  }) async {
    await db
        .into(db.accountsTable)
        .insert(
          AccountsTableCompanion.insert(
            id: id,
            name: id,
            type: 'bankCard',
            currency: currency,
            initialBalanceMinor: Value(balance),
            currentBalanceMinor: Value(balance),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  }

  Future<int> balanceOf(String id) async => (await (db.select(
    db.accountsTable,
  )..where((t) => t.id.equals(id))).getSingle()).currentBalanceMinor;

  Future<List<TransactionData>> activeTxs() => (db.select(
    db.transactionsTable,
  )..where((t) => t.deletedAt.isNull())).get();

  Future<void> seedPlan({String currency = 'TOMAN', int count = 3}) async {
    final now = DateTime(2026, 4, 1);
    await instRepo.createInstallment(
      InstallmentEntity(
        id: 'plan',
        title: 'وام',
        accountId: 'acc',
        totalAmount: Money.fromMinor(
          100000 * count,
          Currency.fromCode(currency),
        ),
        numberOfInstallments: count,
        installmentAmount: Money.fromMinor(100000, Currency.fromCode(currency)),
        startDate: now,
        nextDueDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> seedCheck({String status = 'pending'}) async {
    await db
        .into(db.checksTable)
        .insert(
          ChecksTableCompanion.insert(
            id: 'chk',
            checkNumber: '123',
            bankName: 'ملت',
            type: 'received',
            amountMinor: 250000,
            currency: 'TOMAN',
            partyName: 'علی',
            dueDate: 1,
            accountId: const Value('acc'),
            status: status,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    txRepo = TransactionRepositoryImpl(db);
    instRepo = InstallmentRepositoryImpl(db);
    checkRepo = CheckRepositoryImpl(db);
    await seedAccount('acc');
  });

  tearDown(() => db.close());

  group('installment transactions', () {
    test('are linked to their plan', () async {
      await seedPlan();
      await instRepo.payNextInstallment('plan');

      final tx = (await activeTxs()).single;
      expect(tx.sourceType, 'installment');
      expect(tx.sourceId, 'plan');
    });

    test('cannot be deleted from the activity list', () async {
      await seedPlan();
      await instRepo.payNextInstallment('plan');
      final tx = (await activeTxs()).single;

      final result = await txRepo.softDeleteTransaction(tx.id);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.message, contains('اقساط'));
      // Nothing changed: plan still paid once, money still gone, tx active.
      expect(await activeTxs(), hasLength(1));
      expect(await balanceOf('acc'), 1000000 - 100000);
      final plan = await db.select(db.installmentsTable).getSingle();
      expect(plan.paidInstallmentsCount, 1);
    });

    test('allow cosmetic edits but refuse amount changes', () async {
      await seedPlan();
      await instRepo.payNextInstallment('plan');
      final row = (await activeTxs()).single;
      final entity = (await txRepo.watchTransactionById(row.id).first)!;
      expect(entity.source, TransactionSource.installment);

      final renamed = await txRepo.updateTransaction(
        entity.copyWith(description: 'قسط وام مسکن', notes: 'یادداشت'),
      );
      expect(renamed.isSuccess, isTrue);

      final resized = await txRepo.updateTransaction(
        entity.copyWith(amount: const Money.fromMinor(1, Currency.toman)),
      );
      expect(resized.isFailure, isTrue);
      expect(await balanceOf('acc'), 1000000 - 100000);

      // The link survives an edit.
      final after = (await activeTxs()).single;
      expect(after.sourceType, 'installment');
      expect(after.description, 'قسط وام مسکن');
    });
  });

  group('check transactions', () {
    test('are linked and protected from deletion', () async {
      await seedCheck();
      await checkRepo.updateCheckStatus('chk', CheckStatus.cleared);

      final tx = (await activeTxs()).single;
      expect(tx.sourceType, 'check');
      expect(tx.sourceId, 'chk');

      final result = await txRepo.softDeleteTransaction(tx.id);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.message, contains('چک'));
      expect(await balanceOf('acc'), 1000000 + 250000);
    });

    test('clear → un-clear → clear brings the transaction back', () async {
      await seedCheck();
      await checkRepo.updateCheckStatus('chk', CheckStatus.cleared);
      await checkRepo.updateCheckStatus('chk', CheckStatus.pending);
      expect(await activeTxs(), isEmpty);
      expect(await balanceOf('acc'), 1000000);

      await checkRepo.updateCheckStatus('chk', CheckStatus.cleared);

      // Before the fix the upsert left deletedAt set: the money moved but
      // the transaction stayed invisible.
      expect(await activeTxs(), hasLength(1));
      expect(await balanceOf('acc'), 1000000 + 250000);
    });

    test(
      'a Rial check clears into a Toman account at the right amount',
      () async {
        await db
            .into(db.checksTable)
            .insert(
              ChecksTableCompanion.insert(
                id: 'chk-irr',
                checkNumber: '9',
                bankName: 'ملی',
                type: 'issued',
                amountMinor: 500000, // 500,000 Rial = 50,000 Toman
                currency: 'IRR',
                partyName: 'رضا',
                dueDate: 1,
                accountId: const Value('acc'),
                status: 'pending',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await checkRepo.updateCheckStatus('chk-irr', CheckStatus.cleared);
        expect(await balanceOf('acc'), 1000000 - 50000);
      },
    );
  });

  group('debt and goal transactions', () {
    test(
      'deleting a debt payment reverts the debt; undo re-applies it',
      () async {
        final debtRepo = DebtRepositoryImpl(db);
        final now = DateTime(2026, 1, 1);
        await debtRepo.createDebt(
          DebtEntity(
            id: 'debt',
            contactName: 'مریم',
            type: DebtType.debt,
            totalAmount: const Money.fromMinor(300000, Currency.toman),
            createdAt: now,
            updatedAt: now,
          ),
        );
        // What DebtBloc does on «پرداخت»: update the debt, then the ledger.
        await debtRepo.addPayment(
          'debt',
          const Money.fromMinor(300000, Currency.toman),
        );
        final created = await txRepo.createTransaction(
          TransactionEntity(
            id: 'tx-debt',
            accountId: 'acc',
            amount: const Money.fromMinor(300000, Currency.toman),
            type: TransactionType.debtPayment,
            date: now,
            description: 'پرداخت بدهی',
            createdAt: now,
            updatedAt: now,
            source: TransactionSource.debt,
            sourceId: 'debt',
          ),
        );
        expect(created.dataOrNull!.source, TransactionSource.debt);

        Future<DebtReceivableData> debt() =>
            db.select(db.debtsReceivablesTable).getSingle();
        expect((await debt()).status, 'settled');

        expect(
          (await txRepo.softDeleteTransaction('tx-debt')).isSuccess,
          isTrue,
        );
        expect((await debt()).paidAmountMinor, 0);
        expect((await debt()).status, 'active');
        expect(await balanceOf('acc'), 1000000);

        expect((await txRepo.restoreTransaction('tx-debt')).isSuccess, isTrue);
        expect((await debt()).paidAmountMinor, 300000);
        expect((await debt()).status, 'settled');
        expect(await balanceOf('acc'), 1000000 - 300000);
      },
    );

    test(
      'deleting a goal contribution takes it back out of the goal',
      () async {
        final goalRepo = GoalRepositoryImpl(db);
        final now = DateTime(2026, 1, 1);
        await goalRepo.createGoal(
          GoalEntity(
            id: 'goal',
            name: 'سفر',
            targetAmount: const Money.fromMinor(200000, Currency.toman),
            createdAt: now,
            updatedAt: now,
          ),
        );
        await goalRepo.contributeToGoal(
          'goal',
          const Money.fromMinor(200000, Currency.toman),
        );
        await txRepo.createTransaction(
          TransactionEntity(
            id: 'tx-goal',
            accountId: 'acc',
            amount: const Money.fromMinor(200000, Currency.toman),
            type: TransactionType.expense,
            date: now,
            description: 'پس‌انداز',
            createdAt: now,
            updatedAt: now,
            source: TransactionSource.goal,
            sourceId: 'goal',
          ),
        );
        Future<FinancialGoalData> goal() =>
            db.select(db.financialGoalsTable).getSingle();
        expect((await goal()).status, 'achieved');

        await txRepo.softDeleteTransaction('tx-goal');

        expect((await goal()).currentAmountMinor, 0);
        expect((await goal()).status, 'active');
      },
    );
  });

  test('recomputeBalances agrees with live balances after installments, '
      'checks and manual entries (Toman and Rial mixed)', () async {
    await seedPlan(currency: 'IRR');
    await instRepo.payNextInstallment('plan');
    await instRepo.payRemaining('plan');
    await seedCheck();
    await checkRepo.updateCheckStatus('chk', CheckStatus.cleared);
    final now = DateTime(2026, 2, 2);
    await txRepo.createTransaction(
      TransactionEntity(
        id: 'manual',
        accountId: 'acc',
        amount: const Money.fromMinor(12345, Currency.toman),
        type: TransactionType.expense,
        date: now,
        description: 'خرید',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final live = await balanceOf('acc');
    // 3 × 100,000 Rial = 30,000 Toman out; +250,000 check; −12,345 manual.
    expect(live, 1000000 - 30000 + 250000 - 12345);

    expect((await txRepo.recomputeBalances()).isSuccess, isTrue);
    expect(await balanceOf('acc'), live);
  });
}
