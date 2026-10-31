import '../../../../core/errors/result.dart';
import '../entities/installment_entity.dart';

abstract interface class InstallmentRepository {
  Stream<List<InstallmentEntity>> watchInstallments();
  Future<Result<List<InstallmentEntity>>> getInstallments();
  Future<Result<InstallmentEntity>> createInstallment(InstallmentEntity installment);
  Future<Result<void>> payNextInstallment(String id);
  Future<Result<void>> deleteInstallment(String id);
}
