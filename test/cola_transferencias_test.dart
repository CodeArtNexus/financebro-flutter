import 'package:flutter_test/flutter_test.dart';
import 'package:financebro/features/banking/cola_transferencias.dart';
import 'package:financebro/core/errores.dart';

class Memoria implements AlmacenCola {
  final datos = <String, String>{};
  @override
  Future<String?> leer(String k) async => datos[k];
  @override
  Future<void> escribir(String k, String v) async {
    datos[k] = v;
  }
}

void main() {
  late Memoria memoria;
  late String? uid;
  late bool conectado, autoriza;
  late DateTime ahora;
  late int llamadas;
  late List<String> referencias;
  late Future<Map<String, dynamic>> Function(Map<String, dynamic>) enviar;
  ColaTransferencias crear() => ColaTransferencias(
    almacen: memoria,
    sesion: () => uid,
    conectado: () => conectado,
    desbloquear: () async => autoriza,
    proyecto: 'demo-financebro',
    reloj: () => ahora,
    enviar: (d) => enviar(d),
  );
  final d = {
    'cuenta': 'ahorros',
    'numero': '10000000000001',
    'centavos': 1000,
    'nota': 'Viaje',
    'referencia': 'referencia_estable_1',
  };
  setUp(() {
    memoria = Memoria();
    uid = 'ana';
    conectado = false;
    autoriza = true;
    ahora = DateTime.utc(2026, 10, 3, 14);
    llamadas = 0;
    referencias = [];
    enviar = (d) async {
      llamadas++;
      referencias.add(d['referencia'] as String);
      return {'referencia': d['referencia'], 'centavos': d['centavos']};
    };
  });
  test('El envío sin conexión conserva autorización y referencia después de reiniciar', () async {
    final q = crear();
    await q.cargar(uid);
    await q.agregar(d, 'Sebas');
    await q.procesar();
    expect(llamadas, 0);
    expect(q.items.single['estado'], 'pendiente');
    final restaurada = crear();
    await restaurada.cargar(uid);
    expect(restaurada.items.single['referencia'], d['referencia']);
    conectado = true;
    await Future.wait([restaurada.procesar(), restaurada.procesar()]);
    expect(llamadas, 1);
    expect(restaurada.items.single['estado'], 'confirmada');
  });
  test('Una respuesta perdida reintenta la misma referencia sin convertir el fallo técnico en un rechazo', () async {
    final q = crear();
    await q.cargar(uid);
    await q.agregar(d, 'Sebas');
    enviar = (d) async {
      llamadas++;
      referencias.add(d['referencia'] as String);
      if (llamadas == 1) {
        throw const FalloApp('Sin respuesta', transitorio: true);
      }
      return {'referencia': d['referencia']};
    };
    conectado = true;
    await q.procesar();
    expect(q.items.single['estado'], 'pendiente');
    await q.procesar();
    expect(referencias, [d['referencia'], d['referencia']]);
    expect(q.items.single['estado'], 'confirmada');
  });
  test('Otra identidad no ejecuta ni consulta la cola anterior y cancelar impide el envío', () async {
    final q = crear();
    await q.cargar(uid);
    await q.agregar(d, 'Sebas');
    uid = 'bruno';
    conectado = true;
    await q.procesar();
    expect(llamadas, 0);
    await q.cargar(uid);
    expect(q.items, isEmpty);
    uid = 'ana';
    await q.cargar(uid);
    await q.cancelar(d['referencia'] as String);
    await q.procesar();
    expect(llamadas, 0);
    expect(q.items.single['estado'], 'cancelada');
  });
  test('Fondos insuficientes detienen los reintentos y una autorización caduca a las 24 horas', () async {
    final q = crear();
    await q.cargar(uid);
    await q.agregar(d, 'Sebas');
    enviar = (_) async {
      llamadas++;
      throw const FalloApp('Fondos insuficientes');
    };
    conectado = true;
    await q.procesar();
    await q.procesar();
    expect(llamadas, 1);
    expect(q.items.single['estado'], 'rechazada');
    conectado = false;
    await q.agregar({...d, 'referencia': 'segunda_referencia'}, 'Sebas');
    ahora = ahora.add(const Duration(hours: 25));
    conectado = true;
    await q.procesar();
    expect(llamadas, 1);
    expect(q.items.last['estado'], 'expirada');
  });
  test(
    'Sin autorización del dispositivo no se guarda ninguna transferencia',
    () async {
      final q = crear();
      await q.cargar(uid);
      autoriza = false;
      await expectLater(q.agregar(d, 'Sebas'), throwsA(isA<FalloApp>()));
      expect(q.items, isEmpty);
      expect(memoria.datos, isEmpty);
    },
  );
}
