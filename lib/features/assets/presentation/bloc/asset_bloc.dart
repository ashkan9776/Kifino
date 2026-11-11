import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_currency.dart';
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
  List<AssetEntity> _lastAssets = const [];
  bool _hasLoaded = false;

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
    _lastAssets = event.assets;
    _hasLoaded = true;
    emit(_computeLoaded(event.assets));
  }

  AssetLoaded _computeLoaded(List<AssetEntity> assets) {
    final baseCurrency = AppCurrency.base;
    int totalCostMinor = 0;
    int totalValuationMinor = 0;

    for (final a in assets) {
      if (a.isDeleted) continue;
      if (a.costBasis.isCompatibleWith(baseCurrency)) {
        totalCostMinor += a.costBasis.currency == baseCurrency
            ? a.costBasis.minorUnits
            : a.costBasis.normalizeTo(baseCurrency).minorUnits;
      }
      if (a.currentValue.isCompatibleWith(baseCurrency)) {
        totalValuationMinor += a.currentValue.currency == baseCurrency
            ? a.currentValue.minorUnits
            : a.currentValue.normalizeTo(baseCurrency).minorUnits;
      }
    }

    final totalCost = Money.fromMinor(totalCostMinor, baseCurrency);
    final totalValuation = Money.fromMinor(totalValuationMinor, baseCurrency);
    final totalProfitLoss = totalValuation - totalCost;

    double pnlPercent = 0.0;
    if (totalCostMinor > 0) {
      pnlPercent =
          ((totalValuationMinor - totalCostMinor) / totalCostMinor) * 100;
    }

    return AssetLoaded(
      assets: assets,
      totalCostBasis: totalCost,
      totalCurrentValuation: totalValuation,
      totalProfitLoss: totalProfitLoss,
      profitLossPercent: double.parse(pnlPercent.toStringAsFixed(1)),
    );
  }

  void _emitFailurePreservingLoaded(Emitter<AssetState> emit, String message) {
    emit(AssetFailure(message));
    if (_hasLoaded) {
      emit(_computeLoaded(_lastAssets));
    }
  }

  Future<void> _onCreateSubmitted(
    AssetCreateSubmitted event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.createAsset(event.asset);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) =>
          _emitFailurePreservingLoaded(emit, failure.message),
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
      onFailure: (failure) =>
          _emitFailurePreservingLoaded(emit, failure.message),
    );
  }

  Future<void> _onDeleteSubmitted(
    AssetDeleteSubmitted event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.deleteAsset(event.id);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) =>
          _emitFailurePreservingLoaded(emit, failure.message),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
