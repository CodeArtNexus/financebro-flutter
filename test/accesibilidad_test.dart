import 'package:financebro/app/tema.dart';
import 'package:financebro/features/banking/componentes_banca.dart';
import 'package:financebro/features/banking/tarjetas_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brillo in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'Comprobante: contraste, etiquetas y objetivos táctiles en ${brillo.name}',
      (t) async {
        final semantica = t.ensureSemantics();
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: crearTema(brillo: brillo),
              home: Scaffold(
                backgroundColor: brillo == Brightness.dark
                    ? const Color(0xFF111923)
                    : fondoFinanceBro,
                body: SingleChildScrollView(
                  child: ReciboBro({
                    'tipo': 'transferencia',
                    'centavos': 10000,
                    'titular': 'Valeria López',
                    'referencia': 'comprobante-unico',
                    'cuenta': 'ahorros',
                  }, otra: () {}),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
          expect(t.takeException(), isNull);
        } finally {
          semantica.dispose();
        }
      },
    );
    testWidgets(
      'Texto al 200 %, alto contraste y movimiento reducido conservan el comprobante en ${brillo.name}',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            theme: crearTema(brillo: brillo),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                highContrast: true,
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReciboBro({
                  'tipo': 'transferencia',
                  'centavos': 10000,
                  'titular': 'Valeria López',
                  'referencia': 'comprobante-unico',
                  'cuenta': 'ahorros',
                }, otra: () {}),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Operación confirmada'), findsOneWidget);
        final filtro = t.widget<BackdropFilter>(
          find.byType(BackdropFilter).first,
        );
        expect(filtro.enabled, isFalse);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'La tarjeta es una acción etiquetada para el lector de pantalla',
    (t) async {
      final semantica = t.ensureSemantics();
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: crearTema(),
            home: Scaffold(
              body: TarjetaVisualBro({
                'banco': 'FinanceBro',
                'ultimos4': '1234',
                'nombre': 'Mi tarjeta',
                'tipo': 'propia',
                'clase': 'debito',
              }, onTap: () {}),
            ),
          ),
        );
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        expect(t.takeException(), isNull);
      } finally {
        semantica.dispose();
      }
    },
  );
}
