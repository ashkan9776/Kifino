import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// KIFINO 2 DESIGN TOKENS — PRIMITIVE COLORS (single source of truth)
///
/// Identity: Persian-modern. Firoozeh (turquoise) is the brand, Ink navy
/// carries weight and the hero surfaces, warm Sand neutrals replace the old
/// cold blue-greys, and Gold marks goals and premium moments.
///
/// Architecture:  Primitives (this file)  →  Semantic (AppColors /
/// KifinoColorsExtension)  →  Components  →  UI.
///
/// Never reference [KifinoPalette] from feature code — consume the semantic
/// layer (`AppColors.*` / `context.customColors`) so themes can remap values
/// without touching screens. Contrast of every text pairing was checked
/// against WCAG (body text ≥ 4.5:1 on its surface).
/// ─────────────────────────────────────────────────────────────────────────
abstract final class KifinoPalette {
  // ── Brand: Firoozeh ──────────────────────────────────────────────────────
  static const Color firoozeh800 = Color(0xFF075E5A);
  static const Color firoozeh700 = Color(0xFF0B7F7A); // light primary (4.85:1)
  static const Color firoozeh500 = Color(0xFF14A39B);
  static const Color firoozeh400 = Color(0xFF2EC4B6); // dark primary
  static const Color firoozeh100 = Color(0xFFD5F1EE);
  static const Color firoozeh50 = Color(0xFFEAF7F5);

  // ── Ink (navy) ───────────────────────────────────────────────────────────
  static const Color ink950 = Color(0xFF0B1220);
  static const Color ink900 = Color(0xFF0F1B2E);
  static const Color ink800 = Color(0xFF16243A);
  static const Color ink700 = Color(0xFF1E2E48);

  // ── Gold ─────────────────────────────────────────────────────────────────
  static const Color gold600 = Color(0xFF9A7314);
  static const Color gold400 = Color(0xFFE2B84A);
  static const Color gold100 = Color(0xFFF7EED3);

  // ── Supporting hues ──────────────────────────────────────────────────────
  static const Color indigo500 = Color(0xFF4F5BD5);
  static const Color indigo300 = Color(0xFF8E97F0);
  static const Color violet500 = Color(0xFF7C5CE0);
  static const Color violet300 = Color(0xFFAD97F5);
  static const Color amber500 = Color(0xFFD9822B);
  static const Color amber300 = Color(0xFFF2B266);
  static const Color sky500 = Color(0xFF2F7DD1);
  static const Color sky300 = Color(0xFF79B4F2);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF0F8A45);
  static const Color successDark = Color(0xFF3DD68C);
  static const Color error = Color(0xFFD93B40);
  static const Color errorDark = Color(0xFFFF6B70);
  static const Color warning = Color(0xFFD98F1E);
  static const Color info = Color(0xFF2F7DD1);

  // ── Sand neutrals (light) ────────────────────────────────────────────────
  static const Color sand0 = Color(0xFFFFFFFF);
  static const Color sand50 = Color(0xFFFAF8F4); // app background
  static const Color sand100 = Color(0xFFF3F0EA); // fills, chips
  static const Color sand200 = Color(0xFFE8E3DA); // hairlines
  static const Color sand400 = Color(0xFF8C8579); // tertiary text, hints
  static const Color sand600 = Color(0xFF6B655B); // secondary text
  static const Color sand900 = Color(0xFF1C1A17);

  // ── Night neutrals (dark) ────────────────────────────────────────────────
  static const Color night950 = Color(0xFF0A0F1A); // app background
  static const Color night900 = Color(0xFF111827); // surface
  static const Color night800 = Color(0xFF182235); // raised surface
  static const Color night700 = Color(0xFF243047); // hairlines
  static const Color night400 = Color(0xFF6C7586); // tertiary text
  static const Color night300 = Color(0xFFA7ADB8); // secondary text
  static const Color night50 = Color(0xFFF4F1EA); // primary text (warm white)

  // ── Gradients (rare & intentional) ───────────────────────────────────────
  /// Net-worth hero: deep ink with a faint firoozeh glow in one corner.
  static const LinearGradient heroLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF123A45), ink900, ink950],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient heroDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F3440), ink800, ink900],
    stops: [0.0, 0.55, 1.0],
  );

  /// Main add action: a quiet two-tone firoozeh.
  static const LinearGradient actionLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [firoozeh500, firoozeh700],
  );

  static const LinearGradient actionDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [firoozeh400, firoozeh500],
  );
}
