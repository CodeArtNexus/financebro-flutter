import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:financebro/features/banking/cola_transferencias.dart';
import 'package:financebro/core/errores.dart';

class Memoria implements AlmacenCola {
  final datos = <String, String>{};
  bool fallar = false;
  Completer<void>? lecturaBloqueada;
  String? bloquearClave;
  @override
  Future<String?> leer(String k) async {
    if (k == bloquearClave) await lecturaBloqueada?.future;
    return datos[k];
  }

  @override
  Future<void> escribir(String k, String v) async {
    if (fallar) throw StateError('Almacenamiento no disponible');
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
  test('Con internet se guarda el envío antes de llamar al servidor y se conserva el comprobante', () async {
    final q = crear();
    await q.cargar(uid);
    conectado = true;
    enviar = (datos) async {
      final guardado = jsonDecode(memoria.datos[q.clave(uid!)]!) as List;
      expect(guardado.single['intentada'], true);
      expect(guardado.single['estado'], 'enviando');
      return {'referencia': datos['referencia']};
    };
    final recibo = await q.agregar(d, 'Sebas');
    expect(recibo!['referencia'], d['referencia']);
    expect(
      jsonDecode(memoria.datos[q.clave(uid!)]!).single['estado'],
      'confirmada',
    );
  });
  test('Una confirmación perdida se consulta después de 24 horas y no se puede cancelar como si nunca hubiera sido enviada', () async {
    final q = crear();
    await q.cargar(uid);
    await q.agregar(d, 'Sebas');
    enviar = (_) async {
      throw const FalloApp('Respuesta perdida', transitorio: true);
    };
    conectado = true;
    await q.procesar();
    await q.cancelar(d['referencia'] as String);
    expect(q.items.single['estado'], 'pendiente');
    ahora = ahora.add(const Duration(hours: 25));
    final restaurada = crear();
    await restaurada.cargar(uid);
    enviar = (datos) async {
      llamadas++;
      return {'referencia': datos['referencia']};
    };
    await restaurada.procesar();
    expect(llamadas, 1);
    expect(restaurada.items.single['estado'], 'confirmada');
  });
  test('Si falla el almacenamiento nunca se envía dinero y una escritura posterior puede recuperarse', () async {
    final q = crear();
    await q.cargar(uid);
    conectado = true;
    memoria.fallar = true;
    await expectLater(q.agregar(d, 'Sebas'), throwsA(isA<FalloApp>()));
    expect(llamadas, 0);
    expect(q.items, isEmpty);
    memoria.fallar = false;
    await q.agregar(d, 'Sebas');
    expect(llamadas, 1);
    expect(q.items.single['estado'], 'confirmada');
  });
  test('Una cola dañada se conserva y bloquea nuevas escrituras para no perder transferencias', () async {
    final q = crear();
    memoria.datos[q.clave(uid!)] = '{incompleto';
    await expectLater(q.cargar(uid), throwsA(isA<FalloApp>()));
    await expectLater(q.agregar(d, 'Sebas'), throwsA(isA<FalloApp>()));
    expect(memoria.datos[q.clave(uid!)], '{incompleto');
    expect(llamadas, 0);
  });
  test('Un cambio de sesión durante el envío guarda su respuesta en la identidad original', () async {
    final q = crear();
    await q.cargar(uid);
    await q.agregar(d, 'Sebas');
    final respuesta = Completer<Map<String, dynamic>>(),
        inicio = Completer<void>();
    enviar = (_) {
      inicio.complete();
      return respuesta.future;
    };
    conectado = true;
    final proceso = q.procesar();
    await inicio.future;
    uid = 'bruno';
    await q.cargar(uid);
    respuesta.complete({'referencia': d['referencia']});
    await proceso;
    expect(q.items, isEmpty);
    expect(memoria.datos[q.clave('bruno')], isNull);
    uid = 'ana';
    await q.cargar(uid);
    expect(q.items.single['estado'], 'confirmada');
  });
  test(
    'Una lectura lenta de una sesión anterior no sustituye la sesión nueva',
    () async {
      final q = crear();
      memoria.bloquearClave = q.clave('ana');
      memoria.lecturaBloqueada = Completer<void>();
      final antigua = q.cargar('ana');
      await Future<void>.delayed(Duration.zero);
      uid = 'bruno';
      await q.cargar(uid);
      memoria.lecturaBloqueada!.complete();
      await antigua;
      expect(q.uid, 'bruno');
      expect(q.items, isEmpty);
    },
  );
  test('Una cancelación que no se pudo guardar conserva el estado pendiente y avisa del fallo', () async {
    final q = crear();
    await q.cargar(uid);
    await q.agregar(d, 'Sebas');
    memoria.fallar = true;
    await expectLater(
      q.cancelar(d['referencia'] as String),
      throwsA(isA<FalloApp>()),
    );
    expect(q.items.single['estado'], 'pendiente');
    expect(llamadas, 0);
    memoria.fallar = false;
    await q.cancelar(d['referencia'] as String);
    conectado = true;
    await q.procesar();
    expect(llamadas, 0);
  });
}
