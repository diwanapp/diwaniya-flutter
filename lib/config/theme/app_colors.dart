import 'package:flutter/material.dart';

/// Central Diwaniya brand palette.
///
/// Direction:
/// - Majlis Blue: deep, premium, calm blue.
/// - Sand Taupe: warm Saudi desert-inspired accent.
/// - Warm Ivory: soft warm off-white text/highlight.
/// - Soft Taupe: subtle supporting neutral.
///
/// Keep legacy names such as [accent], [success], [warning], [error], and [info]
/// to avoid breaking existing screens while progressively migrating the app.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand primitives
  // ---------------------------------------------------------------------------
  static const majlisNight = Color(0xFF0B111C);
  static const majlisBlueDark = Color(0xFF0B1724);
  static const majlisBlue = Color(0xFF10263A);
  static const majlisBlueSoft = Color(0xFF183B55);

  static const sandTaupe = Color(0xFFB79A72);
  static const sandTaupeLight = Color(0xFFC8AD83);
  static const sandGold = Color(0xFFD9B56D);

  static const warmIvory = Color(0xFFF5EFE3);
  static const ivoryMuted = Color(0xFFE8DDCB);

  static const softTaupe = Color(0xFF8C8173);
  static const softTaupeLight = Color(0xFFB8AFA2);

  // ---------------------------------------------------------------------------
  // Theme surfaces
  // ---------------------------------------------------------------------------
  static const backgroundDark = majlisNight;
  static const backgroundLight = Color(0xFFF5EFE3);

  static const surfaceDark = Color(0xFF101722);
  static const surfaceLight = Color(0xFFFFFBF4);

  static const surfaceElevatedDark = Color(0xFF142133);
  static const surfaceElevatedLight = Color(0xFFF0E7D8);

  static const inputDark = Color(0xFF17263A);
  static const inputLight = Color(0xFFECE2D3);

  static const hoverDark = Color(0xFF1B3048);
  static const hoverLight = Color(0xFFE4D7C5);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------
  static const textPrimaryDark = warmIvory;
  static const textPrimaryLight = Color(0xFF10263A);

  static const textSecondaryDark = Color(0xFFB8AFA2);
  static const textSecondaryLight = Color(0xFF5E554B);

  static const textTertiaryDark = Color(0xFF8C8173);
  static const textTertiaryLight = Color(0xFF8C8173);

  static const textInverseDark = Color(0xFF0B1724);
  static const textInverseLight = warmIvory;

  // ---------------------------------------------------------------------------
  // Semantic / interactive colors
  // ---------------------------------------------------------------------------
  static const accent = sandTaupeLight;

  // Muted functional colors aligned with the new brand.
  static const success = Color(0xFF7FAE8A);
  static const warning = sandGold;
  static const error = Color(0xFFD36B6B);
  static const info = Color(0xFF6EA6C9);
}

/// Theme-aware color resolver.
/// Usage:
/// `final c = context.cl;`
class CL {
  final bool isDark;
  const CL._(this.isDark);

  Color get bg =>
      isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
  Color get card => isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get cardElevated => isDark
      ? AppColors.surfaceElevatedDark
      : AppColors.surfaceElevatedLight;
  Color get inputBg => isDark ? AppColors.inputDark : AppColors.inputLight;
  Color get hover => isDark ? AppColors.hoverDark : AppColors.hoverLight;

  Color get t1 =>
      isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get t2 =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get t3 =>
      isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
  Color get tInverse =>
      isDark ? AppColors.textInverseDark : AppColors.textInverseLight;

  Color get accent => AppColors.accent;
  Color get accentMuted => AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.16);
  Color get accentSurface =>
      AppColors.accent.withValues(alpha: isDark ? 0.075 : 0.13);

  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get info => AppColors.info;

  Color get successM => success.withValues(alpha: isDark ? 0.15 : 0.13);
  Color get warningM => warning.withValues(alpha: isDark ? 0.16 : 0.14);
  Color get errorM => error.withValues(alpha: isDark ? 0.15 : 0.12);
  Color get infoM => info.withValues(alpha: isDark ? 0.14 : 0.11);

  Color get divider => isDark
      ? AppColors.warmIvory.withValues(alpha: 0.075)
      : AppColors.majlisBlue.withValues(alpha: 0.10);

  Color get border => isDark
      ? AppColors.warmIvory.withValues(alpha: 0.055)
      : AppColors.majlisBlue.withValues(alpha: 0.075);

  Color get navBg => isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

  Color get shadow => isDark
      ? Colors.transparent
      : AppColors.majlisBlue.withValues(alpha: 0.06);
}

extension ThemeColorsX on BuildContext {
  CL get cl => CL._(Theme.of(this).brightness == Brightness.dark);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
