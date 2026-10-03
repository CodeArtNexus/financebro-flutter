import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:financebro/main.dart' as app;
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> esperarRemoto(WidgetTester tester, Finder elemento) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (elemento.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'El servicio remoto no completó el paso esperado: $elemento',
  );
}

Future<void> pausaEvidencia(WidgetTester tester) async {
  if (!const bool.fromEnvironment('CAPTURE_EVIDENCE')) return;
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Firebase remoto: identidad y push en primer y segundo plano', (
    tester,
  ) async {
    const correo = String.fromEnvironment('DEMO_EMAIL');
    const clave = String.fromEnvironment('DEMO_PASSWORD');
    expect(
      correo.isNotEmpty && clave.isNotEmpty,
      isTrue,
      reason: 'Usar un archivo de defines privado, fuera de Git.',
    );
    final aplicacion = await app.prepararAplicacion();
    await FirebaseAuth.instance.signOut();
    await tester.pumpWidget(aplicacion);
    await esperarRemoto(tester, find.text('Ya tengo una cuenta'));
    await tester.ensureVisible(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya tengo una cuenta'));
    await esperarRemoto(tester, find.byKey(const Key('correo')));
    await tester.enterText(find.byKey(const Key('correo')), correo);
    await tester.enterText(find.byKey(const Key('clave')), clave);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
    await tester.tap(find.byKey(const Key('enviar-acceso')));
    await esperarRemoto(tester, find.text('Cuenta del día a día'));
    expect(
      FirebaseAuth.instance.currentUser?.uid,
      const String.fromEnvironment('DEMO_UID'),
    );
    await tester.tap(find.byTooltip('Notificaciones'));
    await esperarRemoto(tester, find.text('Activar notificaciones'));
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(FinanceBroApp)),
    );
    final llegado = Completer<void>();
    final suscripcion = contenedor
        .read(notificacionesRepositorioProvider)
        .recibidas
        .listen((aviso) {
          if (!llegado.isCompleted) llegado.complete();
        });
    addTearDown(suscripcion.cancel);
    await tester.tap(find.text('Activar notificaciones'));
    await esperarRemoto(
      tester,
      find.text('Este dispositivo está listo para recibir notificaciones.'),
    );
    debugPrint('FinanceBro evidencia=esperando_push_primer_plano');
    // La herramienta del administrador envía el mensaje; no se genera una recepción falsa.
    for (var i = 0; i < 450 && !llegado.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      llegado.isCompleted,
      isTrue,
      reason: 'No llegó el mensaje FCM al dispositivo dentro del límite.',
    );
    await esperarRemoto(tester, find.text('Ver'));
    await pausaEvidencia(tester);
    await tester.tap(find.text('Ver'));
    await esperarRemoto(tester, find.text('Tus cuentas'));
    expect(find.text('Cuenta del día a día'), findsOneWidget);
    await pausaEvidencia(tester);
    const nativo = MethodChannel('ec.financebro/evaluacion');
    await nativo.invokeMethod<void>('limpiarAvisos');
    expect(await nativo.invokeMethod<bool>('segundoPlano'), isTrue);
    debugPrint('FinanceBro evidencia=esperando_push_segundo_plano');
    var cantidad = 0;
    for (var intento = 0; intento < 90 && cantidad == 0; intento++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      cantidad = await nativo.invokeMethod<int>('cantidadAvisos') ?? 0;
    }
    expect(
      cantidad,
      greaterThan(0),
      reason: 'Android no publicó la notificación en segundo plano.',
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    debugPrint('FinanceBro evidencia=aviso_android_publicado');
    // UI Automator pulsa el aviso del sistema desde un proceso de prueba separado.
    // Mientras la app está oculta no se solicitan frames al motor Flutter.
    var visible = false;
    for (var intento = 0; intento < 90 && !visible; intento++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      visible = await nativo.invokeMethod<bool>('estaVisible') ?? false;
    }
    expect(
      visible,
      isTrue,
      reason: 'El aviso no devolvió la app al primer plano.',
    );
    await esperarRemoto(tester, find.text('Una experiencia hecha para ti'));
    // El runner de Android cierra su conexión de accesibilidad al finalizar.
    // Dar tiempo a ese cierre antes de comprobar los recursos del test Flutter.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 4)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    debugPrint('FinanceBro evidencia=push_segundo_plano_abierto');
  });
}
