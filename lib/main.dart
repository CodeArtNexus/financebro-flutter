import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

Future<Widget> prepararAplicacion({
  Future<bool> Function()? autenticarDispositivo,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = usarEmuladores
      ? await Firebase.initializeApp(
          name: 'demo-financebro',
          // Firebase Installations en iOS valida el formato incluso en Emulator Suite.
          // Esta clave sintética no pertenece a ningún proyecto remoto.
          options: FirebaseOptions(
            apiKey: 'A00000000000000000000000000000000000000',
            appId: defaultTargetPlatform == TargetPlatform.iOS
                ? '1:1:ios:1'
                : '1:1:android:1',
            messagingSenderId: '1',
            projectId: 'demo-financebro',
            storageBucket: 'demo-financebro.appspot.com',
          ),
        )
      : await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
  if (usarEmuladores) {
    await FirebaseAuth.instanceFor(app: app)
        .useAuthEmulator(servidorEmuladores, puertoAuth);
    final datos = FirebaseFirestore.instanceFor(app: app);
    datos.settings = const Settings(persistenceEnabled: false);
    datos.useFirestoreEmulator(servidorEmuladores, puertoFirestore);
  } else {
    FirebaseMessaging.onBackgroundMessage(recibirEnSegundoPlano);
  }
  return ProviderScope(
    retry: (int intento, Object error) => null,
    overrides: [
      if (autenticarDispositivo != null)
        autenticarDispositivoProvider.overrideWithValue(autenticarDispositivo),
      firebaseAppProvider.overrideWithValue(app),
      preferenciasLocalesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
    child: const FinanceBroApp(),
  );
}

Future<void> main() async {
  final aplicacion = await prepararAplicacion();
  FlutterError.onError = (detalle) {
    registrarEvento('error_flutter');
    FlutterError.presentError(detalle);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    registrarEvento('error_no_controlado');
    return true;
  };
  runApp(aplicacion);
}
