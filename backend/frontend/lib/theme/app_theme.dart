import 'package:flutter/material.dart';

class Palette {
  final Color primary;
  final Color accent;
  final Color warm;
  const Palette({required this.primary, required this.accent, required this.warm});
}

class AppTheme {
  AppTheme._();

  static ThemeMode _themeMode = ThemeMode.dark;
  static ThemeMode get themeMode => _themeMode;
  static bool get isDark => _themeMode == ThemeMode.dark;

  static void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
  }

  // --- Base ---
  static Color get bgColor => isDark ? const Color(0xFF1A1B2E) : const Color(0xFFF5F6FA);
  static Color get sidebarBg => isDark ? const Color(0xFF12131C) : Colors.white;
  static Color get cardBg => isDark ? const Color(0xFF1E1F33) : Colors.white;
  static const double cardRadius = 24.0;

  static Color get textPrimary => isDark ? const Color(0xFFE8E8EC) : Colors.black87;
  static Color get textSecondary => isDark ? const Color(0xFF9A9AB0) : Colors.grey.shade600;
  static Color get textHint => isDark ? const Color(0xFF6B6B80) : Colors.grey.shade500;
  static Color get surfaceBg => isDark ? const Color(0xFF232438) : Colors.grey.shade50;

  // --- Palette pool ---
  static const List<Palette> palettes = [
    Palette(primary: Color(0xFFFF6B9D), accent: Color(0xFFA855F7), warm: Color(0xFFF97316)),
    Palette(primary: Color(0xFF3B82F6), accent: Color(0xFF06B6D4), warm: Color(0xFF14B8A6)),
    Palette(primary: Color(0xFF8B5CF6), accent: Color(0xFFEC4899), warm: Color(0xFFF59E0B)),
    Palette(primary: Color(0xFF10B981), accent: Color(0xFF6366F1), warm: Color(0xFFEF4444)),
    Palette(primary: Color(0xFFF43E5C), accent: Color(0xFF8B5CF6), warm: Color(0xFF06B6D4)),
  ];

  /// Returns the palette for a language at [index] in the loaded languages list.
  static Palette paletteForIndex(int index) => palettes[index % palettes.length];

  // --- Public accessors for the currently active language ---
  static int _activeIndex = 0;

  static void setActiveIndex(int index) {
    _activeIndex = index;
  }

  static Color get primary => paletteForIndex(_activeIndex).primary;
  static Color get accent => paletteForIndex(_activeIndex).accent;
  static Color get warm => paletteForIndex(_activeIndex).warm;

  static List<Color> get primaryGradient => [primary, _darken(primary, 0.25)];
  static List<Color> get accentGradient => [accent, _darken(accent, 0.3)];
  static List<Color> get warmGradient => [warm, _darken(warm, 0.3)];

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(
      (c.a * 255.0).round().clamp(0, 255),
      (c.r * 255.0 * (1 - amount)).round().clamp(0, 255),
      (c.g * 255.0 * (1 - amount)).round().clamp(0, 255),
      (c.b * 255.0 * (1 - amount)).round().clamp(0, 255),
    );
  }

  // --- Card shadow ---
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ];

  // --- ThemeData ---
  static ThemeData get themeData {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      fontFamily: null,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
