import 'dart:math';

import 'package:financebro/app/tema.dart';
import 'package:financebro/core/conexion_pantalla.dart';
import 'package:financebro/core/red_banco.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

double contraste(Color texto, Color fondo) {
  final a = texto.computeLuminance(), b = fondo.computeLuminance();
  return (max(a, b) + .05) / (min(a, b) + .05);
}

void main() {
  for (final brillo in [Brightness.light, Brightness.dark]) {
    testWidgets('El aviso de conexión conserva texto legible en $brillo', (
      t,
    ) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            conexionBancoProvider.overrideWith(
              (ref) => Stream.value(EstadoConexion.sinConexion),
            ),
          ],
          child: MaterialApp(
            theme: crearTema(brillo: brillo),
            home: const Scaffold(body: AvisoConexion()),
          ),
        ),
      );
      await t.pumpAndSettle();
      final fondo = t
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(AvisoConexion),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      for (final mensaje in [
        'Sin conexión · datos guardados',
        'Los pagos se confirman cuando FinanceBro los acepta.',
      ]) {
        final texto = t.widget<RichText>(
          find.descendant(
            of: find.text(mensaje),
            matching: find.byType(RichText),
          ),
        );
        final color = texto.text.style!.color!;
        expect(
          contraste(color, fondo),
          greaterThanOrEqualTo(4.5),
          reason: 'El texto informativo debe poder leerse contra el fondo real del aviso.',
        );
      }
      expect(find.byTooltip('Revisar conexión'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
