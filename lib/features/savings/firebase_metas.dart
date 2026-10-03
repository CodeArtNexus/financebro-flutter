import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errores.dart';
import 'metas.dart';

class FirebaseMetas implements RepositorioMetas {
  FirebaseMetas(this.datos);
  final FirebaseFirestore datos;
  @override
  Stream<List<MetaAhorro>> observar(String uid) => datos
      .collection('usuarios/$uid/metas')
      .snapshots()
      .map(
        (s) => s.docs.map((d) {
          final m = d.data();
          return MetaAhorro(
            id: d.id,
            nombre: m['nombre'] as String,
            cuenta: m['cuenta'] as String,
            objetivo: m['objetivoCentavos'] as int,
            aporteMensual: m['aporteMensualCentavos'] as int,
            fecha: (m['fechaObjetivo'] as Timestamp).toDate(),
          );
        }).toList(),
      );
  @override
  Future<void> guardar(String uid, MetaAhorro meta) async {
    await datos.runTransaction((tx) async {
      final cuenta = await tx.get(
        datos.doc('usuarios/$uid/cuentas/${meta.cuenta}'),
      );
      if (!cuenta.exists) {
        throw const FalloApp('Selecciona una cuenta disponible.');
      }
      tx.set(datos.doc('usuarios/$uid/metas/${meta.id}'), {
        'nombre': meta.nombre.trim(),
        'cuenta': meta.cuenta,
        'objetivoCentavos': meta.objetivo,
        'aporteMensualCentavos': meta.aporteMensual,
        'fechaObjetivo': Timestamp.fromDate(meta.fecha),
        'actualizado': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> eliminar(String uid, String id) =>
      datos.doc('usuarios/$uid/metas/$id').delete();
}
