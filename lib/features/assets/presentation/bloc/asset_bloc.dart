import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/repositories/asset_repository.dart';

// Events
sealed class AssetEvent extends Equatable {
  const AssetEvent();
  @override
  List<Object?> get props => [];
}

final class WatchAssetsStarted extends AssetEvent {
  final AssetCategory? category;
  const WatchAssetsStarted({this.category});
  @override
  List<Object?> get props => [category];
}

final class _AssetsUpdated extends AssetEvent {
  final List<AssetEntity> assets;
  const _AssetsUpdated(this.assets);
  @override
  List<Object?> get props => [assets];
}

final class AssetCreateSubmitted extends AssetEvent {
  final AssetEntity asset;
  const AssetCreateSubmitted(this.asset);
  @override
  List<Object?> get props => [asset];
}

final class AssetValuationUpdated extends AssetEvent {
  final String id;
  final Money currentValue;
  const AssetValuationUpdated({required this.id, required this.currentValue});
  @override
  List<Object?> get props => [id, currentValue];
}

final class AssetDeleteSubmitted extends AssetEvent {
  final String id;
  const AssetDeleteSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

// States
sealed class AssetState extends Equatable {
  const AssetState();
  @override
  List<Object?> get props => [];
}

final class AssetInitial extends AssetState {}

final class AssetLoading extends AssetState {}

final class AssetLoaded extends AssetState {
  final List<AssetEntity> assets;
  final Money totalCostBasis;
  final Money totalCurrentValuation;
  final Money totalProfitLoss;
  final double profitLossPercent;

  const AssetLoaded({
    required this.assets,
    required this.totalCostBasis,
    required this.totalCurrentValuation,
    required this.totalProfitLoss,
    required this.profitLossPercent,
  });

  @override
  List<Object?> get props => [
    assets,
    totalCostBasis,
    totalCurrentValuation,
    totalProfitLoss,
    profitLossPercent,
  ];
}

final class AssetFailure extends AssetState {
  final String message;
  const AssetFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class AssetBloc extends Bloc<AssetEvent, AssetState> {
  final AssetRepository _repository;
  StreamSubscription<List<AssetEntity>>? _subscription;

  AssetBloc(this._repository) : super(AssetInitial()) {
    on<WatchAssetsStarted>(_onWatchStarted);
    on<_AssetsUpdated>(_onAssetsUpdated);
    on<AssetCreateSubmitted>(_onCreateSubmitted);
    on<AssetValuationUpdated>(_onValuationUpdated);
    on<AssetDeleteSubmitted>(_onDeleteSubmitted);
  }

  void _onWatchStarted(WatchAssetsStarted event, Emitter<AssetState> emit) {
    emit(AssetLoading());
    _subscription?.cancel();
    _subscription = _repository
        .watchAssets(category: event.category)
        .listen(
          (assets) => add(_AssetsUpdated(assets)),
          onError: (e) => emit(AssetFailure(e.toString())),
        );
  }

  void _onAssetsUpdated(_AssetsUpdated event, Emitter<AssetState> emit) {
    int totalCostMinor = 0;
    int totalValuationMinor = 0;
    const currency = Currency.irr;

    for (final a in event.assets) {
      if (a.isDeleted) continue;
      totalCostMinor += a.costBasis.minorUnits;
      totalValuationMinor += a.currentValue.minorUnits;
    }

    final totalCost = Money.fromMinor(totalCostMinor, currency);
    final totalValuation = Money.fromMinor(totalValuationMinor, currency);
    final totalProfitLoss = totalValuation - totalCost;

    double pnlPercent = 0.0;
    if (totalCostMinor > 0) {
      pnlPercent =
          ((totalValuationMinor - totalCostMinor) / totalCostMinor) * 100;
    }

    emit(
      AssetLoaded(
        assets: event.assets,
        totalCostBasis: totalCost,
        totalCurrentValuation: totalValuation,
        totalProfitLoss: totalProfitLoss,
        profitLossPercent: double.parse(pnlPercent.toStringAsFixed(1)),
      ),
    );
  }

  Future<void> _onCreateSubmitted(
    AssetCreateSubmitted event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.createAsset(event.asset);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(AssetFailure(failure.message)),
    );
  }

  Future<void> _onValuationUpdated(
    AssetValuationUpdated event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.updateAssetValuation(
      event.id,
      event.currentValue,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(AssetFailure(failure.message)),
    );
  }

  Future<void> _onDeleteSubmitted(
    AssetDeleteSubmitted event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.deleteAsset(event.id);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(AssetFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
