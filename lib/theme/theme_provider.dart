import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == savedTheme,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode.toString());

    notifyListeners();
  }
}

class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color.fromARGB(255, 0, 7, 15);
  static const Color _lightSecondary = Color(0xFF28A745);
  static const Color _lightAccent = Color(0xFFFFC107);
  static const Color _lightBackground = Color(0xFFF8F9FA);
  static const Color _lightText = Color(0xFF333333);

  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xFF1E90FF);
  static const Color _darkSecondary = Color(0xFF4CAF50);
  static const Color _darkAccent = Color(0xFFFFA000);
  static const Color _darkBackground = Color(0xFF1A1A1A);
  static const Color _darkText = Color(0xFFF1F1F1);

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _lightPrimary,
    scaffoldBackgroundColor: _lightBackground,
    cardColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: _lightPrimary,
      secondary: _lightSecondary,
      tertiary: _lightAccent,
      surface: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _lightText,fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(color: _lightText),
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
    primaryColor: _darkPrimary,
    scaffoldBackgroundColor: _darkBackground,
    cardColor: const Color(0xFF2A2A2A),
    colorScheme: const ColorScheme.dark(
      primary: _darkPrimary,
      secondary: _darkSecondary,
      tertiary: _darkAccent,
      surface: Color(0xFF2A2A2A),
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
