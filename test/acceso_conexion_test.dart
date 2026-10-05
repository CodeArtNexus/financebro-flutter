import 'dart:async';

import 'package:financebro/app/proveedores.dart';
import 'package:financebro/core/control_red.dart';
import 'package:financebro/core/red_banco.dart';
import 'package:financebro/features/auth/acceso_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'apoyos.dart';

void main() {
  for (final estado in [EstadoConexion.conectado, EstadoConexion.sinConexion]) {
    testWidgets('El primer ingreso espera la revisión real: ${estado.name}', (
      t,
    ) async {
      final resultado = Completer<EstadoConexion>();
      var consultas = 0;
      final red = RedBanco(
        'proyecto-ficticio',
        ControlRed(),
        comprobarConexion: () {
          consultas++;
          return resultado.future;
        },
      );
      final identidad = IdentidadPrueba();
      final router = GoRouter(
        initialLocation: '/ingresar',
        routes: [
          GoRoute(path: '/ingresar', builder: (_, _) => const AccesoPantalla()),
          GoRoute(
            path: '/conexion',
            builder: (_, _) =>
                const Scaffold(body: Text('Conexión confirmada ausente')),
          ),
        ],
      );
      addTearDown(identidad.controlador.close);
      addTearDown(router.dispose);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            redBancoProvider.overrideWith((ref) {
              ref.onDispose(red.dispose);
              return red;
            }),
            identidadProvider.overrideWithValue(identidad),
            recuerdoAccesoProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('correo')),
        'persona@financebro.test',
      );
      await t.enterText(find.byKey(const Key('clave')), 'Seguro2026!');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.ensureVisible(find.byKey(const Key('enviar-acceso')));
      await t.tap(find.byKey(const Key('enviar-acceso')));
      await t.pump();
      expect(find.text('Conectando…'), findsOneWidget);
      expect(find.text('Conexión confirmada ausente'), findsNothing);
      expect(identidad.actual, isNull);
      expect(consultas, 1);
      resultado.complete(estado);
      await t.pumpAndSettle();
      if (estado == EstadoConexion.conectado) {
        expect(identidad.actual, isNotNull);
        expect(find.text('Conexión confirmada ausente'), findsNothing);
      } else {
        expect(identidad.actual, isNull);
        expect(find.text('Conexión confirmada ausente'), findsOneWidget);
        router.pop();
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextFormField>(find.byKey(const Key('correo')))
              .controller!
              .text,
          'persona@financebro.test',
        );
        expect(
          t
              .widget<TextFormField>(find.byKey(const Key('clave')))
              .controller!
              .text,
          'Seguro2026!',
        );
        expect(
          t
              .widget<FilledButton>(find.byKey(const Key('enviar-acceso')))
              .onPressed,
          isNotNull,
        );
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
