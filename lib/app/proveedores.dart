import 'package:dio/dio.dart';

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
final identidadProvider = Provider<RepositorioIdentidad>(
  (ref) => FirebaseIdentidad(
    ref.watch(authFirebaseProvider),
    ref.watch(datosProvider),
  ),
);
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
