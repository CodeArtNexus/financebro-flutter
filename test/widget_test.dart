import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/features/experience/experiencia.dart';
import 'package:financebro/features/accounts/movimientos_pantalla.dart';
import 'package:financebro/features/accounts/cuentas_pantalla.dart';
import 'package:financebro/features/accounts/cuentas.dart';
import 'package:financebro/core/errores.dart';
import 'package:financebro/features/auth/identidad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyos.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferencias;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferencias = await SharedPreferences.getInstance();
  });
  testWidgets('El inicio no interpreta una caché vacía como saldo cero', (
    tester,
  ) async {
    final identidad = IdentidadPrueba()
      ..usuario = const Identidad('usuario-prueba', 'Sebastian');
    addTearDown(identidad.controlador.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identidadProvider.overrideWithValue(identidad),
          cuentasProvider.overrideWith(
            (ref) => Stream.value(
              DatosGuardados<List<Cuenta>>(
                [],
                desdeCache: true,
                actualizado: DateTime(1970),
              ),
            ),
          ),
          perfilProvider.overrideWith(
            (ref) => Stream.value(
              DatosGuardados<Perfil>(
                const Perfil(nombre: 'Sebastian'),
                desdeCache: true,
                actualizado: DateTime(1970),
              ),
            ),
          ),
          contenidoProvider.overrideWith(
            (ref) => Stream.value(experienciaBase),
          ),
        ],
        child: const MaterialApp(home: InicioPantalla()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Necesitamos conexión'), findsOneWidget);
    expect(find.text('Tu saldo total'), findsNothing);
    expect(find.text('Tu espacio está listo'), findsNothing);
  });
  testWidgets('Las cuentas muestran carga mientras espera el servicio', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cuentasProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(home: CuentasPantalla()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets(
    'Un fallo de cuentas permite reintentar y llegar al estado vacío',
    (tester) async {
      var intentos = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (int intento, Object error) => null,
          overrides: [
            cuentasProvider.overrideWith(
              (ref) => ++intentos == 1
                  ? Stream.error(
                      const FalloApp('Servicio temporalmente indisponible'),
                    )
                  : Stream.value(
                      DatosGuardados<List<Cuenta>>(
                        [],
                        desdeCache: false,
                        actualizado: DateTime(2026, 10, 3),
                      ),
                    ),
            ),
          ],
          child: const MaterialApp(home: CuentasPantalla()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Servicio temporalmente indisponible'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu espacio está listo'), findsOneWidget);
      expect(intentos, 2);
    },
  );
  testWidgets('El ingreso valida campos vacíos sin llamar al servidor', (
    tester,
  ) async {
    final identidad = IdentidadPrueba();
    addTearDown(identidad.controlador.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identidadProvider.overrideWithValue(identidad),
          preferenciasLocalesProvider.overrideWithValue(preferencias),
        ],
        child: const FinanceBroApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ya tengo una cuenta'));
    await tester.tap(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
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
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const MovimientosPantalla('principal'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compra de prueba'), findsOneWidget);
    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();
    expect(find.text('Sin movimientos'), findsOneWidget);
  });
}
