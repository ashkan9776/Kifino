import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/repositories/asset_repository.dart';

class AssetRepositoryImpl implements AssetRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  AssetRepositoryImpl(this._db);

  AssetEntity _toEntity(AssetData data) {
    final currency = Currency.fromCode(data.currency);
    return AssetEntity(
      id: data.id,
      name: data.name,
      category: AssetCategory.fromCode(data.category),
      quantity: data.quantity,
      unit: data.unit,
      costBasis: Money.fromMinor(data.costBasisMinor, currency),
      currentValue: Money.fromMinor(data.currentValueMinor, currency),
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(data.purchaseDate),
      notes: data.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!) : null,
    );
  }

  @override
  Stream<List<AssetEntity>> watchAssets({AssetCategory? category}) {
    final query = _db.select(_db.assetsTable)
      ..where((tbl) {
        Expression<bool> predicate = tbl.deletedAt.isNull();
        if (category != null) {
          predicate = predicate & tbl.category.equals(category.code);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Result<List<AssetEntity>>> getAssets({AssetCategory? category}) async {
    try {
      final query = _db.select(_db.assetsTable)
        ..where((tbl) {
          Expression<bool> predicate = tbl.deletedAt.isNull();
          if (category != null) {
            predicate = predicate & tbl.category.equals(category.code);
          }
          return predicate;
        })
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      final rows = await query.get();
      return Success(rows.map(_toEntity).toList());
    } catch (e) {
      return DatabaseFailure('خواندن دارایی‌ها انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<AssetEntity>> createAsset(AssetEntity asset) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final aId = asset.id.isEmpty ? _uuid.v4() : asset.id;

      await _db.transaction(() async {
        final companion = AssetsTableCompanion.insert(
          id: aId,
          name: asset.name,
          category: asset.category.code,
          quantity: asset.quantity,
          unit: asset.unit,
          costBasisMinor: asset.costBasis.minorUnits,
          currentValueMinor: asset.currentValue.minorUnits,
          currency: asset.currentValue.currency.code,
          purchaseDate: asset.purchaseDate.millisecondsSinceEpoch,
          notes: Value(asset.notes),
          createdAt: now,
          updatedAt: now,
        );

        await _db.into(_db.assetsTable).insert(companion);

        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'assets',
                entityId: aId,
                operation: 'INSERT',
                payloadJson: '{"id":"$aId","name":"${asset.name}","value":${asset.currentValue.minorUnits}}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return Success(asset.copyWith(id: aId));
    } catch (e) {
      return DatabaseFailure('ثبت دارایی انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateAssetValuation(String id, Money currentValue) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.assetsTable)..where((t) => t.id.equals(id))).write(
        AssetsTableCompanion(
          currentValueMinor: Value(currentValue.minorUnits),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'assets',
              entityId: id,
              operation: 'UPDATE',
              payloadJson: '{"id":"$id","currentValue":${currentValue.minorUnits}}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('به‌روزرسانی ارزش دارایی انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteAsset(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.assetsTable)..where((t) => t.id.equals(id))).write(
        AssetsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف دارایی انجام نشد.').asFailure();
    }
  }
}
