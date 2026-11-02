import 'package:equatable/equatable.dart';

import '../../../../core/utils/text_normalizer.dart';

enum AccountingSubjectType {
  debtor('debtor'),
  creditor('creditor'),
  both('both');

  final String code;
  const AccountingSubjectType(this.code);

  static AccountingSubjectType fromCode(String code) {
    return AccountingSubjectType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AccountingSubjectType.both,
    );
  }

  String get titleFa => switch (this) {
    AccountingSubjectType.debtor => 'ماهیت بدهکار',
    AccountingSubjectType.creditor => 'ماهیت بستانکار',
    AccountingSubjectType.both => 'دوگانه / شناور',
  };
}

enum AccountingSubjectLevel {
  group('group'),
  kol('kol'),
  moein('moein'),
  tafsili('tafsili');

  final String code;
  const AccountingSubjectLevel(this.code);

  static AccountingSubjectLevel fromCode(String code) {
    return AccountingSubjectLevel.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AccountingSubjectLevel.kol,
    );
  }

  static AccountingSubjectLevel fromSubjectCode(String code) {
    final clean = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length <= 1) return AccountingSubjectLevel.group;
    if (clean.length <= 3) return AccountingSubjectLevel.kol;
    if (clean.length <= 6) return AccountingSubjectLevel.moein;
    return AccountingSubjectLevel.tafsili;
  }

  String get titleFa => switch (this) {
    AccountingSubjectLevel.group => 'گروه حساب',
    AccountingSubjectLevel.kol => 'حساب کل',
    AccountingSubjectLevel.moein => 'حساب معین',
    AccountingSubjectLevel.tafsili => 'حساب تفصیلی',
  };
}

class AccountingSubjectEntity extends Equatable {
  final String id;
  final String code;
  final String name;
  final String? parentId;
  final AccountingSubjectType type;
  final AccountingSubjectLevel level;
  final bool isPermanent;
  final String? fiscalYearId;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountingSubjectEntity({
    required this.id,
    required this.code,
    required this.name,
    this.parentId,
    this.type = AccountingSubjectType.both,
    required this.level,
    this.isPermanent = true,
    this.fiscalYearId,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Format code into segmented standard format e.g. 011/001 or 011/001/001
  String get formattedCode {
    final clean = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length <= 3) return TextNormalizer.auto(clean);
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i += 3) {
      final end = (i + 3 < clean.length) ? i + 3 : clean.length;
      if (i > 0) buffer.write('/');
      buffer.write(clean.substring(i, end));
    }
    return TextNormalizer.auto(buffer.toString());
  }

  String get formattedName => '$formattedCode - $name';

  AccountingSubjectEntity copyWith({
    String? id,
    String? code,
    String? name,
    String? parentId,
    AccountingSubjectType? type,
    AccountingSubjectLevel? level,
    bool? isPermanent,
    String? fiscalYearId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountingSubjectEntity(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      level: level ?? this.level,
      isPermanent: isPermanent ?? this.isPermanent,
      fiscalYearId: fiscalYearId ?? this.fiscalYearId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    parentId,
    type,
    level,
    isPermanent,
    fiscalYearId,
    description,
  ];
}
