import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  static const String _themeKey = 'theme_mode';

  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.light;
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = state == ThemeMode.dark;
    await prefs.setBool(_themeKey, !isDark);
    state = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  bool get isDarkMode => state == ThemeMode.dark;
}

class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color(0xFF2C2C2E);    // Dark gray for primary
  static const Color _lightSecondary = Color(0xFF007AFF);  // iOS blue for accents
  static const Color _lightAccent = Color(0xFF34C759);     // iOS green for success
  static const Color _lightBackground = Color(0xFFF7F7F7); // Very light gray background
  static const Color _lightText = Color(0xFF2C2C2E);       // Dark gray text
  static const Color _lightBubble = Color(0xFFEBEEF2);     // Light blue-gray for bot bubbles
  static const Color _lightUserBubble = Color(0xFF007AFF); // iOS blue for user bubbles

  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xFF1E90FF);
  static const Color _darkSecondary = Color(0xFF4CAF50);
  static const Color _darkAccent = Color(0xFFFFA000);
  static const Color _darkBackground = Color.fromARGB(255, 26, 26, 26);
  static const Color _darkText = Color(0xFFF1F1F1);
  static const Color _darkBubble = Color(0xFF2A2A2A);      // Dark gray for bot bubbles
  static const Color _darkUserBubble = Color(0xFF0A84FF);  // Bright blue for user bubbles

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _lightUserBubble,  // Changed to match user bubble color
    scaffoldBackgroundColor: _lightBackground,
    cardColor: _lightBubble,  // Bot bubble color
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: _lightText.withOpacity(0.15),
      cursorColor: _lightText,
      selectionHandleColor: _lightText,
    ),
    colorScheme: const ColorScheme.light(
      primary: _lightUserBubble,
      secondary: _lightSecondary,
      tertiary: _lightAccent,
      surface: _lightBubble,
      background: _lightBackground,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        color: _lightText,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(color: _lightText),
      bodySmall: TextStyle(color: Color(0xFF6C6C70)),
    ),
    iconTheme: const IconThemeData(color: _lightText),
    appBarTheme: const AppBarTheme(
      color: Colors.transparent,
      iconTheme: IconThemeData(color: _lightPrimary),
      titleTextStyle: TextStyle(
        color: _lightText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _darkUserBubble,
    scaffoldBackgroundColor: _darkBackground,
    cardColor: _darkBubble,
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: _darkText.withOpacity(0.2),
      cursorColor: _darkText,
      selectionHandleColor: _darkText,
    ),
    colorScheme: const ColorScheme.dark(
      primary: _darkUserBubble,
      secondary: _darkSecondary,
      tertiary: _darkAccent,
      surface: _darkBubble,
      background: _darkBackground,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _darkText),
      bodyMedium: TextStyle(color: _darkText),
    ),
    iconTheme: const IconThemeData(color: _darkText),
    appBarTheme: const AppBarTheme(
      color: Colors.transparent,
      iconTheme: IconThemeData(color: _darkPrimary),
      titleTextStyle: TextStyle(
        color: _darkText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
