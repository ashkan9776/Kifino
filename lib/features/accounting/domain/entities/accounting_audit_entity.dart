import 'package:equatable/equatable.dart';

enum AuditLogAction {
  create('create'),
  update('update'),
  approve('approve'),
  delete('delete');

  final String code;
  const AuditLogAction(this.code);

  static AuditLogAction fromCode(String code) => values.firstWhere(
    (a) => a.code == code,
    orElse: () => AuditLogAction.create,
  );
}

/// Immutable audit trail entry for accounting documents (Phase 1):
/// who-did-what is reduced to what-and-when because the app is single-user
/// offline — before/after JSON snapshots carry the substance.
class AccountingAuditLogEntity extends Equatable {
  final String id;
  final String entityType;
  final String entityId;
  final AuditLogAction action;
  final String? beforeJson;
  final String? afterJson;
  final String? description;
  final DateTime performedAt;

  const AccountingAuditLogEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.beforeJson,
    this.afterJson,
    this.description,
    required this.performedAt,
  });

  @override
  List<Object?> get props => [
    id,
    entityType,
    entityId,
    action,
    beforeJson,
    afterJson,
    description,
    performedAt,
  ];
}

/// تفصیلی شناور — a named analysis dimension (customers, projects, cost
/// centers). Documents tag one value per ledger; reports slice by value
/// without creating parallel accounts.
class DetailLedgerEntity extends Equatable {
  final String id;
  final String title;
  final String code;
  final bool isActive;
  final int sortOrder;

  const DetailLedgerEntity({
    required this.id,
    required this.title,
    required this.code,
    this.isActive = true,
    this.sortOrder = 0,
  });

  @override
  List<Object?> get props => [id, title, code, isActive, sortOrder];
}

class DetailValueEntity extends Equatable {
  final String id;
  final String ledgerId;
  final String title;
  final String? code;
  final bool isActive;

  const DetailValueEntity({
    required this.id,
    required this.ledgerId,
    required this.title,
    this.code,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, ledgerId, title, code, isActive];
}

class DetailLedgerWithValues extends Equatable {
  final DetailLedgerEntity ledger;
  final List<DetailValueEntity> values;

  const DetailLedgerWithValues({required this.ledger, required this.values});

  @override
  List<Object?> get props => [ledger, values];
}

/// One row of the تفصیلی شناور report: a transaction of a document tagged
/// with the selected detail value.
class DetailReportRow extends Equatable {
  final DateTime date;
  final int documentNumber;
  final String documentTitle;
  final String subjectName;
  final String description;
  final int debitMinorUnits;
  final int creditMinorUnits;
  final int runningBalanceMinorUnits; // debit positive, credit negative

  const DetailReportRow({
    required this.date,
    required this.documentNumber,
    required this.documentTitle,
    required this.subjectName,
    required this.description,
    required this.debitMinorUnits,
    required this.creditMinorUnits,
    required this.runningBalanceMinorUnits,
  });

  @override
  List<Object?> get props => [
    date,
    documentNumber,
    documentTitle,
    subjectName,
    description,
    debitMinorUnits,
    creditMinorUnits,
    runningBalanceMinorUnits,
  ];
}

class DetailReport extends Equatable {
  final DetailLedgerEntity ledger;
  final DetailValueEntity value;
  final List<DetailReportRow> rows;
  final int totalDebitMinorUnits;
  final int totalCreditMinorUnits;

  const DetailReport({
    required this.ledger,
    required this.value,
    required this.rows,
    required this.totalDebitMinorUnits,
    required this.totalCreditMinorUnits,
  });

  int get netMinorUnits => totalDebitMinorUnits - totalCreditMinorUnits;

  @override
  List<Object?> get props => [
    ledger,
    value,
    rows,
    totalDebitMinorUnits,
    totalCreditMinorUnits,
  ];
}

/// A detail tag applied to a document (one per ledger, max 10 ledgers).
class DocumentDetailTag extends Equatable {
  final String ledgerId;
  final String valueId;

  const DocumentDetailTag({required this.ledgerId, required this.valueId});

  @override
  List<Object?> get props => [ledgerId, valueId];
}
