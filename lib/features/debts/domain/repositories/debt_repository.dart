import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../entities/debt_entity.dart';

abstract interface class DebtRepository {
  Stream<List<DebtEntity>> watchDebts({DebtType? type});
  Future<Result<List<DebtEntity>>> getDebts({DebtType? type});
  Future<Result<DebtEntity>> createDebt(DebtEntity debt);
  Future<Result<void>> addPayment(String id, Money paymentAmount);
  Future<Result<void>> updateDebt(DebtEntity debt);

  Future<Result<void>> updateDebtStatus(String id, DebtStatus status);
  Future<Result<void>> deleteDebt(String id);
}
