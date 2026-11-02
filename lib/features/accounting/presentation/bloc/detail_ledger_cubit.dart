import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/accounting_audit_entity.dart';
import '../../domain/repositories/accounting_repository.dart';

sealed class DetailLedgerState extends Equatable {
  const DetailLedgerState();
  @override
  List<Object?> get props => [];
}

final class DetailLedgerInitial extends DetailLedgerState {}

final class DetailLedgerLoading extends DetailLedgerState {}

/// Floating-detail ledgers with their values. [errorMessage] carries the last
/// failure (already in Persian, from the repository StateErrors) and
/// [errorStamp] keeps it unique so an identical message can re-trigger a
/// SnackBar listener.
final class DetailLedgerLoaded extends DetailLedgerState {
  final List<DetailLedgerWithValues> ledgers;
  final String? errorMessage;
  final int errorStamp;

  const DetailLedgerLoaded({
    required this.ledgers,
    this.errorMessage,
    this.errorStamp = 0,
  });

  @override
  List<Object?> get props => [ledgers, errorMessage, errorStamp];
}

final class DetailLedgerError extends DetailLedgerState {
  final String message;

  const DetailLedgerError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Manages تفصیلی شناور (floating detail) ledgers and their values.
class DetailLedgerCubit extends Cubit<DetailLedgerState> {
  final AccountingRepository _repository;

  DetailLedgerCubit(this._repository) : super(DetailLedgerInitial());

  Future<void> load() async {
    emit(DetailLedgerLoading());
    try {
      final ledgers = await _repository.getDetailLedgers();
      emit(DetailLedgerLoaded(ledgers: ledgers));
    } catch (e) {
      emit(DetailLedgerError(_message(e)));
    }
  }

  Future<bool> createLedger({required String title, required String code}) =>
      _mutate(() => _repository.createDetailLedger(title: title, code: code));

  Future<bool> renameLedger({required String id, required String title}) =>
      _mutate(() => _repository.updateDetailLedger(id: id, title: title));

  Future<bool> deleteLedger(String id) =>
      _mutate(() => _repository.deleteDetailLedger(id));

  Future<bool> createValue({
    required String ledgerId,
    required String title,
    String? code,
  }) => _mutate(
    () => _repository.createDetailValue(
      ledgerId: ledgerId,
      title: title,
      code: code,
    ),
  );

  Future<bool> deleteValue(String id) =>
      _mutate(() => _repository.deleteDetailValue(id));

  /// Runs a mutation, reloads on success, surfaces the (Persian) error on
  /// failure while keeping the currently visible list intact. Returns whether
  /// the mutation succeeded.
  Future<bool> _mutate(Future<Object?> Function() action) async {
    try {
      await action();
      final ledgers = await _repository.getDetailLedgers();
      emit(DetailLedgerLoaded(ledgers: ledgers));
      return true;
    } catch (e) {
      final current = state;
      final ledgers = current is DetailLedgerLoaded
          ? current.ledgers
          : const <DetailLedgerWithValues>[];
      emit(
        DetailLedgerLoaded(
          ledgers: ledgers,
          errorMessage: _message(e),
          errorStamp: DateTime.now().microsecondsSinceEpoch,
        ),
      );
      return false;
    }
  }

  static String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^(Bad state|StateError):\s*'), '');
}
