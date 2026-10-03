import 'package:flutter/material.dart';

const naranjaFinanceBro = Color(0xFFAC3A00);
const fondoFinanceBro = Color(0xFFFFF9F5);

ThemeData crearTema() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: naranjaFinanceBro,
    primary: naranjaFinanceBro,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: fondoFinanceBro,
  appBarTheme: const AppBarTheme(backgroundColor: fondoFinanceBro),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xFFF0DDD0)),
    ),
  ),
);
