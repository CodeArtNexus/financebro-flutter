import 'dart:async';

import 'package:financebro/app/proveedores.dart';
import 'package:financebro/app/tema.dart';
import 'package:financebro/features/banking/contacto_detalle_pantalla.dart';
import 'package:financebro/app/proveedores_historial.dart';
import 'package:financebro/features/banking/historial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'apoyos.dart';

class ContactoPrueba implements RepositorioContactos {
  @override
  Future<ContactoGuardado> leer(String uid, String id) async =>
      const ContactoGuardado(
        ContactoBro(
          id: 'valeria',
          nombre: 'Valeria López',
          banco: 'FinanceBro',
          numero: '12345678901234',
          interno: true,
        ),
        false,
      );
}

class ConversacionPrueba implements RepositorioHistorial {
  final enviados = StreamController<PaginaHistorial>.broadcast(),
      recibidos = StreamController<PaginaHistorial>.broadcast();
  @override
  Stream<PaginaHistorial> observar(ConsultaHistorial c) =>
      c.campo == 'numeroDestino' ? enviados.stream : recibidos.stream;
  @override
  Future<PaginaHistorial> pagina(
    ConsultaHistorial c, {
    CursorHistorial? despues,
  }) async => const PaginaHistorial([], desdeCache: false, mas: false);
}

MovimientoBanco movimiento(String id, int importe) => MovimientoBanco(
  id: id,
  descripcion: 'Contrato con Valeria',
  centavos: importe,
  fecha: DateTime(2026, 10, 5),
  categoria: 'Transferencia',
  referencia: id,
);
void main() {
  setUpAll(() => initializeDateFormatting('es'));
  testWidgets(
    'El contacto espera sus dos consultas y conserva envíos y recepciones sin duplicados',
    (t) async {
      final identidad = IdentidadPrueba(), repo = ConversacionPrueba();
      await identidad.ingresar('', '');
      addTearDown(identidad.controlador.close);
      addTearDown(repo.enviados.close);
      addTearDown(repo.recibidos.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            identidadProvider.overrideWithValue(identidad),
            contactosRepositorioProvider.overrideWithValue(ContactoPrueba()),
            historialRepositorioProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: crearTema(),
            home: const ContactoDetallePantalla('valeria'),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      expect(
        find.text('Todavía no hay operaciones con esta persona.'),
        findsNothing,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      repo.enviados.add(
        PaginaHistorial(
          [movimiento('envio', -10)],
          desdeCache: false,
          mas: false,
        ),
      );
      repo.recibidos.add(
        PaginaHistorial(
          [movimiento('recibo', 20)],
          desdeCache: false,
          mas: false,
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.text('Enviaste'), findsOneWidget);
      expect(find.text('Recibiste'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      repo.enviados.add(
        PaginaHistorial(
          [movimiento('envio', -10)],
          desdeCache: false,
          mas: false,
        ),
      );
      await t.pump();
      expect(find.text('Enviaste'), findsOneWidget);
      expect(find.text('Recibiste'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
