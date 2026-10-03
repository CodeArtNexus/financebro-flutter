import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errores.dart';
import '../accounts/cuentas.dart';
import 'experiencia.dart';

class FirebaseExperiencia implements RepositorioExperiencia {
  FirebaseExperiencia(this.datos, this.preferencias);
  final FirebaseFirestore datos;
  final SharedPreferences preferencias;
  @override
  Stream<Experiencia> observarContenido() async* {
    var ultima = experienciaBase;
    final cache = preferencias.getString('experiencia_valida_v1');
    if (cache != null) {
      try {
        ultima = Experiencia.desdeMapa(
          jsonDecode(cache) as Map<String, dynamic>,
        );
      } catch (_) {
        registrarEvento('configuracion_cache_rechazada');
      }
    }
    yield Experiencia(ultima.tarjetas, ultima.revision, respaldo: true);
    try {
      await for (final snapshot
          in datos
              .doc('experiencias/actual')
              .snapshots(includeMetadataChanges: true)) {
        try {
          ultima = Experiencia.desdeMapa(snapshot.data() ?? {});
          await preferencias.setString(
            'experiencia_valida_v1',
            jsonEncode(ultima.aMapa()),
          );
          yield Experiencia(
            ultima.tarjetas,
            ultima.revision,
            respaldo: snapshot.metadata.isFromCache,
          );
        } catch (_) {
          registrarEvento(
            'configuracion_remota_rechazada',
            servicio: 'experiencia',
          );
          yield Experiencia(ultima.tarjetas, ultima.revision, respaldo: true);
        }
      }
    } catch (_) {
      registrarEvento('experiencia_respaldo', servicio: 'experiencia');
      yield Experiencia(ultima.tarjetas, ultima.revision, respaldo: true);
    }
  }

  @override
  Stream<DatosGuardados<Perfil>> observarPerfil(String uid) => datos
      .doc('usuarios/$uid')
      .snapshots(includeMetadataChanges: true)
      .map((s) {
        final m = s.data() ?? {};
        return DatosGuardados(
          Perfil(
            nombre: m['nombre'] as String? ?? 'Mi perfil',
            segmento: m['segmento'] as String? ?? 'equilibrio',
            mostrarSaldo: m['mostrarSaldo'] as bool? ?? true,
          ),
          desdeCache: s.metadata.isFromCache,
          pendiente: s.metadata.hasPendingWrites,
          actualizado:
              (m['actualizado'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
  @override
  Future<void> guardarPerfil(String uid, Perfil perfil) => datos
      .doc('usuarios/$uid')
      .set({
        'nombre': perfil.nombre,
        'segmento': perfil.segmento,
        'mostrarSaldo': perfil.mostrarSaldo,
        'actualizado': FieldValue.serverTimestamp(),
      })
      .timeout(const Duration(seconds: 10));
}
