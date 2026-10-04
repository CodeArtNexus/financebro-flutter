import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/core/configuracion.dart';
import 'package:financebro/core/funciones_banca.dart';
import 'package:financebro/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flujo_critico_test.dart' show esperar;
import 'registro_test.dart' show llenarRegistro;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'El asesor emite crédito con cupo y el titular activa y paga su tarjeta',
    (tester) async {
      expect(
        usarEmuladores,
        isTrue,
        reason: 'Solo fondos y usuarios sintéticos locales.',
      );
      final aplicacion = await app.prepararAplicacion();
      final principal = Firebase.app('demo-financebro');
      await FirebaseAuth.instanceFor(app: principal).signOut();
      await tester.pumpWidget(aplicacion);
      await tester.pump(const Duration(milliseconds: 700));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(FinanceBroApp)),
      );
      c.read(rutasProvider).go('/registrar');
      await llenarRegistro(tester);
      await esperar(tester, find.text('Tu dinero, a tu manera'));
      final uid = c.read(identidadProvider).actual!.uid;
      final db = c.read(datosProvider);
      final adminApp = await Firebase.initializeApp(
        name: 'asesor-tarjetas',
        options: principal.options,
      );
      final auth = FirebaseAuth.instanceFor(app: adminApp);
      await auth.useAuthEmulator(servidorEmuladores, puertoAuth);
      await tester.runAsync(
        () => auth.signInWithEmailAndPassword(
          email: 'admin@financebro.test',
          password: 'FinanceBro-admin-local-2026!',
        ),
      );
      final funciones = FirebaseFunctions.instanceFor(app: adminApp);
      funciones.useFunctionsEmulator(servidorEmuladores, puertoFunciones);
      Future<void> administrar(
        String operacion,
        Map<String, dynamic> datos,
      ) async {
        await tester.runAsync(() => llamarBanca(funciones, operacion, datos));
      }

      Future<void> pulsar(Finder f) async {
        await esperar(tester, f);
        mensajero.currentState?.clearSnackBars();
        mensajero.currentState?.removeCurrentSnackBar();
        await tester.ensureVisible(f);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(f);
        await tester.pump(const Duration(milliseconds: 600));
      }

      Future<Map<String, dynamic>> tarjeta() async => (await tester.runAsync(
        () => db
            .doc('usuarios/$uid/tarjetas/bro_credito')
            .get(const GetOptions(source: Source.server)),
      ))!.data()!;
      c.read(rutasProvider).go('/tarjetas/credito');
      await esperar(tester, find.byKey(const Key('ocupacion-credito')));
      await tester.enterText(
        find.byKey(const Key('ocupacion-credito')),
        'Arquitecta',
      );
      await tester.enterText(find.byKey(const Key('ingresos-credito')), '2400');
      FocusManager.instance.primaryFocus?.unfocus();
      await pulsar(find.byType(CheckboxListTile));
      await pulsar(find.text('Enviar solicitud'));
      await esperar(tester, find.text('En revisión por un asesor'));
      await administrar('revisarTarjeta', {
        'uid': uid,
        'id': 'credito',
        'accion': 'aprobar',
        'cupoCentavos': 150000,
        'nota': 'Tarjeta y cupo aprobados tras revisión',
      });
      await esperar(tester, find.text('Tu tarjeta de crédito está aprobada'));
      expect((await tarjeta())['estado'], 'pendiente_corte');
      await pulsar(find.text('Ver tarjeta y elegir mi corte'));
      await pulsar(find.byKey(const Key('condiciones-corte')));
      await pulsar(find.text('Activar mi tarjeta'));
      await esperar(tester, find.text('Tu estado de cuenta'));
      expect((await tarjeta())['diaCorte'], 15);
      await administrar('registrarConsumoTarjeta', {
        'uid': uid,
        'centavos': 15000,
        'comercio': 'Librería Alameda',
        'referencia': 'compra_${DateTime.now().microsecondsSinceEpoch}',
      });
      await administrar('ajustar', {
        'uid': uid,
        'cuenta': 'ahorros',
        'centavos': 5000,
        'motivo': 'Fondos sintéticos para abono',
        'referencia': 'fondos_${DateTime.now().microsecondsSinceEpoch}',
      });
      await pulsar(find.text('Pagar mi tarjeta'));
      await pulsar(find.byKey(const Key('cuenta-pago')));
      final ahorro = (await tester.runAsync(
        () => db.doc('usuarios/$uid/cuentas/ahorros').get(),
      ))!.data()!;
      await pulsar(find.text('Ahorros · ${ahorro['numero']}').last);
      await tester.ensureVisible(find.byKey(const Key('importe-pago-credito')));
      await tester.enterText(
        find.byKey(const Key('importe-pago-credito')),
        '20.00',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await pulsar(find.text('Revisar abono'));
      await pulsar(find.widgetWithText(FilledButton, 'Confirmar pago'));
      await esperar(tester, find.byKey(const Key('recibo-pago')));
      expect((await tarjeta())['deudaCentavos'], 13000);
      expect((await tarjeta())['cupoCentavos'], 150000);
      final cuenta = (await tester.runAsync(
        () => db
            .doc('usuarios/$uid/cuentas/ahorros')
            .get(const GetOptions(source: Source.server)),
      ))!.data()!;
      expect(cuenta['saldoCentavos'], 3000);
      c.read(rutasProvider).go('/historial?tipo=tarjeta&id=bro_credito');
      await esperar(tester, find.text('Compra · Librería Alameda'));
      expect(find.text('Pago desde Cuenta de ahorros'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await auth.signOut();
    },
  );
}
