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
  testWidgets('Metas persistentes, saludo recordado y reanudación demo', (
    tester,
  ) async {
    expect(usarEmuladores, isTrue);
    final aplicacion = await app.prepararAplicacion();
    final auth = FirebaseAuth.instanceFor(app: Firebase.app('demo-financebro'));
    await auth.signOut();
    await tester.pumpWidget(aplicacion);
    await tester.pump(const Duration(milliseconds: 700));
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
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(FinanceBroApp)),
    );
    final uid = contenedor.read(identidadProvider).actual!.uid;
    final datos = contenedor.read(datosProvider);
    contenedor.read(rutasProvider).go('/metas');
    await esperar(tester, find.byKey(const Key('nueva-meta')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('nueva-meta')));
    await esperar(tester, find.byKey(const Key('nombre-meta')));
    final nombre = 'Viaje ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(find.byKey(const Key('nombre-meta')), nombre);
    await tester.enterText(find.byKey(const Key('objetivo-meta')), '5000');
    await tester.enterText(find.byKey(const Key('aporte-meta')), '100');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.byKey(const Key('guardar-meta')));
    await tester.tap(find.byKey(const Key('guardar-meta')));
    await esperar(tester, find.text(nombre));
    final guardadas = await tester.runAsync(
      () => datos
          .collection('usuarios/$uid/metas')
          .get(const GetOptions(source: Source.server)),
    );
    expect(
      guardadas!.docs.any(
        (d) =>
            d.data()['nombre'] == nombre &&
            d.data()['aporteMensualCentavos'] == 10000,
      ),
      isTrue,
    );
    // Reinicia la interfaz y su contenedor; el SDK mantiene su sesión previa.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(await app.prepararAplicacion());
    await esperar(tester, find.byKey(const Key('correo')));
    expect(find.textContaining('Hola, Sebastian'), findsOneWidget);
    expect(find.text('Pagar con QR'), findsOneWidget);
    await tester.ensureVisible(find.text('Face ID · demo'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Face ID · demo'));
    await esperar(tester, find.text('Continuar demo'));
    await tester.tap(find.text('Continuar demo'));
    await esperar(tester, find.text('Tu dinero, a tu manera'));
    expect(auth.currentUser?.uid, uid);
    expect(tester.takeException(), isNull);
  });
}
