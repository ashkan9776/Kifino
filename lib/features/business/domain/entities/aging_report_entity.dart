import 'package:equatable/equatable.dart';

/// One contact row of the aging report (گزارش سنی مطالبات/بدهی‌ها):
/// open invoices bucketed by how many days PAST DUE they are.
class ContactAgingEntry extends Equatable {
  final String contactId;
  final String contactName;
  /// Not yet due (dueDate today or in the future).
  final int currentMinor;
  /// 1–30 days past due.
  final int days1To30Minor;
  /// 31–60 days past due.
  final int days31To60Minor;
  /// 61–90 days past due.
  final int days61To90Minor;
  /// More than 90 days past due.
  final int days90PlusMinor;

  const ContactAgingEntry({
    required this.contactId,
    required this.contactName,
    this.currentMinor = 0,
    this.days1To30Minor = 0,
    this.days31To60Minor = 0,
    this.days61To90Minor = 0,
    this.days90PlusMinor = 0,
  });

  int get totalMinor =>
      currentMinor +
      days1To30Minor +
      days31To60Minor +
      days61To90Minor +
      days90PlusMinor;

  ContactAgingEntry addBucket({
    required int daysPastDue,
    required int amountMinor,
  }) {
    if (daysPastDue <= 0) {
      return _copy(currentMinor: currentMinor + amountMinor);
    } else if (daysPastDue <= 30) {
      return _copy(days1To30Minor: days1To30Minor + amountMinor);
    } else if (daysPastDue <= 60) {
      return _copy(days31To60Minor: days31To60Minor + amountMinor);
    } else if (daysPastDue <= 90) {
      return _copy(days61To90Minor: days61To90Minor + amountMinor);
    }
    return _copy(days90PlusMinor: days90PlusMinor + amountMinor);
  }

  ContactAgingEntry _copy({
    int? currentMinor,
    int? days1To30Minor,
    int? days31To60Minor,
    int? days61To90Minor,
    int? days90PlusMinor,
  }) {
    return ContactAgingEntry(
      contactId: contactId,
      contactName: contactName,
      currentMinor: currentMinor ?? this.currentMinor,
      days1To30Minor: days1To30Minor ?? this.days1To30Minor,
      days31To60Minor: days31To60Minor ?? this.days31To60Minor,
      days61To90Minor: days61To90Minor ?? this.days61To90Minor,
      days90PlusMinor: days90PlusMinor ?? this.days90PlusMinor,
    );
  }

  @override
  List<Object?> get props => [
        contactId,
        contactName,
        currentMinor,
        days1To30Minor,
        days31To60Minor,
        days61To90Minor,
        days90PlusMinor,
      ];
}
