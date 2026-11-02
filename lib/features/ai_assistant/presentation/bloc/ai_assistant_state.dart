import 'package:equatable/equatable.dart';

import '../../domain/entities/parsed_transaction_draft.dart';
import '../../domain/services/financial_context_provider.dart';

class AiChatMessage extends Equatable {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ParsedTransactionDraft? draftTransaction;

  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.draftTransaction,
  });

  @override
  List<Object?> get props => [id, text, isUser, timestamp, draftTransaction];
}

class AiAssistantState extends Equatable {
  final List<AiChatMessage> messages;
  final bool isLoading;
  final FinancialContextSummary? summary;
  final String? errorMessage;
  final bool transactionCreatedSuccessfully;

  const AiAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.summary,
    this.errorMessage,
    this.transactionCreatedSuccessfully = false,
  });

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    FinancialContextSummary? summary,
    String? errorMessage,
    bool? transactionCreatedSuccessfully,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
      transactionCreatedSuccessfully: transactionCreatedSuccessfully ?? false,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    isLoading,
    summary,
    errorMessage,
    transactionCreatedSuccessfully,
  ];
}
