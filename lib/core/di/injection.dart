import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/accounts/data/repositories/account_repository_impl.dart';
import '../../features/accounts/domain/repositories/account_repository.dart';
import '../../features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import '../../features/assets/data/repositories/asset_repository_impl.dart';
import '../../features/assets/domain/repositories/asset_repository.dart';
import '../../features/backup/domain/services/backup_service.dart';
import '../../features/notifications/domain/services/notification_service.dart';
import '../../features/security/domain/services/security_service.dart';
import '../../features/security/presentation/cubit/security_cubit.dart';
import '../../features/business/data/repositories/business_repository_impl.dart';
import '../../features/business/domain/repositories/business_repository.dart';
import '../../features/budgets/data/repositories/budget_repository_impl.dart';
import '../../features/budgets/domain/repositories/budget_repository.dart';
import '../../features/checks/data/repositories/check_repository_impl.dart';
import '../../features/checks/domain/repositories/check_repository.dart';
import '../../features/debts/data/repositories/debt_repository_impl.dart';
import '../../features/debts/domain/repositories/debt_repository.dart';
import '../../features/goals/data/repositories/goal_repository_impl.dart';
import '../../features/goals/domain/repositories/goal_repository.dart';
import '../../features/installments/data/repositories/installment_repository_impl.dart';
import '../../features/installments/domain/repositories/installment_repository.dart';
import '../../features/settings/domain/services/settings_service.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/sync/data/repositories/sync_repository_impl.dart';
import '../../features/sync/domain/repositories/sync_repository.dart';
import '../../features/sync/domain/services/remote_sync_client.dart';
import '../../features/sync/domain/services/sync_engine.dart';
import '../../features/sync/presentation/bloc/sync_bloc.dart';
import '../../features/transactions/data/repositories/category_repository_impl.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/category_repository.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/presentation/bloc/category_cubit.dart';
import '../../features/accounting/data/repositories/accounting_repository_impl.dart';
import '../../features/accounting/domain/repositories/accounting_repository.dart';
import '../../features/accounting/data/services/accounting_export_service.dart';
import '../../features/accounting/domain/services/auto_voucher_service.dart';
import '../../features/accounting/domain/services/voucher_settings_service.dart';
import '../../features/accounting/presentation/bloc/accounting_document_bloc.dart';
import '../../features/accounting/presentation/bloc/audit_log_cubit.dart';
import '../../features/accounting/presentation/bloc/chart_of_accounts_cubit.dart';
import '../../features/accounting/presentation/bloc/detail_ledger_cubit.dart';
import '../../features/accounting/presentation/bloc/fiscal_year_cubit.dart';
import '../../features/accounting/presentation/bloc/financial_statements_bloc.dart';
import '../../features/accounting/presentation/bloc/ledger_bloc.dart';
import '../../features/accounting/presentation/bloc/trial_balance_bloc.dart';
import '../database/app_database.dart';
import 'company_controller.dart';
import '../database/company_registry.dart';

final sl = GetIt.instance;
final getIt = sl;

class ServiceLocator {
  /// All company-scoped singletons (database, repositories, services, blocs)
  /// are registered inside the 'company' scope so switching companies can
  /// dispose the whole set atomically. Root-scope singletons (prefs,
  /// registry, company controller, settings service) survive the switch.
  static const String companyScopeName = 'company';

  static Future<void> resetCompanyScope() async {
    if (sl.hasScope(companyScopeName)) {
      await sl.popScope();
    }
  }

  /// Root-scope singletons that must survive a company switch. Called from
  /// bootstrap (main) before the first company-scope init.
  static Future<void> initRoot() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

    sl.registerLazySingleton<CompanyRegistry>(
      () => CompanyRegistry(sharedPreferences),
    );

