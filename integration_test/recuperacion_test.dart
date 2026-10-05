import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:financebro/main.dart' as app;
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/core/configuracion.dart';
import 'package:financebro/core/errores.dart';
import 'package:financebro/core/funciones_banca.dart';
import 'package:financebro/features/auth/firebase_identidad.dart';
import 'package:financebro/features/banking/banca.dart';
import 'package:financebro/features/banking/pendientes_pantalla.dart';

import 'registro_test.dart' show llenarRegistro;

Future<void> esperarReal(WidgetTester t, Finder objetivo) async {
  final reloj = Stopwatch()..start();
  while (reloj.elapsed < const Duration(seconds: 60)) {
    await t.pump();
    if (objetivo.evaluate().isNotEmpty) return;
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
  }
  throw TestFailure(
    'No apareció $objetivo. ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(" | ")}',
  );
}

// Descarta una respuesta después de que el servidor haya confirmado de verdad.
class RespuestaPerdida extends Banca {
  RespuestaPerdida(super.functions, super.db, super.storage);
  bool perder = true;
  bool recuperar = false;
  Map<String, dynamic>? recibo;
  @override
  Future<Map<String, dynamic>> ejecutar(
    String operacion, [
    Map<String, dynamic> datos = const {},
  ]) async {
    if (operacion == 'transferir' && !perder && !recuperar) {
      throw const FalloApp('Esperando recuperación', transitorio: true);
    }
    final resultado = await super.ejecutar(operacion, datos);
    if (operacion == 'transferir' && perder) {
      perder = false;
      recibo = resultado;
      throw const FalloApp(
        'Respuesta perdida después de confirmar',
        transitorio: true,
      );
    }
    return resultado;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Alta interrumpida y transferencia recuperada con almacenamiento nativo y comprobante único',
    (t) async {
      expect(
        usarEmuladores,
        isTrue,
        reason:
            'Nunca ejecutar este fallo inducido contra el servidor publicado.',
      );
      final raiz = await app.prepararAplicacion(
        autenticarDispositivo: () async => true,
      ) as ProviderScope;
      final firebase = Firebase.app('demo-financebro');
      await FirebaseAuth.instanceFor(app: firebase).signOut();
      var primerAlta = true;
      RespuestaPerdida? transporte;
      Widget crearApp() => ProviderScope(
        key: UniqueKey(),
        overrides: [
          ...raiz.overrides,
          identidadProvider.overrideWith((ref) {
            final funciones = ref.watch(funcionesProvider);
            final identidad = FirebaseIdentidad(
              ref.watch(authFirebaseProvider),
              ref.watch(datosProvider),
              ref.watch(preferenciasLocalesProvider),
              funciones,
              () async => true,
              tieneConexion: () async => true,
              completarApertura: (registro) async {
                if (primerAlta) {
                  primerAlta = false;
                  throw const ErrorFuncionBanca(
                    'unavailable',
                    'Apertura interrumpida',
                  );
                }
                return llamarBanca(
                  funciones,
                  'registrarCliente',
                  registro.apertura,
                );
              },
            );
            ref.onDispose(identidad.dispose);
            return identidad;
          }),
          bancaProvider.overrideWith((ref) {
            final storage = FirebaseStorage.instanceFor(app: firebase)
              ..useStorageEmulator(servidorEmuladores, puertoStorage);
            return transporte ??= RespuestaPerdida(
              ref.watch(funcionesProvider),
              ref.watch(datosProvider),
              storage,
            );
          }),
        ],
        child: const FinanceBroApp(),
      );
      await t.pumpWidget(crearApp());
      await t.pump(const Duration(seconds: 2));
      await esperarReal(t, find.byType(FinanceBroApp));
      var c = ProviderScope.containerOf(t.element(find.byType(FinanceBroApp)));
      c.read(rutasProvider).go('/registrar');
      await llenarRegistro(t);
      await esperarReal(t, find.textContaining('Conservamos tu acceso'));
      final auth = FirebaseAuth.instanceFor(app: firebase),
          db = c.read(datosProvider);
      final uidAlta = auth.currentUser!.uid;
      expect(
        (await t.runAsync(
          () => db.collection('usuarios/$uidAlta/cuentas').get(),
        ))!.docs,
        isEmpty,
      );
      await t.ensureVisible(find.byKey(const Key('enviar-acceso')));
      await t.pump(const Duration(milliseconds: 350));
      await t.tap(find.byKey(const Key('enviar-acceso')));
      await esperarReal(t, find.text('Tu dinero, a tu manera'));
      expect(auth.currentUser!.uid, uidAlta);
      final alta = (await t.runAsync(
        () => db.collection('usuarios/$uidAlta/cuentas').get(),
      ))!;
      final tarjetas = (await t.runAsync(
        () => db.collection('usuarios/$uidAlta/tarjetas').get(),
      ))!;
      expect(alta.docs.length, 1);
      expect(alta.docs.single.data()['saldoCentavos'], 0);
      expect(tarjetas.docs.length, 1);
      expect(tarjetas.docs.single.data()['clase'], 'debito');
      debugPrint('recuperacion=alta_unica_con_acceso_conservado');
      await t.runAsync(() => c.read(identidadProvider).salir());
      c.read(rutasProvider).go('/ingresar');
      Future<void> ingresar({String correo = 'demo@financebro.test'}) async {
        await esperarReal(t, find.byKey(const Key('correo')));
        t.testTextInput.register();
        await t.enterText(find.byKey(const Key('correo')), correo);
        await t.enterText(
          find.byKey(const Key('clave')),
          'FinanceBro-local-2026!',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await t.ensureVisible(find.byKey(const Key('enviar-acceso')));
        await t.pump(const Duration(milliseconds: 350));
        await t.tap(find.byKey(const Key('enviar-acceso')));
        await esperarReal(t, find.text('Tu dinero, a tu manera'));
      }

      await ingresar();
      final uid = auth.currentUser!.uid;
      final antes = (await t.runAsync(
        () => db.doc('usuarios/$uid/cuentas/ahorros').get(),
      ))!.data()!;
      const numero = String.fromEnvironment('NUMERO_DESTINO');
      expect(numero.length, 14);
      c.read(rutasProvider).go('/qr');
      await esperarReal(t, find.text('Tengo un código o número'));
      await t.tap(find.text('Tengo un código o número'));
      await t.pump();
      await t.enterText(
        find.byKey(const Key('codigo-qr')),
        'financebro://transferir?cuenta=$numero&v=1',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await t.drag(find.byType(ListView).first, const Offset(0, -350));
      await t.pump(const Duration(milliseconds: 400));
      await t.ensureVisible(find.text('Revisar cuenta'));
      await t.pump(const Duration(milliseconds: 350));
      await t.tap(find.text('Revisar cuenta'));
      await esperarReal(t, find.text('Valeria Demo'));
      await t.ensureVisible(find.byKey(const Key('monto-transferencia')));
      await t.pump(const Duration(milliseconds: 350));
      await t.enterText(find.byKey(const Key('monto-transferencia')), '0.10');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.ensureVisible(find.byKey(const Key('cuenta-pago')));
      await t.pump(const Duration(milliseconds: 350));
      await t.tap(find.byKey(const Key('cuenta-pago')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Ahorros · ${antes['numero']}').last);
      await t.pump(const Duration(milliseconds: 300));
      await t.ensureVisible(find.byKey(const Key('confirmar-pago')));
      await t.pump(const Duration(milliseconds: 350));
      await t.tap(find.byKey(const Key('confirmar-pago')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await esperarReal(
        t,
        find.text(
          'Conservamos tu autorización y referencia. En el estado del envío podrás comprobar si está pendiente, confirmado o rechazado.',
        ),
      );
      final referencia = transporte!.recibo!['referencia'];
      final cola = c.read(colaTransferenciasProvider);
      expect(
        cola.items.singleWhere((e) => e['referencia'] == referencia)['estado'],
        'pendiente',
      );
      await t.runAsync(() => cola.guardar());
      await t.pumpWidget(const SizedBox());
      await t.pump();
      // Nueva composición, nueva identidad y nueva cola; conserva el almacenamiento seguro real.
      transporte!.recuperar = true;
      await t.pumpWidget(crearApp());
      await t.pump(const Duration(seconds: 2));
      await esperarReal(t, find.byType(FinanceBroApp));
      c = ProviderScope.containerOf(t.element(find.byType(FinanceBroApp)));
      c.read(rutasProvider).go('/ingresar');
      await ingresar();
      c.read(rutasProvider).go('/pendientes');
      await esperarReal(t, find.byKey(const Key('recibo-pago')));
      expect(find.text('Referencia: $referencia'), findsOneWidget);
      final despues = (await t.runAsync(
        () => db
            .doc('usuarios/$uid/cuentas/ahorros')
            .get(const GetOptions(source: Source.server)),
      ))!.data()!;
      expect(despues['saldoCentavos'], (antes['saldoCentavos'] as int) - 10);
      final recibos = (await t.runAsync(
        () => db
            .collection('usuarios/$uid/operaciones')
            .where(FieldPath.documentId, isEqualTo: referencia)
            .get(),
      ))!;
      expect(recibos.docs.length, 1);
      final movimientos = (await t.runAsync(
        () => db
            .collection('usuarios/$uid/cuentas/ahorros/movimientos')
            .where('referencia', isEqualTo: referencia)
            .get(),
      ))!;
      expect(movimientos.docs.length, 1);
      const uidDestino = String.fromEnvironment('UID_DESTINO');
      const saldoDestino = int.fromEnvironment('SALDO_DESTINO');
      expect(uidDestino, isNotEmpty);
      await t.runAsync(() async {
        await expectLater(
          db.doc('usuarios/$uidDestino/cuentas/ahorros').get(),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'codigo',
              'permission-denied',
            ),
          ),
        );
      });
      await t.runAsync(() => c.read(identidadProvider).salir());
      c.read(rutasProvider).go('/ingresar');
      await ingresar(correo: 'valeria@financebro.test');
      expect(auth.currentUser!.uid, uidDestino);
      final destino = (await t.runAsync(
        () => db
            .doc('usuarios/$uidDestino/cuentas/ahorros')
            .get(const GetOptions(source: Source.server)),
      ))!.data()!;
      expect(destino['saldoCentavos'], saldoDestino + 10);
      final abonos = (await t.runAsync(
        () => db
            .collection('usuarios/$uidDestino/cuentas/ahorros/movimientos')
            .where('referenciaOperacion', isEqualTo: referencia)
            .get(),
      ))!;
      expect(abonos.docs.length, 1);
      expect(abonos.docs.single.data()['centavos'], 10);
      expect(t.takeException(), isNull);
      debugPrint('recuperacion=almacen_nativo_comprobante_unico_debito_abono');
      await t.pumpWidget(const SizedBox());
    },
  );
}
