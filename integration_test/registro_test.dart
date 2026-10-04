import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/core/configuracion.dart';
import 'package:financebro/features/auth/registro.dart';
import 'package:financebro/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flujo_critico_test.dart' show esperar;

Future<void> llenarRegistro(WidgetTester tester, {String? correo}) async {
  // Mantiene la escritura automatizada sin competir con el teclado nativo.
  tester.testTextInput.register();
  addTearDown(tester.testTextInput.unregister);
  await esperar(tester, find.byKey(const Key('nombre')));
  final datos = {
    'nombre': 'Lucía',
    'apellidos': 'Pérez',
    'cedula': DateTime.now().millisecondsSinceEpoch.toString().substring(3),
    'correo':
        correo ??
        'alta${DateTime.now().microsecondsSinceEpoch}@financebro.test',
    'clave': 'FinanceBro-registro-2026!',
  };
  for (final d in datos.entries) {
    await tester.ensureVisible(find.byKey(Key(d.key)));
    await tester.enterText(find.byKey(Key(d.key)), d.value);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
  await tester.tap(find.byKey(const Key('enviar-acceso')));
  await tester.pump(const Duration(milliseconds: 700));
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('enviar-acceso')))
        .onPressed,
    isNull,
  );
  for (final d in {
    'direccion': 'Calle Naranjos 120',
    'ciudad': 'Quito',
    'telefono': '0991234567',
  }.entries) {
    await tester.ensureVisible(find.byKey(Key(d.key)));
    await tester.enterText(find.byKey(Key(d.key)), d.value);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.ensureVisible(
    find.text('Leer contrato, términos y condiciones'),
  );
  await tester.tap(find.text('Leer contrato, términos y condiciones'));
  await tester.pump(const Duration(milliseconds: 700));
  expect(find.text('Contrato, términos y condiciones'), findsWidgets);
  await tester.tap(find.text('Entendido'));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.ensureVisible(find.byKey(const Key('aceptar-contrato')));
  await tester.tap(find.byKey(const Key('aceptar-contrato')));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
  await tester.tap(find.byKey(const Key('enviar-acceso')));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'El alta obligatoria crea ahorros, débito y consentimiento; permite pedir crédito y tarjeta física',
    (tester) async {
      expect(usarEmuladores, isTrue);
      final aplicacion = await app.prepararAplicacion();
      await FirebaseAuth.instanceFor(app: Firebase.app('demo-financebro'))
          .signOut();
      await tester.pumpWidget(aplicacion);
      await tester.pump(const Duration(milliseconds: 700));
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byType(FinanceBroApp)),
      );
      if (const bool.fromEnvironment('SDK_REGISTRO')) {
        contenedor.read(rutasProvider).go('/registrar');
        await tester.pump(const Duration(milliseconds: 400));
        debugPrint('registro_dispositivo=inicio');
        await tester.runAsync(
          () => contenedor
              .read(identidadProvider)
              .registrar(
                DatosRegistro(
                  nombres: 'Lucía',
                  apellidos: 'Pérez',
                  correo:
                      'iphone${DateTime.now().microsecondsSinceEpoch}@financebro.test',
                  cedula: DateTime.now().millisecondsSinceEpoch
                      .toString()
                      .substring(3),
                  clave: 'FinanceBro-registro-2026!',
                  direccion: 'Calle Naranjos 120',
                  ciudad: 'Quito',
                  telefono: '0991234567',
                ),
              ),
        );
        expect(tester.takeException(), isNull);
        debugPrint('registro_dispositivo=alta_completada');
      } else {
        contenedor.read(rutasProvider).go('/registrar');
        await llenarRegistro(tester);
      }
      await esperar(tester, find.text('Tu dinero, a tu manera'));
      final uid = contenedor.read(identidadProvider).actual!.uid,
          db = contenedor.read(datosProvider);
      final documentos = await tester.runAsync(
        () => Future.wait([
          db
              .collection('usuarios/$uid/cuentas')
              .get(const GetOptions(source: Source.server)),
          db
              .collection('usuarios/$uid/tarjetas')
              .get(const GetOptions(source: Source.server)),
        ]),
      );
      expect(documentos![0].docs.length, 1);
      expect(documentos[1].docs.length, 1);
      expect(documentos[0].docs.single.data()['saldoCentavos'], 0);
      expect(documentos[1].docs.single.data()['clase'], 'debito');
      final personal = await tester.runAsync(
        () => db.doc('usuarios/$uid/datosPersonales/identidad').get(),
      );
      expect(personal!.data()!['contratoVersion'], contratoVersion);
      expect(personal.data()!['aceptado'], isA<Timestamp>());
      debugPrint('registro_dispositivo=ahorros_debito_contrato_verificados');
      if (const bool.fromEnvironment('SDK_REGISTRO')) {
        await tester.runAsync(
          () => contenedor
              .read(identidadProvider)
              .registrar(
                DatosRegistro(
                  nombres: 'Lucía',
                  apellidos: 'Pérez',
                  correo: FirebaseAuth.instanceFor(
                    app: Firebase.app('demo-financebro'),
                  ).currentUser!.email!,
                  cedula: personal.data()!['documento'] as String,
                  clave: 'FinanceBro-registro-2026!',
                  direccion: 'Calle Naranjos 120',
                  ciudad: 'Quito',
                  telefono: '0991234567',
                ),
              ),
        );
        expect(tester.takeException(), isNull);
        debugPrint('registro_dispositivo=reintento_verificado');
        return;
      }
      if (const bool.fromEnvironment('AVISOS_NATIVOS')) {
        const puente = MethodChannel('ec.financebro/evaluacion');
        await puente.invokeMethod<void>('limpiarAvisos');
        final permiso = await tester.runAsync(
          () => contenedor.read(notificacionesRepositorioProvider).activar(uid),
        );
        expect(permiso, true);
      }
      contenedor.read(rutasProvider).go('/tarjetas/fisica/bro_ahorros');
      await esperar(tester, find.byKey(const Key('direccion-fisica')));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('direccion-fisica')))
            .controller!
            .text,
        'Calle Naranjos 120',
      );
      mensajero.currentState?.clearSnackBars();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.text('Solicitar mi tarjeta física'));
      await tester.tap(find.text('Solicitar mi tarjeta física'));
      await esperar(tester, find.text('Preparando tu tarjeta'));
      contenedor.read(rutasProvider).go('/tarjetas/credito');
      await esperar(tester, find.byKey(const Key('ocupacion-credito')));
      await tester.enterText(
        find.byKey(const Key('ocupacion-credito')),
        'Diseñadora',
      );
      await tester.enterText(find.byKey(const Key('ingresos-credito')), '1500');
      FocusManager.instance.primaryFocus?.unfocus();
      mensajero.currentState?.clearSnackBars();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await esperar(tester, find.text('En revisión por un asesor'));
      if (const bool.fromEnvironment('AVISOS_NATIVOS')) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );
        const puente = MethodChannel('ec.financebro/evaluacion');
        expect(
          await puente.invokeMethod<int>('cantidadAvisos'),
          greaterThanOrEqualTo(2),
        );
        debugPrint('avisos_nativos=verificados_por_Android');
      }
      if (const bool.fromEnvironment('CAPTURE_EVIDENCE')) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
        }
        await binding.takeScreenshot('credito-solicitado');
      }
      contenedor.read(rutasProvider).go('/inicio');
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    },
  );
}
