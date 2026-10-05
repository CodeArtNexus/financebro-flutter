import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errores.dart';
import 'historial.dart';

class FirebaseHistorial implements RepositorioHistorial {
  FirebaseHistorial(this.db);
  final FirebaseFirestore db;
  Query<Map<String, dynamic>> consulta(ConsultaHistorial c) {
    final raiz = 'usuarios/${c.uid}';
    final ruta = switch (c.ambito) {
      AmbitoHistorial.global ||
      AmbitoHistorial.contraparte => '$raiz/movimientosGlobales',
      AmbitoHistorial.cuenta => '$raiz/cuentas/${c.destino}/movimientos',
      AmbitoHistorial.tarjeta => '$raiz/tarjetas/${c.destino}/movimientos',
      AmbitoHistorial.contacto => '$raiz/contactos/${c.destino}/movimientos',
    };
    Query<Map<String, dynamic>> q = db.collection(ruta);
    if (c.ambito == AmbitoHistorial.contraparte) {
      if (!['numeroDestino', 'numeroOrigen'].contains(c.campo)) {
        throw const FalloApp('Consulta de contacto inválida.');
      }
      q = q.where(c.campo, isEqualTo: c.destino);
    }
    return q
        .orderBy('fecha', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
  }

  MovimientoBanco convertir(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data(), fecha = d['fecha'], importe = d['centavos'];
    if (fecha is! Timestamp || importe is! int || d['descripcion'] is! String) {
      throw const FalloApp(
        'No pudimos validar un movimiento. Actualiza tu histórico.',
      );
    }
    return MovimientoBanco(
      id: doc.id,
      descripcion: d['descripcion'],
      centavos: importe,
      fecha: fecha.toDate(),
      categoria: d['categoria'] as String? ?? 'Movimiento',
      referencia: d['referencia'] as String? ?? doc.id,
      cuenta: d['cuenta'] as String? ?? '',
      nota: d['nota'] as String?,
      automatico: d['automatico'] == true,
    );
  }

  PaginaHistorial convertirPagina(
    ConsultaHistorial c,
    QuerySnapshot<Map<String, dynamic>> s,
  ) {
    final movimientos = s.docs.map(convertir).toList();
    return PaginaHistorial(
      movimientos,
      desdeCache: s.metadata.isFromCache,
      mas: movimientos.length == 30,
      cursor: movimientos.isEmpty
          ? null
          : CursorHistorial(
              c.clave,
              movimientos.last.fecha,
              movimientos.last.id,
              segundos: (s.docs.last.data()['fecha'] as Timestamp).seconds,
              nanosegundos:
                  (s.docs.last.data()['fecha'] as Timestamp).nanoseconds,
            ),
    );
  }

  @override
  Future<PaginaHistorial> pagina(
    ConsultaHistorial c, {
    CursorHistorial? despues,
  }) async {
    if (despues != null && despues.consulta != c.clave) {
      throw const FalloApp('Actualiza el histórico antes de continuar.');
    }
    var q = consulta(c).limit(30);
    if (despues != null) {
      q = q.startAfter([
        despues.segundos == null
            ? Timestamp.fromDate(despues.fecha)
            : Timestamp(despues.segundos!, despues.nanosegundos!),
        despues.id,
      ]);
    }
    QuerySnapshot<Map<String, dynamic>> s;
    final reloj = Stopwatch()..start();
    try {
      s = await q
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      s = await q.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      s = await q.get(const GetOptions(source: Source.cache));
    }
    registrarEvento(
      s.metadata.isFromCache ? 'pagina_cache' : 'pagina_servidor',
      servicio: 'historial',
      duracionMs: reloj.elapsedMilliseconds,
    );
    return convertirPagina(c, s);
  }

  @override
  Stream<PaginaHistorial> observar(ConsultaHistorial c) =>
      consulta(c)
          .limit(30)
          .snapshots(includeMetadataChanges: true)
          .map((s) => convertirPagina(c, s));
}

class FirebaseContactos implements RepositorioContactos {
  FirebaseContactos(this.db);
  final FirebaseFirestore db;
  @override
  Future<ContactoGuardado> leer(String uid, String id) async {
    final ref = db.doc('usuarios/$uid/contactos/$id');
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      doc = await ref.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      doc = await ref.get(const GetOptions(source: Source.cache));
    }
    final d = doc.data();
    if (d == null) {
      throw const FalloApp(
        'No encontramos ese contacto. Vuelve a tus contactos para revisarlo.',
      );
    }
    return ContactoGuardado(
      ContactoBro(
        id: id,
        nombre: d['nombre'] as String,
        banco: d['banco'] as String,
        numero: d['numero'] as String,
        interno: d['tipo'] == 'interno',
      ),
      doc.metadata.isFromCache,
    );
  }
}
