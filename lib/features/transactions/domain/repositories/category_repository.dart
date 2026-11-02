import '../../../../core/errors/result.dart';
import '../entities/category_entity.dart';

abstract interface class CategoryRepository {
  Stream<List<CategoryEntity>> watchCategories({
    CategoryType? type,
    bool? isBusiness,
  });
  Future<Result<List<CategoryEntity>>> getCategories({
    CategoryType? type,
    bool? isBusiness,
  });
  Future<Result<CategoryEntity>> createCategory(CategoryEntity category);
  Future<Result<CategoryEntity>> updateCategory(CategoryEntity category);

  /// Soft-deletes a category. Transactions referencing it become
  /// uncategorized (categoryId → null) so no financial data is ever lost.
  Future<Result<void>> deleteCategory(String id);

  Future<Result<void>> seedDefaultCategoriesIfEmpty();

  /// Number of non-deleted transactions using this category.
  Future<int> countTransactionsUsing(String categoryId);
}
