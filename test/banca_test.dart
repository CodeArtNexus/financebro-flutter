import 'package:financebro/features/banking/banca.dart';
import 'package:financebro/features/notifications/notificaciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El QR identifica una cuenta y rechaza enlaces ajenos o parámetros ambiguos', () {
    expect(
      leerQrCuenta('financebro://transferir?cuenta=10000000000001&v=1'),
      '10000000000001',
    );
    for (final c in [
      'https://financebro.test/transferir?cuenta=10000000000001&v=1',
      'financebro://transferir?cuenta=10000000000001&v=1&saldo=999',
      'financebro://transferir?cuenta=10000000000001&cuenta=20000000000001&v=1',
      'financebro://transferir?cuenta=10000000000001&v=2',
      'financebro://transferir?cuenta=10000000000001&v=1#otra',
      'financebro://transferir/otro?cuenta=10000000000001&v=1',
    ]) {
      expect(() => leerQrCuenta(c), throwsException);
    }
  });
  test('Los límites del monto incluyen diez centavos y cien dólares, sin redondeos', () {
    expect(montoCentavos('0,10'), 10);
    expect(montoCentavos('100.00'), 10000);
    expect(montoCentavos('1.2'), 120);
    for (final v in ['0.09', '100.01', '0.001', '-1', 'NaN', '1e2', '1.000']) {
      expect(() => montoCentavos(v), throwsException);
    }
  });
  test('Una notificación abre rutas propias y no acepta enlaces o recorrido de archivos', () {
    expect(destinoPush({'ruta': '/cuentas/ahorros'}), '/cuentas/ahorros');
    expect(destinoPush({'destino': '/pagos'}), '/pagos');
    for (final v in [
      'https://ajeno.test',
      '/cuentas/../admin',
      '/admin',
      '//ajeno.test',
    ]) {
      expect(destinoPush({'ruta': v}), '/notificaciones');
    }
  });
}
