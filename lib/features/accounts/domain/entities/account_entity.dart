import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum AccountType {
  bankCard('bankCard', 'کارت بانکی', 'Bank Card'),
  cashWallet('cashWallet', 'کیف پول نقدی', 'Cash Wallet'),
  savings('savings', 'سپرده پس‌انداز', 'Savings'),
  credit('credit', 'کارت اعتباری', 'Credit Card'),
  investment('investment', 'سرمایه‌گذاری', 'Investment'),
  crypto('crypto', 'رمزارز', 'Crypto');

  final String code;
  final String titleFa;
  final String titleEn;

  const AccountType(this.code, this.titleFa, this.titleEn);

  static AccountType fromCode(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return AccountType.bankCard;
  }
}

class AccountEntity extends Equatable {
  final String id;
  final String name;
  final AccountType type;
  final Currency currency;
  final Money initialBalance;
  final Money currentBalance;
  final String? cardNumberLastFour;
  final String? bankName;
  final String? colorHex;
  final String? iconName;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncStatus;
  final int version;

  const AccountEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalance,
    required this.currentBalance,
    this.cardNumberLastFour,
    this.bankName,
    this.colorHex,
    this.iconName,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = 0,
    this.version = 1,
  });

  bool get isDeleted => deletedAt != null;

  AccountEntity copyWith({
    String? id,
    String? name,
    AccountType? type,
    Currency? currency,
    Money? initialBalance,
    Money? currentBalance,
    String? cardNumberLastFour,
    String? bankName,
    String? colorHex,
    String? iconName,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncStatus,
    int? version,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      cardNumberLastFour: cardNumberLastFour ?? this.cardNumberLastFour,
      bankName: bankName ?? this.bankName,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    currency,
    initialBalance,
    currentBalance,
    cardNumberLastFour,
    bankName,
    colorHex,
    iconName,
    isArchived,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
