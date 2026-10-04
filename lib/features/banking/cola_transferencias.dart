import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/errores.dart';

abstract interface class AlmacenCola {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
}

class AlmacenSeguroCola implements AlmacenCola {
  final storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  @override
  Future<String?> leer(String clave) => storage.read(key: clave);
  @override
  Future<void> escribir(String clave, String valor) =>
      storage.write(key: clave, value: valor);
}

class ColaTransferencias extends ChangeNotifier {
  ColaTransferencias({
    required this.almacen,
    required this.sesion,
    required this.enviar,
    required this.conectado,
    required this.desbloquear,
    required this.proyecto,
    DateTime Function()? reloj,
  }) : reloj = reloj ?? DateTime.now;
  final AlmacenCola almacen;
  final String? Function() sesion;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) enviar;
  final bool Function() conectado;
  final Future<bool> Function() desbloquear;
  final String proyecto;
  final DateTime Function() reloj;
  String? uid;
  List<Map<String, dynamic>> items = [];
  bool procesando = false;
  bool _cerrada = false;
  Future<void> _escritura = Future.value();
  String clave(String u) => 'bro_cola_${proyecto}_$u';
  Future<void> cargar(String? u) async {
    await _escritura;
    uid = u;
    items = [];
    if (u != null) {
      final raw = await almacen.leer(clave(u));
      if (uid != u) return;
      try {
        final lista = jsonDecode(raw ?? '[]');
        if (lista is! List || lista.length > 50) throw const FormatException();
        items = lista
            .map((v) => Map<String, dynamic>.from(v as Map))
            .where(
              (v) =>
                  v['uid'] == u &&
                  v['referencia'] is String &&
                  v['creada'] is String &&
                  v['datos'] is Map,
            )
            .map(
              (v) =>
                  v['estado'] == 'enviando' ? {...v, 'estado': 'pendiente'} : v,
            )
            .toList();
      } catch (_) {
        throw const FalloApp(
          'No pudimos leer tus transferencias pendientes. Conservamos el archivo para revisarlo.',
        );
      }
    }
    if (!_cerrada) notifyListeners();
  }

  Future<void> guardar() {
    final u = uid;
    if (u == null) return Future.value();
    final raw = jsonEncode(items);
    _escritura = _escritura.then((_) => almacen.escribir(clave(u), raw));
    return _escritura;
  }

  void avisar() {
    if (!_cerrada) notifyListeners();
  }

  Future<void> agregar(Map<String, dynamic> datos, String titular) async {
    final u = uid;
    if (u == null || sesion() != u) {
      throw const FalloApp(
        'Desbloquea tu sesión para preparar una transferencia.',
      );
    }
    if (items
            .where((v) => ['pendiente', 'enviando'].contains(v['estado']))
            .length >=
        20) {
      throw const FalloApp(
        'Tienes 20 transferencias pendientes. Revisa la lista antes de agregar otra.',
      );
    }
    if (!await desbloquear()) {
      throw const FalloApp(
        'Autoriza la transferencia con la seguridad de tu dispositivo.',
      );
    }
    if (uid != u || sesion() != u) {
      throw const FalloApp(
        'Tu sesión cambió. Vuelve a revisar la transferencia.',
      );
    }
    if (items.any((v) => v['referencia'] == datos['referencia'])) return;
    items = items
        .where((v) => ['pendiente', 'enviando'].contains(v['estado']))
        .followedBy(
          items
              .where((v) => !['pendiente', 'enviando'].contains(v['estado']))
              .take(29),
        )
        .toList();
    final creada = reloj().toUtc().toIso8601String();
    items.add({
      'uid': u,
      'referencia': datos['referencia'],
      'titular': titular,
      'creada': creada,
      'estado': 'pendiente',
      'mensaje': 'Se validará al reconectar. Aún no descontamos dinero.',
      'datos': {...datos, 'colaCreada': creada},
    });
    await guardar();
    avisar();
    if (conectado()) unawaited(procesar());
  }

  Future<void> cancelar(String ref) async {
    final i = items.where((v) => v['referencia'] == ref).firstOrNull;
    if (i == null || i['estado'] != 'pendiente') return;
    i['estado'] = 'cancelada';
    i['mensaje'] = 'Cancelada antes de enviarse.';
    await guardar();
    avisar();
  }

  Future<void> procesar() async {
    if (procesando || uid == null || !conectado() || sesion() != uid) return;
    procesando = true;
    final u = uid;
    try {
      for (final item
          in items.where((v) => v['estado'] == 'pendiente').toList()) {
        if (uid != u || sesion() != u || !conectado()) break;
        final creada = DateTime.tryParse(item['creada'] as String);
        if (creada == null ||
            reloj().difference(creada) > const Duration(hours: 24) ||
            creada.isAfter(reloj().add(const Duration(minutes: 5)))) {
          item['estado'] = 'expirada';
          item['mensaje'] = 'Pasaron 24 horas. Revisa los datos y crea una nueva transferencia.';
          await guardar();
          avisar();
          continue;
        }
        item['estado'] = 'enviando';
        await guardar();
        avisar();
        try {
          final recibo = await enviar(
            Map<String, dynamic>.from(item['datos'] as Map),
          );
          item['estado'] = 'confirmada';
          item['mensaje'] = 'Transferencia confirmada por FinanceBro.';
          item['recibo'] = recibo;
        } catch (e) {
          if (e is FalloApp && !e.transitorio) {
            item['estado'] = 'rechazada';
            item['mensaje'] = e.mensaje;
          } else {
            item['estado'] = 'pendiente';
            item['mensaje'] =
                'Estamos esperando conexión. Conservamos la misma referencia.';
          }
        }
        if (uid == u) {
          await guardar();
          avisar();
        } else {
          final raw = await almacen.leer(clave(u!));
          final antiguos = (jsonDecode(raw ?? '[]') as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          final ix = antiguos.indexWhere(
            (v) => v['referencia'] == item['referencia'],
          );
          if (ix >= 0) {
            antiguos[ix] = item;
            await almacen.escribir(clave(u), jsonEncode(antiguos));
          }
          break;
        }
        if (item['estado'] == 'pendiente') break;
      }
    } finally {
      procesando = false;
      avisar();
    }
  }

  @override
  void dispose() {
    _cerrada = true;
    super.dispose();
  }
}
