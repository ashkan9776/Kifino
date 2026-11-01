import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/domain/entities/contact_entity.dart';
import 'package:kifino/features/business/domain/entities/invoice_entity.dart';
import 'package:kifino/features/business/presentation/bloc/business_bloc.dart';
import 'package:kifino/features/business/presentation/bloc/business_event.dart';
import 'package:kifino/features/business/presentation/bloc/business_state.dart';

void main() {
  late AppDatabase db;
  late BusinessRepositoryImpl repo;
  late BusinessBloc bloc;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BusinessRepositoryImpl(db);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    bloc = BusinessBloc(
      repo,
      AutoVoucherService(
        AccountingRepositoryImpl(db),
        settingsService: VoucherSettingsService(prefs),
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  group('BusinessBloc Tests', () {
    test(
      'emits [BusinessLoading, BusinessLoaded] on WatchBusinessDataStarted',
      () async {
        final states = <BusinessState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const WatchBusinessDataStarted());
        await Future.delayed(const Duration(milliseconds: 100));

        expect(states.isNotEmpty, isTrue);
        expect(states.first, isA<BusinessLoading>());
        expect(states.last, isA<BusinessLoaded>());

        await sub.cancel();
      },
    );

    test('P0-4: closed period emits BusinessInvoiceVoucherPending with warning message instead of swallowing error', () async {
      final now = DateTime(2026, 5, 10);

      // Seed chart of accounts
      await AccountingRepositoryImpl(db).seedChartOfAccountsIfNotExists();

      // Create a CLOSED fiscal year covering 2026
      await db
          .into(db.fiscalYearsTable)
          .insert(
            FiscalYearsTableCompanion.insert(
              id: 'fy-2026-closed',
              title: 'سال مالی ۱۴۰۵ بسته',
              yearNumber: 1405,
              startDate: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              endDate: DateTime(2026, 12, 29).millisecondsSinceEpoch,
              isClosed: const Value(true),
              isActive: const Value(false),
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
            ),
          );

      // Seed contact
      await repo.createContact(
        ContactEntity(
          id: 'c-p04',
          name: 'مشتری P04',
          type: ContactType.customer,
          outstandingBalance: Money.zero(Currency.irr),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final invoice = InvoiceEntity(
        id: 'inv-p04',
        invoiceNumber: 'INV-P04',
        contactId: 'c-p04',
        type: InvoiceType.sale,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(1000, Currency.irr),
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: Money.fromMinor(1000, Currency.irr),
        paidAmount: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: const [],
      );

      final states = <BusinessState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(BusinessInvoiceCreateSubmitted(invoice));
      await Future.delayed(const Duration(milliseconds: 300));

      // Must emit BusinessInvoiceVoucherPending with warning message
      final pendingState = states
          .whereType<BusinessInvoiceVoucherPending>()
          .firstOrNull;
      expect(pendingState, isNotNull);
      expect(pendingState!.warningMessage, contains('بسته'));

      await sub.cancel();
    });
  });
}
