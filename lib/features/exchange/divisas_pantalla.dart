import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import 'divisas.dart';

class DivisasPantalla extends ConsumerStatefulWidget {
  const DivisasPantalla({super.key});
  @override
  ConsumerState<DivisasPantalla> createState() => _DivisasEstado();
}

class _DivisasEstado extends ConsumerState<DivisasPantalla> {
  final monto = TextEditingController(text: '100');
  String moneda = 'EUR';
  @override
  void dispose() {
    monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = cotizacionProvider(moneda);
    final centavos = leerCentavos(monto.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Divisas')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Imagina tu próximo destino',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Calcula cuánto representa tu presupuesto con una tasa de referencia.',
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('monto-divisas'),
            controller: monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto en USD',
              errorText: centavos == null
                  ? 'Usa un monto válido, con hasta dos decimales.'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: moneda,
            decoration: const InputDecoration(labelText: 'Convertir a'),
            items: const [
              DropdownMenuItem(value: 'EUR', child: Text('EUR · Euro')),
              DropdownMenuItem(
                value: 'GBP',
                child: Text('GBP · Libra esterlina'),
              ),
              DropdownMenuItem(
                value: 'COP',
                child: Text('COP · Peso colombiano'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => moneda = v);
            },
          ),
          const SizedBox(height: 24),
          ref
              .watch(provider)
              .when(
                skipLoadingOnRefresh: false,
                loading: () => const PanelEstado(
                  titulo: 'Consultando la tasa',
                  mensaje: 'Estamos conectando con el servicio de divisas.',
                  icono: Icons.hourglass_top,
                ),
                error: (e, _) => PanelError(e, () => ref.invalidate(provider)),
                data: (tasa) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          centavos == null
                              ? 'Revisa el monto'
                              : NumberFormat.currency(
                                  locale: 'es_EC',
                                  symbol: '$moneda ',
                                  decimalDigits: 2,
                                ).format(
                                  tasa.convertirCentavos(centavos) / 100,
                                ),
                          key: const Key('resultado-divisas'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text('1 USD = ${tasa.tasa} $moneda'),
                        Text(
                          'Tasa de referencia del ${DateFormat("dd/MM/yyyy").format(tasa.fecha)}',
                        ),
                        const Text(
                          'Fuente: Frankfurter. Esta consulta no realiza compras ni cambios de moneda.',
                        ),
                        if (tasa.desdeCache)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(tasa.aviso!),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Actualizar tasa'),
          ),
        ],
      ),
    );
  }
}
