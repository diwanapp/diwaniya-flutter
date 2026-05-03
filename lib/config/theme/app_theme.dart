import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const String _themeModePrefsKey = 'theme_mode';

final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_themeModePrefsKey);

  switch (stored) {
    case 'light':
      themeNotifier.value = ThemeMode.light;
      break;
    case 'system':
      themeNotifier.value = ThemeMode.system;
      break;
    case 'dark':
    default:
      themeNotifier.value = ThemeMode.dark;
      break;
  }
}

Future<void> saveThemePreference(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();

  final value = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    ThemeMode.dark => 'dark',
  };

  await prefs.setString(_themeModePrefsKey, value);
  themeNotifier.value = mode;
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static TextStyle _arabicStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.ibmPlexSansArabic(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final card = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final inputBg = isDark ? AppColors.inputDark : AppColors.inputLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final tInverse = isDark ? AppColors.textInverseDark : AppColors.textInverseLight;
    final navBg = isDark ? AppColors.surfaceDark : Colors.white;

    final base = isDark ? ThemeData.dark() : ThemeData.light();

    final arabicTextTheme = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
        .apply(bodyColor: t1, displayColor: t1)
        .copyWith(
          bodySmall: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.bodySmall?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          bodyMedium: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.bodyMedium?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          bodyLarge: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.bodyLarge?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          labelSmall: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.labelSmall?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          labelMedium: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.labelMedium?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          labelLarge: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.labelLarge?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          titleSmall: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.titleSmall?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          titleMedium: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.titleMedium?.copyWith(color: t1),
            letterSpacing: 0,
          ),
          titleLarge: GoogleFonts.ibmPlexSansArabic(
            textStyle: base.textTheme.titleLarge?.copyWith(color: t1),
            letterSpacing: 0,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: card,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: tInverse,
        secondary: AppColors.accent,
        onSecondary: tInverse,
        error: AppColors.error,
        onError: Colors.white,
        surface: card,
        onSurface: t1,
      ),
      textTheme: arabicTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: t1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: _arabicStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: t1,
        ),
        iconTheme: IconThemeData(color: t1),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBg,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: t3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: _arabicStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
        unselectedLabelStyle: _arabicStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t3),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
        thickness: 1,
        space: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: _arabicStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tInverse),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: _arabicStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: _arabicStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.accent,
            width: 1.5,
          ),
        ),
        hintStyle: _arabicStyle(color: t3, fontSize: 14),
        labelStyle: _arabicStyle(color: t2, fontSize: 14),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: _arabicStyle(fontSize: 14, color: t1),
      ),
    );
  }
}
