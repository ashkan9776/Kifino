import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/app/localization/app_localizations.dart';
import 'package:kifino/core/constants/app_currency.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/errors/result.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/core/widgets/optional_account_selector.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:kifino/features/debts/domain/entities/debt_entity.dart';
import 'package:kifino/features/debts/presentation/bloc/debt_bloc.dart';
import 'package:kifino/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:kifino/features/goals/domain/entities/goal_entity.dart';
import 'package:kifino/features/goals/presentation/bloc/goal_bloc.dart';
import 'package:kifino/features/notifications/domain/services/notification_service.dart';
import 'package:kifino/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  late AppDatabase db;
  late NotificationService notifications;
  late AccountRepositoryImpl accountRepo;
  late TransactionRepositoryImpl txRepo;

  setUp(() async {
    AppCurrency.set(Currency.toman);
    db = AppDatabase(NativeDatabase.memory());
    notifications = NotificationService(db: db);
    accountRepo = AccountRepositoryImpl(db);
    txRepo = TransactionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<AccountEntity> insertAccount({
    required String id,
    required String name,
    required int balanceMinor,
    Currency currency = Currency.toman,
    bool isArchived = false,
  }) async {
    final now = DateTime.now();
    final entity = AccountEntity(
      id: id,
      name: name,
      type: AccountType.bankCard,
      currency: currency,
      initialBalance: Money.fromMinor(balanceMinor, currency),
      currentBalance: Money.fromMinor(balanceMinor, currency),
      isArchived: isArchived,
      createdAt: now,
      updatedAt: now,
    );
    final res = await accountRepo.createAccount(entity);
    return res.dataOrNull!;
  }

  Future<AccountEntity> getAccountById(String id) async {
    final accounts = (await accountRepo.getAccounts()).dataOrNull!;
    return accounts.firstWhere((a) => a.id == id);
  }

  group('Phase 4.2 — Debt & Goal Account Balance Integration', () {
    test('paying a debt with accountId creates debtPayment tx and deducts account balance (verified via recomputeBalances)', () async {
      final account = await insertAccount(
        id: 'acc-debt-pay',
        name: 'کارت ملت',
        balanceMinor: 1000000,
      );
      final debtRepo = DebtRepositoryImpl(db);
      final now = DateTime.now();
      await debtRepo.createDebt(
        DebtEntity(
          id: 'debt-1',
          contactName: 'احمد',
          type: DebtType.debt,
          totalAmount: const Money.fromMinor(400000, Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final bloc = DebtBloc(
        debtRepo,
        notifications,
        transactionRepository: txRepo,
      );
      addTearDown(bloc.close);

      bloc.add(const WatchDebtsStarted());
      await bloc.stream.firstWhere((s) => s is DebtLoaded);

      bloc.add(
        const DebtPaymentSubmitted(
          id: 'debt-1',
          amount: Money.fromMinor(150000, Currency.toman),
          accountId: 'acc-debt-pay',
        ),
      );

      await bloc.stream.firstWhere(
        (s) =>
            s is DebtLoaded &&
            s.debts.any(
              (d) => d.id == 'debt-1' && d.paidAmount.minorUnits == 150000,
            ),
      );
      // Let trailing transaction creation settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final accAfter = await getAccountById(account.id);
      expect(accAfter.currentBalance.minorUnits, equals(850000));

      final txs = (await txRepo.getRecentTransactions(limit: 10)).dataOrNull!;
      expect(txs.length, equals(1));
      expect(txs.first.type, equals(TransactionType.debtPayment));
      expect(txs.first.amount.minorUnits, equals(150000));
      expect(txs.first.accountId, equals('acc-debt-pay'));

      await txRepo.recomputeBalances();
      final accRecomputed = await getAccountById(account.id);
      expect(accRecomputed.currentBalance.minorUnits, equals(850000));
    });

    test('collecting a receivable with accountId creates receivablePayment tx and credits account balance', () async {
      final account = await insertAccount(
        id: 'acc-rec-pay',
        name: 'کارت سامان',
        balanceMinor: 500000,
      );
      final debtRepo = DebtRepositoryImpl(db);
      final now = DateTime.now();
      await debtRepo.createDebt(
        DebtEntity(
          id: 'rec-1',
          contactName: 'سارا',
          type: DebtType.receivable,
          totalAmount: const Money.fromMinor(300000, Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final bloc = DebtBloc(
        debtRepo,
        notifications,
        transactionRepository: txRepo,
      );
      addTearDown(bloc.close);

      bloc.add(const WatchDebtsStarted());
      await bloc.stream.firstWhere((s) => s is DebtLoaded);

      bloc.add(
        const DebtPaymentSubmitted(
          id: 'rec-1',
          amount: Money.fromMinor(200000, Currency.toman),
          accountId: 'acc-rec-pay',
        ),
      );

      await bloc.stream.firstWhere(
        (s) =>
            s is DebtLoaded &&
            s.debts.any(
              (d) => d.id == 'rec-1' && d.paidAmount.minorUnits == 200000,
            ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final accAfter = await getAccountById(account.id);
      expect(accAfter.currentBalance.minorUnits, equals(700000));

      final txs = (await txRepo.getRecentTransactions(limit: 10)).dataOrNull!;
      expect(txs.length, equals(1));
      expect(txs.first.type, equals(TransactionType.receivablePayment));
      expect(txs.first.amount.minorUnits, equals(200000));

      await txRepo.recomputeBalances();
      final accRecomputed = await getAccountById(account.id);
      expect(accRecomputed.currentBalance.minorUnits, equals(700000));
    });

    test('paying a debt with accountId == null leaves bank balance untouched and creates no transaction', () async {
      final account = await insertAccount(
        id: 'acc-unchanged',
        name: 'حساب اصلی',
        balanceMinor: 1000000,
      );
      final debtRepo = DebtRepositoryImpl(db);
      final now = DateTime.now();
      await debtRepo.createDebt(
        DebtEntity(
          id: 'debt-no-acc',
          contactName: 'علی',
          type: DebtType.debt,
          totalAmount: const Money.fromMinor(200000, Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final bloc = DebtBloc(
        debtRepo,
        notifications,
        transactionRepository: txRepo,
      );
      addTearDown(bloc.close);

      bloc.add(const WatchDebtsStarted());
      await bloc.stream.firstWhere((s) => s is DebtLoaded);

      bloc.add(
        const DebtPaymentSubmitted(
          id: 'debt-no-acc',
          amount: Money.fromMinor(100000, Currency.toman),
        ),
      );

      await bloc.stream.firstWhere(
        (s) =>
            s is DebtLoaded &&
            s.debts.any(
              (d) => d.id == 'debt-no-acc' && d.paidAmount.minorUnits == 100000,
            ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final accAfter = await getAccountById(account.id);
      expect(accAfter.currentBalance.minorUnits, equals(1000000));
      final txs = (await txRepo.getRecentTransactions(limit: 10)).dataOrNull!;
      expect(txs, isEmpty);
    });

    test('contributing to a goal with accountId creates expense tx and deducts account balance', () async {
      final account = await insertAccount(
        id: 'acc-goal',
        name: 'کارت بلوبانک',
        balanceMinor: 2000000,
      );
      final goalRepo = GoalRepositoryImpl(db);
      final now = DateTime.now();
      await goalRepo.createGoal(
        GoalEntity(
          id: 'goal-1',
          name: 'خرید لپ‌تاپ',
          targetAmount: const Money.fromMinor(5000000, Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final bloc = GoalBloc(goalRepo, transactionRepository: txRepo);
      addTearDown(bloc.close);

      bloc.add(const WatchGoalsStarted());
      await bloc.stream.firstWhere((s) => s is GoalLoaded);

      bloc.add(
        const GoalContributeSubmitted(
          'goal-1',
          Money.fromMinor(500000, Currency.toman),
          accountId: 'acc-goal',
        ),
      );

      await bloc.stream.firstWhere((s) => s is GoalOperationSuccess);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final accAfter = await getAccountById(account.id);
      expect(accAfter.currentBalance.minorUnits, equals(1500000));

      final txs = (await txRepo.getRecentTransactions(limit: 10)).dataOrNull!;
      expect(txs.length, equals(1));
      expect(txs.first.type, equals(TransactionType.expense));
      expect(txs.first.amount.minorUnits, equals(500000));
      expect(txs.first.description, contains('خرید لپ‌تاپ'));

      await txRepo.recomputeBalances();
      final accRecomputed = await getAccountById(account.id);
      expect(accRecomputed.currentBalance.minorUnits, equals(1500000));
    });

    test('contributing to a goal with accountId == null leaves bank balance untouched', () async {
      final account = await insertAccount(
        id: 'acc-goal-none',
        name: 'کارت ملی',
        balanceMinor: 900000,
      );
      final goalRepo = GoalRepositoryImpl(db);
      final now = DateTime.now();
      await goalRepo.createGoal(
        GoalEntity(
          id: 'goal-2',
          name: 'صندوق اضطراری',
          targetAmount: const Money.fromMinor(1000000, Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final bloc = GoalBloc(goalRepo, transactionRepository: txRepo);
      addTearDown(bloc.close);

      bloc.add(const WatchGoalsStarted());
      await bloc.stream.firstWhere((s) => s is GoalLoaded);

      bloc.add(
        const GoalContributeSubmitted(
          'goal-2',
          Money.fromMinor(300000, Currency.toman),
        ),
      );

      await bloc.stream.firstWhere((s) => s is GoalOperationSuccess);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final accAfter = await getAccountById(account.id);
      expect(accAfter.currentBalance.minorUnits, equals(900000));
      final txs = (await txRepo.getRecentTransactions(limit: 10)).dataOrNull!;
      expect(txs, isEmpty);
    });

    testWidgets(
      'OptionalAccountSelector shows no-change option + compatible active accounts only',
      (tester) async {
        final now = DateTime.now();
        final accounts = [
          AccountEntity(
            id: 'a-toman',
            name: 'بانک ملت',
            type: AccountType.bankCard,
            currency: Currency.toman,
            initialBalance: const Money.fromMinor(100000, Currency.toman),
            currentBalance: const Money.fromMinor(100000, Currency.toman),
            createdAt: now,
            updatedAt: now,
          ),
          AccountEntity(
            id: 'a-usd',
            name: 'حساب دلاری',
            type: AccountType.savings,
            currency: Currency.usd,
            initialBalance: const Money.fromMinor(10000, Currency.usd),
            currentBalance: const Money.fromMinor(10000, Currency.usd),
            createdAt: now,
            updatedAt: now,
          ),
          AccountEntity(
            id: 'a-arch',
            name: 'حساب بایگانی',
            type: AccountType.bankCard,
            currency: Currency.toman,
            initialBalance: const Money.fromMinor(50000, Currency.toman),
            currentBalance: const Money.fromMinor(50000, Currency.toman),
            isArchived: true,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fa'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: OptionalAccountSelector(
                accountsFuture: Future.value(Success(accounts)),
                compatibleCurrency: Currency.toman,
                selectedAccountId: selected,
                label: 'برداشت از حساب (اختیاری)',
                onChanged: (val) => selected = val,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('بدون تغییر موجودی حساب'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();

        expect(find.textContaining('بانک ملت').last, findsOneWidget);
        expect(find.textContaining('حساب دلاری'), findsNothing);
        expect(find.textContaining('حساب بایگانی'), findsNothing);

        await tester.tap(find.textContaining('بانک ملت').last);
        await tester.pumpAndSettle();
        expect(selected, equals('a-toman'));
      },
    );
  });
}
