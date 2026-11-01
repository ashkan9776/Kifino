import '../../../../core/errors/result.dart';
import '../entities/installment_entity.dart';
import '../entities/installment_payment_entity.dart';

abstract interface class InstallmentRepository {
  Stream<List<InstallmentEntity>> watchInstallments();
  Future<Result<List<InstallmentEntity>>> getInstallments();
  Future<Result<InstallmentEntity>> createInstallment(InstallmentEntity installment);
  Future<Result<void>> payNextInstallment(String id);

  /// Pays ALL remaining installments at once (تسویه زودهنگام).
  Future<Result<void>> payRemaining(String id);

  /// Edits the plan fields of an installment (title, amounts, count, dates).
  /// Past payments are never touched.
  Future<Result<void>> updateInstallment(InstallmentEntity installment);

  /// Payment history for one installment, newest first.
  Future<List<InstallmentPaymentEntity>> getPaymentHistory(String installmentId);

  /// Deletes a payment and fully reverts it: money returns to the linked
  /// account, the linked ledger transaction is soft-deleted, the paid count
  /// and next due date are recomputed.
  Future<Result<void>> deletePayment(String paymentId);

  Future<Result<void>> deleteInstallment(String id);
}
