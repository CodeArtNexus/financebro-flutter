import 'package:financebro/core/apariencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final configuracion = {
    'activa': true,
    'tema': 'navidad',
    'desde': '2026-12-01',
    'hasta': '2026-12-31',
  };
  test(
    'La decoración respeta el período en Ecuador y se retira al finalizar',
    () {
      expect(
        decoracionVigente(
          configuracion,
          ahora: DateTime.parse('2026-12-01T04:59:00Z'),
        ),
        isNull,
      );
      expect(
        decoracionVigente(
          configuracion,
          ahora: DateTime.parse('2026-12-01T05:00:00Z'),
        ),
        isNotNull,
      );
      expect(
        decoracionVigente(
          configuracion,
          ahora: DateTime.parse('2027-01-01T05:00:00Z'),
        ),
        isNull,
      );
    },
  );
  test(
    'Una temporada desactivada o desconocida conserva la marca habitual',
    () {
      expect(decoracionVigente({...configuracion, 'activa': false}), isNull);
      expect(
        decoracionVigente({...configuracion, 'tema': 'desconocido'}),
        isNull,
      );
    },
  );
}
