import 'package:firebase_auth/firebase_auth.dart';

import 'registro_test.dart' show llenarRegistro;

import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:financebro/main.dart' as app;
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/core/control_red.dart';
import 'package:financebro/core/configuracion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> esperar(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final textos = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .join(' | ');
  throw TestFailure(
    'No apareció el elemento esperado: $finder. Pantalla: $textos',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const guardarCapturas = bool.fromEnvironment('CAPTURE_EVIDENCE');
  Future<void> captura(WidgetTester tester, String nombre) async {
    if (!guardarCapturas) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot(nombre);
  }

  testWidgets('Ingreso, preferencias, divisas, recuperación y registro', (
    tester,
  ) async {
    final aplicacion = await app.prepararAplicacion();
    await FirebaseAuth.instanceFor(app: Firebase.app('demo-financebro'))
        .signOut();
    await tester.pumpWidget(aplicacion);
    await tester.pump(const Duration(milliseconds: 700));
    if (guardarCapturas) {
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await captura(tester, '01-bienvenida');
    }
    if (find.text('Ya tengo una cuenta').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Ya tengo una cuenta'));
      await tester.tap(find.text('Ya tengo una cuenta'));
    }
    await esperar(tester, find.byKey(const Key('correo')));
    await tester.enterText(
      find.byKey(const Key('correo')),
      'demo@financebro.test',
    );
    await tester.enterText(
      find.byKey(const Key('clave')),
      'FinanceBro-local-2026!',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
    await tester.tap(find.byKey(const Key('enviar-acceso')));
    await esperar(tester, find.text('Tu dinero, a tu manera'));
    await captura(tester, '02-inicio');
    await tester.tap(find.text('Cuentas'));
    await esperar(tester, find.text('Tus cuentas'));
    await tester.tap(find.text('Cuenta del día a día'));
    await esperar(tester, find.text('Movimientos de tu cuenta'));
    await tester.tap(find.text('Gastos'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.scrollUntilVisible(
      find.text('Supermercado de prueba'),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Gastos'))
          .selected,
      isTrue,
    );
    expect(find.text('Ingreso de prueba'), findsNothing);
    expect(find.text('Supermercado de prueba'), findsOneWidget);
    await captura(tester, '03-movimientos');
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Mi perfil'));
    await esperar(tester, find.text('Organizar mis finanzas'));
    await tester.tap(find.text('Organizar mis finanzas'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Preparar mi próximo viaje').last);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Guardar preferencias'));
    await esperar(tester, find.text('Tus preferencias están actualizadas.'));
    await tester.tap(find.text('Inicio'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.scrollUntilVisible(
      find.text('Tu próximo viaje empieza aquí'),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    // El endpoint administrativo sin credenciales existe solo en los emuladores.
    expect(usarEmuladores, isTrue);
    final http = HttpClient();
    final solicitud = await http.patchUrl(
      Uri.parse(
        'http://$servidorEmuladores:$puertoFirestore/v1/projects/demo-financebro/databases/(default)/documents/experiencias/actual',
      ),
    );
    solicitud.headers.set('Authorization', 'Bearer owner');
    solicitud.headers.contentType = ContentType.json;
    solicitud.write(
      jsonEncode({
        'fields': {
          'schemaVersion': {'integerValue': '1'},
          'revision': {'integerValue': '2'},
          'tarjetas': {
            'arrayValue': {
              'values': [
                {
                  'mapValue': {
                    'fields': {
                      'id': {'stringValue': 'cambio-e2e'},
                      'tipo': {'stringValue': 'aviso'},
                      'titulo': {
                        'stringValue':
                            'Contenido actualizado desde el servicio',
                      },
                      'texto': {
                        'stringValue':
                            'Esta tarjeta llegó sin reinstalar la aplicación.',
                      },
                      'segmento': {'stringValue': 'todos'},
                      'destino': {'stringValue': '/cuentas'},
                      'orden': {'integerValue': '1'},
                    },
                  },
                },
              ],
            },
          },
        },
      }),
    );
    final respuesta = await solicitud.close();
    expect(respuesta.statusCode, 200);
    await respuesta.drain<void>();
    http.close();
    await esperar(tester, find.text('Contenido actualizado desde el servicio'));
    await captura(tester, '04-contenido-remoto');
    await tester.tap(find.text('Mi perfil'));
    await esperar(tester, find.text('Divisas'));
    await tester.ensureVisible(find.text('Divisas'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Divisas'));
    await esperar(tester, find.byKey(const Key('resultado-divisas')));
    await captura(tester, '05-divisas');
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(FinanceBroApp)),
    );
    final red = contenedor.read(controlRedProvider);
    await red.cambiar(EscenarioRed.sinConexion);
    await tester.tap(find.text('Actualizar tasa'));
    await esperar(tester, find.textContaining('guardada'));
    await captura(tester, '06-sin-conexion');
    await tester.tap(find.text('Cuentas'));
    await esperar(tester, find.text('Cuenta del día a día'));
    await red.cambiar(EscenarioRed.normal);
    await red.cambiar(EscenarioRed.divisasCaidas);
    await tester.tap(find.text('Mi perfil'));
    await esperar(tester, find.text('Divisas'));
    await tester.ensureVisible(find.text('Divisas'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Divisas'));
    await esperar(tester, find.textContaining('guardada'));
    await tester.tap(find.text('Cuentas'));
    await esperar(tester, find.text('Cuenta del día a día'));
    await red.cambiar(EscenarioRed.latencia);
    await tester.tap(find.text('Mi perfil'));
    await esperar(tester, find.text('Divisas'));
    await tester.ensureVisible(find.text('Divisas'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Divisas'));
    await esperar(tester, find.text('Consultando la tasa'));
    await esperar(tester, find.byKey(const Key('resultado-divisas')));
    await red.cambiar(EscenarioRed.normal);
    await tester.tap(find.text('Mi perfil'));
    await esperar(tester, find.text('Cerrar sesión'));
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await esperar(tester, find.byKey(const Key('correo')));
    await tester.ensureVisible(find.text('Quiero crear una cuenta'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Quiero crear una cuenta'));
    await llenarRegistro(tester);
    await esperar(tester, find.textContaining('Hola, Lucía'));
    await tester.tap(find.text('Cuentas'));
    await esperar(tester, find.text('Cuenta de ahorros'));
  });
}
