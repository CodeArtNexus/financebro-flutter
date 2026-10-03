import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'identidad.dart';

class FirebaseIdentidad implements RepositorioIdentidad {
  FirebaseIdentidad(this.auth, this.datos);
  final FirebaseAuth auth;
  final FirebaseFirestore datos;
  bool _preparando = false;
  final _preparada = StreamController<void>.broadcast();
  Identidad? _identidad(User? u) =>
      u == null ? null : Identidad(u.uid, u.displayName ?? 'Tu espacio');
  @override
  Identidad? get actual => _preparando ? null : _identidad(auth.currentUser);
  @override
  Stream<Identidad?> get cambios => Stream<Identidad?>.multi((controlador) {
    controlador.add(actual);
    final nativa = auth.userChanges().listen(
      (_) => controlador.add(actual),
      onError: controlador.addError,
    );
    final preparada = _preparada.stream.listen((_) => controlador.add(actual));
    controlador.onCancel = () async {
      await nativa.cancel();
      await preparada.cancel();
    };
  }, isBroadcast: true);
  void dispose() => _preparada.close();

  Future<void> _completar(
    Future<UserCredential> Function() autenticar, {
    String? nombre,
  }) async {
    _preparando = true;
    try {
      final credencial = await autenticar().timeout(
        const Duration(seconds: 15),
      );
      final usuario = credencial.user!;
      final documento = datos.doc('usuarios/${usuario.uid}');
      final perfil = await documento.get().timeout(const Duration(seconds: 10));
      if (!perfil.exists) {
        await documento
            .set({
              'nombre': nombre?.trim() ?? usuario.displayName ?? 'Mi perfil',
              'segmento': 'equilibrio',
              'mostrarSaldo': true,
              'actualizado': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 10));
      }
      if (nombre != null) await usuario.updateDisplayName(nombre.trim());
    } catch (_) {
      await auth.signOut();
      rethrow;
    } finally {
      _preparando = false;
      _preparada.add(null);
    }
  }

  @override
  Future<void> ingresar(String correo, String clave) async {
    await _completar(
      () => auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: clave,
      ),
    );
  }

  @override
  Future<void> registrar(String nombre, String correo, String clave) async {
    await _completar(
      () => auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: clave,
      ),
      nombre: nombre,
    );
  }

  @override
  Future<void> recuperar(String correo) =>
      auth.sendPasswordResetEmail(email: correo.trim());
  @override
  Future<void> salir() => auth.signOut();
}
