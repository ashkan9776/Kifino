import 'package:equatable/equatable.dart';

/// One recorded payment of an installment plan (Phase 3 rework). Used for
/// payment history, review and correction (deleting a wrong payment reverts
/// money, ledger rows and the paid counter).
class InstallmentPaymentEntity extends Equatable {
  final String id;
  final String installmentId;
  final int amountMinor;
  final int installmentIndex; // which قسط (1-based)
  final String? ledgerTransactionId;
  final String? notes;
  final DateTime paidAt;

  const InstallmentPaymentEntity({
    required this.id,
    required this.installmentId,
    required this.amountMinor,
    required this.installmentIndex,
    this.ledgerTransactionId,
    this.notes,
    required this.paidAt,
  });

  @override
  List<Object?> get props => [
        id, installmentId, amountMinor, installmentIndex,
        ledgerTransactionId, notes, paidAt,
      ];
}
