import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/features/banking/banca.dart';
import 'package:financebro/main.dart' as app;
import 'package:financebro/core/configuracion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flujo_critico_test.dart' show esperar;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const capturas = bool.fromEnvironment('CAPTURE_EVIDENCE');
  Future<void> capturar(WidgetTester tester, String nombre) async {
    if (!capturas) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot(nombre);
  }

  testWidgets(
    'Dos cuentas transfieren por QR y los pagos conservan sus históricos',
    (tester) async {
      expect(
        usarEmuladores,
        isTrue,
        reason: 'Este recorrido usa exclusivamente datos locales de prueba.',
      );
      final aplicacion = await app.prepararAplicacion();
      await FirebaseAuth.instanceFor(app: Firebase.app('demo-financebro'))
          .signOut();
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
      if (capturas) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
        }
        await tester.pump(const Duration(milliseconds: 700));
        await capturar(tester, 'banca-acceso');
      }
      await tester.ensureVisible(find.byKey(const Key('enviar-acceso')));
      await tester.tap(find.byKey(const Key('enviar-acceso')));
      await esperar(tester, find.text('Tu dinero, a tu manera'));
      await esperar(tester, find.text('Cuenta de ahorros'));
      debugPrint('verificacion_banca=ingreso');
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Cuenta de ahorros'), findsOneWidget);
      expect(find.text('Cuenta corriente'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (capturas) await capturar(tester, 'banca-inicio');
      debugPrint('verificacion_banca=inicio');
      final contenedor = ProviderScope.containerOf(
            tester.element(find.byType(FinanceBroApp)),
          ),
          db = contenedor.read(datosProvider),
          uid = contenedor.read(identidadProvider).actual!.uid;
      final cuenta = db.doc('usuarios/$uid/cuentas/ahorros');
      final antes = (await tester.runAsync(() => cuenta.get()))!.data()!;
      final numeroDestino = const String.fromEnvironment('NUMERO_DESTINO');
      expect(numeroDestino.length, 14);
      contenedor.read(rutasProvider).go('/qr');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.text('Tengo un código o número'));
      await tester.tap(find.text('Tengo un código o número'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(
        find.byKey(const Key('codigo-qr')),
        'financebro://transferir?cuenta=$numeroDestino&v=1',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.text('Revisar cuenta'));
      await tester.tap(find.text('Revisar cuenta'));
      await esperar(tester, find.text('Valeria Demo'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byKey(const Key('monto-transferencia')));
      await tester.enterText(
        find.byKey(const Key('monto-transferencia')),
        '0.10',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byKey(const Key('cuenta-pago')));
      await tester.tap(find.byKey(const Key('cuenta-pago')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Ahorros · ${antes['numero']}').last);
      await tester.pump(const Duration(milliseconds: 700));
      if (capturas) await capturar(tester, 'banca-transferencia');
      await tester.ensureVisible(find.byKey(const Key('confirmar-pago')));
      await tester.tap(find.byKey(const Key('confirmar-pago')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await esperar(tester, find.byKey(const Key('recibo-pago')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        (await cuenta.get(const GetOptions(source: Source.server)))
            .data()!['saldoCentavos'],
        (antes['saldoCentavos'] as int) - 10,
      );
      if (capturas) await capturar(tester, 'banca-recibo');
      contenedor.read(rutasProvider).go('/qr');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Mi QR'));
      await tester.pump(const Duration(milliseconds: 700));
      await esperar(tester, find.byKey(const Key('numero-mi-qr')));
      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key('numero-mi-qr')))
            .data,
        antes['numeroCuenta'],
      );
      if (capturas) await capturar(tester, 'banca-mi-qr');
      contenedor.read(rutasProvider).go('/pagos/luz');
      await tester.pump(const Duration(milliseconds: 700));
      final contrato = 'E2E${DateTime.now().microsecondsSinceEpoch}';
      await tester.enterText(
        find.widgetWithText(TextField, 'Código de contrato'),
        contrato,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.text('Consultar valor'));
      await tester.tap(find.text('Consultar valor'));
      await esperar(tester, find.text('Energía eléctrica'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byKey(const Key('cuenta-pago')));
      await tester.tap(find.byKey(const Key('cuenta-pago')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Ahorros · ${antes['numero']}').last);
      await tester.pump(const Duration(milliseconds: 700));
      if (capturas) await capturar(tester, 'banca-servicios');
      await tester.ensureVisible(find.text('Revisar y pagar'));
      await tester.tap(find.text('Revisar y pagar'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pago'));
      await esperar(tester, find.byKey(const Key('recibo-pago')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.text('Activar pago mensual'));
      await tester.tap(find.text('Activar pago mensual'));
      await esperar(tester, find.text('Menos pendientes, más planes'));
      await tester.scrollUntilVisible(
        find.text('Tus pagos mensuales'),
        320,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 15,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.text('Tus pagos mensuales'));
      await esperar(tester, find.textContaining(contrato));
      expect(find.textContaining(contrato), findsWidgets);
      if (capturas) await capturar(tester, 'banca-mensuales');
      final banca = contenedor.read(bancaProvider);
      await banca.ejecutar('guardarContacto', {
        'tipo': 'interno',
        'numero': numeroDestino,
      });
      contenedor.read(rutasProvider).go('/contactos');
      await esperar(tester, find.text('Valeria Demo'));
      await tester.pump(const Duration(milliseconds: 700));
      if (capturas) await capturar(tester, 'banca-contactos');
      contenedor.read(rutasProvider).go('/historial');
      await esperar(tester, find.text('Todos tus movimientos'));
      final transferencia = find.text('Transferencia a Valeria Demo');
      // El histórico puede tener varias páginas de pagos mensuales previos.
      for (
        var pagina = 0;
        pagina < 40 && transferencia.evaluate().isEmpty;
        pagina++
      ) {
        final anteriores = find.text('Cargar movimientos anteriores');
        if (anteriores.evaluate().isNotEmpty) {
          await tester.ensureVisible(anteriores);
          await tester.tap(anteriores);
          await tester.pump(const Duration(milliseconds: 700));
        } else {
          await tester.drag(find.byType(ListView).first, const Offset(0, -550));
          await tester.pump(const Duration(milliseconds: 400));
        }
      }
      expect(transferencia, findsWidgets);
      await tester.ensureVisible(transferencia.first);
      await tester.pump(const Duration(milliseconds: 700));
      if (capturas) await capturar(tester, 'banca-historico');
      contenedor.read(rutasProvider).go('/tarjetas');
      await esperar(tester, find.text('Mi FinanceBro'));
      await tester.pump(const Duration(milliseconds: 700));
      if (capturas) await capturar(tester, 'banca-tarjetas');
      contenedor.read(rutasProvider).go('/apertura/corriente');
      await esperar(tester, find.text('Razón social'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Razón social'),
        'Empresa Sebas Demo',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'RUC · 13 dígitos'),
        '1791234567001',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Representante legal'),
        'Sebastian Demo',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.text('Guardar datos y continuar'));
      await tester.tap(find.text('Guardar datos y continuar'));
      await esperar(tester, find.text('Documentos de tu empresa'));
      await tester.pump(const Duration(milliseconds: 700));
      if (capturas) await capturar(tester, 'banca-corriente');
      expect(
        (await db.doc('usuarios/$uid/solicitudes/corriente').get())
            .data()!['estado'],
        'borrador',
      );
      expect(tester.takeException(), isNull);
      contenedor.read(rutasProvider).go('/inicio');
      await tester.pump(const Duration(milliseconds: 700));
    },
  );
}
