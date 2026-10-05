import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/tema.dart';
import 'package:financebro/features/banking/historial.dart';
import 'package:financebro/app/proveedores_historial.dart';
import 'package:financebro/features/banking/historial_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyos.dart';

MovimientoBanco movimiento(String id, int dia) => MovimientoBanco(
  id: id,
  descripcion: 'Movimiento $id',
  centavos: -10,
  fecha: DateTime(2026, 10, dia),
  categoria: 'Transferencia',
  referencia: id,
);

class HistorialPrueba implements RepositorioHistorial {
  final cambios = StreamController<PaginaHistorial>.broadcast();
  CursorHistorial? solicitado;
  @override
  Stream<PaginaHistorial> observar(ConsultaHistorial c) => cambios.stream;
  @override
  Future<PaginaHistorial> pagina(
    ConsultaHistorial c, {
    CursorHistorial? despues,
  }) async {
    solicitado = despues;
    return PaginaHistorial(
      [movimiento('antiguo', 1), movimiento('primero', 3)],
      desdeCache: false,
      mas: false,
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  testWidgets(
    'El histórico presenta caché, recibe cambios y pagina sin duplicar ni perder el cursor',
    (t) async {
      final repo = HistorialPrueba(), identidad = IdentidadPrueba();
      await identidad.ingresar('', '');
      addTearDown(repo.cambios.close);
      addTearDown(identidad.controlador.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            identidadProvider.overrideWithValue(identidad),
            historialRepositorioProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: crearTema(),
            home: const HistorialPantalla(),
          ),
        ),
      );
      await t.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final cursor = CursorHistorial(
        'consulta',
        DateTime(2026, 10, 3),
        'primero',
      );
      repo.cambios.add(
        PaginaHistorial(
          [movimiento('primero', 3)],
          desdeCache: true,
          mas: true,
          cursor: cursor,
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.text('Movimiento primero'), findsOneWidget);
      expect(
        find.text(
          'Mostramos los movimientos guardados. Conéctate para actualizarlos.',
        ),
        findsOneWidget,
      );
      await t.ensureVisible(find.text('Cargar movimientos anteriores'));
      await t.tap(find.text('Cargar movimientos anteriores'));
      await t.pump();
      await t.pump();
      expect(repo.solicitado, same(cursor));
      expect(find.text('Movimiento primero'), findsOneWidget);
      repo.cambios.add(
        PaginaHistorial(
          [movimiento('nuevo', 4), movimiento('primero', 3)],
          desdeCache: false,
          mas: true,
          cursor: CursorHistorial('consulta', DateTime(2026, 10, 3), 'primero'),
        ),
      );
      await t.pump();
      expect(find.text('Movimiento nuevo'), findsOneWidget);
      expect(find.text('Movimiento antiguo'), findsOneWidget);
      expect(find.text('Cargar movimientos anteriores'), findsNothing);
      expect(
        find.text(
          'Mostramos los movimientos guardados. Conéctate para actualizarlos.',
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  test(
    'Los movimientos con igual fecha tienen orden estable por identificador',
    () {
      final items = [
        movimiento('a', 1),
        movimiento('b', 1),
        movimiento('nuevo', 2),
      ]..sort(MovimientoBanco.ordenar);
      expect(items.map((m) => m.id), ['nuevo', 'b', 'a']);
    },
  );
}
