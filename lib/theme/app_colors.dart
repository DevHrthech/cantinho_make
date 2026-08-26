import 'package:flutter/material.dart';

/// Paleta Cantinho Make — vinho, creme e tema escuro (dashboard).
abstract final class AppColors {
  static const Color wine = Color(0xFF89102A);
  static const Color wineDark = Color(0xFF5C0B1D);
  static const Color wineLight = Color(0xFFB91C3F);
  static const Color cream = Color(0xFFF8D5B1);
  static const Color creamDeep = Color(0xFFE8B88A);
  static const Color creamSoft = Color(0xFFFCF0E4);

  /// Tema claro legado (formulários sobre fundo claro local).
  static const Color surface = Color(0xFFFFF9F3);
  static const Color textOnWine = Color(0xFFFFF4EC);
  static const Color textPrimary = Color(0xFF2D1218);
  static const Color textSecondary = Color(0xFF6B4E56);

  // —— Dark dashboard (mockup) ——
  static const Color darkBg = Color(0xFF120305);
  static const Color darkCard = Color(0xFF4A0815);
  static const Color darkCardElevated = Color(0xFF5C1020);
  static const Color darkTextMuted = Color(0xFFC9A89A);
  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFE85D5D);
  static const Color warning = Color(0xFFF59E0B);
}
