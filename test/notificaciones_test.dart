import 'package:financebro/features/notifications/notificaciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El push solo abre destinos reconocidos', () {
    expect(destinoPush({'ruta': '/cuentas'}), '/cuentas');
    expect(destinoPush({'ruta': 'https://externo.test'}), '/notificaciones');
    expect(destinoPush({}), '/notificaciones');
  });
}