    sl.registerLazySingleton<CompanyController>(
      () => CompanyController(sl<CompanyRegistry>()),
    );

    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: true),
    );
    sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);
  }

  static Future<void> init({String? companyId}) async {
    if (sl.hasScope(companyScopeName)) {
      await sl.popScope();
    }
    sl.pushNewScope(scopeName: companyScopeName);

    // 1. SharedPreferences: registered once in root scope (initRoot) and
    // looked up here so company-scoped services share the same instance.

    // 2. Secure Storage
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: true),
    );
    sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

    // 3. Local Database — company-specific file
    final database = AppDatabase(
      null,
      CompanyRegistry.dbFileNameFor(
        companyId ?? CompanyRegistry.defaultCompanyId,
      ),
    );
    sl.registerLazySingleton<AppDatabase>(() => database);

    // 4. Repositories
    sl.registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<BudgetRepository>(
      () => BudgetRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<DebtRepository>(
      () => DebtRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<InstallmentRepository>(
      () => InstallmentRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<CheckRepository>(
      () => CheckRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<AssetRepository>(
      () => AssetRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<BusinessRepository>(
      () => BusinessRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<GoalRepository>(
      () => GoalRepositoryImpl(sl<AppDatabase>()),
    );

    // 5. Sync Engine & Outbox
    sl.registerLazySingleton<SyncRepository>(
      () => SyncRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<RemoteSyncClient>(
      () => kDebugMode
          ? const FakeRemoteSyncClient()
          : const UnavailableRemoteSyncClient(),
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

    // 6. AI Assistant & Blocs
    sl.registerFactory<AiAssistantBloc>(
      () => AiAssistantBloc(
        transactionRepository: sl<TransactionRepository>(),
        accountRepository: sl<AccountRepository>(),
        budgetRepository: sl<BudgetRepository>(),
        debtRepository: sl<DebtRepository>(),
        settingsService: sl<SettingsService>(),
      ),
    );

    // 7. Security, Backup & Notifications
    sl.registerLazySingleton<SecurityService>(
      () => SecurityService(secureStorage: sl<FlutterSecureStorage>()),
    );

    sl.registerFactory<SecurityCubit>(
      () => SecurityCubit(securityService: sl<SecurityService>()),
    );

    sl.registerLazySingleton<BackupService>(
      () => BackupService(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<NotificationService>(
      () => NotificationService(db: sl<AppDatabase>()),
    );

    // 8. User settings (locale, currency, theme, onboarding)
    sl.registerLazySingleton<SettingsService>(
      () => SettingsService(sl<SharedPreferences>()),
    );

    sl.registerFactory<SettingsCubit>(
      () => SettingsCubit(sl<SettingsService>()),
    );

    // Custom categories manager (watch per selected type + CRUD).
    sl.registerFactory<CategoryCubit>(
      () => CategoryCubit(sl<CategoryRepository>()),
    );

    // 9. Accounting OS Core & Standard Double-Entry System
    sl.registerLazySingleton<AccountingRepository>(
      () => AccountingRepositoryImpl(sl<AppDatabase>()),
    );

    sl.registerLazySingleton<AutoVoucherService>(
      () => AutoVoucherService(
        sl<AccountingRepository>(),
        settingsService: VoucherSettingsService(sl<SharedPreferences>()),
      ),
    );
    sl.registerLazySingleton<AccountingExportService>(
      () => AccountingExportService(sl<AccountingRepository>()),
    );
    sl.registerLazySingleton<VoucherSettingsService>(
      () => VoucherSettingsService(sl<SharedPreferences>()),
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

    sl.registerFactory<AuditLogCubit>(
      () => AuditLogCubit(sl<AccountingRepository>()),
    );

    sl.registerFactory<DetailLedgerCubit>(
      () => DetailLedgerCubit(sl<AccountingRepository>()),
    );

    sl.registerFactory<FiscalYearCubit>(
      () => FiscalYearCubit(sl<AccountingRepository>()),
    );

    // 10. Default reference data (categories) & services
    await sl<CategoryRepository>().seedDefaultCategoriesIfEmpty();
    await sl<AccountingRepository>().seedChartOfAccountsIfNotExists();
    await sl<NotificationService>().init();
  }
}
