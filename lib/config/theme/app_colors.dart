import 'package:flutter/material.dart';

/// Legacy static constants — kept for reference where direct constants are needed.
class AppColors {
  AppColors._();

  static const backgroundDark = Color(0xFF0F1117);
  static const backgroundLight = Color(0xFFF5F6F8);

  static const surfaceDark = Color(0xFF1A1D27);
  static const surfaceLight = Colors.white;

  static const surfaceElevatedDark = Color(0xFF242836);
  static const surfaceElevatedLight = Color(0xFFF0F1F3);

  static const inputDark = Color(0xFF2E3344);
  static const inputLight = Color(0xFFEEEFF2);

  static const hoverDark = Color(0xFF363B4D);
  static const hoverLight = Color(0xFFE8E9EC);

  static const textPrimaryDark = Color(0xFFF2F2F7);
  static const textPrimaryLight = Color(0xFF111827);

  static const textSecondaryDark = Color(0xFF9CA3AF);
  static const textSecondaryLight = Color(0xFF6B7280);

  static const textTertiaryDark = Color(0xFF6B7280);
  static const textTertiaryLight = Color(0xFF9CA3AF);

  static const textInverseDark = Color(0xFF0F1117);
  static const textInverseLight = Colors.white;

  static const accent = Color(0xFF2DD4A8);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF60A5FA);
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
  Color get accentMuted => AppColors.accent.withValues(alpha: 0.10);
  Color get accentSurface =>
      AppColors.accent.withValues(alpha: isDark ? 0.07 : 0.05);

  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get info => AppColors.info;

  Color get successM => success.withValues(alpha: isDark ? 0.15 : 0.10);
  Color get warningM => warning.withValues(alpha: isDark ? 0.15 : 0.10);
  Color get errorM => error.withValues(alpha: isDark ? 0.15 : 0.10);
  Color get infoM => info.withValues(alpha: isDark ? 0.15 : 0.10);

  Color get divider => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.08);

  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.03)
      : Colors.black.withValues(alpha: 0.04);

  Color get navBg => isDark ? AppColors.surfaceDark : Colors.white;

  Color get shadow => isDark
      ? Colors.transparent
      : Colors.black.withValues(alpha: 0.04);
}

extension ThemeColorsX on BuildContext {
  CL get cl => CL._(Theme.of(this).brightness == Brightness.dark);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
