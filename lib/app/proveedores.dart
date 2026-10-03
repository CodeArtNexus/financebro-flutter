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
