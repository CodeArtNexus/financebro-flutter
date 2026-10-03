import 'package:shared_preferences/shared_preferences.dart';

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/financebro_app.dart';
import 'app/proveedores.dart';
import 'core/configuracion.dart';
import 'core/errores.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> recibirEnSegundoPlano(RemoteMessage mensaje) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  registrarEvento('push_segundo_plano', servicio: 'notificaciones');
}

Future<Widget> prepararAplicacion() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = usarEmuladores
      ? await Firebase.initializeApp(demoProjectId: 'demo-financebro')
      : await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
  if (usarEmuladores) {
    await FirebaseAuth.instanceFor(app: app)
        .useAuthEmulator(servidorEmuladores, 9099);
    final datos = FirebaseFirestore.instanceFor(app: app);
    datos.settings = const Settings(persistenceEnabled: false);
    datos.useFirestoreEmulator(servidorEmuladores, 8080);
  } else {
    FirebaseMessaging.onBackgroundMessage(recibirEnSegundoPlano);
  }
  FlutterError.onError = (detalle) {
    registrarEvento('error_flutter');
    FlutterError.presentError(detalle);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    registrarEvento('error_no_controlado');
    return true;
  };
  return ProviderScope(
    retry: (int intento, Object error) => null,
    overrides: [
      firebaseAppProvider.overrideWithValue(app),
      preferenciasLocalesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
    child: const FinanceBroApp(),
  );
}

Future<void> main() async {
  runApp(await prepararAplicacion());
}
