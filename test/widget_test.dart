import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/features/accounts/movimientos_pantalla.dart';
import 'package:financebro/features/auth/identidad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyos.dart';

void main() {
  testWidgets('El ingreso valida campos vacíos sin llamar al servidor', (
    tester,
  ) async {
    final identidad = IdentidadPrueba();
    addTearDown(identidad.controlador.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identidadProvider.overrideWithValue(identidad)],
        child: const FinanceBroApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enviar-acceso')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
    expect(identidad.actual, isNull);
  });
  testWidgets('Los movimientos se filtran y soportan texto ampliado', (
    tester,
  ) async {
    final identidad = IdentidadPrueba()
      ..usuario = const Identidad('usuario-prueba', 'Sebastian');
    addTearDown(identidad.controlador.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identidadProvider.overrideWithValue(identidad),
          cuentasRepositorioProvider.overrideWithValue(CuentasPrueba()),
        ],
        child: const MaterialApp(home: MovimientosPantalla('principal')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compra de prueba'), findsOneWidget);
    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();
    expect(find.text('Sin movimientos'), findsOneWidget);
  });
}
