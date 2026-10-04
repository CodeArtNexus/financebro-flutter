import 'registro.dart';

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/errores.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'identidad.dart';
import 'acceso_rapido.dart';

import 'package:shared_preferences/shared_preferences.dart';

class FirebaseIdentidad implements RepositorioIdentidad {
  FirebaseIdentidad(
    this.auth,
    this.datos,
    this.preferencias,
    this.functions,
    this.autenticarDispositivo,
  );
  final FirebaseFunctions functions;
  final Future<bool> Function() autenticarDispositivo;
  bool _requiereRegistro = false;
  String? _nombreSesion;
  @override
  bool get requiereRegistro => _requiereRegistro;
  final FirebaseAuth auth;
  final FirebaseFirestore datos;
  final SharedPreferences preferencias;
  bool _desbloqueada = false;
  bool _preparando = false;
  final _preparada = StreamController<void>.broadcast();
  Identidad? _identidad(User? u) => u == null
      ? null
      : Identidad(u.uid, _nombreSesion ?? u.displayName ?? 'Tu espacio');
  @override
  Identidad? get actual =>
      _preparando || !_desbloqueada ? null : _identidad(auth.currentUser);
  @override
  bool get sesionGuardada => auth.currentUser != null;
  @override
  Future<void> reanudarConBiometria() async {
    final usuario = auth.currentUser;
    if (usuario == null) {
      throw StateError('Ingresa con tu correo y contraseña primero.');
    }
    if (!await autenticarDispositivo()) {
      throw const FalloApp(
        'No se completó el desbloqueo. Puedes ingresar con tu contraseña.',
      );
    }
    final token = await usuario
        .getIdToken(true)
        .timeout(const Duration(seconds: 10));
    if (token == null) throw StateError('Tu sesión necesita un nuevo ingreso.');
    final cuentas = await datos
        .collection('usuarios/${usuario.uid}/cuentas')
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    _requiereRegistro = cuentas.docs.isEmpty;
    _desbloqueada = true;
    _preparada.add(null);
  }

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
      _nombreSesion =
          perfil.data()?['nombre'] as String? ?? usuario.displayName;
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
      await RecuerdoAcceso(
        usuario.uid,
        nombre?.trim() ?? usuario.displayName ?? 'Bro',
      ).guardar(preferencias);
      final cuentas = await datos
          .collection('usuarios/${usuario.uid}/cuentas')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      _requiereRegistro = cuentas.docs.isEmpty;
      _desbloqueada = true;
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
  Future<void> registrar(DatosRegistro registro) async {
    _preparando = true;
    _desbloqueada = false;
    try {
      registrarEvento('registro_acceso_iniciado', servicio: 'identidad');
      UserCredential credencial;
      try {
        credencial = await auth
            .createUserWithEmailAndPassword(
              email: registro.correo.trim(),
              password: registro.clave,
            )
            .timeout(const Duration(seconds: 15));
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        credencial = await auth
            .signInWithEmailAndPassword(
              email: registro.correo.trim(),
              password: registro.clave,
            )
            .timeout(const Duration(seconds: 15));
      }
      registrarEvento('registro_acceso_validado', servicio: 'identidad');
      final resultado = await functions
          .httpsCallable(
            'banca',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
          )
          .call<Map<String, dynamic>>({
            'operacion': 'registrarCliente',
            'datos': registro.apertura,
          });
      final nombre = resultado.data['nombre'] as String;
      _nombreSesion = nombre;
      registrarEvento('registro_apertura_completada', servicio: 'banca');
      try {
        await credencial.user!
            .updateDisplayName(nombre)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        registrarEvento('nombre_sdk_pendiente', servicio: 'identidad');
      }
      await RecuerdoAcceso(credencial.user!.uid, nombre).guardar(preferencias);
      _requiereRegistro = false;
      _desbloqueada = true;
    } on FirebaseFunctionsException catch (e) {
      _requiereRegistro = true;
      throw FalloApp(
        e.code == 'unavailable' || e.code == 'deadline-exceeded'
            ? 'No pudimos conectar para terminar tu apertura. Conservamos tu acceso; vuelve a intentar con los mismos datos.'
            : e.message ?? 'No pudimos completar tu apertura.',
      );
    } finally {
      _preparando = false;
      _preparada.add(null);
    }
  }

  @override
  Future<void> recuperar(String correo) =>
      auth.sendPasswordResetEmail(email: correo.trim());
  @override
  Future<void> salir() async {
    _desbloqueada = false;
    await auth.signOut();
  }
}
