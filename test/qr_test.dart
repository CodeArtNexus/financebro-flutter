import 'package:financebro/features/payments/pagos.dart';
import 'package:financebro/core/errores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Solo se aceptan solicitudes QR canónicas con importe y referencia acotados', () {
    const solicitud = SolicitudQr('cafe-bro', 450, 'referencia-1234');
    final leida = SolicitudQr.leer(solicitud.contenido);
    expect(leida.centavos, 450);
    expect(leida.referencia, solicitud.referencia);
    for (final codigo in [
      'https://example.com/pagar?comercio=cafe-bro&centavos=450&referencia=referencia-1234',
      'financebro://pagar?comercio=cafe-bro&centavos=-450&referencia=referencia-1234',
      'financebro://pagar?comercio=cafe-bro&centavos=450.50&referencia=referencia-1234',
      'financebro://pagar?comercio=cafe-bro&centavos=1000001&referencia=referencia-1234',
      '${solicitud.contenido}&centavos=100',
      '${solicitud.contenido}&saldo=999',
      '${solicitud.contenido}#otro',
      'financebro://pagar?comercio=../otra&centavos=450&referencia=../../cuenta',
    ]) {
      expect(() => SolicitudQr.leer(codigo), throwsA(isA<FalloApp>()));
    }
  });
}
