import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'componentes_banca.dart';

class ContactoDetallePantalla extends ConsumerStatefulWidget {
  const ContactoDetallePantalla(this.id, {super.key});
  final String id;
  @override
  ConsumerState<ContactoDetallePantalla> createState() =>
      _ContactoDetalleEstado();
}

class _ContactoDetalleEstado extends EstadoBanco<ContactoDetallePantalla> {
  Map<String, dynamic>? contacto;
  final movimientos = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  final ultimos = <int, DocumentSnapshot<Map<String, dynamic>>>{};
  final quedan = <int, bool>{};
  final paginadas = <int>{};
  final caches = <int, bool>{};
  final suscripciones =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  bool cache = false;
  String get uid => ref.read(identidadProvider).actual!.uid;
  List<Query<Map<String, dynamic>>> consultas() {
    final db = ref.read(datosProvider);
    final c = contacto!;
    if (c['tipo'] != 'interno') {
      return [
        db
            .collection('usuarios/$uid/contactos/${widget.id}/movimientos')
            .orderBy('fecha', descending: true)
            .orderBy(FieldPath.documentId, descending: true),
      ];
    }
    return ['numeroDestino', 'numeroOrigen']
        .map(
          (campo) => db
              .collection('usuarios/$uid/movimientosGlobales')
              .where(campo, isEqualTo: c['numero'])
              .orderBy('fecha', descending: true)
              .orderBy(FieldPath.documentId, descending: true),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => cargar());
  }

  @override
  void dispose() {
    for (final s in suscripciones) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> cargar() => trabajar(() async {
    final documento = ref
        .read(datosProvider)
        .doc('usuarios/$uid/contactos/${widget.id}');
    DocumentSnapshot<Map<String, dynamic>> d;
    try {
      d = await documento
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      d = await documento.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      d = await documento.get(const GetOptions(source: Source.cache));
    }
    if (!d.exists) {
      throw const FalloApp(
        'No encontramos ese contacto. Vuelve a tus contactos para revisarlo.',
      );
    }
    contacto = d.data();
    for (final s in suscripciones) {
      await s.cancel();
    }
    suscripciones.clear();
    movimientos.clear();
    ultimos.clear();
    quedan.clear();
    paginadas.clear();
    caches.clear();
    final qs = consultas();
    for (var i = 0; i < qs.length; i++) {
      final indice = i;
      suscripciones.add(
        qs[i]
            .limit(30)
            .snapshots(includeMetadataChanges: true)
            .listen(
              (s) {
                if (!mounted) return;
                setState(() {
                  caches[indice] = s.metadata.isFromCache;
                  cache = caches.values.any((v) => v);
                  for (final d in s.docs) {
                    movimientos[d.id] = d;
                  }
                  if (!paginadas.contains(indice)) {
                    if (s.docs.isNotEmpty) {
                      ultimos[indice] = s.docs.last;
                    }
                    quedan[indice] = s.docs.length == 30;
                  }
                });
              },
              onError: (Object e) {
                if (mounted) setState(() => error = mensajeError(e));
              },
            ),
      );
    }
  });
  Future<void> anteriores() => trabajar(() async {
    final qs = consultas();
    for (var i = 0; i < qs.length; i++) {
      if (quedan[i] != true || ultimos[i] == null) continue;
      final q = qs[i].startAfterDocument(ultimos[i]!).limit(30);
      QuerySnapshot<Map<String, dynamic>> s;
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
      if (!mounted) return;
      setState(() {
        cache = s.metadata.isFromCache;
        for (final d in s.docs) {
          movimientos[d.id] = d;
        }
        if (s.docs.isNotEmpty) ultimos[i] = s.docs.last;
        quedan[i] = s.docs.length == 30;
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    final c = contacto;
    final lista = movimientos.values.toList()
      ..sort((a, b) {
        final n = (b.data()['fecha'] as Timestamp).compareTo(
          a.data()['fecha'] as Timestamp,
        );
        return n == 0 ? b.id.compareTo(a.id) : n;
      });
    return pagina(c?['nombre'] as String? ?? 'Tu contacto', [
      if (c != null) ...[
        CristalBro(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(c['nombre'] as String),
            subtitle: Text('${c['banco']} · ${c['numero']}'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: ocupado
              ? null
              : () => context.push(
                  c['tipo'] == 'interno'
                      ? '/transferir?numero=${c['numero']}'
                      : '/pagar-externo?tipo=contacto&id=${widget.id}',
                ),
          icon: const Icon(Icons.send_rounded),
          label: const Text('Enviar dinero'),
        ),
        EncabezadoBro(
          'Nuestra actividad',
          subtitulo: 'Cada envío y recibo queda aquí.',
          accion: IconButton(
            tooltip: 'Actualizar actividad',
            onPressed: ocupado ? null : cargar,
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (cache)
          const CristalBro(
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Actividad guardada. Se actualizará al recuperar la conexión.',
                  ),
                ),
              ],
            ),
          ),
        if (lista.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Todavía no hay operaciones con esta persona.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final doc in lista)
          Builder(
            builder: (context) {
              final d = doc.data(),
                  centavos = (d['centavos'] as num).toInt(),
                  recibido = centavos > 0;
              return Align(
                alignment: recibido
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: .9,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CristalBro(
                      color: recibido
                          ? const Color(0xFFE5F1EA)
                          : const Color(0xFFFFE8D8),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                recibido
                                    ? Icons.call_received_rounded
                                    : Icons.north_east_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(recibido ? 'Recibiste' : 'Enviaste'),
                              const Spacer(),
                              Text(
                                dinero(centavos.abs()),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            d['nota'] as String? ?? d['descripcion'] as String,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat(
                              'dd MMM yyyy · HH:mm',
                              'es',
                            ).format((d['fecha'] as Timestamp).toDate()),
                            style: const TextStyle(fontSize: 11),
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              'Detalles',
                              style: TextStyle(fontSize: 11),
                            ),
                            children: [
                              SelectableText(
                                'Referencia: ${d['referencia'] ?? doc.id}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        if (quedan.values.any((v) => v))
          OutlinedButton.icon(
            onPressed: ocupado ? null : anteriores,
            icon: const Icon(Icons.history),
            label: const Text('Ver actividad anterior'),
          ),
      ],
    ]);
  }
}
