import 'registro.dart';

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/errores.dart';
import '../../core/funciones_banca.dart';

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
    this.autenticarDispositivo, {
    this.tieneConexion,
    this.completarApertura,
  });
  final Future<bool> Function()? tieneConexion;
  final Future<Map<String, dynamic>> Function(DatosRegistro)? completarApertura;
  Future<void> exigirConexion() async {
    if (tieneConexion != null && !await tieneConexion!()) {
      throw const FalloApp(
        "Necesitamos conexión para ingresar o abrir una cuenta.",
        transitorio: true,
      );
    }
  }

  final FirebaseFunctions functions;
  final Future<bool> Function() autenticarDispositivo;
  bool _requiereRegistro = false;
  String? _nombreSesion;
  String? _uidNombreSesion;
  @override
  bool get requiereRegistro => _requiereRegistro;
  final FirebaseAuth auth;
  final FirebaseFirestore datos;
  final SharedPreferences preferencias;
  bool _desbloqueada = false;
  bool _preparando = false;
  final _preparada = StreamController<void>.broadcast();
  static String? _nombreValido(Object? valor) {
    if (valor is! String) return null;
    final nombre = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
    return nombre.isEmpty ? null : nombre;
  }

  String? _resolverNombre(User usuario, {Object? nombrePerfil}) {
    final recuerdo = RecuerdoAcceso.leer(preferencias);
    return _nombreValido(nombrePerfil) ??
        (recuerdo?.uid == usuario.uid
            ? _nombreValido(recuerdo!.nombre)
            : null) ??
        _nombreValido(usuario.displayName);
  }

  Future<void> _recordarNombre(User usuario, {Object? nombrePerfil}) async {
    _nombreSesion = _resolverNombre(usuario, nombrePerfil: nombrePerfil);
    _uidNombreSesion = usuario.uid;
    if (_nombreSesion != null) {
      await RecuerdoAcceso(usuario.uid, _nombreSesion!).guardar(preferencias);
    }
  }

  void _limpiarNombreSesion() {
    _nombreSesion = null;
    _uidNombreSesion = null;
  }

  Identidad? _identidad(User? usuario) => usuario == null
      ? null
      : Identidad(
          usuario.uid,
          (_uidNombreSesion == usuario.uid ? _nombreSesion : null) ??
              _resolverNombre(usuario) ??
              'Tu espacio',
        );
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
    if (tieneConexion != null && !await tieneConexion!()) {
      final cuentas = await datos
          .collection('usuarios/${usuario.uid}/cuentas')
          .limit(1)
          .get(const GetOptions(source: Source.cache));
      if (cuentas.docs.isEmpty) {
        throw const FalloApp(
          'Conéctate una vez para guardar tu cuenta en este dispositivo.',
        );
      }
      await _recordarNombre(usuario);
      _requiereRegistro = false;
      _desbloqueada = true;
      _preparada.add(null);
      return;
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
    final perfil = await datos
        .doc('usuarios/${usuario.uid}')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    await _recordarNombre(usuario, nombrePerfil: perfil.data()?['nombre']);
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
    _desbloqueada = false;
    _limpiarNombreSesion();
    try {
      final credencial = await autenticar().timeout(
        const Duration(seconds: 15),
      );
      final usuario = credencial.user!;
      final documento = datos.doc('usuarios/${usuario.uid}');
      final perfil = await documento
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      final nombrePerfil =
          _nombreValido(perfil.data()?['nombre']) ?? _nombreValido(nombre);
      if (!perfil.exists) {
        await documento
            .set({
              'nombre':
                  _resolverNombre(usuario, nombrePerfil: nombrePerfil) ??
                  'Mi perfil',
              'segmento': 'equilibrio',
              'mostrarSaldo': true,
              'actualizado': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 10));
      }
      if (nombre != null) await usuario.updateDisplayName(nombre.trim());
      final cuentas = await datos
          .collection('usuarios/${usuario.uid}/cuentas')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      await _recordarNombre(usuario, nombrePerfil: nombrePerfil);
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
    await exigirConexion();
    await _completar(
      () => auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: clave,
      ),
    );
  }

  @override
  Future<void> registrar(DatosRegistro registro) async {
    await exigirConexion();
    _preparando = true;
    _desbloqueada = false;
    _limpiarNombreSesion();
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
      final resultado = completarApertura != null
          ? await completarApertura!(registro)
          : await llamarBanca(functions, 'registrarCliente', registro.apertura);
      final nombre = resultado['nombre'] as String;
      registrarEvento('registro_apertura_completada', servicio: 'banca');
      try {
        await credencial.user!
            .updateDisplayName(nombre)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        registrarEvento('nombre_sdk_pendiente', servicio: 'identidad');
      }
      await _recordarNombre(credencial.user!, nombrePerfil: nombre);
      _requiereRegistro = false;
      _desbloqueada = true;
    } on ErrorFuncionBanca catch (e) {
      _requiereRegistro = true;
      throw FalloApp(
        e.codigo == 'unavailable' || e.codigo == 'deadline-exceeded'
            ? 'No pudimos conectar para terminar tu apertura. Conservamos tu acceso; vuelve a intentar con los mismos datos.'
            : e.mensaje,
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
    _limpiarNombreSesion();
    await auth.signOut();
  }
}
