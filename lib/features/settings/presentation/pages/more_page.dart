import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/di/company_controller.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_card.dart';
import '../widgets/company_switcher_sheet.dart';
import '../../../../core/database/company_registry.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPersian = l10n.isPersian;

    final managementItems = [
      (
        Icons.account_balance_wallet_outlined,
        isPersian ? 'حساب‌ها و کارت‌ها' : 'Accounts & Cards',
        '/accounts',
      ),
      (
        Icons.category_outlined,
        isPersian ? 'دسته‌بندی‌های سفارشی' : 'Custom categories',
        '/categories',
      ),
      (
        Icons.flag_outlined,
        isPersian ? 'اهداف مالی و پس‌انداز' : 'Financial goals',
        '/goals',
      ),
      (Icons.handshake_outlined, l10n.debts, '/debts'),
      (Icons.calendar_month_outlined, l10n.installments, '/installments'),
      (Icons.fact_check_outlined, l10n.checks, '/checks'),
      (Icons.savings_outlined, l10n.assets, '/assets'),
      (
        Icons.storefront_outlined,
        isPersian ? 'مدیریت کسب‌وکار و فاکتورها' : 'Business & Invoices',
        '/business',
      ),
      (Icons.auto_awesome_rounded, l10n.aiAssistant, '/ai'),
    ];

    final systemItems = [
      (
        Icons.notifications_outlined,
        isPersian ? 'اعلان‌ها و یادآورها' : 'Notifications',
        '/notifications',
      ),
      (
        Icons.cloud_sync_outlined,
        isPersian ? 'همگام‌سازی ابری (به‌زودی)' : 'Cloud sync (Coming soon)',
        '/sync',
      ),
      (
        Icons.security_outlined,
        isPersian ? 'امنیت و رمز عبور' : 'Security & PIN',
        '/security',
      ),
      (
        Icons.backup_outlined,
        isPersian ? 'پشتیبان‌گیری و بازیابی' : 'Backup & restore',
        '/backup',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _CompanyCard(isPersian: isPersian),
          const SizedBox(height: AppSpacing.lg),
          _SettingsSection(isPersian: isPersian),
          const SizedBox(height: AppSpacing.lg),

          // Enterprise Accounting OS Hero Card
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final accent = Theme.of(context).colorScheme.primary;
              return AppCard(
                onTap: () => context.push('/accounting'),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: AppSpacing.borderRadiusMd,
                    gradient: LinearGradient(
                      colors: [
                        Colors.indigo.withValues(alpha: 0.12),
                        Colors.indigo.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.account_balance,
                          color: accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isPersian
                                        ? 'سیستم حسابداری مالی (دوبل)'
                                        : 'Financial Accounting OS',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkBackground
                                          : Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isPersian
                                  ? 'اسناد دوبل، کدینگ، دفاتر قانونی، تراز آزمایشی و ترازنامه'
                                  : 'General ledger, journal vouchers, trial balance & statements',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_left_rounded, color: accent),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          _SectionHeader(
            label: isPersian ? 'مدیریت مالی' : 'Financial management',
          ),
          const SizedBox(height: AppSpacing.sm),
          ...managementItems.map((item) => _MoreRow(item: item)),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(label: isPersian ? 'سیستم' : 'System'),
          const SizedBox(height: AppSpacing.sm),
          ...systemItems.map((item) => _MoreRow(item: item)),
          const SizedBox(height: AppSpacing.lg),
          _MoreRow(
            item: (
              Icons.palette_outlined,
              isPersian
                  ? 'نمایش سیستم طراحی (توسعه‌دهنده)'
                  : 'Design system showcase (dev)',
              '/design-system',
            ),
          ),
        ],
      ),
    );
  }
}

