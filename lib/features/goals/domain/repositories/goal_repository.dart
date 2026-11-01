import '../../../../core/errors/result.dart';
import '../entities/goal_entity.dart';
import '../../../../core/utils/money.dart';

abstract interface class GoalRepository {
  Stream<List<GoalEntity>> watchGoals();
  Future<Result<GoalEntity>> createGoal(GoalEntity goal);
  Future<Result<GoalEntity>> contributeToGoal(String id, Money amount);
  Future<Result<void>> updateGoal(GoalEntity goal);

  Future<Result<void>> deleteGoal(String id);
}
