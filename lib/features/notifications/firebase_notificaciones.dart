import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errores.dart';
import 'notificaciones.dart';

class FirebaseNotificaciones implements RepositorioNotificaciones {
  FirebaseNotificaciones(this.datos, this.preferencias);
  final FirebaseFirestore datos;
  final SharedPreferences preferencias;
  final mensajes = FirebaseMessaging.instance;
  final locales = FlutterLocalNotificationsPlugin();
  final _recibidas = StreamController<AvisoCliente>.broadcast();
  final _suscripciones = <StreamSubscription>[];
  String? _uid;
  String? _dispositivo;
  void Function(String)? _abrir;
  @override
  Stream<AvisoCliente> get recibidas => _recibidas.stream;
  @override
  Future<void> conectar(String uid, void Function(String) abrir) async {
    if (_uid == uid) return;
    await _cancelarSuscripciones();
    _uid = uid;
    _abrir = abrir;
    _dispositivo = preferencias.getString('dispositivo_push');
    _dispositivo ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await preferencias.setString('dispositivo_push', _dispositivo!);
    await locales.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (respuesta) =>
          _abrir?.call(destinoPush({'ruta': respuesta.payload})),
    );
    await locales
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'financebro_clientes',
            'Avisos de FinanceBro',
            description: 'Novedades de tu espacio financiero',
            importance: Importance.high,
          ),
        );
    _suscripciones.add(
      FirebaseMessaging.onMessage.listen((m) async {
        if (m.data['uid'] != _uid) return;
        final aviso = AvisoCliente(
          m.notification?.title ?? 'FinanceBro',
          m.notification?.body ?? 'Hay una novedad para ti.',
          DateTime.now(),
          destinoPush(m.data),
        );
        _recibidas.add(aviso);
        registrarEvento('push_recibido', servicio: 'notificaciones');
        await locales.show(
          id: m.messageId.hashCode & 0x7fffffff,
          title: aviso.titulo,
          body: aviso.texto,
          payload: aviso.destino,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'financebro_clientes',
              'Avisos de FinanceBro',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
          ),
        );
      }),
    );
    _suscripciones.add(
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        if (m.data['uid'] == _uid) _abrir?.call(destinoPush(m.data));
      }),
    );
    _suscripciones.add(
      mensajes.onTokenRefresh.listen((token) {
        _guardarToken(token).catchError(
          (Object e) => registrarEvento(
            'token_no_sincronizado',
            servicio: 'notificaciones',
          ),
        );
      }),
    );
    final inicial = await mensajes.getInitialMessage();
    if (inicial != null && inicial.data['uid'] == uid) {
      _abrir?.call(destinoPush(inicial.data));
    }
    final permiso = await mensajes.getNotificationSettings();
    if (permiso.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await mensajes.getToken();
      if (token != null) await _guardarToken(token);
    }
  }

  Future<void> _guardarToken(String token) async {
    final uid = _uid;
    if (uid == null || _dispositivo == null) return;
    await datos
        .doc('usuarios/$uid/dispositivos/$_dispositivo')
        .set({'token': token, 'actualizado': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<bool> activar(String uid) async {
    if (_uid != uid) {
      throw const FalloApp('Estamos preparando tu sesión. Vuelve a intentar.');
    }
    final resultado = await mensajes.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (resultado.authorizationStatus != AuthorizationStatus.authorized) {
      return false;
    }
    final token = await mensajes.getToken();
    if (token == null) {
      throw const FalloApp(
        'No pudimos registrar este dispositivo. Vuelve a intentar.',
      );
    }
    await _guardarToken(token);
    return true;
  }

  Future<void> _cancelarSuscripciones() async {
    for (final s in _suscripciones) {
      await s.cancel();
    }
    _suscripciones.clear();
  }

  void dispose() {
    _cancelarSuscripciones();
    _recibidas.close();
  }

  @override
  Future<void> desconectar() async {
    final uid = _uid;
    _uid = null;
    _abrir = null;
    await _cancelarSuscripciones();
    try {
      if (uid != null && _dispositivo != null) {
        await datos
            .doc('usuarios/$uid/dispositivos/$_dispositivo')
            .delete()
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      registrarEvento('baja_push_pendiente', servicio: 'notificaciones');
    }
    try {
      await mensajes.deleteToken().timeout(const Duration(seconds: 3));
    } catch (_) {
      registrarEvento('token_no_eliminado', servicio: 'notificaciones');
    }
  }

  @override
  Stream<List<AvisoCliente>> historial(String uid) => datos
      .collection('usuarios/$uid/notificaciones')
      .orderBy('fecha', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => AvisoCliente(
                d.data()['titulo'] as String,
                d.data()['texto'] as String,
                (d.data()['fecha'] as Timestamp).toDate(),
                destinoPush(d.data()),
              ),
            )
            .toList(),
      );
}

class NotificacionesEmuladas implements RepositorioNotificaciones {
  @override
  Stream<AvisoCliente> get recibidas => const Stream.empty();
  @override
  Stream<List<AvisoCliente>> historial(String uid) => Stream.value([]);
  @override
  Future<void> conectar(String uid, void Function(String) abrir) async {}
  @override
  Future<bool> activar(String uid) async => throw const FalloApp(
    'La recepción push requiere Firebase real; no se simula en este entorno local.',
  );
  @override
  Future<void> desconectar() async {}
}
