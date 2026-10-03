import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:financebro/core/control_red.dart';
import 'package:financebro/features/exchange/divisas.dart';
import 'package:financebro/features/exchange/http_divisas.dart';
import 'package:flutter_test/flutter_test.dart';

class CachePrueba implements CacheCotizaciones {
  Cotizacion? valor;
  @override
  Cotizacion? leer(String moneda) => valor?.moneda == moneda ? valor : null;
  @override
  Future<void> guardar(Cotizacion cotizacion) async {
    valor = cotizacion;
  }
}

class HttpPrueba implements HttpClientAdapter {
  HttpPrueba(this.estados);
  final List<int> estados;
  int llamadas = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final estado = estados[llamadas.clamp(0, estados.length - 1)];
    llamadas++;
    return ResponseBody.fromString(
      jsonEncode(
        estado == 200
            ? {'base': 'USD', 'quote': 'EUR', 'rate': 0.8, 'date': '2026-10-03'}
            : {'message': 'error'},
      ),
      estado,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final ahora = DateTime(2026, 10, 3);
  test('Convierte con centavos exactos y valida entradas decimales', () {
    expect(leerCentavos('12,35'), 1235);
    expect(leerCentavos('1.234'), isNull);
    expect(leerCentavos('-1'), isNull);
    expect(leerCentavos('1000001'), isNull);
    expect(
      Cotizacion(
        moneda: 'EUR',
        tasa: 0.8,
        fecha: ahora,
        consultada: ahora,
      ).convertirCentavos(1235),
      988,
    );
  });
  test('Un 503 se reintenta y se guarda la respuesta válida', () async {
    final adaptador = HttpPrueba([503, 200]);
    final http = Dio()..httpClientAdapter = adaptador;
    final cache = CachePrueba();
    final repo = HttpDivisas(
      http,
      cache,
      ControlRed(),
      esperar: (_) async {},
      ahora: () => ahora,
    );
    expect((await repo.consultar('EUR')).tasa, 0.8);
    expect(adaptador.llamadas, 2);
    expect(cache.valor, isNotNull);
  });
  test('Un 401 no se reintenta', () async {
    final adaptador = HttpPrueba([401]);
    final repo = HttpDivisas(
      Dio()..httpClientAdapter = adaptador,
      CachePrueba(),
      ControlRed(),
      esperar: (_) async {},
    );
    await expectLater(repo.consultar('EUR'), throwsException);
    expect(adaptador.llamadas, 1);
  });
  test('Sin conexión usa caché reciente y rechaza una caché vencida', () async {
    final cache = CachePrueba()
      ..valor = Cotizacion(
        moneda: 'EUR',
        tasa: 0.8,
        fecha: ahora,
        consultada: ahora,
      );
    final control = ControlRed();
    await control.cambiar(EscenarioRed.sinConexion);
    expect(
      (await HttpDivisas(
        Dio(),
        cache,
        control,
        ahora: () => ahora,
      ).consultar('EUR')).desdeCache,
      isTrue,
    );
    await expectLater(
      HttpDivisas(
        Dio(),
        cache,
        control,
        ahora: () => ahora.add(const Duration(days: 8)),
      ).consultar('EUR'),
      throwsException,
    );
  });
  test('Rechaza tasas negativas y respuestas para otra moneda', () {
    expect(
      () => Cotizacion.desdeMapa(
        {'base': 'USD', 'quote': 'EUR', 'rate': -1, 'date': '2026-10-03'},
        'EUR',
        ahora,
      ),
      throwsException,
    );
    expect(
      () => Cotizacion.desdeMapa(
        {'base': 'USD', 'quote': 'GBP', 'rate': 1, 'date': '2026-10-03'},
        'EUR',
        ahora,
      ),
      throwsException,
    );
  });
}
