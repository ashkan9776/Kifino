import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/onboarding_cubit.dart';

class OnboardingFlowPage extends StatelessWidget {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(sl()),
      child: const _OnboardingFlowView(),
    );
  }
}

class _OnboardingFlowView extends StatefulWidget {
  const _OnboardingFlowView();

  @override
  State<_OnboardingFlowView> createState() => _OnboardingFlowViewState();
}

class _OnboardingFlowViewState extends State<_OnboardingFlowView> {
  static const int _totalSteps = 5;
  static const List<Currency> _secondaryCurrencies = [
    Currency.usd,
    Currency.eur,
    Currency.aed,
    Currency.tryCurrency,
    Currency.gbp,
  ];

  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 2: language — visual selection only, applied on completion.
  bool _isPersian = true;

  // Step 3: currency.
  Currency _selectedCurrency = Currency.toman;

  // Step 4: first account.
  late final TextEditingController _accountNameController;
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _cardLastFourController = TextEditingController();
  AccountType _selectedAccountType = AccountType.bankCard;
  int _initialBalanceMinor = 0;
  bool _skippedAccount = false;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _accountNameController = TextEditingController(text: 'حساب اصلی');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _accountNameController.dispose();
    _bankNameController.dispose();
    _cardLastFourController.dispose();
    super.dispose();
  }

  // Navigation ----------------------------------------------------------------

  void _goToStep(int step) {
    setState(() {
      // Returning to the account step re-enables account creation.
      if (step == 3) _skippedAccount = false;
      _currentStep = step;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextStep() => _goToStep(_currentStep + 1);

  void _previousStep() => _goToStep(_currentStep - 1);

  void _selectLanguage(bool persian) {
    setState(() {
      _isPersian = persian;
      // Keep the prefilled account name in sync while it is still untouched.
      if (_accountNameController.text == 'حساب اصلی' ||
          _accountNameController.text == 'Main account') {
        _accountNameController.text = persian ? 'حساب اصلی' : 'Main account';
      }
    });
  }

  void _skipAccount() {
    setState(() => _skippedAccount = true);
    _nextStep();
  }

  void _submitAccountStep() {
    final isFa = _isPersian;
    if (_accountNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFa
                ? 'لطفاً نام حساب را وارد کنید'
                : 'Please enter an account name',
          ),
          backgroundColor: AppColors.expenseLight,
        ),
      );
      return;
    }
    _nextStep();
  }

  Future<void> _finish({required bool goToAddTransaction}) async {
    if (_isFinishing) return;

    // Capture everything up-front: completing onboarding refreshes the router
    // and may navigate away from this page while we await.
    final onboardingCubit = context.read<OnboardingCubit>();
    final settingsCubit = context.read<SettingsCubit>();
    final router = GoRouter.of(context);

    setState(() => _isFinishing = true);

    // Create the first account while the onboarding gate is still open.
    if (!_skippedAccount && _accountNameController.text.trim().isNotEmpty) {
      final ok = await onboardingCubit.createFirstAccount(
        name: _accountNameController.text,
        type: _selectedAccountType,
        initialBalance: Money.fromMinor(
          _initialBalanceMinor,
          _selectedCurrency,
        ),
        bankName: _bankNameController.text,
        cardLastFour: _cardLastFourController.text,
      );
      if (!ok) {
        if (!mounted) return;
        setState(() => _isFinishing = false);
        final state = onboardingCubit.state;
        if (state is OnboardingAccountFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.expenseLight,
            ),
          );
        }
        return;
      }
    }

    // Persist language + currency choices; this unblocks the router gate.
    // Explicit navigation re-evaluates the redirect with the flag already set.
    await settingsCubit.completeOnboarding(
      locale: Locale(_isPersian ? 'fa' : 'en'),
      currency: _selectedCurrency,
    );

    if (goToAddTransaction) {
      router.go('/dashboard');
      router.push('/transaction/new', extra: 'expense');
    } else {
      router.go('/dashboard');
    }
  }

  // Build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: (_currentStep >= 1 && _currentStep <= 3)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _isFinishing ? null : _previousStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed slot: changing the child count/type here would force the
            // PageView below to remount and snap back to page 0.
            _ProgressDots(currentStep: _currentStep, totalSteps: _totalSteps),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(context),
                  _buildLanguageStep(context),
                  _buildCurrencyStep(context),
                  _buildAccountStep(context),
                  _buildDoneStep(context),
                ],
              ),
            ),
            _BottomBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              isPersian: _isPersian,
              isFinishing: _isFinishing,
              onPrimary: _currentStep == 3 ? _submitAccountStep : _nextStep,
              onSkip: _skipAccount,
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Welcome -----------------------------------------------------------

  Widget _buildWelcomeStep(BuildContext context) {
    final isFa = _isPersian;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                isFa ? 'کیفینو' : 'Kifino',
                style: AppTypography.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isFa
                    ? 'سیستم‌عامل مالی شما'
                    : 'Your Financial Operating System',
                style: AppTypography.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step 2: Language ----------------------------------------------------------

  Widget _buildLanguageStep(BuildContext context) {
    final isFa = _isPersian;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isFa ? 'زبان خود را انتخاب کنید' : 'Choose your language',
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isFa
                ? 'بعداً از تنظیمات هم قابل تغییر است'
                : 'You can change this later in settings',
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _LanguageCard(
                  label: 'فارسی',
                  badge: 'فا',
                  sub: 'RTL',
                  isSelected: _isPersian,
                  onTap: () => _selectLanguage(true),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _LanguageCard(
                  label: 'English',
                  badge: 'EN',
                  sub: 'LTR',
                  isSelected: !_isPersian,
                  onTap: () => _selectLanguage(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 3: Currency ----------------------------------------------------------

  Widget _buildCurrencyStep(BuildContext context) {
    final isFa = _isPersian;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isFa ? 'ارز پایه را انتخاب کنید' : 'Choose your base currency',
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isFa
                ? 'تمام محاسبات بر این اساس انجام می‌شود'
                : 'All calculations are based on this',
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _CurrencyCard(
                  title: isFa ? 'تومان ایران' : 'Iranian Toman',
                  symbol: Currency.toman.symbol,
                  isSelected: _selectedCurrency == Currency.toman,
                  onTap: () =>
                      setState(() => _selectedCurrency = Currency.toman),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _CurrencyCard(
                  title: isFa ? 'ریال ایران' : 'Iranian Rial',
                  symbol: Currency.irr.symbol,
                  isSelected: _selectedCurrency == Currency.irr,
                  onTap: () => setState(() => _selectedCurrency = Currency.irr),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            isFa ? 'سایر ارزها' : 'Other currencies',
            style: AppTypography.labelLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < _secondaryCurrencies.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  _buildCurrencyRow(context, _secondaryCurrencies[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyRow(BuildContext context, Currency currency) {
    final isSelected = _selectedCurrency == currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => setState(() => _selectedCurrency = currency),
      borderRadius: AppSpacing.borderRadiusLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                currency.symbol,
                style: AppTypography.titleMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currency.code, style: AppTypography.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    currency.displayName,
                    style: AppTypography.labelMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary),
            ),
          ],
        ),
      ),
    );
  }

  // Step 4: First account -----------------------------------------------------

  Widget _buildAccountStep(BuildContext context) {
    final isFa = _isPersian;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isFa ? 'حساب اول را بسازید' : 'Create your first account',
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isFa
                ? 'برای شروع ثبت تراکنش به یک حساب نیاز دارید'
                : 'You need an account to start recording transactions',
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _accountNameController,
            decoration: InputDecoration(
              labelText: isFa ? 'نام حساب' : 'Account name',
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isFa ? 'نوع حساب' : 'Account type',
            style: AppTypography.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: AccountType.values.map((type) {
              return ChoiceChip(
                label: Text(isFa ? type.titleFa : type.titleEn),
                selected: _selectedAccountType == type,
                onSelected: (_) => setState(() => _selectedAccountType = type),
              );
            }).toList(),
          ),
          if (_selectedAccountType == AccountType.bankCard) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _bankNameController,
              decoration: InputDecoration(
                labelText: isFa ? 'نام بانک (اختیاری)' : 'Bank name (optional)',
                prefixIcon: const Icon(Icons.account_balance_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _cardLastFourController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [
                PersianDigitsTextInputFormatter(enabled: isFaLocale(context)),
              ],
              decoration: InputDecoration(
                labelText: isFa
                    ? '۴ رقم آخر کارت (اختیاری)'
                    : 'Card last 4 digits (optional)',
                prefixIcon: const Icon(Icons.credit_card_rounded),
                counterText: '',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            isFa ? 'موجودی اولیه (اختیاری)' : 'Initial balance (optional)',
            style: AppTypography.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppAmountField(
            currency: _selectedCurrency,
            autoFocus: false,
            onAmountMinorChanged: (value) => _initialBalanceMinor = value,
          ),
        ],
      ),
    );
  }

  // Step 5: Done --------------------------------------------------------------

  Widget _buildDoneStep(BuildContext context) {
    final isFa = _isPersian;
    final colors = context.customColors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 104,
                height: 104,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.income.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration_rounded,
                  size: 48,
                  color: colors.income,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                isFa
                    ? 'فضای کاری مالی شما آماده است 🎉'
                    : 'Your financial workspace is ready 🎉',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isFa
                    ? 'همه‌چیز برای شروع ثبت تراکنش‌ها آماده است'
                    : 'Everything is set up to start tracking your money',
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: isFa ? 'ثبت اولین تراکنش' : 'Add first transaction',
                onPressed: () => _finish(goToAddTransaction: true),
                isLoading: _isFinishing,
                width: double.infinity,
                variant: AppButtonVariant.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: isFa ? 'رفتن به داشبورد' : 'Go to dashboard',
                onPressed: _isFinishing
                    ? null
                    : () => _finish(goToAddTransaction: false),
                width: double.infinity,
                variant: AppButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Cards -----------------------------------------------------------------------

/// Always-present slot for the step indicator. Renders as [SizedBox.shrink]
/// on the final step — keeping the widget type stable so the [PageView] in
/// the parent [Column] never remounts when the step changes.
class _ProgressDots extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _ProgressDots({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    if (currentStep >= totalSteps - 1) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          final isActive = index == currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              borderRadius: AppSpacing.borderRadiusPill,
            ),
          );
        }),
      ),
    );
  }
}

