import 'package:flutter/material.dart';

import '../../core/design_system/tokens/colors.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// SEMANTIC COLOR LAYER (light/dark resolved values) — Kifino 2
///
/// Every value maps onto [KifinoPalette] primitives — screens never see raw
/// hex. Key names are stable across palette migrations so existing screens
/// keep compiling while the whole brand shifts underneath them. (The
/// `primaryBlue*` names are historical: the brand is now Firoozeh.)
/// ─────────────────────────────────────────────────────────────────────────
class AppColors {
  // Brand — Firoozeh (turquoise).
  static const Color primaryBlueLight = KifinoPalette.firoozeh700;
  static const Color primaryBlueDark = KifinoPalette.firoozeh400;
  static const Color primaryTintLight = KifinoPalette.firoozeh50;
  static const Color primaryTintDark = Color(0xFF0E2F33);
  static const Color accentIndigo = KifinoPalette.violet500;
  static const Color accentIndigoLight = KifinoPalette.violet300;

  // Ink — hero surfaces and strong text.
  static const Color ink = KifinoPalette.ink900;
  static const Color inkDeep = KifinoPalette.ink950;
  static const Color onInk = KifinoPalette.night50;
  static const Color onInkSecondary = Color(0xFF9FB3C8);

  // Gold — goals, achievements, premium.
  static const Color gold = KifinoPalette.gold600;
  static const Color goldDark = KifinoPalette.gold400;
  static const Color goldBgLight = KifinoPalette.gold100;
  static const Color goldBgDark = Color(0xFF33290F);

  // Standard Semantic Shortcuts
  static const Color primary = primaryBlueLight;
  static const Color income = incomeLight;
  static const Color expense = expenseLight;
  static const Color warning = KifinoPalette.warning;
  static const Color danger = expenseLight;
  static const Color info = KifinoPalette.info;
  static const Color receivable = receivableLight;
  static const Color asset = accentIndigo;
  static const Color lightSubtext = lightTextSecondary;
  static const Color darkSubtext = darkTextSecondary;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;

  // Financial Semantic — Income (Emerald)
  static const Color incomeLight = KifinoPalette.success;
  static const Color incomeDark = KifinoPalette.successDark;
  static const Color incomeBgLight = Color(0xFFE4F4EA);
  static const Color incomeBgDark = Color(0xFF0D2A1C);

  // Financial Semantic — Expense (Pomegranate)
  static const Color expenseLight = KifinoPalette.error;
  static const Color expenseDark = KifinoPalette.errorDark;
  static const Color expenseBgLight = Color(0xFFFBE7E7);
  static const Color expenseBgDark = Color(0xFF34161A);

  // Financial Semantic — Transfer (Indigo) & Debt (Amber)
  static const Color transferLight = KifinoPalette.indigo500;
  static const Color transferDark = KifinoPalette.indigo300;
  static const Color debtOrangeLight = KifinoPalette.amber500;
  static const Color debtOrangeDark = KifinoPalette.amber300;

  // Financial Semantic — Receivable (Sky) & Asset (Violet)
  static const Color receivableLight = KifinoPalette.sky500;
  static const Color receivableDark = KifinoPalette.sky300;
  static const Color receivableBgLight = Color(0xFFE5F0FB);
  static const Color receivableBgDark = Color(0xFF0E2238);
  static const Color assetLight = KifinoPalette.violet500;
  static const Color assetDark = KifinoPalette.violet300;
  static const Color assetBgLight = Color(0xFFEFEAFC);
  static const Color assetBgDark = Color(0xFF221A3D);

  // Light Theme Neutrals (warm sand)
  static const Color lightSurface = KifinoPalette.sand0;
  static const Color lightBackground = KifinoPalette.sand50;
  static const Color lightSurfaceVariant = KifinoPalette.sand100;
  static const Color lightBorder = KifinoPalette.sand200;
  static const Color lightTextPrimary = KifinoPalette.ink900;
  static const Color lightTextSecondary = KifinoPalette.sand600;
  static const Color lightTextTertiary = KifinoPalette.sand400;

  // Dark Theme Neutrals (night — never pure black)
  static const Color darkSurface = KifinoPalette.night900;
  static const Color darkBackground = KifinoPalette.night950;
  static const Color darkSurfaceVariant = KifinoPalette.night800;
  static const Color darkSurfaceElevated = KifinoPalette.night800;
  static const Color darkBorder = KifinoPalette.night700;
  static const Color darkTextPrimary = KifinoPalette.night50;
  static const Color darkTextSecondary = KifinoPalette.night300;
  static const Color darkTextTertiary = KifinoPalette.night400;

  // Business Mode Accent (Gold)
  static const Color businessPurpleLight = KifinoPalette.gold600;
  static const Color businessPurpleDark = KifinoPalette.gold400;
  static const Color businessBgLight = KifinoPalette.gold100;
  static const Color businessBgDark = Color(0xFF33290F);
}

