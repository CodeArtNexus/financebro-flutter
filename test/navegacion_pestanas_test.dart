import 'package:financebro/app/rutas.dart';
import 'package:financebro/app/tema.dart';
import 'package:financebro/core/red_banco.dart';
import 'package:financebro/core/apariencia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final plataforma in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'Las pestañas sustituyen la vista anterior desde el primer fotograma en ${plataforma.name}',
      (t) async {
        final router = GoRouter(
          initialLocation: '/inicio',
          routes: [
            ShellRoute(
              builder: (context, state, child) =>
                  NavegacionPantalla(state.uri.path, child),
              routes: [
                for (final ruta in NavegacionPantalla.destinos)
                  pantalla(
                    ruta,
                    (_) => Scaffold(
                      backgroundColor: Colors.transparent,
                      body: Center(child: Text('Contenido $ruta')),
                    ),
                  ),
                pantalla(
                  '/tarjetas/detalle',
                  (_) => const Scaffold(
                    body: Center(child: Text('Detalle de tarjeta')),
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              decoracionProvider.overrideWith((ref) => Stream.value({})),
              conexionBancoProvider.overrideWith(
                (ref) => Stream.value(EstadoConexion.conectado),
              ),
            ],
            child: MaterialApp.router(
              theme: crearTema().copyWith(platform: plataforma),
              routerConfig: router,
            ),
          ),
        );
        await t.pumpAndSettle();
        var anterior = '/inicio';
        for (final destino in [
          '/tarjetas',
          '/qr',
          '/pagos',
          '/perfil',
          '/inicio',
        ]) {
          final indice = NavegacionPantalla.destinos.indexOf(destino);
          await t.tap(find.byType(NavigationDestination).at(indice));
          await t.pump();
          // Comprobar durante la transición, sin esperar a que termine.
          for (final ms in [0, 30, 70, 180]) {
            await t.pump(Duration(milliseconds: ms));
            expect(find.text('Contenido $anterior'), findsNothing);
            expect(find.text('Contenido $destino'), findsOneWidget);
            expect(find.byType(NavigationBar), findsOneWidget);
          }
          anterior = destino;
        }
        router.go('/tarjetas');
        await t.pumpAndSettle();
        router.push('/tarjetas/detalle');
        await t.pumpAndSettle();
        expect(find.text('Detalle de tarjeta'), findsOneWidget);
        if (plataforma == TargetPlatform.iOS) {
          await t.dragFrom(const Offset(1, 200), const Offset(600, 0));
        } else {
          router.pop();
        }
        await t.pumpAndSettle();
        expect(find.text('Detalle de tarjeta'), findsNothing);
        expect(find.text('Contenido /tarjetas'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
}
