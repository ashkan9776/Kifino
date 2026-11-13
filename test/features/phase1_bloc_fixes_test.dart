import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/constants/app_currency.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_document_entity.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_transaction_entity.dart';
import 'package:kifino/features/accounting/presentation/bloc/accounting_document_bloc.dart';
import 'package:kifino/features/assets/data/repositories/asset_repository_impl.dart';
import 'package:kifino/features/assets/domain/entities/asset_entity.dart';
import 'package:kifino/features/assets/presentation/bloc/asset_bloc.dart';
import 'package:kifino/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:kifino/features/budgets/presentation/bloc/budget_bloc.dart';
import 'package:kifino/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:kifino/features/debts/domain/entities/debt_entity.dart';
import 'package:kifino/features/debts/presentation/bloc/debt_bloc.dart';
import 'package:kifino/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:kifino/features/goals/domain/entities/goal_entity.dart';
import 'package:kifino/features/goals/presentation/bloc/goal_bloc.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';
import 'package:kifino/features/installments/presentation/bloc/installment_bloc.dart';
import 'package:kifino/features/notifications/domain/services/notification_service.dart';

void main() {
  late AppDatabase db;
  late NotificationService notifications;

  setUp(() async {
    AppCurrency.set(Currency.toman);
    db = AppDatabase(NativeDatabase.memory());
    notifications = NotificationService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 1.2 & 1.3 — BLoC state preservation & AppCurrency.base', () {
    test('InstallmentBloc keeps InstallmentLoaded on success & failure, normalizes to AppCurrency.base', () async {
      final repo = InstallmentRepositoryImpl(db);
      final bloc = InstallmentBloc(repo, notifications);
      addTearDown(bloc.close);

      final now = DateTime.now();
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: 'acc-1',
              name: 'بانک',
              type: 'bankCard',
              currency: 'TOMAN',
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
            ),
          );

      bloc.add(const WatchInstallmentsStarted());
      await bloc.stream.firstWhere((s) => s is InstallmentLoaded);

      // 1,000,000 IRR = 100,000 TOMAN per installment; 10 remaining = 1,000,000 TOMAN
      await repo.createInstallment(
        InstallmentEntity(
          id: 'inst-irr',
          title: 'وام ریالی',
          accountId: 'acc-1',
          totalAmount: const Money(
            minorUnits: 10000000,
            currency: Currency.irr,
          ),
          numberOfInstallments: 10,
          installmentAmount: const Money(
            minorUnits: 1000000,
            currency: Currency.irr,
          ),
          startDate: now,
          nextDueDate: now.add(const Duration(days: 30)),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final loaded = await bloc.stream.firstWhere(
        (s) => s is InstallmentLoaded && s.installments.isNotEmpty,
      ) as InstallmentLoaded;

      expect(loaded.totalDebtRemaining.currency, equals(Currency.toman));
      expect(loaded.totalDebtRemaining.minorUnits, equals(1000000));
      expect(loaded.monthlyInstallmentDues.minorUnits, equals(100000));

      // Action success emits InstallmentOperationSuccess which MUST extend InstallmentLoaded
      bloc.add(const InstallmentPaySubmitted('inst-irr'));
      final opState = await bloc.stream.firstWhere(
        (s) => s is InstallmentOperationSuccess,
      );
      expect(opState, isA<InstallmentLoaded>());
      expect((opState as InstallmentLoaded).installments, isNotEmpty);

      // Failure must emit InstallmentFailure and immediately restore InstallmentLoaded
      final emitted = <InstallmentState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(const InstallmentPaySubmitted('does-not-exist'));
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emitted.any((s) => s is InstallmentFailure), isTrue);
      expect(bloc.state, isA<InstallmentLoaded>());
      expect((bloc.state as InstallmentLoaded).installments, isNotEmpty);
    });

    test('GoalBloc keeps GoalLoaded on create/contribute/delete/failure & normalizes to AppCurrency.base', () async {
      final repo = GoalRepositoryImpl(db);
      final bloc = GoalBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const WatchGoalsStarted());
      await bloc.stream.firstWhere((s) => s is GoalLoaded);

      final now = DateTime.now();
      bloc.add(
        GoalCreateSubmitted(
          GoalEntity(
            id: 'g-1',
            name: 'هدف سفر',
            targetAmount: const Money(
              minorUnits: 20000000,
              currency: Currency.irr,
            ), // 2M Toman
            currentAmount: const Money(
              minorUnits: 5000000,
              currency: Currency.irr,
            ), // 500k Toman
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );

      final successState = await bloc.stream.firstWhere(
        (s) => s is GoalOperationSuccess,
      ) as GoalOperationSuccess;
      expect(successState, isA<GoalLoaded>());
      expect(successState.totalTarget.currency, equals(Currency.toman));
      expect(successState.totalTarget.minorUnits, equals(2000000));
      expect(successState.totalSaved.minorUnits, equals(500000));

      // Failure preserves loaded list
      final emitted = <GoalState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(
        const GoalContributeSubmitted(
          'non-existent-goal',
          Money(minorUnits: 1000, currency: Currency.toman),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emitted.any((s) => s is GoalFailure), isTrue);
      expect(bloc.state, isA<GoalLoaded>());
      expect((bloc.state as GoalLoaded).goals, isNotEmpty);
    });

    test('DebtBloc & AssetBloc compute totals in AppCurrency.base and preserve state on failure', () async {
      final debtRepo = DebtRepositoryImpl(db);
      final debtBloc = DebtBloc(debtRepo, notifications);
      addTearDown(debtBloc.close);

      final now = DateTime.now();
      debtBloc.add(const WatchDebtsStarted());
      await debtBloc.stream.firstWhere((s) => s is DebtLoaded);

      await debtRepo.createDebt(
        DebtEntity(
          id: 'd-irr',
          contactName: 'بستانکار',
          type: DebtType.debt,
          totalAmount: const Money(
            minorUnits: 5000000,
            currency: Currency.irr,
          ), // 500k Toman
          createdAt: now,
          updatedAt: now,
        ),
      );
      await debtRepo.createDebt(
        DebtEntity(
          id: 'd-usd',
          contactName: 'ارزی',
          type: DebtType.receivable,
          totalAmount: const Money(minorUnits: 10000, currency: Currency.usd),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final debtLoaded = await debtBloc.stream.firstWhere(
        (s) => s is DebtLoaded && s.debts.length == 2,
      ) as DebtLoaded;
      expect(debtLoaded.totalDebtRemaining.currency, equals(Currency.toman));
      expect(debtLoaded.totalDebtRemaining.minorUnits, equals(500000));
      // Foreign USD ignored in Toman summary totals
      expect(debtLoaded.totalReceivableRemaining.minorUnits, equals(0));

      // Payment failure preserves DebtLoaded
      debtBloc.add(
        const DebtPaymentSubmitted(
          id: 'non-existent',
          amount: Money(minorUnits: 1000, currency: Currency.toman),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(debtBloc.state, isA<DebtLoaded>());

      // AssetBloc
      final assetRepo = AssetRepositoryImpl(db);
      final assetBloc = AssetBloc(assetRepo);
      addTearDown(assetBloc.close);

      assetBloc.add(const WatchAssetsStarted());
      await assetBloc.stream.firstWhere((s) => s is AssetLoaded);

      await assetRepo.createAsset(
        AssetEntity(
          id: 'a-1',
          name: 'طلا',
          category: AssetCategory.gold,
          quantity: 1,
          unit: 'گرم',
          costBasis: const Money(
            minorUnits: 40000000,
            currency: Currency.irr,
          ), // 4M Toman
          currentValue: const Money(
            minorUnits: 45000000,
            currency: Currency.irr,
          ), // 4.5M Toman
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await assetRepo.createAsset(
        AssetEntity(
          id: 'a-usd',
          name: 'ارز',
          category: AssetCategory.currency,
          quantity: 100,
          unit: 'USD',
          costBasis: const Money(minorUnits: 10000, currency: Currency.usd),
          currentValue: const Money(minorUnits: 12000, currency: Currency.usd),
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final assetLoaded = await assetBloc.stream.firstWhere(
        (s) => s is AssetLoaded && s.assets.length == 2,
      ) as AssetLoaded;
      expect(assetLoaded.totalCostBasis.currency, equals(Currency.toman));
      expect(assetLoaded.totalCostBasis.minorUnits, equals(4000000));
      expect(assetLoaded.totalCurrentValuation.minorUnits, equals(4500000));
      expect(assetLoaded.totalProfitLoss.minorUnits, equals(500000));

      // Valuation error preserves AssetLoaded
      assetBloc.add(
        const AssetValuationUpdated(
          id: 'non-existent',
          currentValue: Money(minorUnits: 100, currency: Currency.toman),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(assetBloc.state, isA<AssetLoaded>());

      // BudgetBloc failure preserves BudgetLoaded
      final budgetRepo = BudgetRepositoryImpl(db);
      final budgetBloc = BudgetBloc(budgetRepo);
      addTearDown(budgetBloc.close);
      budgetBloc.add(const WatchBudgetsStarted());
      await budgetBloc.stream.firstWhere((s) => s is BudgetLoaded);
      budgetBloc.add(const BudgetDeleteSubmitted('non-existent'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(budgetBloc.state, isA<BudgetLoaded>());
    });
  });

  group('Phase 1.4 — AccountingDocumentBloc filter preservation', () {
    test(
      'preserves active status and date filters after create, approve, delete',
      () async {
        final repo = AccountingRepositoryImpl(db);
        await repo.seedChartOfAccountsIfNotExists();
        final cashId = (await repo.getSubjectByCode('011'))!.id;
        final salesId = (await repo.getSubjectByCode('060'))!.id;
        final bloc = AccountingDocumentBloc(repo);
        addTearDown(bloc.close);

        final startFilter = DateTime(2026, 1, 1);
        final endFilter = DateTime(2027, 12, 31);
        final docDate = DateTime.now();

        bloc.add(
          LoadAccountingDocuments(
            startDate: startFilter,
            endDate: endFilter,
            status: DocumentStatus.draft,
          ),
        );
        final initialLoaded = await bloc.stream.firstWhere(
          (s) => s is AccountingDocumentLoaded,
        ) as AccountingDocumentLoaded;
        expect(initialLoaded.status, equals(DocumentStatus.draft));
        expect(initialLoaded.startDate, equals(startFilter));
        expect(initialLoaded.endDate, equals(endFilter));

        // Create draft doc -> reload MUST keep draft status & date range
        bloc.add(
          CreateAccountingDocumentSubmitted(
            AccountingDocumentEntity(
              id: 'doc-draft-1',
              number: 0,
              date: docDate,
              title: 'سند پیش‌نویس',
              status: DocumentStatus.draft,
              createdAt: docDate,
              updatedAt: docDate,
              transactions: [
                AccountingTransactionEntity(
                  id: '',
                  documentId: '',
                  subjectId: cashId,
                  debit: const Money(
                    minorUnits: 50000,
                    currency: Currency.toman,
                  ),
                  credit: const Money.zero(),
                  description: 'د',
                  rowOrder: 1,
                  createdAt: docDate,
                  updatedAt: docDate,
                ),
                AccountingTransactionEntity(
                  id: '',
                  documentId: '',
                  subjectId: salesId,
                  debit: const Money.zero(),
                  credit: const Money(
                    minorUnits: 50000,
                    currency: Currency.toman,
                  ),
                  description: 'ب',
                  rowOrder: 2,
                  createdAt: docDate,
                  updatedAt: docDate,
                ),
              ],
            ),
          ),
        );

        final afterCreate = await bloc.stream.firstWhere(
          (s) => s is AccountingDocumentLoaded,
        ) as AccountingDocumentLoaded;
        expect(afterCreate.status, equals(DocumentStatus.draft));
        expect(afterCreate.startDate, equals(startFilter));
        expect(afterCreate.endDate, equals(endFilter));
        expect(afterCreate.documents.length, equals(1));

        // Approve doc -> reload MUST keep draft filter (now empty list since it's approved!)
        bloc.add(
          ApproveAccountingDocumentSubmitted(afterCreate.documents.first.id),
        );
        final afterApprove = await bloc.stream.firstWhere(
          (s) => s is AccountingDocumentLoaded,
        ) as AccountingDocumentLoaded;
        expect(afterApprove.status, equals(DocumentStatus.draft));
        expect(afterApprove.startDate, equals(startFilter));
        expect(afterApprove.documents, isEmpty);

        // Delete doc -> reload MUST keep filters
        bloc.add(
          DeleteAccountingDocumentSubmitted(afterCreate.documents.first.id),
        );
        final afterDelete = await bloc.stream.firstWhere(
          (s) => s is AccountingDocumentLoaded,
        ) as AccountingDocumentLoaded;
        expect(afterDelete.status, equals(DocumentStatus.draft));
        expect(afterDelete.endDate, equals(endFilter));
      },
    );
  });
}
