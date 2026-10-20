import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF192B45);
  static const purple = Color(0xFF7057E8);
  static const canvas = Color(0xFFF6F7FC);
  static const green = Color(0xFF20A779);
  static const palePurple = Color(0xFFECE8FF);
  static const paleGreen = Color(0xFFE4F8EC);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.purple,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
      );
}
