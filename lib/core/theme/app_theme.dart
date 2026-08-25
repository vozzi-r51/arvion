import 'package:flutter/material.dart';

/// Central place for all colors, typography and theme data used across
/// DukanEdge. Keeping this in one file makes it easy to re-skin the app
/// later without touching individual screens.
class AppTheme {
  AppTheme._();

  // ARVION brand palette
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueSoft = Color(0xFF3B82F6);
  static const Color accentSlate = Color(0xFFE2E8F0);
  static const Color neutralWhite = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkFieldFill = Color(0xFF1F2937);

  static ThemeData lightThemeWithPrimary(Color primaryColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      secondary: primaryBlueSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      // Using standard fontFamily ensures 100% offline usage.
      // Falls back to system fonts if assets/fonts/ files are missing.
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        floatingLabelStyle: const TextStyle(color: primaryNavy),
        labelStyle: const TextStyle(color: Color(0xFF334155)),
        hintStyle: TextStyle(color: Colors.grey.shade600),
        prefixIconColor: primaryNavy,
        suffixIconColor: primaryNavy,
        helperStyle: const TextStyle(color: Color(0xFF475569)),
        errorStyle: const TextStyle(color: Color(0xFFB42318)),
        isDense: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(color: Colors.black87),
      ),
    );
  }

  static ThemeData darkThemeWithPrimary(Color primaryColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      secondary: primaryBlueSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      // Using 'Inter' as 'NotoSans' was not found in the assets.
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // This was missing before — text fields fell back to a theme-less
      // default in Dark Mode and could render dark text on a dark
      // background (unreadable). Now every field has an explicit dark
      // fill with light text/labels.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkFieldFill,
        floatingLabelStyle: const TextStyle(color: Colors.white),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
        helperStyle: const TextStyle(color: Colors.white70),
        errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
        isDense: false,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkSurface,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: darkSurface,
        textStyle: TextStyle(color: Colors.white),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Colors.white),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white70,
      ),
    );
  }

  static ThemeData get lightTheme => lightThemeWithPrimary(primaryBlue);

  static ThemeData get darkTheme => darkThemeWithPrimary(primaryBlueSoft);
}

/// Simple ChangeNotifier so the whole app can toggle light/dark at runtime.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = AppTheme.primaryBlue;

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }

  void toggle() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
