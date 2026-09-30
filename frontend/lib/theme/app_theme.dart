import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF7F7F7);
  static const border = Color(0xFFEAEAEA);
  static const textSecondary = Color(0xFF6B6B6B);
  static const brand = Color(0xFFE53935);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}