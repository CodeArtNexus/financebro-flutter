import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/configuracion.dart';
import '../../core/errores.dart';
import 'notificaciones.dart';

class FirebaseNotificaciones implements RepositorioNotificaciones {
  FirebaseNotificaciones(this.datos, this.preferencias);
  final FirebaseFirestore datos;
  final SharedPreferences preferencias;
  final locales = FlutterLocalNotificationsPlugin();
  final _recibidas = StreamController<AvisoCliente>.broadcast();
  final _suscripciones = <StreamSubscription>[];
  String? _uid, _dispositivo;
  void Function(String)? _abrir;
  bool get remotas =>
      !usarEmuladores &&
      (defaultTargetPlatform != TargetPlatform.iOS ||
          const bool.fromEnvironment('IOS_PUSH_ENABLED'));
  FirebaseMessaging get mensajes => FirebaseMessaging.instance;
  @override
  Stream<AvisoCliente> get recibidas => _recibidas.stream;
  @override
  Future<void> conectar(String uid, void Function(String) abrir) async {
    if (_uid == uid) return;
    await _cancelar();
    _uid = uid;
    _abrir = abrir;
    _dispositivo =
        preferencias.getString('dispositivo_push') ??
        List.generate(
          16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await preferencias.setString('dispositivo_push', _dispositivo!);
    await locales.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) =>
          _abrir?.call(destinoPush({'ruta': r.payload})),
    );
    await locales
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'financebro_clientes',
            'Avisos de FinanceBro',
            importance: Importance.high,
          ),
        );
    if (!remotas) {
      final desde = Timestamp.fromDate(DateTime.now());
      _suscripciones.add(
        datos
            .collection('usuarios/$uid/notificaciones')
            .where('fecha', isGreaterThan: desde)
            .snapshots(includeMetadataChanges: true)
            .listen(
              (s) async {
                for (final documento in s.docs) {
                  if (s.metadata.isFromCache || _uid != uid) continue;
                  final d = documento.data();
                  await _recibir(
                    d['evento'] as String? ?? '${uid}_${documento.id}',
                    AvisoCliente(
                      d['titulo'] as String,
                      (d['cuerpo'] ?? d['texto']) as String,
                      (d['fecha'] as Timestamp).toDate(),
                      destinoPush(d),
                    ),
                  );
                }
              },
              onError: (Object e) => registrarEvento(
                'avisos_no_sincronizados',
                servicio: 'notificaciones',
              ),
            ),
      );
      return;
    }
    _suscripciones.add(
      FirebaseMessaging.onMessage.listen((m) async {
        if (m.data['uid'] != _uid) return;
        await _recibir(
          m.data['evento'] ?? m.messageId ?? nuevaId(),
          AvisoCliente(
            m.notification?.title ?? 'FinanceBro',
            m.notification?.body ?? 'Hay una novedad para ti.',
            DateTime.now(),
            destinoPush(m.data),
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

  String nuevaId() => DateTime.now().microsecondsSinceEpoch.toString();
  Future<void> _recibir(String evento, AvisoCliente aviso) async {
    final uid = _uid;
    if (uid == null) return;
    final vistos = preferencias.getStringList('avisos_vistos_$uid') ?? [];
    if (vistos.contains(evento)) return;
    vistos.add(evento);
    await preferencias.setStringList(
      'avisos_vistos_$uid',
      vistos.skip(vistos.length > 100 ? vistos.length - 100 : 0).toList(),
    );
    if (_uid != uid) return;
    _recibidas.add(aviso);
    if (preferencias.getBool('avisos_activos_$uid') != true) return;
    await locales.show(
      id: evento.hashCode & 0x7fffffff,
      title: aviso.titulo,
      body: aviso.texto,
      payload: aviso.destino,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'financebro_clientes',
          'Avisos de FinanceBro',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
    );
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
      throw const FalloApp('Estamos preparando tus avisos. Vuelve a intentar.');
    }
    bool permitido;
    if (remotas) {
      permitido =
          (await mensajes.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )).authorizationStatus ==
          AuthorizationStatus.authorized;
      if (permitido) {
        await mensajes.setAutoInitEnabled(true);
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            await mensajes.getAPNSToken() == null) {
          throw const FalloApp(
            'Estamos preparando los avisos de este dispositivo. Vuelve a intentar en un momento.',
          );
        }
        final token = await mensajes.getToken();
        if (token == null) {
          throw const FalloApp(
            'No pudimos activar tus avisos. Vuelve a intentar.',
          );
        }
        await _guardarToken(token);
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      permitido =
          await locales
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else {
      permitido =
          await locales
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    await preferencias.setBool('avisos_activos_$uid', permitido);
    return permitido;
  }

  Future<void> _cancelar() async {
    for (final s in _suscripciones) {
      await s.cancel();
    }
    _suscripciones.clear();
  }

  @override
  Future<void> desconectar() async {
    final uid = _uid;
    _uid = null;
    _abrir = null;
    await _cancelar();
    await locales.cancelAll();
    if (remotas) {
      try {
        if (uid != null && _dispositivo != null) {
          await datos
              .doc('usuarios/$uid/dispositivos/$_dispositivo')
              .delete()
              .timeout(const Duration(seconds: 3));
        }
        await mensajes.deleteToken().timeout(const Duration(seconds: 3));
      } catch (_) {
        registrarEvento('baja_push_pendiente', servicio: 'notificaciones');
      }
    }
  }

  void dispose() {
    _cancelar();
    _recibidas.close();
  }

  @override
  Stream<List<AvisoCliente>> historial(String uid) => datos
      .collection('usuarios/$uid/notificaciones')
      .orderBy('fecha', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => AvisoCliente(
                d.data()['titulo'] as String,
                (d.data()['texto'] ?? d.data()['cuerpo']) as String,
                (d.data()['fecha'] as Timestamp).toDate(),
                destinoPush(d.data()),
              ),
            )
            .toList(),
      );
}
