import 'package:flutter/material.dart';

const naranjaFinanceBro = Color(0xFFFFAF7F);
const naranjaTextoBro = Color(0xFF8B4624);
const tintaBro = Color(0xFF242735);
const fondoFinanceBro = Color(0xFFF8F8FC);

ThemeData crearTema() {
  final base = ThemeData(useMaterial3: true, fontFamily: 'Poppins');
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: naranjaFinanceBro,
      primary: naranjaTextoBro,
      onPrimary: Colors.white,
      secondary: const Color(0xFF7977AE),
      surface: Colors.white,
      onSurface: tintaBro,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      bodyColor: tintaBro,
      displayColor: tintaBro,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: tintaBro,
        fontSize: 21,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: const TextStyle(color: Color(0xFF636777), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE4E5ED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE4E5ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: naranjaTextoBro, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: naranjaFinanceBro,
        foregroundColor: tintaBro,
        minimumSize: const Size(48, 56),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        foregroundColor: tintaBro,
        side: const BorderSide(color: Color(0xFFD6D7E2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: .75),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Colors.white),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE5E5ED)),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white.withValues(alpha: .7),
      selectedColor: const Color(0xFFFFDFCA),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
