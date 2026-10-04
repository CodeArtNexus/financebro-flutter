import 'package:flutter_test/flutter_test.dart';
import 'package:financebro/features/banking/solicitudes_tarjetas.dart';
import 'package:financebro/features/auth/registro.dart';

void main() {
  test('La fecha mínima respeta el día de Ecuador y el cambio de mes', () {
    expect(fechaEnvio(primerEnvio(DateTime.utc(2026, 10, 3, 4))), '2026-10-05');
    expect(fechaEnvio(primerEnvio(DateTime.utc(2026, 10, 3, 5))), '2026-10-06');
    expect(
      fechaEnvio(primerEnvio(DateTime.utc(2026, 12, 30, 14))),
      '2027-01-02',
    );
  });
  test('El contrato enviado está versionado y la contraseña nunca pasa al servicio bancario', () {
    const d = DatosRegistro(
      nombres: 'Ana',
      apellidos: 'Pérez',
      correo: 'ana@financebro.test',
      cedula: '1723456789',
      clave: 'privada-2026!',
      direccion: 'Calle Aurora 120',
      ciudad: 'Quito',
      telefono: '0991234567',
    );
    expect(d.apertura['versionContrato'], contratoVersion);
    expect(d.apertura.values, isNot(contains(d.clave)));
    expect(d.apertura['aceptaContrato'], true);
  });
}
