import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  CategoryRepositoryImpl(this._db);

  CategoryEntity _toEntity(CategoryData data) {
    return CategoryEntity(
      id: data.id,
      name: data.name,
      type: CategoryType.fromCode(data.type),
      iconCodePoint: data.iconCodePoint,
      iconFontFamily: data.iconFontFamily,
      colorHex: data.colorHex,
      parentId: data.parentId,
      isBusiness: data.isBusiness,
      sortOrder: data.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
    );
  }

  @override
  Stream<List<CategoryEntity>> watchCategories({
    CategoryType? type,
    bool? isBusiness,
  }) {
    final query = _db.select(_db.categoriesTable)
      ..where((tbl) {
        var predicate = tbl.deletedAt.isNull();
        if (type != null) {
          predicate = predicate & tbl.type.equals(type.code);
        }
        if (isBusiness != null) {
          predicate = predicate & tbl.isBusiness.equals(isBusiness);
        }
        return predicate;
      })
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.sortOrder, mode: OrderingMode.asc),
      ]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Result<List<CategoryEntity>>> getCategories({
    CategoryType? type,
    bool? isBusiness,
  }) async {
    try {
      final query = _db.select(_db.categoriesTable)
        ..where((tbl) {
          var predicate = tbl.deletedAt.isNull();
          if (type != null) {
            predicate = predicate & tbl.type.equals(type.code);
          }
          if (isBusiness != null) {
            predicate = predicate & tbl.isBusiness.equals(isBusiness);
          }
          return predicate;
        })
        ..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.sortOrder, mode: OrderingMode.asc),
        ]);

      final rows = await query.get();
      return Success(rows.map(_toEntity).toList());
    } catch (e) {
      return DatabaseFailure('خواندن دسته‌ها انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<CategoryEntity>> createCategory(CategoryEntity category) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final companion = CategoriesTableCompanion.insert(
        id: category.id.isEmpty ? _uuid.v4() : category.id,
        name: category.name,
        type: category.type.code,
        iconCodePoint: category.iconCodePoint,
        iconFontFamily: Value(category.iconFontFamily),
        colorHex: category.colorHex,
        parentId: Value(category.parentId),
        isBusiness: Value(category.isBusiness),
        sortOrder: Value(category.sortOrder),
        createdAt: now,
        updatedAt: now,
      );

      await _db.into(_db.categoriesTable).insert(companion);
      final created = await (_db.select(
        _db.categoriesTable,
      )..where((t) => t.id.equals(companion.id.value))).getSingle();
      return Success(_toEntity(created));
    } catch (e) {
      return DatabaseFailure('ساخت دسته انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<CategoryEntity>> updateCategory(CategoryEntity category) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.categoriesTable,
      )..where((tbl) => tbl.id.equals(category.id))).write(
        CategoriesTableCompanion(
          name: Value(category.name),
          iconCodePoint: Value(category.iconCodePoint),
          colorHex: Value(category.colorHex),
          updatedAt: Value(now),
          syncStatus: const Value(1),
        ),
      );
      final updated = await (_db.select(
        _db.categoriesTable,
      )..where((tbl) => tbl.id.equals(category.id))).getSingle();
      return Success(_toEntity(updated));
    } catch (e) {
      return DatabaseFailure('ویرایش دسته انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteCategory(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        // Transactions survive: they just become uncategorized. No financial
        // data is ever deleted along with a category.
        await (_db.update(_db.transactionsTable)
              ..where((tbl) => tbl.categoryId.equals(id)))
            .write(const TransactionsTableCompanion(categoryId: Value(null)));

        await (_db.update(
          _db.categoriesTable,
        )..where((tbl) => tbl.id.equals(id))).write(
          CategoriesTableCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value(3),
          ),
        );

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'categories',
                entityId: id,
                operation: 'DELETE',
                payloadJson: '{"id":"$id"}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف دسته انجام نشد.').asFailure();
    }
  }

  @override
  Future<int> countTransactionsUsing(String categoryId) async {
    final rows =
        await (_db.select(_db.transactionsTable)..where(
              (tbl) =>
                  tbl.categoryId.equals(categoryId) & tbl.deletedAt.isNull(),
            ))
            .get();
    return rows.length;
  }

  @override
  Future<Result<void>> seedDefaultCategoriesIfEmpty() async {
    try {
      final count = await _db.categoriesTable.count().getSingle();
      if (count == 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final defaults = [
          // Expenses
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'خوراک و غذا',
            type: 'expense',
            iconCodePoint: Icons.restaurant_rounded.codePoint,
            colorHex: '#EF4444',
            sortOrder: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'حمل و نقل',
            type: 'expense',
            iconCodePoint: Icons.directions_car_rounded.codePoint,
            colorHex: '#F59E0B',
            sortOrder: const Value(2),
            createdAt: now,
            updatedAt: now,
          ),
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'کافه و سرگرمی',
            type: 'expense',
            iconCodePoint: Icons.coffee_rounded.codePoint,
            colorHex: '#8B5CF6',
            sortOrder: const Value(3),
            createdAt: now,
            updatedAt: now,
          ),
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'خرید و بازار',
            type: 'expense',
            iconCodePoint: Icons.shopping_bag_rounded.codePoint,
            colorHex: '#EC4899',
            sortOrder: const Value(4),
            createdAt: now,
            updatedAt: now,
          ),
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'مسکن و قبوض',
            type: 'expense',
            iconCodePoint: Icons.home_rounded.codePoint,
            colorHex: '#3B82F6',
            sortOrder: const Value(5),
            createdAt: now,
            updatedAt: now,
          ),
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'سلامت و درمان',
            type: 'expense',
            iconCodePoint: Icons.medical_services_rounded.codePoint,
            colorHex: '#10B981',
            sortOrder: const Value(6),
            createdAt: now,
            updatedAt: now,
          ),
          // Incomes
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'حقوق و دستمزد',
            type: 'income',
            iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
            colorHex: '#10B981',
            sortOrder: const Value(10),
            createdAt: now,
            updatedAt: now,
          ),
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'پروژه و فریلنس',
            type: 'income',
            iconCodePoint: Icons.computer_rounded.codePoint,
            colorHex: '#6366F1',
            sortOrder: const Value(11),
            createdAt: now,
            updatedAt: now,
          ),
          CategoriesTableCompanion.insert(
            id: _uuid.v4(),
            name: 'سرمایه‌گذاری',
            type: 'income',
            iconCodePoint: Icons.trending_up_rounded.codePoint,
            colorHex: '#059669',
            sortOrder: const Value(12),
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await _db.batch((batch) {
          batch.insertAll(_db.categoriesTable, defaults);
        });
      }
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('آماده‌سازی دسته‌ها انجام نشد.').asFailure();
    }
  }
}
