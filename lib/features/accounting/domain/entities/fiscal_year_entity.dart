import 'package:equatable/equatable.dart';

class FiscalYearEntity extends Equatable {
  final String id;
  final String title;
  final int yearNumber;
  final DateTime startDate;
  final DateTime endDate;
  final bool isClosed;
  final bool isActive;
  final String? openingDocumentId;
  final String? closingDocumentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FiscalYearEntity({
    required this.id,
    required this.title,
    required this.yearNumber,
    required this.startDate,
    required this.endDate,
    this.isClosed = false,
    this.isActive = true,
    this.openingDocumentId,
    this.closingDocumentId,
    required this.createdAt,
    required this.updatedAt,
  });

  FiscalYearEntity copyWith({
    String? id,
    String? title,
    int? yearNumber,
    DateTime? startDate,
    DateTime? endDate,
    bool? isClosed,
    bool? isActive,
    String? openingDocumentId,
    String? closingDocumentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FiscalYearEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      yearNumber: yearNumber ?? this.yearNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isClosed: isClosed ?? this.isClosed,
      isActive: isActive ?? this.isActive,
      openingDocumentId: openingDocumentId ?? this.openingDocumentId,
      closingDocumentId: closingDocumentId ?? this.closingDocumentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        yearNumber,
        startDate,
        endDate,
        isClosed,
        isActive,
        openingDocumentId,
        closingDocumentId,
      ];
}
