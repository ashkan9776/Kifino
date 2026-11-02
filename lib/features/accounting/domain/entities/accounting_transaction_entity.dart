import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import 'accounting_subject_entity.dart';

class AccountingTransactionEntity extends Equatable {
  final String id;
  final String documentId;
  final String subjectId;
  final AccountingSubjectEntity? subject;
  final String? detailSubjectId;
  final String? detailSubjectName;
  final Money debit;
  final Money credit;
  final String description;
  final int rowOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountingTransactionEntity({
    required this.id,
    required this.documentId,
    required this.subjectId,
    this.subject,
    this.detailSubjectId,
    this.detailSubjectName,
    required this.debit,
    required this.credit,
    required this.description,
    this.rowOrder = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDebit => debit.minorUnits > 0;
  bool get isCredit => credit.minorUnits > 0;

  AccountingTransactionEntity copyWith({
    String? id,
    String? documentId,
    String? subjectId,
    AccountingSubjectEntity? subject,
    String? detailSubjectId,
    String? detailSubjectName,
    Money? debit,
    Money? credit,
    String? description,
    int? rowOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountingTransactionEntity(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      subjectId: subjectId ?? this.subjectId,
      subject: subject ?? this.subject,
      detailSubjectId: detailSubjectId ?? this.detailSubjectId,
      detailSubjectName: detailSubjectName ?? this.detailSubjectName,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      description: description ?? this.description,
      rowOrder: rowOrder ?? this.rowOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    documentId,
    subjectId,
    subject,
    detailSubjectId,
    detailSubjectName,
    debit,
    credit,
    description,
    rowOrder,
  ];
}
