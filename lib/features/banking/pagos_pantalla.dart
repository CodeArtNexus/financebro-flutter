import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import '../../core/componentes.dart';
import 'banca.dart';
import 'componentes_banca.dart';

IconData iconoServicio(String? icono) => switch (icono) {
  'luz' => Icons.bolt_rounded,
  'agua' => Icons.water_drop_outlined,
  'telefono' => Icons.phone_outlined,
  _ => Icons.wifi_rounded,
};

class PagosPantalla extends ConsumerStatefulWidget {
  const PagosPantalla({super.key});
  @override
  ConsumerState<PagosPantalla> createState() => _PagosEstado();
}

class _PagosEstado extends EstadoBanco<PagosPantalla> {
  @override
  Widget build(BuildContext context) => pagina('Pagos', [
    const EncabezadoBro(
      'Menos pendientes, más planes',
      subtitulo: 'Consulta tu planilla y paga desde tu cuenta.',
    ),
    ref
        .watch(serviciosBroProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensajeError(e)),
          data: (servicios) => Column(
            children: [
              if (servicios.isEmpty)
                const CristalBro(
                  child: Text('Los servicios disponibles aparecerán aquí.'),
                ),
              for (final s in servicios)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CristalBro(
                    padding: const EdgeInsets.all(14),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFE8D7),
                        child: Icon(iconoServicio(s['icono'] as String?)),
                      ),
                      title: Text(s['nombre'] as String),
                      subtitle: const Text(
                        'Consulta por código de contrato',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/pagos/${s['id']}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
    const EncabezadoBro(
      'Tus pagos mensuales',
      subtitulo: 'Tú decides el día y el límite. Puedes pausarlos.',
    ),
    ref
        .watch(autopagosBroProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensajeError(e)),
          data: (autos) => Column(
            children: [
              if (autos.isEmpty)
                const Text(
                  'Después de pagar puedes activar el pago mensual.',
                  style: TextStyle(fontSize: 12),
                ),
              for (final a in autos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CristalBro(
                    padding: const EdgeInsets.all(14),
                    child: ListTile(
                      title: Text(a['nombre'] as String),
                      subtitle: Text(
                        '${a['contrato']} · ${a['activo'] == true ? 'Próximo: ${a['siguiente']}' : 'Pausado'}\nLímite ${dinero((a['maximoCentavos'] as num).toInt())}${a['ultimoEstado'] == 'requiere_atencion' ? ' · Revisa tus avisos' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: a['activo'] == true
                          ? IconButton(
                              tooltip: 'Pausar pago mensual',
                              onPressed: ocupado
                                  ? null
                                  : () => trabajar(() async {
                                      await llamar('pausarAutopago', {
                                        'id': a['id'],
                                      });
                                    }),
                              icon: const Icon(Icons.pause_circle_outline),
                            )
                          : const Icon(Icons.pause_circle_outline),
                    ),
                  ),
                ),
            ],
          ),
        ),
    const SizedBox(height: 18),
    const Text(
      'Planillas de demostración. El catálogo se actualiza desde el panel de administración.',
      style: TextStyle(fontSize: 11),
    ),
  ]);
}

class ServicioPagoPantalla extends ConsumerStatefulWidget {
  const ServicioPagoPantalla(this.servicio, {super.key});
  final String servicio;
  @override
  ConsumerState<ServicioPagoPantalla> createState() => _ServicioEstado();
}

class _ServicioEstado extends EstadoBanco<ServicioPagoPantalla> {
  final contrato = TextEditingController(),
      limite = TextEditingController(text: '100.00');
  Map<String, dynamic>? factura, recibo;
  String? cuenta;
  String referencia = nuevaReferencia();
  int dia = 5;
  bool acepta = false;
  @override
  void dispose() {
    contrato.dispose();
    limite.dispose();
    super.dispose();
  }

  Future<void> consultar() => trabajar(() async {
    final r = await llamar('consultarFactura', {
      'servicio': widget.servicio,
      'contrato': contrato.text.trim(),
    });
    if (mounted) {
      setState(() {
        factura = r;
        referencia = nuevaReferencia();
      });
    }
  });
  Future<void> pagar() => trabajar(() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar planilla'),
        content: Text(
          '${factura!['nombre']} · ${factura!['contrato']}\n${dinero((factura!['centavos'] as num).toInt())} · ${factura!['periodo']}',
        ),
        actions: [
          TextButton(
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
    if (si != true) return;
    final r = await llamar('pagarServicio', {
      'cuenta': cuenta,
      'factura': factura!['id'],
      'referencia': referencia,
    });
    if (mounted) setState(() => recibo = r);
  });
  @override
  Widget build(BuildContext context) => pagina('Pagar servicio', [
    if (recibo != null) ...[
      ReciboBro(recibo!),
      const EncabezadoBro(
        '¿Lo dejamos para cada mes?',
        subtitulo: 'Autoriza el pago automático con un límite.',
      ),
      CristalBro(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            campo(
              limite,
              'Máximo mensual en USD',
              teclado: const TextInputType.numberWithOptions(decimal: true),
            ),
            DropdownButtonFormField<int>(
              initialValue: dia,
              decoration: const InputDecoration(labelText: 'Día del mes'),
              items: List.generate(
                28,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: ocupado ? null : (v) => setState(() => dia = v!),
            ),
            CheckboxListTile(
              value: acepta,
              onChanged: ocupado
                  ? null
                  : (v) => setState(() => acepta = v ?? false),
              title: const Text(
                'Autorizo consultar y pagar cada mes con esta cuenta, sin superar mi límite.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            FilledButton(
              onPressed: ocupado || !acepta
                  ? null
                  : () => trabajar(() async {
                      await llamar('configurarAutopago', {
                        'referencia': recibo!['referencia'],
                        'maximoCentavos': montoCentavos(
                          limite.text,
                          maximo: 101500,
                        ),
                        'dia': dia,
                        'acepta': true,
                      });
                      if (context.mounted) context.go('/pagos');
                    }),
              child: const Text('Activar pago mensual'),
            ),
            TextButton(
              onPressed: () => context.go('/pagos'),
              child: const Text('Solo por esta vez'),
            ),
          ],
        ),
      ),
    ] else ...[
      const EncabezadoBro(
        'Consulta lo que tienes pendiente',
        subtitulo: 'El proveedor de prueba devuelve el valor del mes actual.',
      ),
      CristalBro(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            campo(contrato, 'Código de contrato', maximo: 30),
            FilledButton(
              onPressed: ocupado ? null : consultar,
              child: const Text('Consultar valor'),
            ),
          ],
        ),
      ),
      if (factura != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CristalBro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  factura!['nombre'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${factura!['periodo']} · Contrato ${factura!['contrato']}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  dinero((factura!['centavos'] as num).toInt()),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (factura!['estado'] == 'pagada')
                  const Text('Esta planilla ya fue pagada.')
                else ...[
                  const SizedBox(height: 16),
                  ElegirCuentaBro(
                    valor: cuenta,
                    cambiar: ocupado ? null : (v) => setState(() => cuenta = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: ocupado || cuenta == null ? null : pagar,
                    child: const Text('Revisar y pagar'),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Valor sintético. No consulta ni paga una planilla real.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
    ],
  ]);
}
