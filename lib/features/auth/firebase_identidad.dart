import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'identidad.dart';

class FirebaseIdentidad implements RepositorioIdentidad {
  FirebaseIdentidad(this.auth, this.datos);
  final FirebaseAuth auth;
  final FirebaseFirestore datos;
  Identidad? _identidad(User? u) =>
      u == null ? null : Identidad(u.uid, u.displayName ?? 'Tu espacio');
  @override
  Identidad? get actual => _identidad(auth.currentUser);
  @override
  Stream<Identidad?> get cambios => auth.userChanges().map(_identidad);
  @override
  Future<void> ingresar(String correo, String clave) async {
    await auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
  }

  @override
  Future<void> registrar(String nombre, String correo, String clave) async {
    final credencial = await auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
    await credencial.user!.updateDisplayName(nombre.trim());
    // El perfil no contiene importes ni permite crear cuentas financieras.
    await datos.doc('usuarios/${credencial.user!.uid}').set({
      'nombre': nombre.trim(),
      'segmento': 'equilibrio',
      'mostrarSaldo': true,
      'actualizado': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> recuperar(String correo) =>
      auth.sendPasswordResetEmail(email: correo.trim());
  @override
  Future<void> salir() => auth.signOut();
}
