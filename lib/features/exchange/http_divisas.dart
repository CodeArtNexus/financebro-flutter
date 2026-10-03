import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/control_red.dart';
import '../../core/errores.dart';
import 'divisas.dart';

class CacheDivisas implements CacheCotizaciones {
  CacheDivisas(this.preferencias);
  final SharedPreferences preferencias;
  @override
  Cotizacion? leer(String moneda) {
    try {
      final contenido = preferencias.getString('tasa_USD_$moneda');
      if (contenido == null) return null;
      final mapa = jsonDecode(contenido) as Map<String, dynamic>;
      return Cotizacion.desdeMapa(
        mapa,
        moneda,
        DateTime.parse(mapa['consultada']),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(Cotizacion cotizacion) => preferencias.setString(
    'tasa_USD_${cotizacion.moneda}',
    jsonEncode(cotizacion.aMapa()),
  );
}

class HttpDivisas implements RepositorioDivisas {
  HttpDivisas(
    this.http,
    this.cache,
    this.control, {
    Future<void> Function(Duration)? esperar,
    DateTime Function()? ahora,
  }) : esperar = esperar ?? Future<void>.delayed,
       ahora = ahora ?? DateTime.now;
  final Dio http;
  final CacheCotizaciones cache;
  final ControlRed control;
  final Future<void> Function(Duration) esperar;
  final DateTime Function() ahora;
  bool _transitorio(Object error) =>
      error is TimeoutException ||
      (error is FalloApp && error.transitorio) ||
      (error is DioException &&
          (error.response == null ||
              [
                408,
                429,
                500,
                502,
                503,
                504,
              ].contains(error.response?.statusCode)));
  @override
  Future<Cotizacion> consultar(String moneda) async {
    if (!['EUR', 'GBP', 'COP'].contains(moneda)) {
      throw const FalloApp('Esta moneda no está disponible.');
    }
    final reloj = Stopwatch()..start();
    Object? ultimoError;
    for (var intento = 0; intento < 3; intento++) {
      try {
        final respuesta = await control
            .ejecutarDivisas(
              () => http.get<Map<String, dynamic>>(
                'https://api.frankfurter.dev/v2/rate/usd/${moneda.toLowerCase()}',
              ),
            )
            .timeout(const Duration(seconds: 8));
        final tasa = Cotizacion.desdeMapa(
          respuesta.data ?? {},
          moneda,
          ahora(),
        );
        await cache.guardar(tasa);
        registrarEvento(
          'consulta_correcta',
          servicio: 'divisas',
          duracionMs: reloj.elapsedMilliseconds,
        );
        return tasa;
      } catch (error) {
        ultimoError = error;
        if (!_transitorio(error) ||
            control.escenario == EscenarioRed.sinConexion ||
            intento == 2) {
          break;
        }
        registrarEvento('reintento', servicio: 'divisas');
        await esperar(
          Duration(milliseconds: 300 * (1 << intento) + Random().nextInt(100)),
        );
      }
    }
    final anterior = cache.leer(moneda);
    if (anterior != null &&
        ahora().difference(anterior.consultada) <= const Duration(days: 7)) {
      registrarEvento('cache_utilizada', servicio: 'divisas');
      return Cotizacion(
        moneda: anterior.moneda,
        tasa: anterior.tasa,
        fecha: anterior.fecha,
        consultada: anterior.consultada,
        desdeCache: true,
        aviso:
            'No pudimos actualizar la tasa. Consulta guardada del ${anterior.consultada.day}/${anterior.consultada.month}; puede estar desactualizada.',
      );
    }
    registrarEvento(
      'consulta_fallida',
      servicio: 'divisas',
      duracionMs: reloj.elapsedMilliseconds,
    );
    throw ultimoError is FalloApp
        ? ultimoError
        : const FalloApp(
            'No pudimos consultar las divisas. Revisa tu conexión y vuelve a intentar.',
            transitorio: true,
          );
  }
}
