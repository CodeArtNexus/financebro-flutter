import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/features/payments/pagos.dart';
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
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
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(FinanceBroApp)),
    );
    final datos = contenedor.read(datosProvider);
    final uid = contenedor.read(identidadProvider).actual!.uid;
    final cuenta = datos.doc('usuarios/$uid/cuentas/principal');
    final saldoAntes =
        (await cuenta.get(const GetOptions(source: Source.server)))
                .data()!['saldoCentavos']
            as int;
    final referencia = 'e2e-${DateTime.now().microsecondsSinceEpoch}';
    final solicitud = SolicitudQr('cafe-bro', 450, referencia);
    await tester.tap(find.text('QR'));
    await esperar(tester, find.text('Tengo un código de pago'));
    await tester.ensureVisible(find.text('Tengo un código de pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tengo un código de pago'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('codigo-qr')),
      solicitud.contenido,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Revisar código'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar código'));
    await esperar(tester, find.text('Café Bro'));
    await tester.ensureVisible(find.byKey(const Key('cuenta-pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cuenta-pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta del día a día').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('confirmar-pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-pago')));
    await esperar(tester, find.byKey(const Key('recibo-pago')));
    await tester.ensureVisible(find.byKey(const Key('recibo-pago')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    if (capturas) await binding.takeScreenshot('producto-qr');
    expect(
      (await cuenta.get(const GetOptions(source: Source.server)))
          .data()!['saldoCentavos'],
      saldoAntes - 450,
    );
    // Un reintento del mismo recibo conserva el saldo, incluso con llamadas concurrentes.
    final pagos = contenedor.read(pagosRepositorioProvider);
    await Future.wait([
      pagos.pagar(uid, 'principal', solicitud),
      pagos.pagar(uid, 'principal', solicitud),
    ]);
    expect(
      (await cuenta.get(const GetOptions(source: Source.server)))
          .data()!['saldoCentavos'],
      saldoAntes - 450,
    );
    expect(
      (await cuenta.collection('movimientos').doc(referencia).get())
          .data()!['centavos'],
      -450,
    );
    await tester.tap(find.text('Metas'));
    await esperar(tester, find.byKey(const Key('nueva-meta')));
    await tester.tap(find.byKey(const Key('nueva-meta')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nombre-meta')),
      'Mi próximo viaje',
    );
    await tester.enterText(find.byKey(const Key('objetivo-meta')), '5000');
    await tester.enterText(find.byKey(const Key('aporte-meta')), '100');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guardar-meta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardar-meta')));
    await esperar(tester, find.text('Mi próximo viaje'));
    await tester.pumpAndSettle();
    if (capturas) await binding.takeScreenshot('producto-metas');
    final guardadas = await datos
        .collection('usuarios/$uid/metas')
        .get(const GetOptions(source: Source.server));
    expect(
      guardadas.docs.any(
        (d) =>
            d.data()['nombre'] == 'Mi próximo viaje' &&
            d.data()['aporteMensualCentavos'] == 10000,
      ),
      isTrue,
    );
  });
}
