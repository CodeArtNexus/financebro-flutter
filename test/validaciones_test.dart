import 'package:financebro/features/auth/identidad.dart';
import 'package:financebro/core/componentes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rechaza correo incompleto, espacios internos y contraseña corta', () {
    expect(validarCorreo('a@b'), isNotNull);
    expect(validarCorreo('a b@correo.com'), isNotNull);
    expect(validarCorreo(' sebastian@correo.com '), isNull);
    expect(validarClave('1234567'), isNotNull);
    expect(validarClave('12345678'), isNull);
  });
  test('Los importes conservan centavos y signo', () {
    expect(dinero(125), contains('1,25'));
    expect(dinero(-125), contains('-'));
  });
}