/// Company switcher entry (Phase 5): shows the active دفتر and opens the
/// switcher sheet. Switching rebuilds the whole app under the new company.
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
        if (snapshot.hasData) {
          for (final c in snapshot.data!) {
            if (c.id == activeId) active = c;
          }
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          onTap: () => showCompanySwitcherSheet(context),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.domain_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPersian ? 'شرکت / دفتر فعال' : 'Active company',
                      style: AppTypography.labelMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active?.name ?? (isPersian ? '…' : '…'),
                      style: AppTypography.titleMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Inline settings (theme, language, base currency) — every choice persists
/// immediately through [SettingsCubit] and applies app-wide.
class _SettingsSection extends StatelessWidget {
  final bool isPersian;

  const _SettingsSection({required this.isPersian});

  static const String _themeSystemFa = 'سیستم';
  static const String _themeLightFa = 'روشن';
  static const String _themeDarkFa = 'تاریک';

  static String themeLabel(ThemeMode mode, bool isPersian) {
    final fa = switch (mode) {
      ThemeMode.system => _themeSystemFa,
      ThemeMode.light => _themeLightFa,
      ThemeMode.dark => _themeDarkFa,
    };
    return isPersian
        ? fa
        : switch (mode) {
            ThemeMode.system => 'System',
            ThemeMode.light => 'Light',
            ThemeMode.dark => 'Dark',
          };
  }

  static String langLabel(Locale locale, bool isPersian) =>
      locale.languageCode == 'fa' ? 'فارسی' : 'English';

  static String _currencyLabelFa(Currency currency) => switch (currency) {
    Currency.toman => 'تومان',
    Currency.irr => 'ریال',
    Currency.usd => 'دلار آمریکا',
    Currency.eur => 'یورو',
    Currency.aed => 'درهم امارات',
    Currency.tryCurrency => 'لیر ترکیه',
    Currency.gbp => 'پوند انگلیس',
  };

  Future<void> _pickTheme(BuildContext context, SettingsState state) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => AppBottomSheet(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(title: isPersian ? 'حالت نمایش' : 'Appearance'),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(_themeSystemFa),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(_themeLightFa),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(_themeDarkFa),
                  ),
                ],
                selected: {state.themeMode},
                onSelectionChanged: (selection) {
                  context.read<SettingsCubit>().setThemeMode(selection.first);
                  Navigator.pop(sheetContext);
                },
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => AppBottomSheet(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(
                  title: isPersian ? 'زبان برنامه' : 'App language',
                ),
                const SizedBox(height: AppSpacing.sm),
                RadioGroup<String>(
                  groupValue: context
                      .read<SettingsCubit>()
                      .state
                      .locale
                      .languageCode,
                  onChanged: (code) {
                    context.read<SettingsCubit>().setLocale(Locale(code!));
                    Navigator.pop(sheetContext);
                  },
                  child: Column(
                    children: [
                      for (final (code, label) in [
                        ('fa', 'فارسی — RTL'),
                        ('en', 'English — LTR'),
                      ])
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppSpacing.borderRadiusMd,
                          ),
                          title: Text(label),
                          trailing: Radio<String>(value: code),
                          onTap: () {
                            context.read<SettingsCubit>().setLocale(
                              Locale(code),
                            );
                            Navigator.pop(sheetContext);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => AppBottomSheet(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(title: isPersian ? 'ارز پایه' : 'Base currency'),
                Text(
                  isPersian
                      ? 'مبالغ تومان و ریال به این واحد نرمال می‌شوند؛ ارزهای خارجی دست‌نخورده می‌مانند.'
                      : 'Toman/Rial amounts are normalized to this unit; foreign currencies stay untouched.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      RadioGroup<String>(
                        groupValue: context
                            .read<SettingsCubit>()
                            .state
                            .currency
                            .code,
                        onChanged: (code) {
                          final match = Currency.values
                              .where((c) => c.code == code)
                              .firstOrNull;
                          if (match != null) {
                            context.read<SettingsCubit>().setCurrency(match);
                          }
                          Navigator.pop(sheetContext);
                        },
                        child: Column(
                          children: [
                            for (final currency in Currency.values)
                              ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppSpacing.borderRadiusMd,
                                ),
                                leading: Text(
                                  currency.symbol,
                                  style: AppTypography.titleMedium,
                                ),
                                title: Text(currency.code),
                                subtitle: Text(currency.displayName),
                                trailing: Radio<String>(value: currency.code),
                                onTap: () {
                                  context.read<SettingsCubit>().setCurrency(
                                    currency,
                                  );
                                  Navigator.pop(sheetContext);
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.dark_mode_outlined,
                title: isPersian ? 'حالت نمایش' : 'Appearance',
                value: themeLabel(state.themeMode, isPersian),
                onTap: () => _pickTheme(context, state),
              ),
              Divider(
                height: 1,
                indent: AppSpacing.xl,
                color: Theme.of(context).dividerColor,
              ),
              _SettingRow(
                icon: Icons.language_rounded,
                title: isPersian ? 'زبان' : 'Language',
                value: langLabel(state.locale, isPersian),
                onTap: () => _pickLanguage(context),
              ),
              Divider(
                height: 1,
                indent: AppSpacing.xl,
                color: Theme.of(context).dividerColor,
              ),
              _SettingRow(
                icon: Icons.currency_exchange_rounded,
                title: isPersian ? 'ارز پایه' : 'Base currency',
                value: isPersian
                    ? _currencyLabelFa(state.currency)
                    : state.currency.code,
                onTap: () => _pickCurrency(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: AppTypography.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.labelLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 4),
          const _ForwardChevron(),
        ],
      ),
    );
  }
}

/// Forward chevron that mirrors for RTL — 'go forward' always points toward
/// the leading edge of reading direction.
class _ForwardChevron extends StatelessWidget {
  const _ForwardChevron();

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: 20,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  final (IconData, String, String) item;

  const _MoreRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        onTap: () => context.push(item.$3),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.$1,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(item.$2, style: AppTypography.titleMedium)),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
