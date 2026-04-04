import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color secondaryColor = Color(0xFF26A69A);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF9A825);

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      primaryColor: primaryColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      primaryColor: primaryColor,
    );
  }
}

