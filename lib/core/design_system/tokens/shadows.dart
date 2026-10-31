import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// KIFINO DESIGN TOKENS — SHADOWS / ELEVATION
///
/// Surface hierarchy beats heavy shadows: soft, large blur, low opacity.
/// Never use dark aggressive shadows.
/// ─────────────────────────────────────────────────────────────────────────
abstract final class KifinoShadows {
  /// Elevation 1 — subtle resting card.
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x0A0B1D35), blurRadius: 10, offset: Offset(0, 2)),
  ];

  /// Elevation 2 — floating card / hovering element.
  static const List<BoxShadow> e2 = [
    BoxShadow(color: Color(0x120B1D35), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Elevation 3 — modal / bottom sheet edge.
  static const List<BoxShadow> e3 = [
    BoxShadow(color: Color(0x1A0B1D35), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Elevation 4 — floating action (FAB).
  static const List<BoxShadow> e4 = [
    BoxShadow(color: Color(0x220B1D35), blurRadius: 20, offset: Offset(0, 6)),
  ];

  /// Dark-theme equivalents — deeper, colorless.
  static const List<BoxShadow> darkE1 = [
    BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> darkE2 = [
    BoxShadow(color: Color(0x52000000), blurRadius: 18, offset: Offset(0, 5)),
  ];
}
