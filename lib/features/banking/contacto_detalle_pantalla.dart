import 'dart:async';

import 'historial.dart';
import '../../app/proveedores_historial.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'componentes_banca.dart';
import '../../core/fila_importe.dart';

class ContactoDetallePantalla extends ConsumerStatefulWidget {
  const ContactoDetallePantalla(this.id, {super.key});
  final String id;
  @override
  ConsumerState<ContactoDetallePantalla> createState() =>
      _ContactoDetalleEstado();
}

class _ContactoDetalleEstado extends EstadoBanco<ContactoDetallePantalla> {
  ContactoBro? contacto;
  final movimientos = <String, MovimientoBanco>{};
  final ultimos = <int, CursorHistorial>{};
  final quedan = <int, bool>{};
  final paginadas = <int>{};
  final caches = <int, bool>{};
  final suscripciones = <StreamSubscription<PaginaHistorial>>[];
  bool cache = false;
  String get uid => ref.read(identidadProvider).actual!.uid;
  List<ConsultaHistorial> consultas() => contacto!.interno
      ? [
          for (final campo in ['numeroDestino', 'numeroOrigen'])
            ConsultaHistorial(
              uid,
              ambito: AmbitoHistorial.contraparte,
              destino: contacto!.numero,
              campo: campo,
            ),
        ]
      : [
          ConsultaHistorial(
            uid,
            ambito: AmbitoHistorial.contacto,
            destino: widget.id,
          ),
        ];

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
    final guardado = await ref
        .read(contactosRepositorioProvider)
        .leer(uid, widget.id);
    if (!mounted) return;
    contacto = guardado.contacto;
    cache = guardado.desdeCache;
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
    final primeras = <Future<void>>[];
    for (var i = 0; i < qs.length; i++) {
      final primera = Completer<void>();
      primeras.add(primera.future);
      final indice = i;
      suscripciones.add(
        ref
            .read(historialRepositorioProvider)
            .observar(qs[i])
            .listen(
              (s) {
                if (!mounted) return;
                setState(() {
                  error = null;
                  caches[indice] = s.desdeCache;
                  cache = caches.values.any((v) => v);
                  for (final d in s.movimientos) {
                    movimientos[d.id] = d;
                  }
                  if (!paginadas.contains(indice)) {
                    if (s.cursor != null) ultimos[indice] = s.cursor!;
                    quedan[indice] = s.mas;
                  }
                });
                if (!primera.isCompleted &&
                    (!s.desdeCache || s.movimientos.isNotEmpty)) {
                  primera.complete();
                }
              },
              onError: (Object e) {
                if (!primera.isCompleted) {
                  primera.completeError(e);
                } else if (mounted) {
                  setState(() => error = mensajeError(e));
                }
              },
            ),
      );
    }
    await Future.wait(primeras).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw const FalloApp(
          'La consulta está tardando. Conservamos tu actividad; vuelve a intentar.',
          transitorio: true,
        );
      },
    );
  });
  Future<void> anteriores() => trabajar(() async {
    final qs = consultas();
    for (var i = 0; i < qs.length; i++) {
      if (quedan[i] != true || ultimos[i] == null) continue;
      final s = await ref
          .read(historialRepositorioProvider)
          .pagina(qs[i], despues: ultimos[i]);
      if (!mounted) return;
      setState(() {
        cache = s.desdeCache;
        for (final d in s.movimientos) {
          movimientos[d.id] = d;
        }
        if (s.cursor != null) ultimos[i] = s.cursor!;
        paginadas.add(i);
        quedan[i] = s.mas;
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    final c = contacto;
    final lista = movimientos.values.toList()..sort(MovimientoBanco.ordenar);
    return pagina(c?.nombre ?? 'Tu contacto', [
      if (c != null) ...[
        CristalBro(
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person_outline)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(c.nombre), Text('${c.banco} · ${c.numero}')],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: ocupado
              ? null
              : () => context.push(
                  c.interno
                      ? '/transferir?numero=${c.numero}'
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
        if (lista.isEmpty && !ocupado && error == null)
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
              final d = doc, centavos = d.centavos, recibido = centavos > 0;
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
                      agrupar: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilaImporteBro(
                            titulo: Row(
                              children: [
                                Icon(
                                  recibido
                                      ? Icons.call_received_rounded
                                      : Icons.north_east_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    recibido ? 'Recibiste' : 'Enviaste',
                                  ),
                                ),
                              ],
                            ),
                            importe: Text(
                              dinero(centavos.abs()),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(d.nota ?? d.descripcion),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat(
                              'dd MMM yyyy · HH:mm',
                              'es',
                            ).format(d.fecha),
                            style: const TextStyle(fontSize: 11),
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              'Detalles',
                              style: TextStyle(fontSize: 11),
                            ),
                            children: [ReferenciaBro(d.referencia)],
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
    ], agruparCristal: true);
  }
}
