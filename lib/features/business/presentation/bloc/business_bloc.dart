import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/money.dart';

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

    _dataSubscription =
        Rx.combineLatest4(
          _businessRepository.watchBusinessMetrics(),
          _businessRepository.watchInvoices(),
          _businessRepository.watchProducts(),
          _businessRepository.watchContacts(),
          (
            BusinessMetricsEntity metrics,
            List<InvoiceEntity> invoices,
            List<ProductEntity> products,
            List<ContactEntity> contacts,
          ) => BusinessDataUpdated(
            metrics: metrics,
            invoices: invoices,
            products: products,
            contacts: contacts,
          ),
        ).listen((event) {
          add(event);
        });
  }

  void _onDataUpdated(BusinessDataUpdated event, Emitter<BusinessState> emit) {
    emit(
      BusinessLoaded(
        metrics: event.metrics,
        invoices: event.invoices,
        products: event.products,
        contacts: event.contacts,
      ),
    );
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
    await result.fold(
      onSuccess: (invoice) async {
        try {
          await _autoVoucherService.generateInvoiceVoucher(invoice);
        } catch (e, st) {
          AppLogger.warning(
            'خطا در صدور خودکار سند حسابداری برای فاکتور ${invoice.invoiceNumber}: $e',
            error: e,
            stackTrace: st,
          );
          await _emitVoucherPending(
            emit,
            invoice: invoice,
            error: e,
            contextVerb: 'ثبت',
          );
        }
      },
      onFailure: (failure) async => emit(BusinessError(failure.message)),
    );
  }

  Future<void> _onInvoicePaymentSubmitted(
    BusinessInvoicePaymentSubmitted event,
    Emitter<BusinessState> emit,
  ) async {
    final result = await _businessRepository.recordInvoicePayment(
      event.invoiceId,
      event.paymentAmount,
    );
    await result.fold(
      onSuccess: (_) async {
        // The money moved in the business tables; mirror it in the ledger:
        // DR bank/cash — CR receivable (sale) or DR payable — CR bank/cash
        // (purchase). A missing voucher would leave the counterparty
        // outstanding forever even after full settlement.
        try {
          final invoice = await _businessRepository
              .getInvoiceById(event.invoiceId);
          await invoice.fold(
            onSuccess: (inv) async {
              await _autoVoucherService.generateInvoicePaymentVoucher(
                inv,
                amount: event.paymentAmount,
              );
            },
            onFailure: (f) async => AppLogger.warning(
              'سند پرداخت فاکتور ${event.invoiceId} صادر نشد: ${f.message}',
            ),
          );
        } catch (e, st) {
          AppLogger.warning(
            'خطا در صدور سند پرداخت برای فاکتور ${event.invoiceId}: $e',
            error: e,
            stackTrace: st,
          );
        }
      },
      onFailure: (failure) async => emit(BusinessError(failure.message)),
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
    await result.fold(
      onSuccess: (_) async {
        // Re-activating a cancelled invoice: the cancel voided the voucher
        // and reversed business effects — the repo re-applied the effects,
        // so the ledger needs the voucher back.
        if (event.status != InvoiceStatus.cancelled) {
          final previous = state;
          final oldInvoice = previous is BusinessLoaded
              ? previous.invoices
                    .where((i) => i.id == event.invoiceId)
                    .firstOrNull
              : null;
          final wasCancelled =
              oldInvoice?.status == InvoiceStatus.cancelled;
          if (wasCancelled && oldInvoice != null) {
            try {
              await _autoVoucherService.generateInvoiceVoucher(
                oldInvoice.copyWith(status: event.status),
              );
            } catch (e, st) {
              AppLogger.warning(
                'خطا در صدور مجدد سند فاکتور ${event.invoiceId}: $e',
                error: e,
                stackTrace: st,
              );
            }
          }
        }
      },
      onFailure: (failure) async => emit(BusinessError(failure.message)),
    );
  }

  /// Emits the voucher-pending state while KEEPING the loaded data visible —
  /// the pending state extends [BusinessLoaded], so the hub never blanks.
  Future<void> _emitVoucherPending(
    Emitter<BusinessState> emit, {
    required InvoiceEntity invoice,
    required Object error,
    required String contextVerb,
  }) async {
    final isPeriodClosed =
        error.toString().contains('بسته شده است') ||
        error.toString().contains('closed');
    final warning = isPeriodClosed
        ? 'فاکتور $contextVerb شد، اما دوره مالی این تاریخ بسته است و سند حسابداری صادر نشد (سند ناقص).'
        : 'فاکتور $contextVerb شد اما صدور سند حسابداری ناموفق بود: $error (سند ناقص).';
    final current = state;
    if (current is BusinessLoaded) {
      emit(
        BusinessInvoiceVoucherPending(
          invoice: invoice,
          warningMessage: warning,
          metrics: current.metrics,
          invoices: current.invoices,
          products: current.products,
          contacts: current.contacts,
        ),
      );
    } else {
      emit(
        BusinessInvoiceVoucherPending(
          invoice: invoice,
          warningMessage: warning,
          metrics: const BusinessMetricsEntity(
            totalSales: Money.zero(Currency.toman),
            unpaidReceivables: Money.zero(Currency.toman),
            activeProductsCount: 0,
            lowStockCount: 0,
            totalInvoicesCount: 0,
          ),
          invoices: const [],
          products: const [],
          contacts: const [],
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _dataSubscription?.cancel();
    return super.close();
  }
}
