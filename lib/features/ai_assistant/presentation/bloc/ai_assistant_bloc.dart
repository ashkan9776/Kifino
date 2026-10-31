import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../../debts/domain/repositories/debt_repository.dart';
import '../../../settings/domain/services/settings_service.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../domain/services/financial_context_provider.dart';
import '../../domain/services/persian_nlp_transaction_parser.dart';
import '../../domain/services/rule_based_financial_advisor.dart';
import 'ai_assistant_event.dart';
import 'ai_assistant_state.dart';

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;
  final BudgetRepository budgetRepository;
  final DebtRepository debtRepository;
  final SettingsService settingsService;
  final Uuid _uuid = const Uuid();

  /// Small pause before the bot answers so the typing indicator is visible.
  /// Tests pass [Duration.zero].
  final Duration replyDelay;

  AiAssistantBloc({
    required this.transactionRepository,
    required this.accountRepository,
    required this.budgetRepository,
    required this.debtRepository,
    required this.settingsService,
    this.replyDelay = const Duration(milliseconds: 450),
  })  : super(AiAssistantState(
          messages: [
            AiChatMessage(
              id: 'init-1',
              text: 'سلام! من دستیار هوشمند مالی کیفینو هستم. می‌توانید وضعیت مالتان را از من بپرسید، یا تراکنش‌های روزمره را با متن بنویسید تا سریعا ثبت کنم.',
              isUser: false,
              timestamp: DateTime(2026),
            ),
          ],
        )) {
    on<AiAssistantQuerySubmitted>(_onQuerySubmitted);
    on<AiAssistantDraftConfirmed>(_onDraftConfirmed);
    on<AiAssistantContextRefreshed>(_onContextRefreshed);
  }

  /// The currency the whole ledger speaks — from user settings, not hardcoded.
  Currency get _baseCurrency =>
      Currency.fromCode(settingsService.loadCurrencyCode());

  Future<FinancialContextSummary> _loadSummary() async {
    final accsRes = await accountRepository.getAccounts();
    final txsRes = await transactionRepository.getRecentTransactions(limit: 200);
    final budsRes = await budgetRepository.getActiveBudgets();
    final debtsRes = await debtRepository.getDebts();

    return FinancialContextProvider.buildSummary(
      accounts: accsRes.dataOrNull ?? [],
      transactions: txsRes.dataOrNull ?? [],
      budgets: budsRes.dataOrNull ?? [],
      debts: debtsRes.dataOrNull ?? [],
    );
  }

  Future<void> _onContextRefreshed(
    AiAssistantContextRefreshed event,
    Emitter<AiAssistantState> emit,
  ) async {
    final summary = await _loadSummary();
    emit(state.copyWith(summary: summary));
  }

  Future<void> _onQuerySubmitted(
    AiAssistantQuerySubmitted event,
    Emitter<AiAssistantState> emit,
  ) async {
    final userMsg = AiChatMessage(
      id: _uuid.v4(),
      text: event.query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    emit(state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    ));

    final summary = await _loadSummary();
    if (replyDelay > Duration.zero) {
      await Future.delayed(replyDelay);
    }

    // 1. Try parsing as a transaction draft — normalized to the base currency
    // so "۴۵ هزار تومن" and "۴۵۰,۰۰۰ ریال" land as the SAME amount.
    final draft = PersianNlpTransactionParser.parse(
      event.query,
      targetCurrency: _baseCurrency,
    );
    if (draft != null && draft.amount.minorUnits > 0) {
      final botMsg = AiChatMessage(
        id: _uuid.v4(),
        text: event.isPersian
            ? 'پیش‌نویس تراکنش بر اساس پیام شما آماده شد. حساب مورد نظر را انتخاب و تایید کنید:'
            : 'Draft transaction extracted. Please confirm to record:',
        isUser: false,
        timestamp: DateTime.now(),
        draftTransaction: draft,
      );

      emit(state.copyWith(
        messages: [...state.messages, botMsg],
        isLoading: false,
        summary: summary,
      ));
      return;
    }

    // 2. Otherwise treat as financial inquiry
    // auto() guarantees Persian digits in the composed report regardless of
    // how each number was stringified ( mixed-text rule).
    final answer = TextNormalizer.auto(
      RuleBasedFinancialAdvisor.answerQuery(
        query: event.query,
        context: summary,
        isPersian: event.isPersian,
      ),
    );

    final botMsg = AiChatMessage(
      id: _uuid.v4(),
      text: answer,
      isUser: false,
      timestamp: DateTime.now(),
    );

    emit(state.copyWith(
      messages: [...state.messages, botMsg],
      isLoading: false,
      summary: summary,
    ));
  }

  Future<void> _onDraftConfirmed(
    AiAssistantDraftConfirmed event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    final draft = event.draft;
    final now = DateTime.now();

    // Align the amount to the SELECTED ACCOUNT's currency so balances never
    // mix units. Toman↔Rial conversion is exact (×10); anything else is
    // rejected honestly instead of corrupting the ledger.
    Money amount = draft.amount;
    final accountsResult = await accountRepository.getAccounts();
    AccountEntity? account;
    for (final a in accountsResult.dataOrNull ?? const <AccountEntity>[]) {
      if (a.id == event.accountId) {
        account = a;
        break;
      }
    }

    if (account != null && account.currency != amount.currency) {
      final amountIsIranian =
          amount.currency == Currency.irr || amount.currency == Currency.toman;
      final accountIsIranian = account.currency == Currency.irr ||
          account.currency == Currency.toman;
      if (amountIsIranian && accountIsIranian) {
        amount = amount.toTomanOrRial();
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'ارز تراکنش (${amount.currency.displayName}) با ارز حساب «${account.name}» (${account.currency.displayName}) سازگار نیست.',
        ));
        return;
      }
    }

    final tx = TransactionEntity(
      id: _uuid.v4(),
      accountId: event.accountId,
      amount: amount,
      type: draft.type,
      date: draft.date,
      description: draft.description,
      createdAt: now,
      updatedAt: now,
    );

    final result = await transactionRepository.createTransaction(tx);
    final summary = await _loadSummary();

    result.fold(
      onSuccess: (_) {
        final successMsg = AiChatMessage(
          id: _uuid.v4(),
          text: TextNormalizer.auto(
            '✅ تراکنش «${draft.description}» به مبلغ ${amount.formatted} با موفقیت در حساب شما ثبت شد.',
          ),
          isUser: false,
          timestamp: DateTime.now(),
        );

        emit(state.copyWith(
          messages: [...state.messages, successMsg],
          isLoading: false,
          summary: summary,
          transactionCreatedSuccessfully: true,
        ));
      },
      onFailure: (failure) {
        emit(state.copyWith(
          errorMessage: failure.message,
          isLoading: false,
        ));
      },
    );
  }
}
