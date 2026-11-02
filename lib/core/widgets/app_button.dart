import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, text, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = AppSpacing.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    BorderSide? borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = isDark
            ? AppColors.primaryBlueDark
            : AppColors.primaryBlueLight;
        fgColor = isDark ? AppColors.darkBackground : Colors.white;
        break;
      case AppButtonVariant.secondary:
        bgColor = isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant;
        fgColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;
        borderSide = BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        );
        break;
      case AppButtonVariant.text:
        bgColor = Colors.transparent;
        fgColor = isDark
            ? AppColors.primaryBlueDark
            : AppColors.primaryBlueLight;
        break;
      case AppButtonVariant.danger:
        bgColor = isDark ? AppColors.expenseDark : AppColors.expenseLight;
        fgColor = Colors.white;
        break;
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label, style: AppTypography.labelLarge.copyWith(color: fgColor)),
      ],
    );

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        child: content,
      ),
    );
  }
}