@immutable
class KifinoColorsExtension extends ThemeExtension<KifinoColorsExtension> {
  final Color income;
  final Color incomeBg;
  final Color expense;
  final Color expenseBg;
  final Color transfer;
  final Color warning;
  final Color business;
  final Color businessBg;
  final Color receivable;
  final Color receivableBg;
  final Color asset;
  final Color assetBg;
  final Color info;
  final Color surfaceVariant;
  final Color surfaceBorder;
  final Color textTertiary;

  Color get primary => surfaceVariant == AppColors.lightSurfaceVariant
      ? AppColors.primaryBlueLight
      : AppColors.primaryBlueDark;

  Color get textPrimary => surfaceVariant == AppColors.lightSurfaceVariant
      ? AppColors.lightTextPrimary
      : AppColors.darkTextPrimary;

  Color get textSecondary => surfaceVariant == AppColors.lightSurfaceVariant
      ? AppColors.lightTextSecondary
      : AppColors.darkTextSecondary;

  const KifinoColorsExtension({
    required this.income,
    required this.incomeBg,
    required this.expense,
    required this.expenseBg,
    required this.transfer,
    required this.warning,
    required this.business,
    required this.businessBg,
    required this.receivable,
    required this.receivableBg,
    required this.asset,
    required this.assetBg,
    required this.info,
    required this.surfaceVariant,
    required this.surfaceBorder,
    required this.textTertiary,
  });

  static const light = KifinoColorsExtension(
    income: AppColors.incomeLight,
    incomeBg: AppColors.incomeBgLight,
    expense: AppColors.expenseLight,
    expenseBg: AppColors.expenseBgLight,
    transfer: AppColors.transferLight,
    warning: AppColors.warning,
    business: AppColors.businessPurpleLight,
    businessBg: AppColors.businessBgLight,
    receivable: AppColors.receivableLight,
    receivableBg: AppColors.receivableBgLight,
    asset: AppColors.assetLight,
    assetBg: AppColors.assetBgLight,
    info: AppColors.info,
    surfaceVariant: AppColors.lightSurfaceVariant,
    surfaceBorder: AppColors.lightBorder,
    textTertiary: AppColors.lightTextTertiary,
  );

  static const dark = KifinoColorsExtension(
    income: AppColors.incomeDark,
    incomeBg: AppColors.incomeBgDark,
    expense: AppColors.expenseDark,
    expenseBg: AppColors.expenseBgDark,
    transfer: AppColors.transferDark,
    warning: AppColors.debtOrangeDark,
    business: AppColors.businessPurpleDark,
    businessBg: AppColors.businessBgDark,
    receivable: AppColors.receivableDark,
    receivableBg: AppColors.receivableBgDark,
    asset: AppColors.assetDark,
    assetBg: AppColors.assetBgDark,
    info: AppColors.info,
    surfaceVariant: AppColors.darkSurfaceVariant,
    surfaceBorder: AppColors.darkBorder,
    textTertiary: AppColors.darkTextTertiary,
  );

  @override
  KifinoColorsExtension copyWith({
    Color? income,
    Color? incomeBg,
    Color? expense,
    Color? expenseBg,
    Color? transfer,
    Color? warning,
    Color? business,
    Color? businessBg,
    Color? receivable,
    Color? receivableBg,
    Color? asset,
    Color? assetBg,
    Color? info,
    Color? surfaceVariant,
    Color? surfaceBorder,
    Color? textTertiary,
  }) {
    return KifinoColorsExtension(
      income: income ?? this.income,
      incomeBg: incomeBg ?? this.incomeBg,
      expense: expense ?? this.expense,
      expenseBg: expenseBg ?? this.expenseBg,
      transfer: transfer ?? this.transfer,
      warning: warning ?? this.warning,
      business: business ?? this.business,
      businessBg: businessBg ?? this.businessBg,
      receivable: receivable ?? this.receivable,
      receivableBg: receivableBg ?? this.receivableBg,
      asset: asset ?? this.asset,
      assetBg: assetBg ?? this.assetBg,
      info: info ?? this.info,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  KifinoColorsExtension lerp(
    ThemeExtension<KifinoColorsExtension>? other,
    double t,
  ) {
    if (other is! KifinoColorsExtension) return this;
    return KifinoColorsExtension(
      income: Color.lerp(income, other.income, t)!,
      incomeBg: Color.lerp(incomeBg, other.incomeBg, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseBg: Color.lerp(expenseBg, other.expenseBg, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      business: Color.lerp(business, other.business, t)!,
      businessBg: Color.lerp(businessBg, other.businessBg, t)!,
      receivable: Color.lerp(receivable, other.receivable, t)!,
      receivableBg: Color.lerp(receivableBg, other.receivableBg, t)!,
      asset: Color.lerp(asset, other.asset, t)!,
      assetBg: Color.lerp(assetBg, other.assetBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

extension BuildContextColors on BuildContext {
  KifinoColorsExtension get customColors =>
      Theme.of(this).extension<KifinoColorsExtension>() ??
      KifinoColorsExtension.light;
}
