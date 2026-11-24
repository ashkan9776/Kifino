import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/tokens/radii.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Kifino 2 theme. Light and dark are generated from one recipe so every
/// component is styled once and the two modes can never drift apart.
class AppTheme {
  static ThemeData get lightTheme => _build(_Tones.light);
  static ThemeData get darkTheme => _build(_Tones.dark);

  static const _textTheme = TextTheme(
    displayLarge: AppTypography.displayLarge,
    displayMedium: AppTypography.displayMedium,
    headlineLarge: AppTypography.displayMedium,
    headlineMedium: AppTypography.moneyHeadline,
    headlineSmall: AppTypography.moneyHeadline,
    titleLarge: AppTypography.titleLarge,
    titleMedium: AppTypography.titleMedium,
    titleSmall: AppTypography.titleSmall,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.labelLarge,
    labelMedium: AppTypography.labelMedium,
    labelSmall: AppTypography.labelSmall,
  );

  static ThemeData _build(_Tones t) {
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KifinoRadii.button),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: 14,
    );
    const minButton = Size(AppSpacing.minTouchTarget, 48);
    final text = _textTheme.apply(
      bodyColor: t.textPrimary,
      displayColor: t.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme(
        brightness: t.brightness,
        primary: t.primary,
        onPrimary: t.onPrimary,
        primaryContainer: t.primaryTint,
        onPrimaryContainer: t.primary,
        secondary: t.secondary,
        onSecondary: t.onPrimary,
        tertiary: t.gold,
        onTertiary: t.onPrimary,
        error: t.error,
        onError: Colors.white,
        surface: t.surface,
        onSurface: t.textPrimary,
        onSurfaceVariant: t.textSecondary,
        surfaceContainerLowest: t.surface,
        surfaceContainerLow: t.surface,
        surfaceContainer: t.surfaceVariant,
        surfaceContainerHigh: t.surfaceVariant,
        surfaceContainerHighest: t.surfaceVariant,
        outline: t.border,
        outlineVariant: t.border,
        inverseSurface: AppColors.ink,
        onInverseSurface: AppColors.onInk,
        shadow: Colors.black,
      ),
      extensions: [t.extension],
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        systemOverlayStyle: t.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: t.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.card),
          side: BorderSide(color: t.border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: controlShape,
          elevation: 0,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: controlShape,
          side: BorderSide(color: t.border),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          minimumSize: const Size(AppSpacing.minTouchTarget, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: controlShape,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: t.textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: t.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.lg),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(AppTypography.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: t.border)),
          shape: WidgetStatePropertyAll(controlShape),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.primaryTint : t.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? t.primary : t.textSecondary,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.primaryTint,
        disabledColor: t.surfaceVariant,
        side: BorderSide(color: t.border),
        labelStyle: AppTypography.labelMedium.copyWith(color: t.textPrimary),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: t.primary,
        ),
        checkmarkColor: t.primary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.input),
          borderSide: BorderSide(color: t.surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.input),
          borderSide: BorderSide(color: t.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.input),
          borderSide: BorderSide(color: t.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.input),
          borderSide: BorderSide(color: t.error, width: 1.5),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: t.textSecondary),
        floatingLabelStyle: AppTypography.labelLarge.copyWith(color: t.primary),
        hintStyle: AppTypography.bodyMedium.copyWith(color: t.textTertiary),
        helperStyle: AppTypography.bodySmall.copyWith(color: t.textSecondary),
        prefixIconColor: t.textSecondary,
        suffixIconColor: t.textSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.primaryTint,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppTypography.labelMedium.copyWith(
            color: s.contains(WidgetState.selected)
                ? t.primary
                : t.textTertiary,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? t.primary
                : t.textTertiary,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.surface,
        selectedItemColor: t.primary,
        unselectedItemColor: t.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        showDragHandle: true,
        dragHandleColor: t.border,
        constraints: const BoxConstraints(maxWidth: 640),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KifinoRadii.bottomSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.dialog),
        ),
        titleTextStyle: AppTypography.titleLarge.copyWith(color: t.textPrimary),
        contentTextStyle: AppTypography.bodyLarge.copyWith(
          color: t.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onInk,
        ),
        actionTextColor: AppColors.primaryBlueDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.md),
        ),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        titleTextStyle: AppTypography.titleSmall.copyWith(color: t.textPrimary),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: t.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.textTertiary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surfaceVariant,
        circularTrackColor: t.surfaceVariant,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.primary,
        unselectedLabelColor: t.textSecondary,
        indicatorColor: t.primary,
        dividerColor: t.border,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KifinoRadii.md),
          side: BorderSide(color: t.border),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(color: t.textPrimary),
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
    );
  }
}

/// The resolved tones one theme mode is built from.
class _Tones {
  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color primaryTint;
  final Color secondary;
  final Color gold;
  final Color error;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final KifinoColorsExtension extension;

  const _Tones({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryTint,
    required this.secondary,
    required this.gold,
    required this.error,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.extension,
  });

  static const light = _Tones(
    brightness: Brightness.light,
    primary: AppColors.primaryBlueLight,
    onPrimary: Colors.white,
    primaryTint: AppColors.primaryTintLight,
    secondary: AppColors.receivableLight,
    gold: AppColors.gold,
    error: AppColors.expenseLight,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceVariant: AppColors.lightSurfaceVariant,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
    extension: KifinoColorsExtension.light,
  );

  static const dark = _Tones(
    brightness: Brightness.dark,
    primary: AppColors.primaryBlueDark,
    onPrimary: AppColors.darkBackground,
    primaryTint: AppColors.primaryTintDark,
    secondary: AppColors.receivableDark,
    gold: AppColors.goldDark,
    error: AppColors.expenseDark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceVariant: AppColors.darkSurfaceVariant,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
    extension: KifinoColorsExtension.dark,
  );
}
