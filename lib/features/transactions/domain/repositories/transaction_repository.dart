import '../../../../core/errors/result.dart';
import '../entities/transaction_entity.dart';

abstract interface class TransactionRepository {
  Stream<List<TransactionEntity>> watchTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    String? categoryId,
    bool? isBusiness,
    int? limit,
    int? offset,
  });

  Stream<TransactionEntity?> watchTransactionById(String id);

  Future<Result<TransactionEntity>> createTransaction(TransactionEntity transaction);
  Future<Result<TransactionEntity>> updateTransaction(TransactionEntity transaction);
  Future<Result<void>> softDeleteTransaction(String id);
  Future<Result<void>> restoreTransaction(String id);

  Future<Result<List<TransactionEntity>>> getRecentTransactions({int limit = 10});
}
