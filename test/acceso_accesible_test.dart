import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/tema.dart';
import 'package:financebro/core/red_banco.dart';
import 'package:financebro/features/auth/acceso_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyos.dart';

void main() {
  for (final brillo in [Brightness.light, Brightness.dark]) {
    for (final registro in [false, true]) {
      testWidgets(
        '${registro ? 'Registro' : 'Ingreso'} legible al 200 % en ${brillo.name}',
        (t) async {
          t.view.physicalSize = const Size(360, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final identidad = IdentidadPrueba();
          addTearDown(identidad.controlador.close);
          await t.pumpWidget(
            ProviderScope(
              overrides: [
                identidadProvider.overrideWithValue(identidad),
                recuerdoAccesoProvider.overrideWithValue(null),
                conexionBancoProvider.overrideWith(
                  (ref) => Stream.value(EstadoConexion.conectado),
                ),
              ],
              child: MaterialApp(
                theme: crearTema(brillo: brillo),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                    highContrast: true,
                  ),
                  child: child!,
                ),
                home: AccesoPantalla(registro: registro),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          // Medir áreas completas: un control parcialmente recortado por el scroll no es su tamaño táctil.
          t.view.physicalSize = const Size(360, 2600);
          await t.pumpAndSettle();
          final semantica = t.ensureSemantics();
          try {
            await expectLater(t, meetsGuideline(androidTapTargetGuideline));
            await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
            await expectLater(t, meetsGuideline(textContrastGuideline));
          } finally {
            semantica.dispose();
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
