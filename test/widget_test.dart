import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/app/app.dart';
import 'package:kifino/core/di/company_controller.dart';
import 'package:kifino/core/database/company_registry.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/di/injection.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/repositories/accounting_repository.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/accounting/presentation/bloc/accounting_document_bloc.dart';
import 'package:kifino/features/accounting/presentation/bloc/chart_of_accounts_cubit.dart';
import 'package:kifino/features/accounting/presentation/bloc/financial_statements_bloc.dart';
import 'package:kifino/features/accounting/presentation/bloc/ledger_bloc.dart';
import 'package:kifino/features/accounting/presentation/bloc/trial_balance_bloc.dart';
import 'package:kifino/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:kifino/features/goals/domain/repositories/goal_repository.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/repositories/account_repository.dart';
import 'package:kifino/features/assets/data/repositories/asset_repository_impl.dart';
import 'package:kifino/features/assets/domain/repositories/asset_repository.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/domain/repositories/business_repository.dart';
import 'package:kifino/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:kifino/features/budgets/domain/repositories/budget_repository.dart';
import 'package:kifino/features/checks/data/repositories/check_repository_impl.dart';
import 'package:kifino/features/checks/domain/repositories/check_repository.dart';
import 'package:kifino/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:kifino/features/debts/domain/repositories/debt_repository.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/repositories/installment_repository.dart';
import 'package:kifino/features/transactions/data/repositories/category_repository_impl.dart';
import 'package:kifino/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:kifino/features/transactions/domain/repositories/category_repository.dart';
import 'package:kifino/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:kifino/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:kifino/features/backup/domain/services/backup_service.dart';
import 'package:kifino/features/notifications/domain/services/notification_service.dart';
import 'package:kifino/features/security/domain/services/security_service.dart';
import 'package:kifino/features/security/presentation/cubit/security_cubit.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:kifino/features/settings/domain/services/settings_service.dart';
import 'package:kifino/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:kifino/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:kifino/features/sync/domain/repositories/sync_repository.dart';
import 'package:kifino/features/sync/domain/services/remote_sync_client.dart';
import 'package:kifino/features/sync/domain/services/sync_engine.dart';
import 'package:kifino/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await sl.reset();

    SharedPreferences.setMockInitialValues({
      'pref_onboarding_completed': true, // Skip onboarding gate in widget tests
    });
    final prefs = await SharedPreferences.getInstance();
    sl.registerLazySingleton<SharedPreferences>(() => prefs);

    const secureStorage = FlutterSecureStorage();
    sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

    db = AppDatabase(NativeDatabase.memory());
    sl.registerLazySingleton<AppDatabase>(() => db);

    sl.registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(db),
    );
    sl.registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(db),
    );
    sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(db),
    );
    sl.registerLazySingleton<BudgetRepository>(() => BudgetRepositoryImpl(db));
    sl.registerLazySingleton<DebtRepository>(() => DebtRepositoryImpl(db));
    sl.registerLazySingleton<InstallmentRepository>(
      () => InstallmentRepositoryImpl(db),
    );
    sl.registerLazySingleton<CheckRepository>(() => CheckRepositoryImpl(db));
    sl.registerLazySingleton<AssetRepository>(() => AssetRepositoryImpl(db));
    sl.registerLazySingleton<BusinessRepository>(
      () => BusinessRepositoryImpl(db),
    );
    sl.registerLazySingleton<GoalRepository>(() => GoalRepositoryImpl(db));

    sl.registerLazySingleton<AccountingRepository>(
      () => AccountingRepositoryImpl(db),
    );
    sl.registerLazySingleton<VoucherSettingsService>(
      () => VoucherSettingsService(prefs),
    );
    sl.registerLazySingleton<AutoVoucherService>(
      () => AutoVoucherService(
        sl<AccountingRepository>(),
        settingsService: sl<VoucherSettingsService>(),
      ),
    );
    sl.registerFactory<AccountingDocumentBloc>(
      () => AccountingDocumentBloc(sl<AccountingRepository>()),
    );
    sl.registerFactory<ChartOfAccountsCubit>(
      () => ChartOfAccountsCubit(sl<AccountingRepository>()),
    );
    sl.registerFactory<TrialBalanceBloc>(
      () => TrialBalanceBloc(sl<AccountingRepository>()),
    );
    sl.registerFactory<LedgerBloc>(
      () => LedgerBloc(sl<AccountingRepository>()),
    );
    sl.registerFactory<FinancialStatementsBloc>(
      () => FinancialStatementsBloc(sl<AccountingRepository>()),
    );

    sl.registerLazySingleton<SyncRepository>(() => SyncRepositoryImpl(db));
    sl.registerLazySingleton<RemoteSyncClient>(
      () => const ProductionRemoteSyncClient(),
    );
    sl.registerLazySingleton<SyncEngine>(
      () => SyncEngine(
        syncRepository: sl<SyncRepository>(),
        remoteClient: sl<RemoteSyncClient>(),
      ),
    );
    sl.registerFactory<SyncBloc>(
      () => SyncBloc(
        syncRepository: sl<SyncRepository>(),
        syncEngine: sl<SyncEngine>(),
      ),
    );

    sl.registerFactory<AiAssistantBloc>(
      () => AiAssistantBloc(
        transactionRepository: sl<TransactionRepository>(),
        accountRepository: sl<AccountRepository>(),
        budgetRepository: sl<BudgetRepository>(),
        debtRepository: sl<DebtRepository>(),
        settingsService: sl<SettingsService>(),
      ),
    );

    sl.registerLazySingleton<SecurityService>(
      () => SecurityService(secureStorage: sl<FlutterSecureStorage>()),
    );
    sl.registerFactory<SecurityCubit>(
      () => SecurityCubit(securityService: sl<SecurityService>()),
    );
    sl.registerLazySingleton<BackupService>(() => BackupService(db));
    sl.registerLazySingleton<NotificationService>(
      () => NotificationService(db: db),
    );

    sl.registerLazySingleton<CompanyRegistry>(() => CompanyRegistry(prefs));
    sl.registerLazySingleton<CompanyController>(
      () => CompanyController(CompanyRegistry(prefs)),
    );
    sl.registerLazySingleton<SettingsService>(() => SettingsService(prefs));
    sl.registerFactory<SettingsCubit>(
      () => SettingsCubit(sl<SettingsService>()),
    );

    await sl<CategoryRepository>().seedDefaultCategoriesIfEmpty();
  });

  tearDown(() async {
    await db.close();
    await sl.reset();
  });

  testWidgets('KifinoApp smoke test renders navigation and dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(const KifinoApp());
    await tester.pumpAndSettle();

    // Verify the floating navigation dock (selected tab shows the rounded
    // icon variant; inactive tabs show outlined).
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);

    // Unmount and flush timers before tearDown
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));

    addTearDown(() => tester.view.resetPhysicalSize());
  });
}
