import 'package:flutter/material.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue[700],
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      bodySmall: TextStyle(color: Colors.black54),
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: Colors.black54),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.black87),
      hintStyle: TextStyle(color: Colors.grey.shade600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue[700],
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
    colorScheme: ColorScheme.light(
      primary: Colors.blue[700]!,
      secondary: Colors.blue[600]!,
      surface: Colors.white,
      background: Colors.white,
      error: Colors.red[700]!,
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue[400],
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white60),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: Colors.white60),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: TextStyle(color: Colors.grey.shade400),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[400],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue[400],
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    colorScheme: ColorScheme.dark(
      primary: Colors.blue[400]!,
      secondary: Colors.blue[300]!,
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
      error: Colors.red[400]!,
    ),
  );
}