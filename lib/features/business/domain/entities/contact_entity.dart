import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum ContactType {
  customer('customer'),
  supplier('supplier'),
  both('both');

  final String code;
  const ContactType(this.code);

  static ContactType fromCode(String code) {
    return ContactType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ContactType.customer,
    );
  }

  String get titleFa => switch (this) {
    ContactType.customer => 'مشتری',
    ContactType.supplier => 'تأمین‌کننده',
    ContactType.both => 'مشتری و تأمین‌کننده',
  };
}

class ContactEntity extends Equatable {
  final String id;
  final String name;
  final String? companyName;
  final ContactType type;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final Money outstandingBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const ContactEntity({
    required this.id,
    required this.name,
    this.companyName,
    required this.type,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    required this.outstandingBalance,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  ContactEntity copyWith({
    String? id,
    String? name,
    String? companyName,
    ContactType? type,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    Money? outstandingBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    companyName,
    type,
    phone,
    email,
    address,
    taxNumber,
    outstandingBalance,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
