import '../../../../core/errors/result.dart';
import '../entities/category_entity.dart';

abstract interface class CategoryRepository {
  Stream<List<CategoryEntity>> watchCategories({CategoryType? type, bool? isBusiness});
  Future<Result<List<CategoryEntity>>> getCategories({CategoryType? type, bool? isBusiness});
  Future<Result<CategoryEntity>> createCategory(CategoryEntity category);
  Future<Result<void>> seedDefaultCategoriesIfEmpty();
}
