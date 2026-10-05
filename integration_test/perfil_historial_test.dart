import 'dart:convert';
import 'dart:io';

import 'package:financebro/main.dart' as app;
import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/rutas.dart';
import 'package:financebro/core/apariencia.dart';
import 'package:financebro/core/configuracion.dart';
import 'package:financebro/app/proveedores_historial.dart';
import 'package:financebro/features/banking/historial.dart';
import 'package:financebro/features/banking/historial_pantalla.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'recuperacion_test.dart' show esperarReal;

// Lecturas reales, datos sintéticos y SDK nativo. No genera fondos desde el cliente.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Histórico paginado y desplazamiento en modo perfil', (t) async {
    expect(usarEmuladores, isTrue);
    expect(kProfileMode, isTrue, reason: 'Las medidas requieren --profile.');
    await t.pumpWidget(await app.prepararAplicacion());
    await t.pump(const Duration(seconds: 2));
    final c = ProviderScope.containerOf(t.element(find.byType(FinanceBroApp)));
    await t.runAsync(
      () => c
          .read(identidadProvider)
          .ingresar('demo@financebro.test', 'FinanceBro-local-2026!'),
    );
    await esperarReal(t, find.text('Tu dinero, a tu manera'));
    final repo = c.read(historialRepositorioProvider);
    final consulta = ConsultaHistorial(c.read(identidadProvider).actual!.uid);
    final lecturas = <int>[];
    PaginaHistorial? primera;
    for (var i = 0; i < 5; i++) {
      final reloj = Stopwatch()..start();
      primera = await t.runAsync(() => repo.pagina(consulta));
      lecturas.add(reloj.elapsedMilliseconds);
      expect(primera!.desdeCache, isFalse);
      expect(primera.movimientos.length, 30);
    }
    final segunda = (await t.runAsync(
      () => repo.pagina(consulta, despues: primera!.cursor),
    ))!;
    expect(segunda.movimientos, isNotEmpty);
    final ids = [
      ...primera!.movimientos,
      ...segunda.movimientos,
    ].map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
    final relojCache = Stopwatch()..start();
    final cache = (await t.runAsync(() => repo.observar(consulta).first))!;
    expect(cache.desdeCache, isTrue);
    expect(cache.movimientos.length, 30);
    final cacheMs = relojCache.elapsedMilliseconds;
    final router = c.read(rutasProvider);
    router.go('/historial');
    await esperarReal(t, find.byType(HistorialPantalla));
    await esperarReal(t, find.textContaining('Ajuste de fondos'));
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      await t.runAsync(() => c.read(modoTemaProvider.notifier).cambiar(tema));
      await t.pumpAndSettle();
      // Calentar tipografía, shaders y las filas antes de medir.
      for (var i = 0; i < 4; i++) {
        await t.drag(
          find.byType(ListView).last,
          Offset(0, i.isEven ? -400 : 400),
        );
        await t.pumpAndSettle();
      }
      await binding.watchPerformance(() async {
        for (var i = 0; i < 12; i++) {
          await t.drag(
            find.byType(ListView).last,
            Offset(0, i.isEven ? -400 : 400),
          );
          await t.pumpAndSettle();
        }
      }, reportKey: 'desplazamiento_${tema.name}');
      expect(t.takeException(), isNull);
    }
    final datos = binding.reportData ??= {};
    datos['contexto'] = {
      'modo': 'profile',
      'plataforma': Platform.operatingSystem,
      'datos':
          'Emulator Suite local: 45 ajustes y una transferencia sintéticos',
      'paginas': [primera.movimientos.length, segunda.movimientos.length],
      'lecturas_servidor_ms': lecturas,
      'primera_emision_cache_ms': cacheMs,
      'muestra': '12 desplazamientos por tema, tras 4 de calentamiento',
      'limite': 'Un emulador no representa el rendimiento de un dispositivo físico ni la latencia de producción.',
    };
    debugPrint('CALIDAD_MEDIDA=${jsonEncode(datos['contexto'])}');
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await t.pump();
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      await t.runAsync(() => c.read(modoTemaProvider.notifier).cambiar(tema));
      t.platformDispatcher.textScaleFactorTestValue = 2;
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            highContrast: true,
            disableAnimations: true,
          );
      for (final ruta in ['/historial', '/contactos/calidad']) {
        router.go(ruta);
        await t.pumpAndSettle();
        await esperarReal(
          t,
          find.textContaining(
            ruta == '/historial' ? 'Transferencia a' : 'Enviaste',
          ),
        );
        await binding.takeScreenshot(
          'calidad-${tema.name}-${ruta == '/historial' ? 'historico' : 'contacto'}-200',
        );
        expect(t.takeException(), isNull);
      }
    }
    t.platformDispatcher.clearTextScaleFactorTestValue();
    t.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await t.pumpWidget(const SizedBox());
  });
}
