import '../../../../core/errors/result.dart';
import '../entities/account_entity.dart';

abstract interface class AccountRepository {
  Stream<List<AccountEntity>> watchAccounts({bool includeArchived = false});
  Stream<AccountEntity?> watchAccountById(String id);
  Future<Result<List<AccountEntity>>> getAccounts({
    bool includeArchived = false,
  });
  Future<Result<AccountEntity>> createAccount(AccountEntity account);
  Future<Result<AccountEntity>> updateAccount(AccountEntity account);
  Future<Result<void>> archiveAccount(String id, bool archive);
  Future<Result<void>> deleteAccount(String id);
}
