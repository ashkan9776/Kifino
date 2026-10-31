import 'package:equatable/equatable.dart';
import '../../../../core/utils/money.dart';

enum TransactionType {
  income('income', 'درآمد', 'Income'),
  expense('expense', 'هزینه', 'Expense'),
  transfer('transfer', 'انتقال', 'Transfer'),
  debtPayment('debtPayment', 'پرداخت بدهی', 'Debt Payment'),
  receivablePayment('receivablePayment', 'دریافت طلب', 'Receivable Payment'),
  adjustment('adjustment', 'اصلاح موجودی', 'Adjustment');

  final String code;
  final String titleFa;
  final String titleEn;

  const TransactionType(this.code, this.titleFa, this.titleEn);

  static TransactionType fromCode(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return TransactionType.expense;
  }
}

class TransactionEntity extends Equatable {
  final String id;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final Money amount;
  final TransactionType type;
  final DateTime date;
  final String description;
  final String? notes;
  final bool isBusiness;
  final String? attachmentUri;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncStatus;
  final int version;

  // Joined presentation data (optional)
  final String? accountName;
  final String? destinationAccountName;
  final String? categoryName;
  final int? categoryIconCodePoint;
  final String? categoryColorHex;

  const TransactionEntity({
    required this.id,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    required this.description,
    this.notes,
    this.isBusiness = false,
    this.attachmentUri,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = 0,
    this.version = 1,
    this.accountName,
    this.destinationAccountName,
    this.categoryName,
    this.categoryIconCodePoint,
    this.categoryColorHex,
  });

  bool get isDeleted => deletedAt != null;

  TransactionEntity copyWith({
    String? id,
    String? accountId,
    String? destinationAccountId,
    String? categoryId,
    Money? amount,
    TransactionType? type,
    DateTime? date,
    String? description,
    String? notes,
    bool? isBusiness,
    String? attachmentUri,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncStatus,
    int? version,
    String? accountName,
    String? destinationAccountName,
    String? categoryName,
    int? categoryIconCodePoint,
    String? categoryColorHex,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      isBusiness: isBusiness ?? this.isBusiness,
      attachmentUri: attachmentUri ?? this.attachmentUri,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
      accountName: accountName ?? this.accountName,
      destinationAccountName: destinationAccountName ?? this.destinationAccountName,
      categoryName: categoryName ?? this.categoryName,
      categoryIconCodePoint: categoryIconCodePoint ?? this.categoryIconCodePoint,
      categoryColorHex: categoryColorHex ?? this.categoryColorHex,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountId,
        destinationAccountId,
        categoryId,
        amount,
        type,
        date,
        description,
        notes,
        isBusiness,
        attachmentUri,
        createdAt,
        updatedAt,
        deletedAt,
        syncStatus,
        version,
      ];
}
