import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:financebro/main.dart' as app;
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/core/configuracion.dart';
import 'package:financebro/core/control_red.dart';
import 'package:financebro/core/red_banco.dart';
import 'package:financebro/features/banking/fondos_tarjeta.dart';
import 'package:financebro/features/banking/pendientes_pantalla.dart';
import 'package:financebro/features/banking/cola_transferencias.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flujo_critico_test.dart' show esperar;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Chequera, imágenes privadas y transferencias pendientes funcionan sin duplicar fondos',
    (tester) async {
      expect(usarEmuladores, true);
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final raiz = await app.prepararAplicacion(
            autenticarDispositivo: () async => true,
          ),
          principal = Firebase.app('demo-financebro');
      await FirebaseAuth.instanceFor(app: principal).signOut();
      await tester.pumpWidget(raiz);
      await tester.pump(const Duration(seconds: 1));
      final c = ProviderScope.containerOf(
            tester.element(find.byType(FinanceBroApp)),
          ),
          router = c.read(rutasProvider),
          red = c.read(redBancoProvider);
      Future<void> redLista() async {
        for (var i = 0; i < 15 && !red.conectado; i++) {
          await tester.runAsync(red.revisar);
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(red.conectado, true);
      }

      Future<void> pulsar(Finder f) async {
        await esperar(tester, f);
        mensajero.currentState?.clearSnackBars();
        mensajero.currentState?.removeCurrentSnackBar();
        await tester.ensureVisible(f);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(f);
        await tester.pump(const Duration(milliseconds: 700));
      }

      Future<void> escribir(Finder f, String t) async {
        await tester.ensureVisible(f);
        await tester.enterText(f, t);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));
      }

      final plataforma = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      const capturas = bool.fromEnvironment('CAPTURE_EVIDENCE');
      if (capturas && plataforma == 'android') {
        await binding.convertFlutterSurfaceToImage();
      }
      Future<void> foto(String nombre) async {
        if (!capturas) return;
        mensajero.currentState?.clearSnackBars();
        mensajero.currentState?.removeCurrentSnackBar();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 800)),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: nombre);
        final png = await binding.takeScreenshot(nombre);
        final carpeta = defaultTargetPlatform == TargetPlatform.android
            ? Directory(
                '/data/data/ec.financebro.financebro/files/financebro_nextgen',
              )
            : Directory('${Directory.systemTemp.path}/financebro_nextgen');
        await tester.runAsync(() async {
          await carpeta.create(recursive: true);
          await File('${carpeta.path}/$nombre.png').writeAsBytes(png);
        });
        binding.reportData?.remove('screenshots');
        if (plataforma == 'android') {
          (binding.reportData ??= {})['capturasNextgen'] ??= <String>[];
          (binding.reportData!['capturasNextgen'] as List<String>).add(nombre);
        }
      }

      Future<void> abrir(String ruta, String nombre) async {
        router.go(ruta);
        await tester.pump(const Duration(seconds: 1));
        await foto(nombre);
      }

      await redLista();
      await abrir('/ingresar', '01-acceso');
      await tester.runAsync(
        () => c
            .read(identidadProvider)
            .ingresar(
              'nextgen_$plataforma@financebro.test',
              const String.fromEnvironment('NEXTGEN_CLAVE'),
            ),
      );
      await esperar(tester, find.text('Tu dinero, a tu manera'));
      final uid = c.read(identidadProvider).actual!.uid,
          db = c.read(datosProvider);
      final tarjetas = (await tester.runAsync(
        () => db.collection('usuarios/$uid/tarjetas').get(),
      ))!.docs;
      final fondo =
          tarjetas.firstWhere((t) => t.id == 'bro_ahorros').data()['fondoRuta']
              as String;
      final imagen = await tester.runAsync(
        () => c.read(fondoTarjetaProvider(fondo).future),
      );
      expect(imagen, isNotNull);
      expect(imagen!.length, greaterThan(100));
      expect(imagen.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      await foto('02-inicio');
      expect(
        find.text('Ya casi despegamos. Vamos por tu próximo viaje.'),
        findsOneWidget,
      );
      await abrir('/tarjetas', '03-tarjetas');
      await esperar(tester, find.text('Mi tarjeta Aurora'));
      expect(find.text('Solicitar tarjeta de crédito'), findsNothing);
      await esperar(tester, find.byType(FondoTarjeta).first);
      await foto('03-tarjetas');
      await abrir('/tarjetas/credito/detalle', '04-credito');
      await esperar(tester, find.text('Tu estado de cuenta'));
      await foto('04-credito');
      await abrir(
        '/historial?tipo=tarjeta&id=bro_credito',
        '05-movimientos-tarjeta',
      );
      await esperar(tester, find.text('Compra · Librería Alameda'));
      await foto('05-movimientos-tarjeta');
      expect(find.byType(NavigationBar), findsOneWidget);
      await abrir('/chequera', '06-chequera');
      await esperar(tester, find.text('Emitir cheques'));
      await foto('06-chequera');
      await pulsar(find.text('Emitir cheques'));
      await esperar(tester, find.byKey(const Key('cheque-numero')));
      await escribir(
        find.byKey(const Key('cheque-numero')),
        const String.fromEnvironment('NUMERO_CORRIENTE'),
      );
      await pulsar(find.text('Validar beneficiario'));
      await esperar(tester, find.text('Valeria Insumos'));
      await escribir(
        find.byKey(const Key('cheque-concepto')),
        'Entrega mensual de materiales',
      );
      await escribir(find.byKey(const Key('cheque-monto-0')), '25.00');
      await foto('07-emitir-cheque');
      await pulsar(find.byType(CheckboxListTile));
      await pulsar(find.text('Emitir y avisar al beneficiario'));
      await esperar(tester, find.text('Agregar otro lote de cheques'));
      await foto('08-agrupacion');
      final cheques = (await tester.runAsync(
        () => db
            .collection('usuarios/$uid/cheques')
            .where('concepto', isEqualTo: 'Entrega mensual de materiales')
            .get(),
      ))!.docs;
      var cheque = cheques.first;
      for (final registroCheque in cheques) {
        if ((registroCheque.data()['creado'] as Timestamp).compareTo(
              cheque.data()['creado'] as Timestamp,
            ) >
            0) {
          cheque = registroCheque;
        }
      }
      await abrir('/chequera/cheques/${cheque.id}', '09-detalle-cheque');
      await esperar(tester, find.text('Bloquear'));
      await foto('09-detalle-cheque');
      expect(find.byType(NavigationBar), findsOneWidget);
      // El histórico se mantiene visible después de una gestión y se cobra solo al desbloquear.
      await pulsar(find.text('Bloquear'));
      await escribir(
        find.widgetWithText(TextField, 'Motivo'),
        'Confirmamos la entrega con el proveedor',
      );
      await pulsar(find.text('Confirmar cambio'));
      await esperar(tester, find.text('Reactivar'));
      await foto('10-cheque-bloqueado');
      await pulsar(find.text('Reactivar'));
      await escribir(
        find.widgetWithText(TextField, 'Motivo'),
        'Entrega confirmada por ambas personas',
      );
      await pulsar(find.text('Confirmar cambio'));
      await esperar(tester, find.text('Reintentar cobro ahora'));
      await pulsar(find.text('Reintentar cobro ahora'));
      await esperar(tester, find.text('Cobrado'));
      await foto('11-cheque-cobrado');
      final ahorroRef = db.doc('usuarios/$uid/cuentas/ahorros'),
          antes = (await tester.runAsync(
            () => ahorroRef.get(const GetOptions(source: Source.server)),
          ))!.data()!['saldoCentavos'];
      final memoria = AlmacenSeguroCola();
      const clave = 'verificacion_keychain';
      await tester.runAsync(() => memoria.escribir(clave, 'cifrado_usable'));
      expect(
        await tester.runAsync(() => memoria.leer(clave)),
        'cifrado_usable',
      );
      final cacheContactos = (await tester.runAsync(
        () => db
            .collection('usuarios/$uid/contactos')
            .get(const GetOptions(source: Source.cache)),
      ))!.docs;
      expect(cacheContactos, isNotEmpty);
      final numero = const String.fromEnvironment('NUMERO_CORRIENTE');
      await tester.runAsync(
        () => c.read(controlRedProvider).cambiar(EscenarioRed.sinConexion),
      );
      await tester.runAsync(red.revisar);
      await tester.pump(const Duration(milliseconds: 700));
      expect(red.conectado, false);
      await abrir('/qr', '12-qr-sin-conexion');
      await pulsar(find.text('Tengo un código o número'));
      await escribir(find.byKey(const Key('codigo-qr')), numero);
      await pulsar(find.text('Revisar cuenta'));
      await esperar(tester, find.text('Valeria Insumos'));
      await escribir(find.byKey(const Key('monto-transferencia')), '0.10');
      final ahorro = (await tester.runAsync(
        () => ahorroRef.get(const GetOptions(source: Source.cache)),
      ))!.data()!;
      await pulsar(find.byKey(const Key('cuenta-pago')));
      await pulsar(find.text('Ahorros · ${ahorro['numero']}').last);
      await pulsar(find.byKey(const Key('confirmar-pago')));
      await pulsar(find.widgetWithText(FilledButton, 'Confirmar'));
      await esperar(tester, find.text('Transferencia preparada'));
      await foto('13-transferencia-preparada');
      await abrir('/pendientes', '14-pendientes');
      final cola = c.read(colaTransferenciasProvider);
      expect(cola.items.any((v) => v['estado'] == 'pendiente'), true);
      await tester.runAsync(
        () => c.read(controlRedProvider).cambiar(EscenarioRed.normal),
      );
      await tester.runAsync(red.revisar);
      await redLista();
      await tester.runAsync(cola.procesar);
      await esperar(
        tester,
        find.textContaining('Transferencia confirmada por FinanceBro.'),
      );
      await foto('15-transferencia-confirmada');
      expect(
        (await tester.runAsync(
          () => ahorroRef.get(const GetOptions(source: Source.server)),
        ))!.data()!['saldoCentavos'],
        (antes as int) - 10,
      );
      await tester.runAsync(cola.procesar);
      expect(
        (await tester.runAsync(
          () => ahorroRef.get(const GetOptions(source: Source.server)),
        ))!.data()!['saldoCentavos'],
        antes - 10,
      );
      final contacto = (await tester.runAsync(
        () => db
            .collection('usuarios/$uid/contactos')
            .where('numero', isEqualTo: numero)
            .get(),
      ))!.docs.first;
      await abrir('/contactos/${contacto.id}', '16-contacto-historico');
      await esperar(tester, find.textContaining('Transferencia FinanceBro'));
      await foto('16-contacto-historico');
      await abrir('/perfil', '17-perfil');
      await abrir('/notificaciones', '18-notificaciones');
      expect(find.byTooltip('Volver'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await pulsar(find.byTooltip('Volver'));
      expect(find.text('Tu dinero, a tu manera'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (capturas) {
        await abrir('/contactos', '19-contactos');
        await esperar(tester, find.text('Valeria Insumos'));
        await foto('19-contactos');
        await pulsar(find.text('Registrar contacto'));
        await foto('20-contacto-interno');
        await pulsar(find.text('Otro banco'));
        await foto('21-contacto-externo');
        await abrir('/qr?recibir=true', '22-mi-qr');
        await esperar(tester, find.byKey(const Key('numero-mi-qr')));
        await foto('22-mi-qr');
        await abrir('/pagos', '23-servicios');
        await esperar(tester, find.text('Energía eléctrica'));
        await foto('23-servicios');
        await abrir('/pagos/luz', '24-consultar-planilla');
        await abrir('/metas', '25-metas-ahorro');
        await abrir('/divisas', '26-divisas');
        await abrir('/cuentas', '27-cuentas');
        expect(find.text('Abrir cuenta de ahorros'), findsNothing);
        await abrir('/cuentas/corriente', '28-corriente-movimientos');
        await esperar(tester, find.text('Abrir mi chequera digital'));
        await foto('28-corriente-movimientos');
        await abrir('/tarjetas', '29-tarjeta-opciones');
        await pulsar(find.text('Mi tarjeta Aurora'));
        await foto('29-tarjeta-opciones');
        await pulsar(find.text('Personalizar diseño'));
        await esperar(tester, find.text('Personaliza tu tarjeta FinanceBro'));
        await foto('30-personalizar-fondo');
        await abrir('/tarjetas/fisica/bro_ahorros', '31-tarjeta-fisica');
        await abrir(
          '/pagar-externo?tipo=tarjeta&id=externa_alameda',
          '32-pagar-tarjeta-externa',
        );
        await abrir('/tarjetas/credito/detalle?pagar=true', '33-pagar-credito');
        await abrir('/historial', '34-historico-global');
      }
      debugPrint(
        'verificacion_nextgen=cheques_imagenes_keychain_conexion_cola_historicos_completada',
      );
    },
  );
}
