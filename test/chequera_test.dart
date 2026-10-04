import 'package:flutter_test/flutter_test.dart';
import 'package:financebro/features/banking/chequera_pantallas.dart';

void main() {
  test(
    'Los lotes mensuales conservan el día original al pasar por febrero',
    () {
      final f = DateTime(2028, 1, 31);
      expect(fechaDigital(mesDigital(f, 1)), '2028-02-29');
      expect(fechaDigital(mesDigital(f, 2)), '2028-03-31');
      expect(fechaDigital(mesDigital(DateTime(2026, 12, 31), 1)), '2027-01-31');
    },
  );
}
