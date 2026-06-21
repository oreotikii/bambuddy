import 'package:flutter/material.dart';

const Color _kGreen = Color(0xFF00C853);
const Color _kGreenDark = Color(0xFF064E2D);
const Color _kBg = Color(0xFF18181B);
const Color _kBar = Color(0xFF202027);
const Color _kCard = Color(0xFF27272A);
const Color _kField = Color(0xFF323238);
const Color _kStroke = Color(0xFF3F3F46);
const Color _kInk = Color(0xFFFAFAFA);
const Color _kDim = Color(0xFFA1A1AA);
const Color _kRed = Color(0xFFEF4444);
const Color _kAmber = Color(0xFFF59E0B);

ColorScheme _colorScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(seedColor: _kGreen, brightness: brightness);
  return base.copyWith(
    primary: _kGreen,
    onPrimary: Colors.black,
    primaryContainer: _kGreenDark,
    onPrimaryContainer: const Color(0xFFB7F4C8),
    secondary: _kField,
    onSecondary: Colors.white,
    secondaryContainer: _kCard,
    onSecondaryContainer: _kInk,
    surface: _kBg,
    onSurface: _kInk,
    surfaceContainerLowest: const Color(0xFF131316),
    surfaceContainerLow: const Color(0xFF1F1F23),
    surfaceContainer: _kBar,
    surfaceContainerHigh: _kCard,
    surfaceContainerHighest: _kCard,
    onSurfaceVariant: _kDim,
    outline: _kStroke,
    outlineVariant: _kStroke,
    error: _kRed,
    onError: Colors.white,
    errorContainer: const Color(0xFF451A1A),
    onErrorContainer: const Color(0xFFFCA5A5),
    tertiary: _kAmber,
  );
}

InputDecorationTheme _inputTheme(ColorScheme cs) => InputDecorationTheme(
      filled: true,
      fillColor: _kField,
      hintStyle: const TextStyle(color: _kDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kStroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kGreen, width: 1.5),
      ),
    );

ButtonStyle _filledStyle() => FilledButton.styleFrom(
      backgroundColor: _kGreen,
      foregroundColor: Colors.black,
      disabledBackgroundColor: _kGreen.withValues(alpha: 0.4),
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );

ButtonStyle _outlinedStyle(ColorScheme cs) => OutlinedButton.styleFrom(
      foregroundColor: _kInk,
      minimumSize: const Size.fromHeight(44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      side: const BorderSide(color: _kStroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 14),
    );

ThemeData bambuddyTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: _colorScheme(Brightness.dark),
  scaffoldBackgroundColor: _kBg,
  splashFactory: NoSplash.splashFactory,
  inputDecorationTheme: _inputTheme(_colorScheme(Brightness.dark)),
  filledButtonTheme: FilledButtonThemeData(style: _filledStyle()),
  outlinedButtonTheme:
      OutlinedButtonThemeData(style: _outlinedStyle(_colorScheme(Brightness.dark))),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: _kBar,
    surfaceTintColor: Colors.transparent,
    indicatorColor: _kGreenDark,
    indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final active = states.contains(WidgetState.selected);
      return TextStyle(
        color: active ? _kGreen : _kDim,
        fontSize: 12,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final active = states.contains(WidgetState.selected);
      return IconThemeData(color: active ? _kGreen : _kDim, size: 24);
    }),
    height: 64,
  ),
  dividerTheme: const DividerThemeData(color: _kStroke, thickness: 1, space: 1),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: _kGreen),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: _kCard,
    contentTextStyle: const TextStyle(color: _kInk),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
);
