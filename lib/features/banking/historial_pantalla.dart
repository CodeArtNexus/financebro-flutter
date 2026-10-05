import 'package:go_router/go_router.dart';

import 'dart:async';

import 'historial.dart';
import '../../app/proveedores_historial.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'componentes_banca.dart';
import '../../core/fila_importe.dart';
import '../../app/tema.dart';

class HistorialPantalla extends ConsumerStatefulWidget {
  const HistorialPantalla({super.key, this.cuenta, this.tipo, this.destino});
  final String? cuenta, tipo, destino;
  @override
  ConsumerState<HistorialPantalla> createState() => _HistorialEstado();
}

class _HistorialEstado extends EstadoBanco<HistorialPantalla> {
  final items = <MovimientoBanco>[];
  CursorHistorial? cursor;
  bool paginada = false;
  bool mas = true, cache = false;
  StreamSubscription<PaginaHistorial>? suscripcion;
  String filtro = 'Todos';
  ConsultaHistorial consulta() => ConsultaHistorial(
    ref.read(identidadProvider).actual!.uid,
    ambito: widget.cuenta != null
        ? AmbitoHistorial.cuenta
        : widget.tipo == 'tarjeta'
        ? AmbitoHistorial.tarjeta
        : widget.tipo == 'contacto'
        ? AmbitoHistorial.contacto
        : AmbitoHistorial.global,
    destino: widget.cuenta ?? widget.destino,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => cargar(inicial: true));
  }

  Future<void> cargar({bool inicial = false}) => trabajar(() async {
    final repositorio = ref.read(historialRepositorioProvider);
    if (inicial) {
      await suscripcion?.cancel();
      items.clear();
      cursor = null;
      paginada = false;
      final primera = Completer<void>();
      suscripcion = repositorio
          .observar(consulta())
          .listen(
            (n) {
              if (!mounted) return;
              setState(() {
                error = null;
                cache = n.desdeCache;
                final documentos = {
                  for (final d in items) d.id: d,
                  for (final d in n.movimientos) d.id: d,
                };
                items
                  ..clear()
                  ..addAll(documentos.values)
                  ..sort(MovimientoBanco.ordenar);
                if (!paginada) {
                  cursor = n.cursor;
                  mas = n.mas;
                }
              });
              if (!primera.isCompleted &&
                  (!n.desdeCache || n.movimientos.isNotEmpty)) {
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
          );
      await primera.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw const FalloApp(
            'La consulta está tardando. Conservamos tu histórico; vuelve a intentar.',
            transitorio: true,
          );
        },
      );
      return;
    }
    final n = await repositorio.pagina(consulta(), despues: cursor);
    if (!mounted) return;
    setState(() {
      cache = n.desdeCache;
      final existentes = items.map((d) => d.id).toSet();
      items.addAll(n.movimientos.where((d) => !existentes.contains(d.id)));
      items.sort(MovimientoBanco.ordenar);
      cursor = n.cursor ?? cursor;
      mas = n.mas;
      paginada = true;
    });
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
        : MediaQuery.textScalerOf(context).scale(12) > 16
        ? 'Movimientos'
        : 'Todos tus movimientos',
    [
      if (widget.cuenta == 'corriente')
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FilledButton.icon(
            onPressed: () => context.push('/chequera'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Abrir mi chequera digital'),
          ),
        ),
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
      if (items.isEmpty && !ocupado && error == null)
        const CristalBro(child: Text('Todavía no hay movimientos.')),
      for (final doc in items.where(
        (d) =>
            filtro == 'Todos' ||
            (filtro == 'Ingresos' ? d.centavos > 0 : d.centavos < 0),
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CristalBro(
            padding: const EdgeInsets.all(16),
            agrupar: true,
            child: Builder(
              builder: (context) {
                final d = doc, centavos = d.centavos, fecha = d.fecha;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilaImporteBro(
                      titulo: Text(
                        d.descripcion,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      importe: Text(
                        '${centavos > 0 ? '+' : ''}${dinero(centavos)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: centavos > 0
                              ? ingresoBro(context)
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat('dd MMM yyyy · HH:mm', 'es').format(fecha)} · ${d.categoria}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    if (widget.cuenta == null && widget.tipo == null)
                      Text(
                        'Cuenta: ${d.cuenta}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    if (d.automatico)
                      const Text(
                        'Pago mensual autorizado',
                        style: TextStyle(fontSize: 10),
                      ),
                    ReferenciaBro(d.referencia),
                  ],
                );
              },
            ),
          ),
        ),
      if (mas)
        TextButton.icon(
          onPressed: ocupado ? null : () => cargar(),
          icon: const Icon(Icons.history_rounded, size: 19),

          label: const Text('Cargar movimientos anteriores'),
        )
      else if (items.isNotEmpty)
        const Text(
          'Llegaste al inicio de tu histórico.',
          style: TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
        ),
    ],
    agruparCristal: true,
  );
}
