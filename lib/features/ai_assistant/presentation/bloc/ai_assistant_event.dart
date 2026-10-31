import 'package:equatable/equatable.dart';
import '../../domain/entities/parsed_transaction_draft.dart';

sealed class AiAssistantEvent extends Equatable {
  const AiAssistantEvent();

  @override
  List<Object?> get props => [];
}

final class AiAssistantQuerySubmitted extends AiAssistantEvent {
  final String query;
  final bool isPersian;

  const AiAssistantQuerySubmitted(this.query, {this.isPersian = true});

  @override
  List<Object?> get props => [query, isPersian];
}

final class AiAssistantDraftConfirmed extends AiAssistantEvent {
  final ParsedTransactionDraft draft;
  final String accountId;

  const AiAssistantDraftConfirmed({
    required this.draft,
    required this.accountId,
  });

  @override
  List<Object?> get props => [draft, accountId];
}

final class AiAssistantContextRefreshed extends AiAssistantEvent {
  const AiAssistantContextRefreshed();
}