/// Always-present slot for the primary navigation bar. Same stability rule as
/// [_ProgressDots]: hidden as [SizedBox.shrink] on the final step, never
/// removed from the tree.
class _BottomBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isPersian;
  final bool isFinishing;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  const _BottomBar({
    required this.currentStep,
    required this.totalSteps,
    required this.isPersian,
    required this.isFinishing,
    required this.onPrimary,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (currentStep >= totalSteps - 1) return const SizedBox.shrink();

    final isFa = isPersian;
    final primaryLabel = currentStep == 0
        ? (isFa ? 'شروع کنیم' : 'Get started')
        : (isFa ? 'ادامه' : 'Continue');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: primaryLabel,
            onPressed: isFinishing ? null : onPrimary,
            width: double.infinity,
            variant: AppButtonVariant.primary,
          ),
          if (currentStep == 3) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isFinishing ? null : onSkip,
              child: Text(isFa ? 'رخ دادن بعداً' : 'Do this later'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String label;
  final String badge;
  final String sub;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.label,
    required this.badge,
    required this.sub,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return AppCard(
      onTap: onTap,
      borderColor: borderColor,
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              badge,
              style: AppTypography.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            sub,
            style: AppTypography.labelMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary),
          ),
        ],
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final String title;
  final String symbol;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyCard({
    required this.title,
    required this.symbol,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return AppCard(
      onTap: onTap,
      borderColor: borderColor,
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              symbol,
              style: AppTypography.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary),
          ),
        ],
      ),
    );
  }
}
