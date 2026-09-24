import 'package:flutter/material.dart';

final eventAdminTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF9B8CFF),
    brightness: Brightness.dark,
    surface: const Color(0xFF12141C),
  ),
  scaffoldBackgroundColor: const Color(0xFF0C0E14),
  appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0C0E14), centerTitle: false),
  cardTheme: CardThemeData(
    color: const Color(0xFF191C26),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1A1D28),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  ),
);
