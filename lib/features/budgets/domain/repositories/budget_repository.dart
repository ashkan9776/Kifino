import '../../../../core/errors/result.dart';
import '../entities/budget_entity.dart';

abstract interface class BudgetRepository {
  Stream<List<BudgetEntity>> watchActiveBudgets({DateTime? forDate});
  Future<Result<List<BudgetEntity>>> getActiveBudgets({DateTime? forDate});
  Future<Result<BudgetEntity>> createBudget(BudgetEntity budget);
  Future<Result<BudgetEntity>> updateBudget(BudgetEntity budget);
  Future<Result<void>> deleteBudget(String id);
}
