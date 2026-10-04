import 'package:flutter/material.dart';

// Un solo acento, con variantes de texto que conservan el contraste.
const naranjaFinanceBro = Color(0xFFFF9A52);
const naranjaTextoBro = Color(0xFFC24D00);
const tintaBro = Color(0xFF202B36);
const fondoFinanceBro = Color(0xFFF5F7F9);

bool oscuroBro(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
Color textoBro(BuildContext context) => Theme.of(context).colorScheme.onSurface;
Color secundarioBro(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;
Color acentoBro(BuildContext context) => Theme.of(context).colorScheme.primary;
Color bordeBro(BuildContext context) => oscuroBro(context)
    ? Colors.white.withValues(alpha: .13)
    : Colors.white.withValues(alpha: .95);
Color cristalBro(BuildContext context, [Color? tinte]) {
  final oscuro = oscuroBro(context);
  final base = oscuro ? const Color(0xFF202A35) : Colors.white;
  if (MediaQuery.highContrastOf(context)) return base;
  return tinte == null
      ? base.withValues(alpha: oscuro ? .84 : .76)
      : Color.alphaBlend(
          tinte.withValues(alpha: oscuro ? .13 : .32),
          base,
        ).withValues(alpha: oscuro ? .86 : .8);
}

ThemeData crearTema({Brightness brillo = Brightness.light}) {
  final oscuro = brillo == Brightness.dark;
  final texto = oscuro ? const Color(0xFFF1F5F9) : tintaBro;
  final secundario = oscuro ? const Color(0xFFB6C1CD) : const Color(0xFF626D7B);
  final superficie = oscuro ? const Color(0xFF202A35) : Colors.white;
  final borde = oscuro ? const Color(0xFF3A4653) : const Color(0xFFDFE5EB);
  final acento = oscuro ? const Color(0xFFFFAE73) : naranjaTextoBro;
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: brillo,
  );
  final esquema = ColorScheme.fromSeed(
    brightness: brillo,
    seedColor: naranjaFinanceBro,
    primary: acento,
    onPrimary: oscuro ? tintaBro : Colors.white,
    primaryContainer: oscuro
        ? const Color(0xFF303C48)
        : const Color(0xFFFFE8D7),
    onPrimaryContainer: texto,
    secondary: oscuro ? const Color(0xFF8EAEC6) : const Color(0xFF426581),
    surface: superficie,
    onSurface: texto,
    onSurfaceVariant: secundario,
    outlineVariant: borde,
    error: oscuro ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  return base.copyWith(
    colorScheme: esquema,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: superficie,
    textTheme: base.textTheme.apply(bodyColor: texto, displayColor: texto),
    iconTheme: IconThemeData(color: texto, size: 21),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: texto,
        fontSize: 21,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: texto),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: superficie.withValues(alpha: .78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: secundario, fontSize: 13),
      prefixIconColor: acento,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: acento, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: naranjaFinanceBro,
        foregroundColor: tintaBro,
        disabledBackgroundColor: naranjaFinanceBro.withValues(alpha: .2),
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        elevation: 0,
        shape: forma,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: texto,
        backgroundColor: superficie.withValues(alpha: .38),
        side: BorderSide(color: borde),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: forma,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: acento,
        minimumSize: const Size(44, 44),
        shape: forma,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: superficie.withValues(alpha: .8),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borde),
      ),
    ),
    dividerTheme: DividerThemeData(color: borde, space: 28),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: superficie.withValues(alpha: .68),
      selectedColor: esquema.primaryContainer,
      labelStyle: TextStyle(color: texto, fontSize: 12),
      side: BorderSide(color: borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: superficie.withValues(alpha: .94),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: borde),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: texto,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: secundario,
        fontSize: 13,
        height: 1.6,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: superficie.withValues(alpha: .95),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: secundario.withValues(alpha: .4),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        side: BorderSide(color: borde),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: oscuro ? const Color(0xFFE8EEF3) : tintaBro,
      contentTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: oscuro ? tintaBro : Colors.white,
        fontSize: 12,
      ),
      actionTextColor: oscuro ? naranjaTextoBro : const Color(0xFFFFBE92),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: forma,
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: 'Poppins', color: texto, fontSize: 10),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected) ? tintaBro : texto,
          size: 23,
        ),
      ),
    ),
  );
}
