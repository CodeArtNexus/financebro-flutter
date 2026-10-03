import 'package:cloud_firestore/cloud_firestore.dart';

import 'cuentas.dart';

class FirebaseCuentas implements RepositorioCuentas {
  FirebaseCuentas(this.datos);
  final FirebaseFirestore datos;
  @override
  Stream<DatosGuardados<List<Cuenta>>> observarCuentas(String uid) => datos
      .collection('usuarios/$uid/cuentas')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => DatosGuardados(
          snapshot.docs
              .map((doc) => Cuenta.desdeMapa(doc.id, doc.data()))
              .toList(),
          desdeCache: snapshot.metadata.isFromCache,
          actualizado: _fecha(
            snapshot.docs.map((d) => d.data()['actualizado']),
          ),
        ),
      );
  @override
  Stream<DatosGuardados<List<Movimiento>>> observarMovimientos(
    String uid,
    String cuenta,
  ) => datos
      .collection('usuarios/$uid/cuentas/$cuenta/movimientos')
      .orderBy('fecha', descending: true)
      .limit(50)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => DatosGuardados(
          snapshot.docs
              .map(
                (d) => Movimiento(
                  id: d.id,
                  descripcion: d.data()['descripcion'] as String,
                  centavos: (d.data()['centavos'] as num).toInt(),
                  fecha: (d.data()['fecha'] as Timestamp).toDate(),
                  categoria: d.data()['categoria'] as String,
                ),
              )
              .toList(),
          desdeCache: snapshot.metadata.isFromCache,
          actualizado: _fecha(snapshot.docs.map((d) => d.data()['fecha'])),
        ),
      );
  DateTime _fecha(Iterable<Object?> fechas) {
    final valores =
        fechas.whereType<Timestamp>().map((f) => f.toDate()).toList()..sort();
    return valores.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : valores.last;
  }
}
