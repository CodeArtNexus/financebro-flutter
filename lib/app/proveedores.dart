import 'package:cloud_functions/cloud_functions.dart';
import 'package:local_auth/local_auth.dart';

import '../features/payments/pagos.dart';
import '../features/payments/firebase_pagos.dart';
import '../features/savings/metas.dart';
import '../features/savings/firebase_metas.dart';

import 'package:dio/dio.dart';

import '../core/configuracion.dart';
import '../core/errores.dart';
import '../features/notifications/notificaciones.dart';
import '../features/notifications/firebase_notificaciones.dart';

import '../core/control_red.dart';
import '../features/exchange/divisas.dart';
import '../features/exchange/http_divisas.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/experience/experiencia.dart';
import '../features/experience/firebase_experiencia.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/identidad.dart';
import '../features/auth/acceso_rapido.dart';
import '../features/auth/firebase_identidad.dart';
import '../features/accounts/cuentas.dart';
import '../features/accounts/firebase_cuentas.dart';

final firebaseAppProvider = Provider<FirebaseApp>((ref) => Firebase.app());
final datosProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instanceFor(app: ref.watch(firebaseAppProvider)),
);
final authFirebaseProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instanceFor(app: ref.watch(firebaseAppProvider)),
);
final autenticarDispositivoProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) {
      throw const FalloApp(
        'Configura un bloqueo seguro en tu dispositivo o ingresa con tu contraseña.',
      );
    }
    return auth.authenticate(
      localizedReason: 'Desbloquea tu espacio FinanceBro',
      persistAcrossBackgrounding: true,
    );
  },
);
final funcionesProvider = Provider<FirebaseFunctions>((ref) {
  final funciones = FirebaseFunctions.instanceFor(
    app: ref.watch(firebaseAppProvider),
    region: 'us-central1',
  );
  if (usarEmuladores) {
    funciones.useFunctionsEmulator(servidorEmuladores, puertoFunciones);
  }
  return funciones;
});
final identidadProvider = Provider<RepositorioIdentidad>((ref) {
  final repositorio = FirebaseIdentidad(
    ref.watch(authFirebaseProvider),
    ref.watch(datosProvider),
    ref.watch(preferenciasLocalesProvider),
    ref.watch(funcionesProvider),
    ref.watch(autenticarDispositivoProvider),
  );
  ref.onDispose(repositorio.dispose);
  return repositorio;
});
final sesionProvider = StreamProvider<Identidad?>(
  (ref) => ref.watch(identidadProvider).cambios,
);
final cuentasRepositorioProvider = Provider<RepositorioCuentas>(
  (ref) => FirebaseCuentas(ref.watch(datosProvider)),
);
final cuentasProvider = StreamProvider<DatosGuardados<List<Cuenta>>>((ref) {
  final usuario = ref.watch(sesionProvider).value;
  if (usuario == null) return const Stream.empty();
  return ref.watch(cuentasRepositorioProvider).observarCuentas(usuario.uid);
});
final movimientosProvider = StreamProvider.autoDispose
    .family<DatosGuardados<List<Movimiento>>, String>((ref, cuenta) {
      final usuario = ref.watch(sesionProvider).value;
      if (usuario == null) return const Stream.empty();
      return ref
          .watch(cuentasRepositorioProvider)
          .observarMovimientos(usuario.uid, cuenta);
    });

final preferenciasLocalesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'Las preferencias locales deben inicializarse al arrancar.',
  ),
);
final experienciaRepositorioProvider = Provider<RepositorioExperiencia>(
  (ref) => FirebaseExperiencia(
    ref.watch(datosProvider),
    ref.watch(preferenciasLocalesProvider),
  ),
);
final perfilProvider = StreamProvider<DatosGuardados<Perfil>>((ref) {
  final usuario = ref.watch(sesionProvider).value;
  if (usuario == null) return const Stream.empty();
  return ref.watch(experienciaRepositorioProvider).observarPerfil(usuario.uid);
});
final contenidoProvider = StreamProvider<Experiencia>((ref) {
  if (ref.watch(sesionProvider).value == null) {
    return Stream.value(experienciaBase);
  }
  return ref.watch(experienciaRepositorioProvider).observarContenido();
});

final controlRedProvider = Provider<ControlRed>((ref) {
  final control = ControlRed.conFirestore(ref.watch(datosProvider));
  ref.onDispose(control.dispose);
  return control;
});
final divisasRepositorioProvider = Provider<RepositorioDivisas>(
  (ref) => HttpDivisas(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    ),
    CacheDivisas(ref.watch(preferenciasLocalesProvider)),
    ref.watch(controlRedProvider),
  ),
);
final cotizacionProvider = FutureProvider.autoDispose
    .family<Cotizacion, String>(
      (ref, moneda) => ref.watch(divisasRepositorioProvider).consultar(moneda),
    );

final notificacionesRepositorioProvider = Provider<RepositorioNotificaciones>((
  ref,
) {
  final repositorio = FirebaseNotificaciones(
    ref.watch(datosProvider),
    ref.watch(preferenciasLocalesProvider),
  );
  ref.onDispose(repositorio.dispose);
  return repositorio;
});
final historialNotificacionesProvider = StreamProvider<List<AvisoCliente>>((
  ref,
) {
  final usuario = ref.watch(sesionProvider).value;
  if (usuario == null) return const Stream.empty();
  return ref.watch(notificacionesRepositorioProvider).historial(usuario.uid);
});

final recuerdoAccesoProvider = Provider<RecuerdoAcceso?>((ref) {
  ref.watch(sesionProvider);
  return RecuerdoAcceso.leer(ref.watch(preferenciasLocalesProvider));
});

final pagosRepositorioProvider = Provider<RepositorioPagos>(
  (ref) => FirebasePagos(ref.watch(datosProvider)),
);
final metasRepositorioProvider = Provider<RepositorioMetas>(
  (ref) => FirebaseMetas(ref.watch(datosProvider)),
);
final metasProvider = StreamProvider.autoDispose<List<MetaAhorro>>((ref) {
  final uid = ref.watch(sesionProvider).value?.uid;
  return uid == null
      ? const Stream.empty()
      : ref.watch(metasRepositorioProvider).observar(uid);
});
