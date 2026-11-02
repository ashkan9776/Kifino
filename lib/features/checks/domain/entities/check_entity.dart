import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum CheckType {
  issued('issued', 'چک صادره (پرداختی)'),
  received('received', 'چک دریافتی');

  final String code;
  final String titleFa;
  const CheckType(this.code, this.titleFa);

  static CheckType fromCode(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return CheckType.issued;
  }
}

enum CheckStatus {
  pending('pending', 'در انتظار وصول'),
  cleared('cleared', 'پاس شده'),
  bounced('bounced', 'برگشت خورده'),
  cancelled('cancelled', 'باطل شده'),
  transferred('transferred', 'خرج شده / واگذار شده');

  final String code;
  final String titleFa;
  const CheckStatus(this.code, this.titleFa);

  static CheckStatus fromCode(String code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return CheckStatus.pending;
  }
}

class CheckEntity extends Equatable {
  final String id;
  final String checkNumber;
  final String? sayadiId;
  final String bankName;
  final CheckType type;
  final Money amount;
  final String partyName;
  final DateTime dueDate;
  final String? accountId;
  final CheckStatus status;
  final String? frontImagePath;
  final String? backImagePath;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const CheckEntity({
    required this.id,
    required this.checkNumber,
    this.sayadiId,
    required this.bankName,
    required this.type,
    required this.amount,
    required this.partyName,
    required this.dueDate,
    this.accountId,
    this.status = CheckStatus.pending,
    this.frontImagePath,
    this.backImagePath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isCleared => status == CheckStatus.cleared;
  bool get isBounced => status == CheckStatus.bounced;
  bool get isPending => status == CheckStatus.pending;

  bool get isOverdue {
    if (!isPending) return false;
    return DateTime.now().isAfter(dueDate);
  }

  bool get isDeleted => deletedAt != null;

  CheckEntity copyWith({
    String? id,
    String? checkNumber,
    String? sayadiId,
    String? bankName,
    CheckType? type,
    Money? amount,
    String? partyName,
    DateTime? dueDate,
    String? accountId,
    CheckStatus? status,
    String? frontImagePath,
    String? backImagePath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return CheckEntity(
      id: id ?? this.id,
      checkNumber: checkNumber ?? this.checkNumber,
      sayadiId: sayadiId ?? this.sayadiId,
      bankName: bankName ?? this.bankName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      partyName: partyName ?? this.partyName,
      dueDate: dueDate ?? this.dueDate,
      accountId: accountId ?? this.accountId,
      status: status ?? this.status,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    checkNumber,
    sayadiId,
    bankName,
    type,
    amount,
    partyName,
    dueDate,
    accountId,
    status,
    frontImagePath,
    backImagePath,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
