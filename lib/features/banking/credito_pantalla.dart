import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/componentes.dart';
import 'banca.dart';
import 'componentes_banca.dart';
import 'tarjetas_pantalla.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditoDetallePantalla extends ConsumerStatefulWidget {
  const CreditoDetallePantalla({super.key, this.pagoInicial = false});
  final bool pagoInicial;
  @override
  ConsumerState<CreditoDetallePantalla> createState() =>
      _CreditoDetalleEstado();
}

class _CreditoDetalleEstado extends EstadoBanco<CreditoDetallePantalla> {
  int dia = 15;
  bool acepta = false, mostrarPago = false;
  String? cuenta;
  String referencia = nuevaReferencia();
  final importe = TextEditingController();
  Map<String, dynamic>? recibo;
  @override
  void initState() {
    super.initState();
    mostrarPago = widget.pagoInicial;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => trabajar(() async {
        final datos = await llamar('consultarTarjetaCredito');
        if (widget.pagoInicial && importe.text.isEmpty) {
          importe.text =
              ((datos['totalPagarCentavos'] as num) > 0
                      ? (datos['totalPagarCentavos'] as num) / 100
                      : (datos['deudaCentavos'] as num) / 100)
                  .toStringAsFixed(2);
        }
      }),
    );
  }

  @override
  void dispose() {
    importe.dispose();
    super.dispose();
  }

  Future<void> pagar() => trabajar(() async {
    final centavos = montoCentavos(importe.text, minimo: 1, maximo: 5000000);
    final confirma = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Revisar pago de tarjeta'),
        content: Text(
          'Abonarás ${dinero(centavos)} desde tu cuenta. Tu pago quedará en ambos históricos y recuperará cupo disponible.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar pago'),
          ),
        ],
      ),
    );
    if (confirma != true) {
      return;
    }
    final r = await llamar('pagarTarjetaCredito', {
      'cuenta': cuenta,
      'centavos': centavos,
      'referencia': referencia,
    });
    if (mounted) {
      setState(() {
        recibo = r;
        mostrarPago = false;
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    final tarjeta = ref
        .watch(tarjetasBroProvider)
        .value
        ?.where((t) => t['id'] == 'bro_credito')
        .firstOrNull;
    if (tarjeta == null) {
      return pagina('Tu tarjeta de crédito', [
        const CristalBro(child: Text('Estamos buscando tu tarjeta.')),
        OutlinedButton(
          onPressed: () => context.push('/tarjetas/credito'),
          child: const Text('Ver mi solicitud'),
        ),
      ]);
    }
    final activa = tarjeta['estado'] == 'activa',
        deuda = (tarjeta['deudaCentavos'] as num).toInt(),
        total = (tarjeta['totalPagarCentavos'] as num).toInt(),
        minimo = (tarjeta['minimoPagarCentavos'] as num).toInt(),
        cupo = (tarjeta['cupoCentavos'] as num).toInt();
    return pagina('Tu tarjeta de crédito', [
      EncabezadoBro(
        activa
            ? 'Más espacio para tus planes'
            : 'Aprobada. El siguiente paso es tuyo.',
        subtitulo: activa
            ? 'Tus consumos y pagos, siempre a la vista.'
            : 'Elige cuándo quieres cerrar tu estado de cuenta cada mes.',
      ),
      TarjetaVisualBro(
        tarjeta,
        titular: ref.watch(sesionProvider).value?.nombre ?? 'FinanceBro',
      ),
      if (activa)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: FilledButton.icon(
            onPressed: deuda == 0 || ocupado
                ? null
                : () => setState(() {
                    mostrarPago = true;
                    recibo = null;
                    referencia = nuevaReferencia();
                    importe.text = (total > 0 ? total / 100 : deuda / 100)
                        .toStringAsFixed(2);
                  }),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pagar mi tarjeta'),
          ),
        ),
      const SizedBox(height: 20),
      CristalBro(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cupo disponible', style: TextStyle(fontSize: 12)),
            Text(
              dinero(cupo - deuda),
              key: const Key('cupo-disponible'),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
            ),
            Text('De ${dinero(cupo)} aprobados'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: deuda / cupo,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (!activa)
        CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tu corte mensual',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Text(
                'Ese día cerramos tus consumos. Tendrás 15 días para pagar el estado de cuenta.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('dia-corte'),
                initialValue: dia,
                decoration: const InputDecoration(labelText: 'Día de corte'),
                items: List.generate(
                  28,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Día ${i + 1} de cada mes'),
                  ),
                ),
                onChanged: ocupado ? null : (v) => setState(() => dia = v!),
              ),
              const SizedBox(height: 12),
              const Text(
                'El mínimo será el 5 % del saldo al corte, desde USD 10 y sin superar lo que debes. Intereses: USD 0,00. Puedes pagar el total o anticipar abonos.',
              ),
              CheckboxListTile(
                key: const Key('condiciones-corte'),
                contentPadding: EdgeInsets.zero,
                value: acepta,
                onChanged: ocupado ? null : (v) => setState(() => acepta = v!),
                title: const Text(
                  'Acepto el corte y estas condiciones de pago.',
                ),
              ),
              FilledButton(
                onPressed: ocupado || !acepta
                    ? null
                    : () => trabajar(() async {
                        await llamar('elegirCorteTarjeta', {
                          'dia': dia,
                          'aceptaCondiciones': true,
                        });
                      }),
                child: const Text('Activar mi tarjeta'),
              ),
            ],
          ),
        ),
      if (activa) ...[
        CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tu estado de cuenta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              _importe('Total a pagar', total, const Key('total-tarjeta')),
              _importe(
                'Pago mínimo pendiente',
                minimo,
                const Key('minimo-tarjeta'),
              ),
              if (tarjeta['pagoHasta'] != null)
                Text('Fecha límite de pago: ${tarjeta['pagoHasta']}'),
              if (tarjeta['ultimoCorte'] == null)
                const Text(
                  'Tu primer estado de cuenta estará listo al llegar el corte. Puedes abonar antes.',
                ),
              const Divider(height: 28),
              _importe(
                'Consumos después del último corte',
                deuda - total,
                null,
              ),
              _importe('Saldo pendiente de la tarjeta', deuda, null),
              Text(
                'Próximo corte: ${tarjeta['proximoCorte']} · día ${tarjeta['diaCorte']}',
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (mostrarPago)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CristalBro(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElegirCuentaBro(
                    valor: cuenta,
                    cambiar: ocupado ? null : (v) => setState(() => cuenta = v),
                  ),
                  campo(
                    importe,
                    'Importe del pago · USD',
                    key: const Key('importe-pago-credito'),
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (minimo > 0)
                        OutlinedButton(
                          onPressed: () => setState(
                            () => importe.text = (minimo / 100).toStringAsFixed(
                              2,
                            ),
                          ),
                          child: const Text('Pagar mínimo'),
                        ),
                      if (total > 0)
                        OutlinedButton(
                          onPressed: () => setState(
                            () =>
                                importe.text = (total / 100).toStringAsFixed(2),
                          ),
                          child: const Text('Pagar total'),
                        ),
                    ],
                  ),
                  FilledButton(
                    onPressed: ocupado || cuenta == null ? null : pagar,
                    child: const Text('Revisar abono'),
                  ),
                ],
              ),
            ),
          ),
        if (recibo != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ReciboBro(recibo!),
          ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => context.push('/historial?tipo=tarjeta&id=bro_credito'),
        icon: const Icon(Icons.history_rounded),
        label: const Text('Compras y pagos de esta tarjeta'),
      ),
      OutlinedButton(
        onPressed: () => context.push('/tarjetas/fisica/bro_credito'),
        child: const Text('Solicitar tarjeta física'),
      ),
      OutlinedButton(
        onPressed: () => context.push('/tarjetas'),
        child: const Text('Personalizar mi diseño'),
      ),
    ]);
  }

  Widget _importe(String etiqueta, int valor, Key? key) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(etiqueta, style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 12),
        Text(
          dinero(valor),
          key: key,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
