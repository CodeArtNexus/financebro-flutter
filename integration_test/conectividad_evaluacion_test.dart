import 'dart:io';

import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/core/apariencia.dart';
import 'package:financebro/core/control_red.dart';
import 'package:financebro/core/red_banco.dart';
import 'package:financebro/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Solo consulta identidad, cuentas y el proveedor externo. No mueve fondos.
// Las credenciales se suministran fuera de Git con --dart-define-from-file.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Divisas: latencia, caída parcial, caché y recuperación', (
    t,
  ) async {
    const correo = String.fromEnvironment('EVAL_CORREO');
    const clave = String.fromEnvironment('EVAL_CLAVE');
    expect(correo.isNotEmpty && clave.isNotEmpty, isTrue);
    await t.pumpWidget(await app.prepararAplicacion());
    await t.pump(const Duration(seconds: 1));
    final c = ProviderScope.containerOf(t.element(find.byType(FinanceBroApp)));
    await t.runAsync(() => c.read(identidadProvider).ingresar(correo, clave));
    final router = c.read(rutasProvider);
    final red = c.read(controlRedProvider);
    final preferencias = c.read(preferenciasLocalesProvider);
    final capturas = <String>[];
    final carpeta = Directory(
      Platform.isIOS
          ? '${Directory.systemTemp.path}/financebro_conectividad'
          : '/data/data/ec.financebro.financebro/files/financebro_conectividad',
    );
    final modoAnterior = c.read(modoTemaProvider);
    final cacheAnterior = preferencias.getString('tasa_USD_EUR');

    Future<void> esperar(Finder f) async {
      for (var i = 0; i < 120; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await t.pump(const Duration(milliseconds: 100));
        if (f.evaluate().isNotEmpty) return;
      }
      throw TestFailure('No apareció $f');
    }

    Future<void> foto(String nombre) async {
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull, reason: nombre);
      final bytes = await binding.takeScreenshot(nombre);
      await t.runAsync(() async {
        await carpeta.create(recursive: true);
        await File('${carpeta.path}/$nombre.png').writeAsBytes(bytes);
      });
      capturas.add(nombre);
      binding.reportData?.remove('screenshots');
      debugPrint('Conectividad verificada: $nombre');
    }

    Future<void> actualizar(EscenarioRed escenario) async {
      await t.runAsync(() => red.cambiar(escenario));
      c.invalidate(cotizacionProvider('EUR'));
      await t.pump();
    }

    try {
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await esperar(find.text('Tu dinero, a tu manera'));
      for (final tema in [ThemeMode.light, ThemeMode.dark]) {
        final prefijo = tema == ThemeMode.light ? 'claro' : 'oscuro';
        await t.runAsync(() => c.read(modoTemaProvider.notifier).cambiar(tema));
        await actualizar(EscenarioRed.normal);
        router.go('/divisas');
        await esperar(find.byKey(const Key('resultado-divisas')));
        expect(find.textContaining('puede estar desactualizada'), findsNothing);
        final cacheValida = preferencias.getString('tasa_USD_EUR');
        expect(cacheValida, isNotNull);

        await actualizar(EscenarioRed.latencia);
        expect(find.text('Consultando la tasa'), findsOneWidget);
        await foto('$prefijo-51-divisas-latencia');
        await esperar(find.byKey(const Key('resultado-divisas')));

        await actualizar(EscenarioRed.divisasCaidas);
        await esperar(find.textContaining('puede estar desactualizada'));
        await foto('$prefijo-52-divisas-caida-cache');
        router.go('/inicio');
        await esperar(find.text('Tu dinero, a tu manera'));
        await t.runAsync(() => c.read(redBancoProvider).revisar());
        expect(c.read(redBancoProvider).conectado, isTrue);
        await t.pump(const Duration(seconds: 1));
        await foto('$prefijo-53-cuentas-servicio-parcial');

        await t.runAsync(() => preferencias.remove('tasa_USD_EUR'));
        c.invalidate(cotizacionProvider('EUR'));
        router.go('/divisas');
        await esperar(
          find.text(
            'El servicio de divisas no está disponible por el momento.',
          ),
        );
        await foto('$prefijo-54-divisas-error-sin-cache');

        await t.runAsync(
          () => preferencias.setString('tasa_USD_EUR', cacheValida!),
        );
        await actualizar(EscenarioRed.sinConexion);
        await esperar(find.textContaining('puede estar desactualizada'));
        await foto('$prefijo-55-divisas-sin-conexion');

        await actualizar(EscenarioRed.normal);
        await esperar(find.byKey(const Key('resultado-divisas')));
        expect(find.textContaining('puede estar desactualizada'), findsNothing);
        await foto('$prefijo-56-divisas-recuperacion');
      }
      expect(capturas.length, 12);
      binding.reportData ??= {};
      binding.reportData!['capturasConectividad'] = capturas;
    } finally {
      await t.runAsync(() async {
        await red.cambiar(EscenarioRed.normal);
        await c.read(modoTemaProvider.notifier).cambiar(modoAnterior);
        if (cacheAnterior != null) {
          await preferencias.setString('tasa_USD_EUR', cacheAnterior);
        } else {
          await preferencias.remove('tasa_USD_EUR');
        }
      });
    }
  });
}
