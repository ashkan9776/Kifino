import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

enum InvoiceType {
  sale('sale'),
  purchase('purchase'),
  quote('quote');

  final String code;
  const InvoiceType(this.code);

  static InvoiceType fromCode(String code) {
    return InvoiceType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => InvoiceType.sale,
    );
  }

  String get titleFa => switch (this) {
    InvoiceType.sale => 'فاکتور فروش',
    InvoiceType.purchase => 'فاکتور خرید',
    InvoiceType.quote => 'پیش‌فاکتور',
  };
}

enum InvoiceStatus {
  draft('draft'),
  sent('sent'),
  partiallyPaid('partiallyPaid'),
  paid('paid'),
  overdue('overdue'),
  cancelled('cancelled');

  final String code;
  const InvoiceStatus(this.code);

  static InvoiceStatus fromCode(String code) {
    return InvoiceStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => InvoiceStatus.draft,
    );
  }

  String get titleFa => switch (this) {
    InvoiceStatus.draft => 'پیش‌نویس',
    InvoiceStatus.sent => 'ارسال شده',
    InvoiceStatus.partiallyPaid => 'پرداخت ناقص',
    InvoiceStatus.paid => 'تسویه شده',
    InvoiceStatus.overdue => 'سررسید گذشته',
    InvoiceStatus.cancelled => 'لغو شده',
  };
}

class InvoiceItemEntity extends Equatable {
  final String id;
  final String invoiceId;
  final String? productId;
  final String description;
  final double quantity;
  final Money unitPrice;
  final Money discount;
  final Money tax;
  final Money total;

  const InvoiceItemEntity({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.tax,
    required this.total,
  });

  factory InvoiceItemEntity.calculate({
    required String id,
    required String invoiceId,
    String? productId,
    required String description,
    required double quantity,
    required Money unitPrice,
    Money? discount,
    double taxRate = 0.0, // e.g. 0.10 for 10% VAT
  }) {
    final cur = unitPrice.currency;
    final grossMinor = (unitPrice.minorUnits * quantity).round();
    final discountMinor = discount?.minorUnits ?? 0;
    final taxableMinor = (grossMinor - discountMinor).clamp(
      0,
      double.maxFinite.toInt(),
    );
    final taxMinor = (taxableMinor * taxRate).round();
    final totalMinor = taxableMinor + taxMinor;

    return InvoiceItemEntity(
      id: id,
      invoiceId: invoiceId,
      productId: productId,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      discount: discount ?? Money.zero(cur),
      tax: Money.fromMinor(taxMinor, cur),
      total: Money.fromMinor(totalMinor, cur),
    );
  }

  @override
  List<Object?> get props => [
    id,
    invoiceId,
    productId,
    description,
    quantity,
    unitPrice,
    discount,
    tax,
    total,
  ];
}

class InvoiceEntity extends Equatable {
  final String id;
  final String invoiceNumber;
  final String contactId;
  final String? contactName;
  final InvoiceType type;
  final InvoiceStatus status;
  final DateTime issueDate;
  final DateTime dueDate;
  final Money subtotal;
  final Money discount;
  final Money tax;
  final Money total;
  final Money paidAmount;
  final String? notes;
  final String? terms;
  final List<InvoiceItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const InvoiceEntity({
    required this.id,
    required this.invoiceNumber,
    required this.contactId,
    this.contactName,
    required this.type,
    required this.status,
    required this.issueDate,
    required this.dueDate,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
    this.notes,
    this.terms,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Money get remainingBalance => total - paidAmount;
  bool get isFullyPaid => paidAmount >= total && total.minorUnits > 0;
  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) &&
      !isFullyPaid &&
      status != InvoiceStatus.cancelled;

  InvoiceEntity copyWith({
    String? id,
    String? invoiceNumber,
    String? contactId,
    String? contactName,
    InvoiceType? type,
    InvoiceStatus? status,
    DateTime? issueDate,
    DateTime? dueDate,
    Money? subtotal,
    Money? discount,
    Money? tax,
    Money? total,
    Money? paidAmount,
    String? notes,
    String? terms,
    List<InvoiceItemEntity>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return InvoiceEntity(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      type: type ?? this.type,
      status: status ?? this.status,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    contactId,
    contactName,
    type,
    status,
    issueDate,
    dueDate,
    subtotal,
    discount,
    tax,
    total,
    paidAmount,
    notes,
    terms,
    items,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
