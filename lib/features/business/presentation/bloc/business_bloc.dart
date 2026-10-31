import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/business_metrics_entity.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../../accounting/domain/services/auto_voucher_service.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/repositories/business_repository.dart';
import 'business_event.dart';
import 'business_state.dart';

class BusinessBloc extends Bloc<BusinessEvent, BusinessState> {
  final BusinessRepository _businessRepository;
  final AutoVoucherService _autoVoucherService;
  StreamSubscription? _dataSubscription;

  BusinessBloc(this._businessRepository, this._autoVoucherService)
      : super(const BusinessInitial()) {
    on<WatchBusinessDataStarted>(_onWatchDataStarted);
    on<BusinessDataUpdated>(_onDataUpdated);
    on<BusinessContactCreateSubmitted>(_onContactCreateSubmitted);
    on<BusinessProductCreateSubmitted>(_onProductCreateSubmitted);
    on<BusinessStockAdjustSubmitted>(_onStockAdjustSubmitted);
    on<BusinessInvoiceCreateSubmitted>(_onInvoiceCreateSubmitted);
    on<BusinessInvoicePaymentSubmitted>(_onInvoicePaymentSubmitted);
    on<BusinessInvoiceStatusUpdated>(_onInvoiceStatusUpdated);
  }

  Future<void> _onWatchDataStarted(
    WatchBusinessDataStarted event,
    Emitter<BusinessState> emit,
  ) async {
    emit(const BusinessLoading());
    await _dataSubscription?.cancel();

    _dataSubscription = Rx.combineLatest4(
      _businessRepository.watchBusinessMetrics(),
      _businessRepository.watchInvoices(),
      _businessRepository.watchProducts(),
      _businessRepository.watchContacts(),
      (
        BusinessMetricsEntity metrics,
        List<InvoiceEntity> invoices,
        List<ProductEntity> products,
        List<ContactEntity> contacts,
      ) =>
          BusinessDataUpdated(
        metrics: metrics,
        invoices: invoices,
        products: products,
        contacts: contacts,
      ),
    ).listen((event) {
      add(event);
    });
  }

  void _onDataUpdated(
    BusinessDataUpdated event,
    Emitter<BusinessState> emit,
  ) {
    emit(BusinessLoaded(
      metrics: event.metrics,
      invoices: event.invoices,
      products: event.products,
      contacts: event.contacts,
    ));
  }

  Future<void> _onContactCreateSubmitted(
    BusinessContactCreateSubmitted event,
    Emitter<BusinessState> emit,
  ) async {
    final result = await _businessRepository.createContact(event.contact);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(BusinessError(failure.message)),
    );
  }

  Future<void> _onProductCreateSubmitted(
    BusinessProductCreateSubmitted event,
    Emitter<BusinessState> emit,
  ) async {
    final result = await _businessRepository.createProduct(event.product);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(BusinessError(failure.message)),
    );
  }

  Future<void> _onStockAdjustSubmitted(
    BusinessStockAdjustSubmitted event,
    Emitter<BusinessState> emit,
  ) async {
    final result = await _businessRepository.adjustStock(
      productId: event.productId,
      changeQuantity: event.changeQuantity,
      type: event.type,
      notes: event.notes,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(BusinessError(failure.message)),
    );
  }

  Future<void> _onInvoiceCreateSubmitted(
    BusinessInvoiceCreateSubmitted event,
    Emitter<BusinessState> emit,
  ) async {
    final result = await _businessRepository.createInvoice(event.invoice);
    result.fold(
      onSuccess: (_) => _createVoucherQuietly(event.invoice),
      onFailure: (failure) => emit(BusinessError(failure.message)),
    );
  }

  /// Fires the double-entry voucher for the new invoice. Accounting must
  /// never block or fail the invoice flow — a voucher problem is logged, not
  /// surfaced as a business error.
  Future<void> _createVoucherQuietly(InvoiceEntity invoice) async {
    try {
      await _autoVoucherService.generateInvoiceVoucher(invoice);
    } catch (_) {}
  }

  Future<void> _onInvoicePaymentSubmitted(
    BusinessInvoicePaymentSubmitted event,
    Emitter<BusinessState> emit,
  ) async {
    final result = await _businessRepository.recordInvoicePayment(
      event.invoiceId,
      event.paymentAmount,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(BusinessError(failure.message)),
    );
  }

  Future<void> _onInvoiceStatusUpdated(
    BusinessInvoiceStatusUpdated event,
    Emitter<BusinessState> emit,
  ) async {
    final result = await _businessRepository.updateInvoiceStatus(
      event.invoiceId,
      event.status,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(BusinessError(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _dataSubscription?.cancel();
    return super.close();
  }
}
