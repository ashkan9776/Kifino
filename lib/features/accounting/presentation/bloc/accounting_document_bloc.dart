import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/accounting_audit_entity.dart';
import '../../domain/entities/accounting_document_entity.dart';
import '../../domain/repositories/accounting_repository.dart';

// Events
sealed class AccountingDocumentEvent extends Equatable {
  const AccountingDocumentEvent();
  @override
  List<Object?> get props => [];
}

final class LoadAccountingDocuments extends AccountingDocumentEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  final DocumentStatus? status;
  final String? fiscalYearId;

  const LoadAccountingDocuments({
    this.startDate,
    this.endDate,
    this.status,
    this.fiscalYearId,
  });

  @override
  List<Object?> get props => [startDate, endDate, status, fiscalYearId];
}

final class CreateAccountingDocumentSubmitted extends AccountingDocumentEvent {
  final AccountingDocumentEntity document;

  /// Optional تفصیلی شناور tags (one value per ledger) applied right after
  /// the document is saved.
  final List<DocumentDetailTag> details;

  const CreateAccountingDocumentSubmitted(
    this.document, {
    this.details = const [],
  });
  @override
  List<Object?> get props => [document, details];
}

final class ApproveAccountingDocumentSubmitted extends AccountingDocumentEvent {
  final String documentId;
  const ApproveAccountingDocumentSubmitted(this.documentId);
  @override
  List<Object?> get props => [documentId];
}

final class DeleteAccountingDocumentSubmitted extends AccountingDocumentEvent {
  final String documentId;
  const DeleteAccountingDocumentSubmitted(this.documentId);
  @override
  List<Object?> get props => [documentId];
}

// States
sealed class AccountingDocumentState extends Equatable {
  const AccountingDocumentState();
  @override
  List<Object?> get props => [];
}

final class AccountingDocumentInitial extends AccountingDocumentState {}

final class AccountingDocumentLoading extends AccountingDocumentState {}

final class AccountingDocumentLoaded extends AccountingDocumentState {
  final List<AccountingDocumentEntity> documents;
  final DateTime? startDate;
  final DateTime? endDate;
  final DocumentStatus? status;
  final String? fiscalYearId;

  const AccountingDocumentLoaded({
    required this.documents,
    this.startDate,
    this.endDate,
    this.status,
    this.fiscalYearId,
  });

  @override
  List<Object?> get props => [
    documents,
    startDate,
    endDate,
    status,
    fiscalYearId,
  ];
}

final class AccountingDocumentOperationSuccess extends AccountingDocumentState {
  final String message;
  const AccountingDocumentOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

final class AccountingDocumentError extends AccountingDocumentState {
  final String message;
  const AccountingDocumentError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class AccountingDocumentBloc
    extends Bloc<AccountingDocumentEvent, AccountingDocumentState> {
  final AccountingRepository _repository;

  AccountingDocumentBloc(this._repository)
    : super(AccountingDocumentInitial()) {
    on<LoadAccountingDocuments>(_onLoad);
    on<CreateAccountingDocumentSubmitted>(_onCreate);
    on<ApproveAccountingDocumentSubmitted>(_onApprove);
    on<DeleteAccountingDocumentSubmitted>(_onDelete);
  }

  Future<void> _onLoad(
    LoadAccountingDocuments event,
    Emitter<AccountingDocumentState> emit,
  ) async {
    emit(AccountingDocumentLoading());
    try {
      await _repository.seedChartOfAccountsIfNotExists();
      final docs = await _repository.getDocuments(
        startDate: event.startDate,
        endDate: event.endDate,
        status: event.status,
        fiscalYearId: event.fiscalYearId,
      );
      emit(
        AccountingDocumentLoaded(
          documents: docs,
          startDate: event.startDate,
          endDate: event.endDate,
          status: event.status,
          fiscalYearId: event.fiscalYearId,
        ),
      );
    } catch (e) {
      emit(AccountingDocumentError(_cleanError(e)));
    }
  }

  Future<void> _onCreate(
    CreateAccountingDocumentSubmitted event,
    Emitter<AccountingDocumentState> emit,
  ) async {
    try {
      final saved = await _repository.createDocument(event.document);
      if (event.details.isNotEmpty) {
        await _repository.setDocumentDetails(
          documentId: saved.id,
          tags: event.details,
        );
      }
      emit(
        const AccountingDocumentOperationSuccess(
          'سند حسابداری با موفقیت ثبت شد',
        ),
      );
      add(const LoadAccountingDocuments());
    } catch (e) {
      emit(AccountingDocumentError(_cleanError(e)));
    }
  }

  Future<void> _onApprove(
    ApproveAccountingDocumentSubmitted event,
    Emitter<AccountingDocumentState> emit,
  ) async {
    try {
      await _repository.approveDocument(event.documentId);
      emit(const AccountingDocumentOperationSuccess('سند حسابداری تأیید شد'));
      add(const LoadAccountingDocuments());
    } catch (e) {
      emit(AccountingDocumentError(_cleanError(e)));
    }
  }

  Future<void> _onDelete(
    DeleteAccountingDocumentSubmitted event,
    Emitter<AccountingDocumentState> emit,
  ) async {
    try {
      await _repository.deleteDocument(event.documentId);
      emit(
        const AccountingDocumentOperationSuccess(
          'سند حسابداری با موفقیت حذف شد',
        ),
      );
      add(const LoadAccountingDocuments());
    } catch (e) {
      emit(AccountingDocumentError(_cleanError(e)));
    }
  }

  /// Repository rule violations come as StateError with a ready Persian
  /// message — strip the engine prefix so the UI shows only the message.
  static String _cleanError(Object e) =>
      e.toString().replaceFirst(RegExp(r'^(Bad state|StateError):\s*'), '');
}
