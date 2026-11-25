import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/company_registry.dart';
import '../../../../core/di/company_controller.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_kit.dart';
import '../../../../core/widgets/app_responsive_container.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../widgets/company_switcher_sheet.dart';

/// «بیشتر»: the hub — the active ledger, every money tool in one grid,
/// accounting, then grouped preferences and system settings.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPersian = l10n.isPersian;
    final colors = context.customColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final tools = <(IconData, String, String, Color)>[
      (
        Icons.account_balance_wallet_outlined,
        isPersian ? 'حساب‌ها' : 'Accounts',
        '/accounts',
        primary,
      ),
      (
        Icons.event_repeat_rounded,
        isPersian ? 'تکراری‌ها' : 'Recurring',
        '/recurring',
        primary,
      ),
      (
        Icons.flag_outlined,
        isPersian ? 'اهداف' : 'Goals',
        '/goals',
        colors.income,
      ),
      (
        Icons.category_outlined,
        isPersian ? 'دسته‌ها' : 'Categories',
        '/categories',
        colors.asset,
      ),
      (
        Icons.handshake_outlined,
        isPersian ? 'بدهی و طلب' : 'Debts',
        '/debts',
        isDark ? AppColors.debtOrangeDark : AppColors.debtOrangeLight,
      ),
      (
        Icons.calendar_month_outlined,
        isPersian ? 'اقساط' : 'Loans',
        '/installments',
        colors.transfer,
      ),
      (
        Icons.fact_check_outlined,
        isPersian ? 'چک‌ها' : 'Checks',
        '/checks',
        colors.warning,
      ),
      (
        Icons.diamond_outlined,
        isPersian ? 'دارایی‌ها' : 'Assets',
        '/assets',
        colors.asset,
      ),
      (
        Icons.storefront_outlined,
        isPersian ? 'کسب‌وکار' : 'Business',
        '/business',
        colors.business,
      ),
      (
        Icons.auto_awesome_outlined,
        isPersian ? 'دستیار' : 'Assistant',
        '/ai',
        colors.business,
      ),
      (
        Icons.manage_search_rounded,
        isPersian ? 'جستجو' : 'Search',
        '/search',
        colors.textSecondary,
      ),
      (
        Icons.notifications_none_rounded,
        isPersian ? 'اعلان‌ها' : 'Alerts',
        '/notifications',
        colors.textSecondary,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: AppResponsiveContainer.settings(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            _CompanyCard(isPersian: isPersian),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: isPersian ? 'ابزارهای مالی' : 'Money tools',
            ),
            AppChoiceGrid<String>(
              choices: [
                for (final (icon, label, route, color) in tools)
                  AppChoice<String>(
                    label: label,
                    icon: icon,
                    color: color,
                    // Tab destinations switch tabs; the rest stack on top.
                    onTap: () =>
                        const {'/business', '/analytics'}.contains(route)
                        ? context.go(route)
                        : context.push(route),
                  ),
              ],
              selected: null,
              onSelected: (_) {},
            ),
            const SizedBox(height: AppSpacing.lg),
            AppListGroup(
              children: [
                AppListRow(
                  icon: Icons.account_balance_outlined,
                  iconColor: colors.business,
                  title: isPersian
                      ? 'حسابداری دوبل'
                      : 'Double-entry accounting',
                  subtitle: isPersian
                      ? 'اسناد، دفاتر قانونی، تراز آزمایشی و ترازنامه'
                      : 'Vouchers, ledgers, trial balance, statements',
                  trailing: const AppStatusBadge(
                    label: 'PRO',
                    icon: Icons.workspace_premium_outlined,
                    tone: AppStatusTone.premium,
                  ),
                  onTap: () => context.push('/accounting'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _PreferencesGroup(isPersian: isPersian),
            const SizedBox(height: AppSpacing.lg),
            AppListGroup(
              title: isPersian ? 'سیستم' : 'System',
              children: [
                AppListRow(
                  icon: Icons.lock_outline_rounded,
                  title: isPersian ? 'امنیت و رمز عبور' : 'Security & PIN',
                  subtitle: isPersian
                      ? 'قفل برنامه، اثر انگشت، اسکرین‌شات'
                      : 'App lock, biometrics, screenshots',
                  onTap: () => context.push('/security'),
                ),
                AppListRow(
                  icon: Icons.cloud_download_outlined,
                  title: isPersian
                      ? 'پشتیبان‌گیری و بازیابی'
                      : 'Backup & restore',
                  subtitle: isPersian
                      ? 'فایل رمزنگاری‌شده، خروجی اکسل، بازسازی مانده‌ها'
                      : 'Encrypted file, CSV export, balance repair',
                  onTap: () => context.push('/backup'),
                ),
                AppListRow(
                  icon: Icons.cloud_sync_outlined,
                  iconColor: colors.textTertiary,
                  title: isPersian ? 'همگام‌سازی ابری' : 'Cloud sync',
                  trailing: AppStatusBadge(
                    label: isPersian ? 'به‌زودی' : 'Soon',
                    icon: Icons.schedule_rounded,
                  ),
                  onTap: () => context.push('/sync'),
                ),
                if (kDebugMode)
                  AppListRow(
                    icon: Icons.palette_outlined,
                    iconColor: colors.asset,
                    title: isPersian ? 'سیستم طراحی' : 'Design system',
                    subtitle: isPersian
                        ? 'فقط در نسخه توسعه'
                        : 'Debug builds only',
                    onTap: () => context.push('/design-system'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                TextNormalizer.auto(
                  '${isPersian ? 'کیفینو' : 'Kifino'} ${AppConstants.appVersion}',
                ),
                style: AppTypography.labelMedium.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final bool isPersian;

  const _CompanyCard({required this.isPersian});

  @override
  Widget build(BuildContext context) {
    final controller = sl<CompanyController>();
    return FutureBuilder<List<CompanyInfo>>(
      future: controller.companies(),
      builder: (context, snapshot) {
        final activeId = controller.activeCompanyId;
        CompanyInfo? active;
        for (final c in snapshot.data ?? const <CompanyInfo>[]) {
          if (c.id == activeId) active = c;
        }
        final count = snapshot.data?.length ?? 1;
        return AppListGroup(
          children: [
            AppListRow(
              icon: Icons.domain_outlined,
              title: active?.name ?? '…',
              subtitle: isPersian
                  ? (count > 1
                        ? TextNormalizer.auto('دفتر فعال · $count دفتر')
                        : 'دفتر فعال · برای افزودن دفتر جدید بزنید')
                  : 'Active ledger',
              onTap: () => showCompanySwitcherSheet(context),
            ),
          ],
        );
      },
    );
  }
}

/// Appearance, language and base currency — applied app-wide at once.
class _PreferencesGroup extends StatelessWidget {
  final bool isPersian;

  const _PreferencesGroup({required this.isPersian});

  static String themeLabel(ThemeMode mode, bool isPersian) => switch (mode) {
    ThemeMode.system => isPersian ? 'مطابق دستگاه' : 'System',
    ThemeMode.light => isPersian ? 'روشن' : 'Light',
    ThemeMode.dark => isPersian ? 'تاریک' : 'Dark',
  };

  static String currencyLabel(Currency c, bool isPersian) {
    if (!isPersian) return c.code;
    return switch (c) {
      Currency.toman => 'تومان',
      Currency.irr => 'ریال',
      Currency.usd => 'دلار آمریکا',
      Currency.eur => 'یورو',
      Currency.aed => 'درهم امارات',
      Currency.tryCurrency => 'لیر ترکیه',
      Currency.gbp => 'پوند انگلیس',
    };
  }

  Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    String? note,
    required List<(T, String, IconData?)> options,
    required T current,
    required ValueChanged<T> onPicked,
  }) async {
    final colors = context.customColors;
    final picked = await showAppSheet<T>(
      context: context,
      title: title,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null) ...[
            Text(
              note,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final (value, label, icon) in options)
            AppListRow(
              icon: icon,
              iconColor: colors.textSecondary,
              title: label,
              showChevron: false,
              trailing: value == current
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(ctx, value),
            ),
        ],
      ),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        return AppListGroup(
          title: isPersian ? 'تنظیمات' : 'Preferences',
          children: [
            AppListRow(
              icon: Icons.contrast_rounded,
              title: isPersian ? 'حالت نمایش' : 'Appearance',
              value: themeLabel(state.themeMode, isPersian),
              onTap: () => _pick<ThemeMode>(
                context,
                title: isPersian ? 'حالت نمایش' : 'Appearance',
                current: state.themeMode,
                options: [
                  (
                    ThemeMode.system,
                    themeLabel(ThemeMode.system, isPersian),
                    Icons.brightness_auto_outlined,
                  ),
                  (
                    ThemeMode.light,
                    themeLabel(ThemeMode.light, isPersian),
                    Icons.light_mode_outlined,
                  ),
                  (
                    ThemeMode.dark,
                    themeLabel(ThemeMode.dark, isPersian),
                    Icons.dark_mode_outlined,
                  ),
                ],
                onPicked: cubit.setThemeMode,
              ),
            ),
            AppListRow(
              icon: Icons.translate_rounded,
              title: isPersian ? 'زبان' : 'Language',
              value: state.locale.languageCode == 'fa' ? 'فارسی' : 'English',
              onTap: () => _pick<String>(
                context,
                title: isPersian ? 'زبان برنامه' : 'App language',
                current: state.locale.languageCode,
                options: const [('fa', 'فارسی', null), ('en', 'English', null)],
                onPicked: (code) => cubit.setLocale(Locale(code)),
              ),
            ),
            AppListRow(
              icon: Icons.currency_exchange_rounded,
              title: isPersian ? 'ارز پایه' : 'Base currency',
              value: currencyLabel(state.currency, isPersian),
              onTap: () => _pick<Currency>(
                context,
                title: isPersian ? 'ارز پایه' : 'Base currency',
                note: isPersian
                    ? 'جمع‌ها و گزارش‌ها به این واحد نمایش داده می‌شوند؛ تومان و ریال خودکار تبدیل می‌شوند.'
                    : 'Totals and reports use this unit; Toman and Rial convert automatically.',
                current: state.currency,
                options: [
                  for (final c in Currency.values)
                    (c, '${currencyLabel(c, isPersian)} (${c.symbol})', null),
                ],
                onPicked: cubit.setCurrency,
              ),
            ),
          ],
        );
      },
    );
  }
}
