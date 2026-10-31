import 'package:flutter/material.dart';

import '../../core/design_system/tokens/colors.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// SEMANTIC COLOR LAYER (light/dark resolved values)
///
/// Every value maps onto [KifinoPalette] primitives — screens never see raw
/// hex. Key names are stable across the palette migration so existing
/// screens keep compiling while the whole brand shifts underneath them.
/// ─────────────────────────────────────────────────────────────────────────
class AppColors {
  // Brand — Electric Blue is the light-theme primary, Bright Blue the dark.
  static const Color primaryBlueLight = KifinoPalette.blue600; // #247BFF
  static const Color primaryBlueDark = KifinoPalette.blue500; // #3187FF
  static const Color accentIndigo = KifinoPalette.purple400; // #8B7CFF (asset accent)
  static const Color accentIndigoLight = Color(0xFFA794FF);

  // Standard Semantic Shortcuts
  static const Color primary = primaryBlueLight;
  static const Color income = incomeLight;
  static const Color expense = expenseLight;
  static const Color warning = Color(0xFFFFB547);
  static const Color danger = expenseLight;
  static const Color info = KifinoPalette.info;
  static const Color receivable = receivableLight;
  static const Color asset = accentIndigo;
  static const Color lightSubtext = lightTextSecondary;
  static const Color darkSubtext = darkTextSecondary;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;

  // Financial Semantic — Income (Emerald)
  static const Color incomeLight = KifinoPalette.emerald500; // #25C997
  static const Color incomeDark = KifinoPalette.mint400; // #39E6A5
  static const Color incomeBgLight = Color(0xFFE7FAF3);
  static const Color incomeBgDark = Color(0xFF0B2E24);

  // Financial Semantic — Expense (Coral)
  static const Color expenseLight = KifinoPalette.error; // #FF5C6C
  static const Color expenseDark = Color(0xFFFF7A87);
  static const Color expenseBgLight = Color(0xFFFFECEE);
  static const Color expenseBgDark = Color(0xFF3A1218);

  // Financial Semantic — Transfer (Blue) & Debt (Orange)
  static const Color transferLight = KifinoPalette.blue600;
  static const Color transferDark = KifinoPalette.cyan500;
  static const Color debtOrangeLight = KifinoPalette.orange400; // #FF9F43
  static const Color debtOrangeDark = KifinoPalette.yellow400; // #FFCA58

  // Financial Semantic — Receivable (Cyan) & Asset (Purple)
  static const Color receivableLight = KifinoPalette.cyan500;
  static const Color receivableDark = Color(0xFF4CD6F0);
  static const Color receivableBgLight = Color(0xFFE4F8FC);
  static const Color receivableBgDark = Color(0xFF082E38);
  static const Color assetLight = KifinoPalette.purple400;
  static const Color assetDark = Color(0xFFA794FF);
  static const Color assetBgLight = Color(0xFFF0EEFE);
  static const Color assetBgDark = Color(0xFF1D1638);

  // Light Theme Neutrals
  static const Color lightSurface = KifinoPalette.neutral0; // #FFFFFF
  static const Color lightBackground = Color(0xFFF6F8FC);
  static const Color lightSurfaceVariant = KifinoPalette.neutral100; // #F1F5F9
  static const Color lightBorder = Color(0xFFE8EDF4); // subtle
  static const Color lightTextPrimary = Color(0xFF0B1220);
  static const Color lightTextSecondary = Color(0xFF687386);
  static const Color lightTextTertiary = KifinoPalette.neutral400; // #94A3B8

  // Dark Theme Neutrals ( — intentionally designed, never pure black)
  static const Color darkSurface = Color(0xFF0D1B2D);
  static const Color darkBackground = KifinoPalette.neutral950; // #07111F
  static const Color darkSurfaceVariant = Color(0xFF12243A);
  static const Color darkSurfaceElevated = Color(0xFF12243A);
  static const Color darkBorder = Color(0xFF1D3350);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = KifinoPalette.neutral400; // #94A3B8
  static const Color darkTextTertiary = KifinoPalette.neutral500; // #64748B

  // Business Mode Accent (Purple)
  static const Color businessPurpleLight = KifinoPalette.purple400;
  static const Color businessPurpleDark = Color(0xFFA794FF);
  static const Color businessBgLight = Color(0xFFF0EEFE);
  static const Color businessBgDark = Color(0xFF1D1638);
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
  KifinoColorsExtension lerp(ThemeExtension<KifinoColorsExtension>? other, double t) {
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
      Theme.of(this).extension<KifinoColorsExtension>() ?? KifinoColorsExtension.light;
}
