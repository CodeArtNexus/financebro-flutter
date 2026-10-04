import '../../core/red_banco.dart';

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/proveedores.dart';
import '../../core/configuracion.dart';
import '../../core/errores.dart';
import '../../core/funciones_banca.dart';

String nuevaReferencia() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
int montoCentavos(String texto, {int minimo = 10, int maximo = 10000}) {
  final valor = texto.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(valor)) {
    throw const FalloApp('Usa un monto con hasta dos decimales.');
  }
  final partes = valor.split('.');
  final centavos =
      int.parse(partes[0]) * 100 +
      int.parse(partes.length == 2 ? partes[1].padRight(2, '0') : '0');
  if (centavos < minimo || centavos > maximo) {
    throw FalloApp(
      'El monto debe estar entre USD ${(minimo / 100).toStringAsFixed(2)} y USD ${(maximo / 100).toStringAsFixed(2)}.',
    );
  }
  return centavos;
}

String leerQrCuenta(String codigo) {
  if (codigo.length > 256) {
    throw const FalloApp('Este QR no corresponde a FinanceBro.');
  }
  final uri = Uri.tryParse(codigo.trim());
  final numero = uri?.queryParameters['cuenta'];
  if (uri == null ||
      uri.scheme != 'financebro' ||
      uri.host != 'transferir' ||
      uri.path.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.queryParameters['v'] != '1' ||
      uri.queryParametersAll.length != 2 ||
      uri.queryParametersAll.values.any((v) => v.length != 1) ||
      !RegExp(r'^\d{14}$').hasMatch(numero ?? '')) {
    throw const FalloApp('Este QR no corresponde a una cuenta de FinanceBro.');
  }
  return numero!;
}

final bancaProvider = Provider<Banca>((ref) {
  final app = ref.watch(firebaseAppProvider);
  final functions = ref.watch(funcionesProvider);
  final storage = FirebaseStorage.instanceFor(app: app);
  if (usarEmuladores) {
    storage.useStorageEmulator(servidorEmuladores, puertoStorage);
  }
  return Banca(
    functions,
    ref.watch(datosProvider),
    storage,
    hayConexion: () => ref.read(redBancoProvider).conectado,
  );
});

class Banca {
  Banca(this.functions, this.db, this.storage, {this.hayConexion});
  final bool Function()? hayConexion;
  final FirebaseFunctions functions;
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  Future<Map<String, dynamic>> ejecutar(
    String operacion, [
    Map<String, dynamic> datos = const {},
  ]) async {
    if (hayConexion?.call() == false) {
      throw const FalloApp(
        "Necesitamos conexión para confirmar esta operación.",
        transitorio: true,
      );
    }
    try {
      return await llamarBanca(functions, operacion, datos);
    } on ErrorFuncionBanca catch (e) {
      throw FalloApp(
        e.codigo == 'unavailable' ||
                e.codigo == 'deadline-exceeded' ||
                e.codigo == 'not-found' && operacion == 'abrirAhorros'
            ? 'No pudimos conectar con el servicio. Revisa tu conexión y vuelve a intentar.'
            : e.mensaje,
        transitorio: [
          'unavailable',
          'deadline-exceeded',
          'internal',
        ].contains(e.codigo),
      );
    }
  }

  Stream<List<Map<String, dynamic>>> observar(
    String ruta, {
    String? orden,
    int limite = 100,
  }) {
    Query<Map<String, dynamic>> q = db.collection(ruta);
    if (orden != null) q = q.orderBy(orden, descending: true);
    return q
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}

final contactosBroProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(sesionProvider).value?.uid;
  return uid == null
      ? const Stream.empty()
      : ref.watch(bancaProvider).observar('usuarios/$uid/contactos');
});
final tarjetasBroProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(sesionProvider).value?.uid;
  return uid == null
      ? const Stream.empty()
      : ref.watch(bancaProvider).observar('usuarios/$uid/tarjetas');
});
final serviciosBroProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref
      .watch(bancaProvider)
      .observar('servicios')
      .map(
        (v) => v
            .where((s) => s['activo'] == true && s['visibleEnApp'] != false)
            .toList(),
      ),
);
final autopagosBroProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(sesionProvider).value?.uid;
  return uid == null
      ? const Stream.empty()
      : ref.watch(bancaProvider).observar('usuarios/$uid/autopagos');
});
final solicitudBroProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(sesionProvider).value?.uid;
  return uid == null
      ? const Stream.empty()
      : ref
            .watch(datosProvider)
            .doc('usuarios/$uid/solicitudes/corriente')
            .snapshots()
            .map((s) => s.data());
});

final solicitudesBroProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final uid = ref.watch(sesionProvider).value?.uid;
  return uid == null
      ? const Stream.empty()
      : ref.watch(bancaProvider).observar('usuarios/$uid/solicitudes');
});
