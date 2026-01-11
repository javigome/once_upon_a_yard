import 'package:flutter/material.dart';

class AppTheme {
  static const Color forestGreen = Color(0xFF228B22);
  static const Color lightGreen = Color(0xFF90EE90);
  static const Color soilBrown = Color(0xFF5D4037);
  static const Color creamBackground = Color(0xFFF9F9F0);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: forestGreen,
      scaffoldBackgroundColor: creamBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: forestGreen,
        secondary: lightGreen,
        surface: creamBackground,
      ),
      useMaterial3: true,
      fontFamily: 'Nunito', // Rounded, friendly font
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forestGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}