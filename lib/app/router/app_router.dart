import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/assets/presentation/pages/assets_page.dart';
import '../../features/backup/presentation/pages/backup_page.dart';
import '../../features/business/presentation/pages/business_page.dart';
import '../../features/checks/presentation/pages/checks_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/debts/presentation/pages/debts_page.dart';
import '../../features/goals/presentation/pages/goals_page.dart';
import '../../features/installments/presentation/pages/installments_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_flow_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/security/presentation/pages/security_settings_page.dart';
import '../../features/settings/presentation/pages/more_page.dart';
import '../../features/sync/presentation/pages/sync_page.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import '../../features/transactions/presentation/pages/activity_page.dart';
import '../../features/transactions/presentation/pages/fast_add_transaction_page.dart';
import '../../features/accounting/presentation/pages/accounting_dashboard_page.dart';
import '../../features/accounting/presentation/pages/voucher_settings_page.dart';
import '../../features/accounting/presentation/pages/accounting_documents_page.dart';
import '../../features/accounting/presentation/pages/audit_log_page.dart';
import '../../features/accounting/presentation/pages/bank_reconciliation_page.dart';
import '../../features/accounting/presentation/pages/create_accounting_document_page.dart';
import '../../features/accounting/presentation/pages/chart_of_accounts_page.dart';
import '../../features/accounting/presentation/pages/detail_ledgers_page.dart';
import '../../features/accounting/presentation/pages/detail_report_page.dart';
import '../../features/accounting/presentation/pages/fiscal_years_page.dart';
import '../../features/accounting/presentation/pages/journal_page.dart';
import '../../features/accounting/presentation/pages/ledger_page.dart';
import '../../features/accounting/presentation/pages/treasury_page.dart';
import '../../features/accounting/presentation/pages/trial_balance_page.dart';
import '../../features/accounting/presentation/pages/financial_statements_page.dart';
import '../../features/business/presentation/pages/product_card_page.dart';
import '../../core/design_system/showcase/design_system_showcase_page.dart';
import 'scaffold_with_nav_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  /// Mirrors [SettingsState.onboardingCompleted] so the router redirect can
  /// gate first-run users without a widget-level dependency. Updated by
  /// [SettingsCubit]; call [refresh] after mutating it.
  static bool onboardingCompleted = false;

  static void refresh() => router.refresh();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');
      if (!onboardingCompleted && !isOnboarding) return '/onboarding';
      if (onboardingCompleted && isOnboarding) return '/dashboard';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/business',
                builder: (context, state) => const BusinessPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MorePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/transaction/new',
        builder: (context, state) {
          final extra = state.extra;
          return FastAddTransactionPage(
            initialType: extra is String ? extra : null,
            editTransaction: extra is TransactionEntity ? extra : null,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounts',
        builder: (context, state) => const AccountsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/goals',
        builder: (context, state) => const GoalsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/debts',
        builder: (context, state) => const DebtsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/installments',
        builder: (context, state) => const InstallmentsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/checks',
        builder: (context, state) => const ChecksPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/assets',
        builder: (context, state) => const AssetsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ai',
        builder: (context, state) => const AiAssistantPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sync',
        builder: (context, state) => const SyncPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/security',
        builder: (context, state) => const SecuritySettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/backup',
        builder: (context, state) => const BackupPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/design-system',
        builder: (context, state) => const DesignSystemShowcasePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting',
        builder: (context, state) => const AccountingDashboardPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/documents',
        builder: (context, state) => const AccountingDocumentsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/documents/create',
        builder: (context, state) => const CreateAccountingDocumentPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/chart-of-accounts',
        builder: (context, state) => const ChartOfAccountsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/journal',
        builder: (context, state) => const JournalPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/ledger',
        builder: (context, state) {
          final extra = state.extra;
          return LedgerPage(initialSubjectId: extra is String ? extra : null);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/trial-balance',
        builder: (context, state) => const TrialBalancePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/financial-statements',
        builder: (context, state) => const FinancialStatementsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/audit-logs',
        builder: (context, state) => const AuditLogPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/detail-ledgers',
        builder: (context, state) => const DetailLedgersPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/detail-ledgers/report',
        builder: (context, state) {
          final extra = state.extra;
          return DetailReportPage(
            initialSelection: extra is DetailReportSelection ? extra : null,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/voucher-settings',
        builder: (context, state) => const VoucherSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/fiscal-years',
        builder: (context, state) => const FiscalYearsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/treasury',
        builder: (context, state) => const TreasuryPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounting/treasury/reconcile',
        builder: (context, state) {
          final extra = state.extra;
          return BankReconciliationPage(
            accountId: extra is String ? extra : '',
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/business/products/card',
        builder: (context, state) {
          final extra = state.extra;
          return ProductCardPage(productId: extra is String ? extra : '');
        },
      ),
    ],
  );
}
