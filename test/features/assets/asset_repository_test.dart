import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/assets/data/repositories/asset_repository_impl.dart';
import 'package:kifino/features/assets/domain/entities/asset_entity.dart';

void main() {
  late AppDatabase db;
  late AssetRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = AssetRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AssetRepositoryImpl Tests', () {
    final now = DateTime.now();

    test(
      'Creates asset, updates valuation and computes profit/loss accurately',
      () async {
        final asset = AssetEntity(
          id: 'asset-1',
          name: 'سکه تمام بهار',
          category: AssetCategory.gold,
          quantity: 2.0,
          unit: 'سکه',
          costBasis: const Money(
            minorUnits: 50000000,
            currency: Currency.irr,
          ), // 50M
          currentValue: const Money(
            minorUnits: 50000000,
            currency: Currency.irr,
          ),
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        );

        await repository.createAsset(asset);

        // Update market valuation to 65,000,000 (+15M gain)
        await repository.updateAssetValuation(
          'asset-1',
          const Money(minorUnits: 65000000, currency: Currency.irr),
        );

        final assets = await repository.getAssets();
        expect(assets.isSuccess, isTrue);
        final updated = assets.dataOrNull!.first;

        expect(updated.currentValue.minorUnits, equals(65000000));
        expect(updated.profitLossMoney.minorUnits, equals(15000000));
        expect(updated.profitLossPercent, equals(30.0));
        expect(updated.isProfitable, isTrue);
      },
    );
  });
}
