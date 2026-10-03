import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import 'componentes_banca.dart';

class HistorialPantalla extends ConsumerStatefulWidget {
  const HistorialPantalla({super.key, this.cuenta, this.tipo, this.destino});
  final String? cuenta, tipo, destino;
  @override
  ConsumerState<HistorialPantalla> createState() => _HistorialEstado();
}

class _HistorialEstado extends EstadoBanco<HistorialPantalla> {
  final items = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  bool mas = true;
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
    final s = await q.get();
    if (mounted) {
      setState(() {
        if (inicial) items.clear();
        items.addAll(s.docs);
        mas = s.docs.length == 30;
      });
    }
  });
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
