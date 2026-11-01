import '../../../../core/errors/result.dart';
import '../entities/check_entity.dart';

abstract interface class CheckRepository {
  Stream<List<CheckEntity>> watchChecks({CheckType? type});
  Future<Result<List<CheckEntity>>> getChecks({CheckType? type});
  Future<Result<CheckEntity>> createCheck(CheckEntity check);
  Future<Result<void>> updateCheck(CheckEntity check);

  Future<Result<void>> updateCheckStatus(String id, CheckStatus status);
  Future<Result<void>> deleteCheck(String id);
}
