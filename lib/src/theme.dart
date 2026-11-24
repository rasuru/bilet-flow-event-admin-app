import 'package:flutter/material.dart';

const _background = Color(0xFF101613);
const _surface = Color(0xFF19221D);
const _raised = Color(0xFF222E27);
const _ink = Color(0xFFF1F5EC);
const _muted = Color(0xFFB5C4B8);
const _accent = Color(0xFFD5F398);
const _line = Color(0xFF35463B);

final eventAdminTheme = _buildTheme();

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
    primary: _accent,
    onPrimary: const Color(0xFF233407),
    surface: _surface,
    surfaceContainerHigh: _raised,
    onSurface: _ink,
    onSurfaceVariant: _muted,
    outline: const Color(0xFF748778),
    outlineVariant: _line,
    error: const Color(0xFFFFB4AA),
    errorContainer: const Color(0xFF482823),
    onErrorContainer: const Color(0xFFFFDAD4),
  );
  final theme = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: _background,
    appBarTheme: const AppBarTheme(
      backgroundColor: _background,
      foregroundColor: _ink,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF748778)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
  );
  final type = theme.textTheme;
  return theme.copyWith(
    textTheme: type.copyWith(
      headlineLarge: type.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: type.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleLarge: type.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: type.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: type.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: type.bodyMedium?.copyWith(height: 1.4),
    ),
  );
}
