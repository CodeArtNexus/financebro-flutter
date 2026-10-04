import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'configuracion.dart';

class ErrorFuncionBanca implements Exception {
  const ErrorFuncionBanca(this.codigo, this.mensaje);
  final String codigo, mensaje;
}

bool hostPrivado(String host) {
  final p = host.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((n) => n == null || n < 0 || n > 255)) {
    return false;
  }
  return p[0] == 10 ||
      p[0] == 192 && p[1] == 168 ||
      p[0] == 172 && p[1]! >= 16 && p[1]! <= 31;
}

// El transporte privado solo acepta identidades sintéticas de Emulator Suite.
bool tokenDeEmulador(String token, String uid, {DateTime? ahora}) {
  try {
    final partes = token.split('.');
    if (partes.length != 3 || partes[2].isNotEmpty) return false;
    Map<String, dynamic> leer(String s) => Map<String, dynamic>.from(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(s)))) as Map,
    );
    final cabecera = leer(partes[0]), datos = leer(partes[1]);
    return cabecera['alg'] == 'none' &&
        datos['aud'] == 'demo-financebro' &&
        datos['iss'] == 'https://securetoken.google.com/demo-financebro' &&
        datos['sub'] == uid &&
        uid.isNotEmpty &&
        datos['exp'] is int &&
        (datos['exp'] as int) >
            (ahora ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  } catch (_) {
    return false;
  }
}

Map<String, dynamic> resultadoCallable(Map<String, dynamic> respuesta) {
  if (respuesta['error'] case final Map error) {
    final estado = error['status'];
    const codigos = {
      'UNAUTHENTICATED': 'unauthenticated',
      'PERMISSION_DENIED': 'permission-denied',
      'FAILED_PRECONDITION': 'failed-precondition',
      'ALREADY_EXISTS': 'already-exists',
      'INVALID_ARGUMENT': 'invalid-argument',
      'NOT_FOUND': 'not-found',
      'UNAVAILABLE': 'unavailable',
      'DEADLINE_EXCEEDED': 'deadline-exceeded',
    };
    throw ErrorFuncionBanca(
      codigos[estado] ?? 'internal',
      error['message'] is String
          ? error['message'] as String
          : 'No pudimos completar la operación.',
    );
  }
  final datos = respuesta['result'] ?? respuesta['data'];
  if (datos is! Map) {
    throw const ErrorFuncionBanca(
      'internal',
      'No pudimos leer la respuesta. Vuelve a intentarlo.',
    );
  }
  return Map<String, dynamic>.from(datos);
}

Future<Map<String, dynamic>> llamarBanca(
  FirebaseFunctions funciones,
  String operacion,
  Map<String, dynamic> datos,
) async {
  final paquete = {'operacion': operacion, 'datos': datos};
  final tlsLocal =
      usarEmuladores &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      !['127.0.0.1', 'localhost', '::1'].contains(servidorEmuladores);
  if (!tlsLocal) {
    try {
      final r = await funciones
          .httpsCallable(
            'banca',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Map<String, dynamic>>(paquete);
      return Map<String, dynamic>.from(r.data);
    } on FirebaseFunctionsException catch (e) {
      throw ErrorFuncionBanca(
        e.code,
        e.message ?? 'No pudimos completar la operación.',
      );
    }
  }
  const certificado = String.fromEnvironment('EMULATOR_TLS_CERT');
  const puerto = int.fromEnvironment('FUNCTIONS_TLS_PORT', defaultValue: 5443);
  if (funciones.app.options.projectId != 'demo-financebro' ||
      !hostPrivado(servidorEmuladores) ||
      certificado.isEmpty) {
    throw const ErrorFuncionBanca(
      'unavailable',
      'No pudimos conectar con tus cuentas. Vuelve a intentarlo.',
    );
  }
  HttpClient? cliente;
  try {
    return await (() async {
      final auth = FirebaseAuth.instanceFor(app: funciones.app),
          usuario = auth.currentUser;
      final token = await usuario?.getIdToken();
      if (usuario == null ||
          token == null ||
          !tokenDeEmulador(token, usuario.uid)) {
        throw const ErrorFuncionBanca(
          'unauthenticated',
          'Ingresa a tu cuenta para continuar.',
        );
      }
      // Confianza limitada al certificado local: conserva validación TLS de fecha y nombre.
      final contexto = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(base64Decode(certificado));
      final transporte = HttpClient(context: contexto)
        ..connectionTimeout = const Duration(seconds: 15);
      cliente = transporte;
      final uri = Uri(
        scheme: 'https',
        host: servidorEmuladores,
        port: puerto,
        path: '/demo-financebro/us-central1/banca',
      );
      final peticion = await transporte.postUrl(uri);
      peticion.headers.contentType = ContentType.json;
      peticion.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      peticion.write(jsonEncode({'data': paquete}));
      final respuesta = await peticion.close();
      final bytes = <int>[];
      await for (final parte in respuesta) {
        bytes.addAll(parte);
        if (bytes.length > 1048576) {
          throw const FormatException('Respuesta demasiado extensa');
        }
      }
      return resultadoCallable(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
      );
    })().timeout(const Duration(seconds: 30));
  } on ErrorFuncionBanca {
    rethrow;
  } on TimeoutException {
    throw const ErrorFuncionBanca(
      'deadline-exceeded',
      'La conexión tardó más de lo esperado. Vuelve a intentarlo.',
    );
  } catch (_) {
    throw const ErrorFuncionBanca(
      'unavailable',
      'No pudimos conectar con tus cuentas. Vuelve a intentarlo.',
    );
  } finally {
    cliente?.close(force: true);
  }
}
