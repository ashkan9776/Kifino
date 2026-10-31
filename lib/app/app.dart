import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/di/injection.dart';
import '../features/accounts/domain/repositories/account_repository.dart';
import '../features/accounts/presentation/bloc/accounts_bloc.dart';
import '../features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import '../features/ai_assistant/presentation/bloc/ai_assistant_event.dart';
import '../features/assets/domain/repositories/asset_repository.dart';
import '../features/assets/presentation/bloc/asset_bloc.dart';
import '../features/business/domain/repositories/business_repository.dart';
import '../features/business/presentation/bloc/business_bloc.dart';
import '../features/business/presentation/bloc/business_event.dart';
import '../features/accounting/domain/services/auto_voucher_service.dart';
import '../features/budgets/domain/repositories/budget_repository.dart';
import '../features/budgets/presentation/bloc/budget_bloc.dart';
import '../features/checks/domain/repositories/check_repository.dart';
import '../features/checks/presentation/bloc/check_bloc.dart';
import '../features/debts/domain/repositories/debt_repository.dart';
import '../features/debts/presentation/bloc/debt_bloc.dart';
import '../features/installments/domain/repositories/installment_repository.dart';
import '../features/notifications/domain/services/notification_service.dart';
import '../features/installments/presentation/bloc/installment_bloc.dart';
import '../features/security/presentation/cubit/security_cubit.dart';
import '../features/security/presentation/cubit/security_state.dart';
import '../features/security/presentation/pages/lock_page.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import '../features/settings/presentation/cubit/settings_state.dart';
import '../features/sync/presentation/bloc/sync_bloc.dart';
import '../features/sync/presentation/bloc/sync_event.dart';
import '../features/transactions/domain/repositories/transaction_repository.dart';
import '../features/transactions/presentation/bloc/transaction_bloc.dart';
import '../features/accounting/presentation/bloc/accounting_document_bloc.dart';
import '../features/accounting/presentation/bloc/chart_of_accounts_cubit.dart';
import '../features/accounting/presentation/bloc/financial_statements_bloc.dart';
import '../features/accounting/presentation/bloc/ledger_bloc.dart';
import '../features/accounting/presentation/bloc/trial_balance_bloc.dart';
import 'localization/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Relocks the session whenever the app returns from the background while a
/// PIN is configured. Lives above MaterialApp so it survives route changes.
class _LifecycleLockObserver extends StatefulWidget {
  final SecurityCubit cubit;
  final Widget child;

  const _LifecycleLockObserver({
    required this.cubit,
    required this.child,
  });

  @override
  State<_LifecycleLockObserver> createState() => _LifecycleLockObserverState();
}

class _LifecycleLockObserverState extends State<_LifecycleLockObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        widget.cubit.onAppPaused();
      case AppLifecycleState.resumed:
        widget.cubit.onAppResumed();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class KifinoApp extends StatelessWidget {
  const KifinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>(
      create: (_) => sl<SettingsCubit>()..init(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<AccountsBloc>(
                create: (context) => AccountsBloc(sl<AccountRepository>())..add(const WatchAccountsStarted()),
              ),
              BlocProvider<TransactionBloc>(
                create: (context) => TransactionBloc(sl<TransactionRepository>())..add(const WatchTransactionsStarted()),
              ),
              BlocProvider<BudgetBloc>(
                create: (context) => BudgetBloc(sl<BudgetRepository>())..add(const WatchBudgetsStarted()),
              ),
              BlocProvider<DebtBloc>(
                create: (context) => DebtBloc(sl<DebtRepository>(), sl<NotificationService>())..add(const WatchDebtsStarted()),
              ),
              BlocProvider<InstallmentBloc>(
                create: (context) => InstallmentBloc(sl<InstallmentRepository>(), sl<NotificationService>())..add(const WatchInstallmentsStarted()),
              ),
              BlocProvider<CheckBloc>(
                create: (context) => CheckBloc(sl<CheckRepository>(), sl<NotificationService>(), sl<AutoVoucherService>())..add(const WatchChecksStarted()),
              ),
              BlocProvider<AssetBloc>(
                create: (context) => AssetBloc(sl<AssetRepository>())..add(const WatchAssetsStarted()),
              ),
              BlocProvider<BusinessBloc>(
                create: (context) => BusinessBloc(sl<BusinessRepository>(), sl<AutoVoucherService>())..add(const WatchBusinessDataStarted()),
              ),
              BlocProvider<AiAssistantBloc>(
                create: (context) => sl<AiAssistantBloc>()..add(const AiAssistantContextRefreshed()),
              ),
              BlocProvider<SyncBloc>(
                create: (context) => sl<SyncBloc>()..add(const SyncInitRequested()),
              ),
              BlocProvider<SecurityCubit>(
                create: (context) => sl<SecurityCubit>()..init(),
              ),
              BlocProvider<AccountingDocumentBloc>(
                create: (context) => sl<AccountingDocumentBloc>(),
              ),
              BlocProvider<ChartOfAccountsCubit>(
                create: (context) => sl<ChartOfAccountsCubit>(),
              ),
              BlocProvider<TrialBalanceBloc>(
                create: (context) => sl<TrialBalanceBloc>(),
              ),
              BlocProvider<LedgerBloc>(
                create: (context) => sl<LedgerBloc>(),
              ),
              BlocProvider<FinancialStatementsBloc>(
                create: (context) => sl<FinancialStatementsBloc>(),
              ),
            ],
            child: MaterialApp.router(
              title: 'Kifino',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settings.themeMode,
              locale: settings.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: AppRouter.router,
              builder: (context, child) {
                return _LifecycleLockObserver(
                  cubit: context.read<SecurityCubit>(),
                  child: BlocBuilder<SecurityCubit, SecurityState>(
                    builder: (context, secState) {
                      return Stack(
                        children: [
                          ?child,
                          if (secState.isLocked) const LockPage(),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
