import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/core/configuracion.dart';
import 'package:financebro/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flujo_critico_test.dart' show esperar;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Crear usuario no abre una cuenta sin consentimiento y permite abrirla después',
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
      contenedor.read(rutasProvider).go('/registrar');
      await esperar(tester, find.byKey(const Key('nombre')));
      await tester.enterText(find.byKey(const Key('nombre')), 'Apertura Demo');
      await tester.enterText(
        find.byKey(const Key('correo')),
        'apertura${DateTime.now().microsecondsSinceEpoch}@financebro.test',
      );
      await tester.enterText(
        find.byKey(const Key('clave')),
        'FinanceBro-apertura-2026!',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
      await tester.tap(find.byKey(const Key('enviar-acceso')));
      await esperar(tester, find.text('Tu dinero, a tu manera'));
      final uid = contenedor.read(identidadProvider).actual!.uid;
      final db = contenedor.read(datosProvider);
      expect(
        (await tester.runAsync(
          () => db
              .collection('usuarios/$uid/cuentas')
              .get(const GetOptions(source: Source.server)),
        ))!.docs,
        isEmpty,
      );
      const numero = String.fromEnvironment('NUMERO_DESTINO');
      expect(numero.length, 14);
      contenedor.read(rutasProvider).go('/transferir?numero=$numero');
      await esperar(
        tester,
        find.text('Abre una cuenta para transferir y pagar.'),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirmar-pago')))
            .onPressed,
        isNull,
      );
      contenedor.read(rutasProvider).go('/apertura/ahorros');
      await esperar(tester, find.widgetWithText(TextField, 'Teléfono'));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('abrir-ahorros')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Teléfono'),
        '0999999999',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Identificación de prueba'),
        'DEMO123456',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nacimiento · AAAA-MM-DD'),
        '1990-01-01',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byKey(const Key('abrir-ahorros')));
      await tester.tap(find.byKey(const Key('abrir-ahorros')));
      await esperar(tester, find.text('Tu dinero, a tu manera'));
      final cuenta = (await tester.runAsync(
        () => db
            .doc('usuarios/$uid/cuentas/ahorros')
            .get(const GetOptions(source: Source.server)),
      ))!.data()!;
      expect(cuenta['saldoCentavos'], 0);
      expect(cuenta['estado'], 'activa');
      expect(cuenta['numeroCuenta'], matches(RegExp(r'^\d{14}$')));
      final consentimiento = (await tester.runAsync(
        () => db.doc('usuarios/$uid/datosPersonales/identidad').get(),
      ))!.data()!;
      expect(consentimiento['terminos'], 'demostracion-2026-10');
      expect(consentimiento['aceptado'], isA<Timestamp>());
      expect(tester.takeException(), isNull);
    },
  );
}
