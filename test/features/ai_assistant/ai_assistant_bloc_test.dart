import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kifino/features/settings/domain/services/settings_service.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/ai_assistant/domain/entities/parsed_transaction_draft.dart';
import 'package:kifino/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:kifino/features/ai_assistant/presentation/bloc/ai_assistant_event.dart';
import 'package:kifino/features/ai_assistant/presentation/bloc/ai_assistant_state.dart';
import 'package:kifino/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:kifino/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:kifino/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl txRepo;
  late AccountRepositoryImpl accRepo;
  late BudgetRepositoryImpl budgetRepo;
  late DebtRepositoryImpl debtRepo;
  late SettingsService settingsService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    txRepo = TransactionRepositoryImpl(db);
    accRepo = AccountRepositoryImpl(db);
    budgetRepo = BudgetRepositoryImpl(db);
    debtRepo = DebtRepositoryImpl(db);

    SharedPreferences.setMockInitialValues({
      'pref_currency_key': 'TOMAN', // base currency for the NLP parser
    });
    final prefs = await SharedPreferences.getInstance();
    settingsService = SettingsService(prefs);

    // Seed default account
    await accRepo.createAccount(
      AccountEntity(
        id: 'acc-1',
        name: 'حساب اصلی',
        type: AccountType.bankCard,
        currency: Currency.irr,
        initialBalance: const Money(
          minorUnits: 100000000,
          currency: Currency.irr,
        ),
        currentBalance: const Money(
          minorUnits: 100000000,
          currency: Currency.irr,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('AiAssistantBloc Tests', () {
    blocTest<AiAssistantBloc, AiAssistantState>(
      'loads financial context on AiAssistantContextRefreshed',
      build: () => AiAssistantBloc(
        transactionRepository: txRepo,
        accountRepository: accRepo,
        budgetRepository: budgetRepo,
        debtRepository: debtRepo,
        settingsService: settingsService,
        replyDelay: Duration.zero,
      ),
      act: (bloc) => bloc.add(const AiAssistantContextRefreshed()),
      expect: () => [
        predicate<AiAssistantState>((state) => state.summary != null),
      ],
    );

    blocTest<AiAssistantBloc, AiAssistantState>(
      'parses transaction message into draft and responds with draft confirmation card',
      build: () => AiAssistantBloc(
        transactionRepository: txRepo,
        accountRepository: accRepo,
        budgetRepository: budgetRepo,
        debtRepository: debtRepo,
        settingsService: settingsService,
        replyDelay: Duration.zero,
      ),
      act: (bloc) => bloc.add(
        const AiAssistantQuerySubmitted(
          'خرید سوپرمارکت ۳۰۰ هزار تومان',
          isPersian: true,
        ),
      ),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        predicate<AiAssistantState>((state) => state.isLoading == true),
        predicate<AiAssistantState>((state) {
          return state.isLoading == false &&
              state.messages.any((m) => m.draftTransaction != null);
        }),
      ],
    );

    blocTest<AiAssistantBloc, AiAssistantState>(
      'creates transaction when AiAssistantDraftConfirmed is added',
      build: () => AiAssistantBloc(
        transactionRepository: txRepo,
        accountRepository: accRepo,
        budgetRepository: budgetRepo,
        debtRepository: debtRepo,
        settingsService: settingsService,
        replyDelay: Duration.zero,
      ),
      act: (bloc) => bloc.add(
        AiAssistantDraftConfirmed(
          draft: ParsedTransactionDraft(
            originalText: 'شام ۲۰۰ هزار تومان',
            description: 'شام رستوران',
            amount: const Money(minorUnits: 2000000, currency: Currency.irr),
            type: TransactionType.expense,
            suggestedCategory: 'خوراک و غذا',
            date: DateTime.now(),
            confidence: 0.9,
          ),
          accountId: 'acc-1',
        ),
      ),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        predicate<AiAssistantState>((state) => state.isLoading == true),
        predicate<AiAssistantState>(
          (state) =>
              state.isLoading == false &&
              state.transactionCreatedSuccessfully == true,
        ),
      ],
      verify: (_) async {
        final txsRes = await txRepo.getRecentTransactions(limit: 10);
        final txs = txsRes.dataOrNull ?? [];
        expect(txs.length, equals(1));
        expect(txs.first.amount.minorUnits, equals(2000000));
      },
    );
  });
}
