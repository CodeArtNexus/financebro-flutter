// Los dobles del SDK se limitan a pruebas; no se heredan estos tipos en producción.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financebro/features/auth/acceso_rapido.dart';
import 'package:financebro/features/auth/firebase_identidad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Usuario extends Fake implements User {
  _Usuario(this.uid, this.displayName);
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';
}

class _Credencial extends Fake implements UserCredential {
  _Credencial(this.user);
  @override
  final User user;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.usuario);
  User? usuario;
  @override
  User? get currentUser => usuario;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _Credencial(usuario!);
  @override
  Stream<User?> userChanges() => Stream.value(usuario);
  @override
  Future<void> signOut() async => usuario = null;
}

class _Documento extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _Documento(this.mapa);
  final Map<String, dynamic>? mapa;
  @override
  Map<String, dynamic>? data() => mapa;
  @override
  bool get exists => mapa != null;
}

class _Referencia extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Referencia(this.mapa);
  final Map<String, dynamic>? mapa;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Documento(mapa);
}

class _Cuenta extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _Cuentas extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [_Cuenta()];
}

class _Consulta extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Cuentas();
}

class _Datos extends Fake implements FirebaseFirestore {
  final perfiles = <String, Map<String, dynamic>>{};
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Referencia(perfiles[path]);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Consulta();
}

class _Funciones extends Fake implements FirebaseFunctions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferencias;
  late _Datos datos;
  late _Auth auth;

  FirebaseIdentidad crear({bool conexion = true}) {
    final repositorio = FirebaseIdentidad(
      auth,
      datos,
      preferencias,
      _Funciones(),
      () async => true,
      tieneConexion: () async => conexion,
    );
    addTearDown(repositorio.dispose);
    return repositorio;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferencias = await SharedPreferences.getInstance();
    datos = _Datos();
    auth = _Auth(_Usuario('sebas', null));
    datos.perfiles['usuarios/sebas'] = {'nombre': 'Sebastián Bustillos'};
  });

  for (final nombreAuth in <String?>[null, '', '   ']) {
    test(
      'El primer ingreso recuerda el perfil con nombre Auth ${nombreAuth == null
          ? 'nulo'
          : nombreAuth.isEmpty
          ? 'vacío'
          : 'de espacios'}',
      () async {
        auth.usuario = _Usuario('sebas', nombreAuth);
        final repositorio = crear();
        await repositorio.ingresar('sebas@financebro.test', 'clave-ficticia');
        expect(repositorio.actual?.nombre, 'Sebastián Bustillos');
        expect(RecuerdoAcceso.leer(preferencias)?.saludo, 'Sebastián');
      },
    );
  }

  test(
    'El nombre del perfil prevalece sobre un nombre antiguo de Auth',
    () async {
      auth.usuario = _Usuario('sebas', 'Nombre antiguo');
      final repositorio = crear();
      await repositorio.ingresar('sebas@financebro.test', 'clave-ficticia');
      expect(repositorio.actual?.nombre, 'Sebastián Bustillos');
      expect(RecuerdoAcceso.leer(preferencias)?.nombre, 'Sebastián Bustillos');
    },
  );

  test(
    'Al reabrir con biometría y conexión se recupera el nombre del perfil',
    () async {
      await const RecuerdoAcceso('sebas', 'Bro').guardar(preferencias);
      final repositorio = crear();
      expect(repositorio.actual, isNull);
      await repositorio.reanudarConBiometria();
      expect(repositorio.actual?.nombre, 'Sebastián Bustillos');
      expect(RecuerdoAcceso.leer(preferencias)?.nombre, 'Sebastián Bustillos');
    },
  );

  test(
    'La sesión nueva actualiza también un saludo guardado anteriormente',
    () async {
      await const RecuerdoAcceso(
        'sebas',
        'Nombre anterior',
      ).guardar(preferencias);
      final repositorio = crear();
      await repositorio.reanudarConBiometria();
      expect(repositorio.actual?.nombre, 'Sebastián Bustillos');
      expect(RecuerdoAcceso.leer(preferencias)?.saludo, 'Sebastián');
    },
  );

  test(
    'Sin conexión se conserva el nombre verificado de la misma cuenta',
    () async {
      auth.usuario = _Usuario('sebas', 'Nombre antiguo');
      await const RecuerdoAcceso(
        'sebas',
        'Sebastián Bustillos',
      ).guardar(preferencias);
      final repositorio = crear(conexion: false);
      await repositorio.reanudarConBiometria();
      expect(repositorio.actual?.nombre, 'Sebastián Bustillos');
    },
  );

  test(
    'Cambiar de cuenta no reutiliza el nombre de la sesión anterior',
    () async {
      final repositorio = crear();
      await repositorio.ingresar('sebas@financebro.test', 'clave-ficticia');
      await repositorio.salir();
      auth.usuario = _Usuario('mateo', null);
      datos.perfiles['usuarios/mateo'] = {'nombre': 'Mateo Torres'};
      await repositorio.reanudarConBiometria();
      expect(repositorio.actual?.uid, 'mateo');
      expect(repositorio.actual?.nombre, 'Mateo Torres');
      expect(RecuerdoAcceso.leer(preferencias)?.uid, 'mateo');
      expect(RecuerdoAcceso.leer(preferencias)?.saludo, 'Mateo');
    },
  );

  test('Los nombres vacíos usan un respaldo sin mezclar usuarios', () async {
    auth.usuario = _Usuario('mateo', '  Mateo   Torres  ');
    datos.perfiles['usuarios/mateo'] = {'nombre': '   '};
    await const RecuerdoAcceso(
      'sebas',
      'Sebastián Bustillos',
    ).guardar(preferencias);
    final repositorio = crear();
    await repositorio.ingresar('mateo@financebro.test', 'clave-ficticia');
    expect(repositorio.actual?.nombre, 'Mateo Torres');
    expect(RecuerdoAcceso.leer(preferencias)?.nombre, 'Mateo Torres');
  });
}
