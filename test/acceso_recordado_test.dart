import 'dart:convert';

import 'package:financebro/app/financebro_app.dart';
import 'package:financebro/app/proveedores.dart';
import 'package:financebro/features/auth/acceso_rapido.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoyos.dart';

void main() {
  test('Un recuerdo incompleto o corrupto no interrumpe el arranque', () async {
    for (final contenido in ['{', '{}', '{"uid":"a","nombre":""}', 'null']) {
      SharedPreferences.setMockInitialValues({'saludo_bro_v1': contenido});
      expect(
        RecuerdoAcceso.leer(await SharedPreferences.getInstance()),
        isNull,
      );
    }
    SharedPreferences.setMockInitialValues({});
    final preferencias = await SharedPreferences.getInstance();
    await const RecuerdoAcceso(
      'uid-demo',
      'Sebastian Demo',
    ).guardar(preferencias);
    expect(RecuerdoAcceso.leer(preferencias)?.saludo, 'Sebastian');
    expect(jsonDecode(preferencias.getString('saludo_bro_v1')!), {
      'uid': 'uid-demo',
      'nombre': 'Sebastian Demo',
    });
  });
  testWidgets('El saludo recordado no habilita Face ID sin sesión real', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'saludo_bro_v1': '{"uid":"anterior","nombre":"Sebastian Demo"}',
    });
    final preferencias = await SharedPreferences.getInstance();
    final identidad = IdentidadPrueba();
    addTearDown(identidad.controlador.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identidadProvider.overrideWithValue(identidad),
          preferenciasLocalesProvider.overrideWithValue(preferencias),
        ],
        child: const FinanceBroApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Hola, Sebastian.'), findsOneWidget);
    await tester.ensureVisible(find.text('Volver a mi espacio'));
    await tester.tap(find.text('Volver a mi espacio'));
    await tester.pumpAndSettle();
    final boton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Face ID · demo'),
    );
    expect(boton.onPressed, isNull);
    expect(identidad.actual, isNull);
  });
}
