import 'package:equatable/equatable.dart';

enum CategoryType {
  income('income', 'درآمد'),
  expense('expense', 'هزینه');

  final String code;
  final String titleFa;
  const CategoryType(this.code, this.titleFa);

  static CategoryType fromCode(String code) {
    return code == 'income' ? CategoryType.income : CategoryType.expense;
  }
}

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final CategoryType type;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String colorHex;
  final String? parentId;
  final bool isBusiness;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    this.iconFontFamily,
    required this.colorHex,
    this.parentId,
    this.isBusiness = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        iconCodePoint,
        iconFontFamily,
        colorHex,
        parentId,
        isBusiness,
        sortOrder,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
