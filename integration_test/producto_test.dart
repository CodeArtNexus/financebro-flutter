import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:financebro/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flujo_critico_test.dart' show esperar;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const capturas = bool.fromEnvironment('CAPTURE_EVIDENCE');
  testWidgets('La nueva identidad permite ingresar y consultar tarjetas', (
    tester,
  ) async {
    final aplicacion = await app.prepararAplicacion();
    await FirebaseAuth.instanceFor(app: Firebase.app('demo-financebro'))
        .signOut();
    await tester.pumpWidget(aplicacion);
    await esperar(tester, find.text('Ya tengo una cuenta'));
    await tester.ensureVisible(find.text('Ya tengo una cuenta'));
    await tester.tap(find.text('Ya tengo una cuenta'));
    await esperar(tester, find.byKey(const Key('correo')));
    await tester.pumpAndSettle();
    if (capturas) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('producto-acceso');
    }
    await tester.enterText(
      find.byKey(const Key('correo')),
      'demo@financebro.test',
    );
    await tester.enterText(
      find.byKey(const Key('clave')),
      'FinanceBro-local-2026!',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
    await tester.tap(find.byKey(const Key('enviar-acceso')));
    await esperar(tester, find.text('Mis tarjetas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('••••  ••••  ••••'), findsWidgets);
    if (capturas) await binding.takeScreenshot('producto-inicio');
    await tester.tap(find.text('Cuentas'));
    await esperar(tester, find.text('Cuenta del día a día'));
    await tester.tap(find.text('Cuenta del día a día'));
    await esperar(tester, find.text('Supermercado de prueba'));
    expect(find.text('Ingreso de prueba'), findsOneWidget);
  });
}
