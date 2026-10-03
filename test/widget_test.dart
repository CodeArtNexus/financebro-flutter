import 'package:financebro/app/financebro_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La bienvenida permanece legible con texto ampliado', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: FinanceBroApp(),
      ),
    );
    expect(find.text('FinanceBro'), findsOneWidget);
    expect(find.text('Tus finanzas, a tu ritmo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
