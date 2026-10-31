import 'package:flutter/animation.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// KIFINO DESIGN TOKENS — MOTION
///
/// Motion communicates navigation, state change, success and hierarchy —
/// never decoration. Durations and curves come from here so the whole app
/// moves with one rhythm.
/// ─────────────────────────────────────────────────────────────────────────
abstract final class KifinoMotion {
  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 350);

  // Curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve emphasized = Curves.easeOutCubic;
}
