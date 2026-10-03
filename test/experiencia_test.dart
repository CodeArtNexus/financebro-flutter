import 'package:financebro/features/experience/experiencia.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> tarjeta({
  String id = '1',
  String segmento = 'todos',
  int orden = 1,
  String destino = '/cuentas',
  String tipo = 'aviso',
}) => {
  'id': id,
  'tipo': tipo,
  'titulo': 'Consejo',
  'texto': 'Contenido remoto',
  'destino': destino,
  'segmento': segmento,
  'orden': orden,
};
void main() {
  test('La experiencia combina tarjetas generales y del segmento en orden', () {
    final e = Experiencia.desdeMapa({
      'schemaVersion': 1,
      'revision': 2,
      'tarjetas': [
        tarjeta(id: 'viaje', segmento: 'viajes', orden: 0),
        tarjeta(id: 'general', orden: 2),
        tarjeta(id: 'ahorro', segmento: 'ahorro'),
      ],
    });
    expect(e.paraPerfil('viajes').map((t) => t.id), ['viaje', 'general']);
  });
  test('Omite componentes desconocidos y rechaza destinos arbitrarios', () {
    expect(
      Experiencia.desdeMapa({
        'schemaVersion': 1,
        'revision': 1,
        'tarjetas': [tarjeta(tipo: 'codigoRemoto')],
      }).tarjetas,
      isEmpty,
    );
    expect(
      () => Experiencia.desdeMapa({
        'schemaVersion': 1,
        'revision': 1,
        'tarjetas': [tarjeta(destino: 'https://externo.test')],
      }),
      throwsException,
    );
  });
  test('Rechaza esquema incompatible e identificadores duplicados', () {
    expect(
      () => Experiencia.desdeMapa({
        'schemaVersion': 2,
        'revision': 1,
        'tarjetas': [],
      }),
      throwsException,
    );
    expect(
      () => Experiencia.desdeMapa({
        'schemaVersion': 1,
        'revision': 1,
        'tarjetas': [tarjeta(), tarjeta()],
      }),
      throwsException,
    );
  });
}
