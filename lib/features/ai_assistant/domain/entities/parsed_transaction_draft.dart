import 'package:equatable/equatable.dart';
import '../../../../core/utils/money.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class ParsedTransactionDraft extends Equatable {
  final String originalText;
  final String description;
  final Money amount;
  final TransactionType type;
  final String? suggestedCategory;
  final DateTime date;
  final double confidence;

  const ParsedTransactionDraft({
    required this.originalText,
    required this.description,
    required this.amount,
    required this.type,
    this.suggestedCategory,
    required this.date,
    required this.confidence,
  });

  @override
  List<Object?> get props => [
        originalText,
        description,
        amount,
        type,
        suggestedCategory,
        date,
        confidence,
      ];
}
