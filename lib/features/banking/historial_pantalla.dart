import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'componentes_banca.dart';

class HistorialPantalla extends ConsumerStatefulWidget {
  const HistorialPantalla({super.key, this.cuenta, this.tipo, this.destino});
  final String? cuenta, tipo, destino;
  @override
  ConsumerState<HistorialPantalla> createState() => _HistorialEstado();
}

class _HistorialEstado extends EstadoBanco<HistorialPantalla> {
  final items = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  bool mas = true, cache = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? suscripcion;
  String filtro = 'Todos';
  Query<Map<String, dynamic>> consulta() {
    final uid = ref.read(identidadProvider).actual!.uid;
    final ruta = widget.cuenta != null
        ? 'usuarios/$uid/cuentas/${widget.cuenta}/movimientos'
        : widget.tipo == 'tarjeta'
        ? 'usuarios/$uid/tarjetas/${widget.destino}/movimientos'
        : widget.tipo == 'contacto'
        ? 'usuarios/$uid/contactos/${widget.destino}/movimientos'
        : 'usuarios/$uid/movimientosGlobales';
    return ref
        .read(datosProvider)
        .collection(ruta)
        .orderBy('fecha', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => cargar(inicial: true));
  }

  Future<void> cargar({bool inicial = false}) => trabajar(() async {
    var q = consulta().limit(30);
    if (!inicial && items.isNotEmpty) q = q.startAfterDocument(items.last);
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
    if (mounted) {
      setState(() {
        cache = s.metadata.isFromCache;
        if (inicial) items.clear();
        final existentes = items.map((d) => d.id).toSet();
        items.addAll(s.docs.where((d) => !existentes.contains(d.id)));
        mas = s.docs.length == 30;
      });
      if (inicial) {
        await suscripcion?.cancel();
        suscripcion = consulta()
            .limit(30)
            .snapshots(includeMetadataChanges: true)
            .listen(
              (n) {
                if (!mounted) return;
                setState(() {
                  cache = n.metadata.isFromCache;
                  final documentos = {
                    for (final d in items) d.id: d,
                    for (final d in n.docs) d.id: d,
                  };
                  items
                    ..clear()
                    ..addAll(documentos.values);
                  items.sort((a, b) {
                    final c = (b.data()['fecha'] as Timestamp).compareTo(
                      a.data()['fecha'] as Timestamp,
                    );
                    return c == 0 ? b.id.compareTo(a.id) : c;
                  });
                });
              },
              onError: (Object e) {
                if (mounted) setState(() => error = mensajeError(e));
              },
            );
      }
    }
  });
  @override
  void dispose() {
    suscripcion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => pagina(
    widget.cuenta != null
        ? 'Movimientos de tu cuenta'
        : widget.tipo != null
        ? 'Movimientos asociados'
        : 'Todos tus movimientos',
    [
      EncabezadoBro(
        'Tu actividad, en detalle',
        subtitulo: 'Histórico conservado por operación.',
        accion: IconButton(
          tooltip: 'Actualizar movimientos',
          onPressed: ocupado ? null : () => cargar(inicial: true),
          icon: const Icon(Icons.refresh),
        ),
      ),
      Wrap(
        spacing: 8,
        children: ['Todos', 'Ingresos', 'Gastos']
            .map(
              (v) => ChoiceChip(
                label: Text(v),
                selected: filtro == v,
                onSelected: (_) => setState(() => filtro = v),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      if (cache)
        const CristalBro(
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mostramos los movimientos guardados. Conéctate para actualizarlos.',
                ),
              ),
            ],
          ),
        ),
      if (items.isEmpty && !ocupado)
        const CristalBro(child: Text('Todavía no hay movimientos.')),
      for (final doc in items.where(
        (d) =>
            filtro == 'Todos' ||
            (filtro == 'Ingresos'
                ? (d.data()['centavos'] as num) > 0
                : (d.data()['centavos'] as num) < 0),
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CristalBro(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) {
                final d = doc.data(),
                    centavos = (d['centavos'] as num).toInt(),
                    fecha = d['fecha'] as Timestamp?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            d['descripcion'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${centavos > 0 ? '+' : ''}${dinero(centavos)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: centavos > 0
                                ? const Color(0xFF356B53)
                                : const Color(0xFF8B4624),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${fecha == null ? 'Pendiente' : DateFormat('dd MMM yyyy · HH:mm', 'es').format(fecha.toDate())} · ${d['categoria']}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    if (widget.cuenta == null && widget.tipo == null)
                      Text(
                        'Cuenta: ${d['cuenta']}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    if (d['automatico'] == true)
                      const Text(
                        'Pago mensual autorizado',
                        style: TextStyle(fontSize: 10),
                      ),
                    SelectableText(
                      'Referencia: ${d['referencia'] ?? doc.id}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      if (mas)
        TextButton(
          onPressed: ocupado ? null : () => cargar(),
          child: const Text('Cargar movimientos anteriores'),
        )
      else if (items.isNotEmpty)
        const Text(
          'Llegaste al inicio de tu histórico.',
          style: TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
        ),
    ],
  );
}
