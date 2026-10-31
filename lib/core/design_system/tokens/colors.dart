import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// KIFINO DESIGN TOKENS — PRIMITIVE COLORS (single source of truth)
///
/// Architecture:  Primitives (this file)  →  Semantic (AppColors /
/// KifinoColorsExtension)  →  Components  →  UI.
///
/// Never reference [KifinoPalette] directly from feature code — consume the
/// semantic layer (`AppColors.*` / `context.customColors`) so themes can
/// remap values without touching screens.
/// ─────────────────────────────────────────────────────────────────────────
abstract final class KifinoPalette {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color navy950 = Color(0xFF071426); // Kifino Navy
  static const Color navy900 = Color(0xFF0B1D35); // Deep Navy
  static const Color blue600 = Color(0xFF247BFF); // Electric Blue
  static const Color blue500 = Color(0xFF3187FF); // Bright Blue
  static const Color cyan500 = Color(0xFF20C8E8); // Cyan
  static const Color mint400 = Color(0xFF39E6A5); // Mint
  static const Color emerald500 = Color(0xFF25C997); // Emerald

  // ── Supporting ───────────────────────────────────────────────────────────
  static const Color purple400 = Color(0xFF8B7CFF);
  static const Color pink400 = Color(0xFFF472B6);
  static const Color orange400 = Color(0xFFFF9F43);
  static const Color yellow400 = Color(0xFFFFCA58);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = emerald500; // #25C997
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF5C6C);
  static const Color info = Color(0xFF4C9AFF);

  // ── Neutral scale ────────────────────────────────────────────────────────
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);
  static const Color neutral950 = Color(0xFF07111F);

  // ── Brand gradients (rare & intentional —) ───────────────────────────
  /// Net-worth hero / premium surfaces, light theme: Navy → Electric → Cyan.
  static const LinearGradient heroLight = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy900, blue600, cyan500],
    stops: [0.0, 0.55, 1.0],
  );

  /// Dark theme hero: deep navy → electric, calmer.
  static const LinearGradient heroDark = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy950, navy900, Color(0xFF17457E)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Primary FAB / main add action: Electric Blue → Cyan.
  static const LinearGradient actionLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue600, cyan500],
  );

  static const LinearGradient actionDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue500, cyan500],
  );
}
