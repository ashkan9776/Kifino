import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../entities/asset_entity.dart';

abstract interface class AssetRepository {
  Stream<List<AssetEntity>> watchAssets({AssetCategory? category});
  Future<Result<List<AssetEntity>>> getAssets({AssetCategory? category});
  Future<Result<AssetEntity>> createAsset(AssetEntity asset);
  Future<Result<void>> updateAsset(AssetEntity asset);

  Future<Result<void>> updateAssetValuation(String id, Money currentValue);
  Future<Result<void>> deleteAsset(String id);
}
