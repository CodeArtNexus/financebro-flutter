import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errores.dart';
import 'pagos.dart';

class FirebasePagos implements RepositorioPagos {
  FirebasePagos(this.datos);
  final FirebaseFirestore datos;
  @override
  Future<String> consultarComercio(String id) async {
    final comercio = await datos
        .doc('comercios/$id')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    if (!comercio.exists || comercio.data()!['activo'] != true) {
      throw const FalloApp('Este comercio no está disponible.');
    }
    return comercio.data()!['nombre'] as String;
  }

  @override
  Future<ReciboPago> pagar(
    String uid,
    String cuenta,
    SolicitudQr solicitud,
  ) async {
    final recibo = datos.doc('usuarios/$uid/pagos/${solicitud.referencia}');
    final cuentaRef = datos.doc('usuarios/$uid/cuentas/$cuenta');
    final movimiento = cuentaRef
        .collection('movimientos')
        .doc(solicitud.referencia);
    // Una transacción necesita conexión. No se confirma dinero desde la caché.
    return datos.runTransaction(
      (tx) async {
        final anterior = await tx.get(recibo);
        if (anterior.exists) {
          final r = anterior.data()!;
          if (r['cuenta'] != cuenta ||
              r['comercio'] != solicitud.comercio ||
              r['centavos'] != solicitud.centavos) {
            throw const FalloApp(
              'Esta referencia ya fue usada para otro pago.',
            );
          }
          return ReciboPago(
            referencia: solicitud.referencia,
            cuenta: cuenta,
            comercio: solicitud.comercio,
            nombre: r['nombre'] as String,
            centavos: solicitud.centavos,
          );
        }
        final disponible = await tx.get(cuentaRef);
        final comercio = await tx.get(
          datos.doc('comercios/${solicitud.comercio}'),
        );
        if (!disponible.exists) {
          throw const FalloApp('La cuenta ya no está disponible.');
        }
        if (!comercio.exists || comercio.data()!['activo'] != true) {
          throw const FalloApp('Este comercio no está disponible.');
        }
        final saldo = (disponible.data()!['saldoCentavos'] as num).toInt();
        if (saldo < solicitud.centavos) {
          throw const FalloApp('Esta cuenta no tiene saldo suficiente.');
        }
        final nombre = comercio.data()!['nombre'] as String;
        tx.update(cuentaRef, {
          'saldoCentavos': saldo - solicitud.centavos,
          'actualizado': FieldValue.serverTimestamp(),
          'ultimoMovimiento': solicitud.referencia,
        });
        tx.set(movimiento, {
          'descripcion': 'Pago QR · $nombre',
          'centavos': -solicitud.centavos,
          'categoria': 'Pago QR',
          'tipo': 'qr',
          'actor': uid,
          'comercio': solicitud.comercio,
          'referencia': solicitud.referencia,
          'fecha': FieldValue.serverTimestamp(),
        });
        tx.set(recibo, {
          'cuenta': cuenta,
          'comercio': solicitud.comercio,
          'nombre': nombre,
          'centavos': solicitud.centavos,
          'fecha': FieldValue.serverTimestamp(),
        });
        return ReciboPago(
          referencia: solicitud.referencia,
          cuenta: cuenta,
          comercio: solicitud.comercio,
          nombre: nombre,
          centavos: solicitud.centavos,
        );
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 3,
    );
  }
}
