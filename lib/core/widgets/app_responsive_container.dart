import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Adaptive responsive wrapper for page bodies and sheets.
///
/// On mobile phones (`width < AppSpacing.mobileBreakpoint`), it returns the child
/// with zero modifications or constraints, preserving 100% of the mobile styling.
///
/// On tablets and desktop screens (such as Windows, macOS, and Linux), it centers
/// the content and constrains its maximum width so the UI remains proportional
/// and legible instead of awkwardly stretching across wide displays.
class AppResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const AppResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1150.0,
    this.padding,
  });

  /// Form dialog or entry form variant (narrower, focused width).
  const AppResponsiveContainer.form({
    super.key,
    required this.child,
    this.maxWidth = 680.0,
    this.padding,
  });

  /// Settings and detail view variant.
  const AppResponsiveContainer.settings({
    super.key,
    required this.child,
    this.maxWidth = 820.0,
    this.padding,
  });

  /// Feed / List view variant.
  const AppResponsiveContainer.feed({
    super.key,
    required this.child,
    this.maxWidth = 960.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppSpacing.mobileBreakpoint) {
      return padding != null ? Padding(padding: padding!, child: child) : child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Helper utilities for querying responsive breakpoint states.
class AppResponsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppSpacing.mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppSpacing.mobileBreakpoint &&
        width < AppSpacing.desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppSpacing.desktopBreakpoint;
}
