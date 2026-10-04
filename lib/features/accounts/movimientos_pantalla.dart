import '../../core/diseno_bro.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';

class MovimientosPantalla extends ConsumerStatefulWidget {
  const MovimientosPantalla(this.cuenta, {super.key});
  final String cuenta;
  @override
  ConsumerState<MovimientosPantalla> createState() => _MovimientosEstado();
}

class _MovimientosEstado extends ConsumerState<MovimientosPantalla> {
  String _filtro = 'Todos';
  @override
  Widget build(BuildContext context) {
    final provider = movimientosProvider(widget.cuenta);
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tu actividad, en detalle',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: ['Todos', 'Ingresos', 'Gastos']
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: _filtro == f,
                    onSelected: (_) => setState(() => _filtro = f),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          ref
              .watch(provider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => PanelError(e, () => ref.invalidate(provider)),
                data: (datos) {
                  final movimientos = datos.valor
                      .where(
                        (m) =>
                            _filtro == 'Todos' ||
                            (_filtro == 'Ingresos'
                                ? m.centavos >= 0
                                : m.centavos < 0),
                      )
                      .toList();
                  return Column(
                    children: [
                      if (datos.desdeCache) AvisoCache(datos.actualizado),
                      if (movimientos.isEmpty)
                        const PanelEstado(
                          titulo: 'Sin movimientos',
                          mensaje: 'No hay movimientos para este filtro.',
                        ),
                      for (final m in movimientos)
                        TarjetaCristalBro(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.descripcion,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${m.centavos >= 0 ? "+" : ""}${dinero(m.centavos)}',
                                ),
                                Text(
                                  '${DateFormat("dd/MM/yyyy").format(m.fecha)} · ${m.categoria}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Se muestran los 50 movimientos más recientes.',
                      ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }
}
