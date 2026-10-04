import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../../core/apariencia.dart';
import '../banking/banca.dart';
import '../banking/tarjetas_pantalla.dart';
import '../experience/tarjeta_remota.dart';
import 'cuentas.dart';

class InicioPantalla extends ConsumerWidget {
  const InicioPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).value,
        nombre = usuario?.nombre.split(' ').first ?? 'Bro',
        mostrar = ref.watch(perfilProvider).value?.valor.mostrarSaldo ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const MarcaBro(compacta: true),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => context.push('/notificaciones'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          if (decoracionVigente(ref.watch(decoracionProvider).value)
              case final temporada?)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CristalBro(
                color: const Color(0xFFE7F2E9),
                child: Row(
                  children: [
                    Icon(
                      temporada['tema'] == 'navidad'
                          ? Icons.park_outlined
                          : Icons.celebration_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            temporada['titulo'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            temporada['mensaje'] as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          EntradaBro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $nombre ✨',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
                Text(switch (ref.watch(perfilProvider).value?.valor.segmento) {
                  'viajes' => 'Ya casi despegamos. Vamos por tu próximo viaje.',
                  'ahorro' => 'Cada paso cuenta. Hagamos crecer tus planes.',
                  _ => 'Aquí tienes a tu financebro de confianza.',
                }, style: TextStyle(fontSize: 12, color: Color(0xFF6E7181))),
                const SizedBox(height: 8),
              ],
            ),
          ),
          ref
              .watch(cuentasProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    PanelError(e, () => ref.invalidate(cuentasProvider)),
                data: (datos) {
                  if (datos.desdeCache && datos.valor.isEmpty) {
                    return const PanelEstado(
                      titulo: 'Necesitamos conexión',
                      mensaje: 'Todavía no hay cuentas guardadas. Conéctate para consultarlas.',
                    );
                  }
                  final ahorro = datos.valor
                          .where((c) => c.tipo == 'ahorro')
                          .firstOrNull,
                      corriente = datos.valor
                          .where((c) => c.tipo == 'corriente')
                          .firstOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const EncabezadoBro('Tu dinero, a tu manera'),
                      LayoutBuilder(
                        builder: (context, medidas) {
                          final compactas =
                              medidas.maxWidth >= 300 &&
                              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                          final cuentas = [
                            CuentaInicioBro(
                              ahorro,
                              tipo: 'ahorro',
                              mostrar: mostrar,
                              compacta: compactas,
                            ),
                            CuentaInicioBro(
                              corriente,
                              tipo: 'corriente',
                              mostrar: mostrar,
                              compacta: compactas,
                            ),
                          ];
                          return compactas
                              ? IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: cuentas[0]),
                                      const SizedBox(width: 12),
                                      Expanded(child: cuentas[1]),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    cuentas[0],
                                    const SizedBox(height: 12),
                                    cuentas[1],
                                  ],
                                );
                        },
                      ),
                      if (datos.desdeCache) AvisoCache(datos.actualizado),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AccionBro(
                              'Transferir',
                              Icons.arrow_outward,
                              () => context.push('/transferir'),
                            ),
                          ),
                          Expanded(
                            child: AccionBro('Mi QR', Icons.qr_code, () {
                              context.go('/qr?recibir=true');
                            }),
                          ),
                          Expanded(
                            child: AccionBro(
                              'Contactos',
                              Icons.people_outline,
                              () => context.push('/contactos'),
                            ),
                          ),
                          Expanded(
                            child: AccionBro(
                              'Mis metas',
                              Icons.savings_outlined,
                              () => context.push('/metas'),
                            ),
                          ),
                        ],
                      ),
                      EncabezadoBro(
                        'Mis tarjetas',
                        subtitulo: 'Tu estilo, tus bancos',
                        accion: TextButton(
                          onPressed: () => context.push('/tarjetas'),
                          child: const Text('Gestionar'),
                        ),
                      ),
                      ref
                          .watch(tarjetasBroProvider)
                          .when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => PanelError(
                              e,
                              () => ref.invalidate(tarjetasBroProvider),
                            ),
                            data: (tarjetas) {
                              final todas = tarjetas.isEmpty
                                  ? datos.valor
                                        .where(
                                          (c) =>
                                              c.tarjetaUltimos4 != null &&
                                              c.activa,
                                        )
                                        .map(
                                          (c) => <String, dynamic>{
                                            'nombre': c.nombre,
                                            'banco': 'FinanceBro',
                                            'ultimos4': c.tarjetaUltimos4,
                                            'color': c.color,
                                          },
                                        )
                                        .toList()
                                  : tarjetas;
                              if (todas.isEmpty) {
                                return CristalBro(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Dale tu estilo a una tarjeta FinanceBro.',
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            context.push('/tarjetas'),
                                        child: const Text('Asociar tarjeta'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return SizedBox(
                                height:
                                    220 +
                                    130 *
                                        (MediaQuery.textScalerOf(context)
                                                .scale(1) -
                                            1),
                                child: PageView.builder(
                                  itemCount: todas.length,
                                  itemBuilder: (c, i) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: TarjetaVisualBro(
                                      todas[i],
                                      compacta: true,
                                      titular: usuario?.nombre ?? 'Bro',
                                      onTap: () => context.push(
                                        todas[i]['clase'] == 'credito'
                                            ? '/tarjetas/credito/detalle'
                                            : '/tarjetas',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
                  );
                },
              ),
          const SizedBox(height: 20),
          CristalBro(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Todos tus movimientos'),
              subtitle: const Text(
                'Transferencias, pagos y ajustes en un lugar.',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/historial'),
            ),
          ),
          const SizedBox(height: 12),
          CristalBro(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bolt_outlined),
              title: const Text('Tus servicios, al día'),
              subtitle: const Text(
                'Consulta una planilla o activa un pago mensual.',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/pagos'),
            ),
          ),
          const EncabezadoBro('Para tus próximos planes'),
          ref
              .watch(contenidoProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    PanelError(e, () => ref.invalidate(contenidoProvider)),
                data: (experiencia) => Column(
                  children: [
                    for (final tarjeta in experiencia.tarjetas.where(
                      (t) =>
                          t.segmento == 'todos' ||
                          t.segmento ==
                              ref.watch(perfilProvider).value?.valor.segmento,
                    ))
                      TarjetaContenido(tarjeta),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => context.push('/divisas'),
            icon: const Icon(Icons.currency_exchange),
            label: const Text('Explorar divisas'),
          ),
        ],
      ),
    );
  }
}

class CuentaInicioBro extends StatelessWidget {
  const CuentaInicioBro(
    this.cuenta, {
    super.key,
    required this.tipo,
    required this.mostrar,
    this.compacta = false,
  });
  final Cuenta? cuenta;
  final String tipo;
  final bool mostrar, compacta;
  @override
  Widget build(BuildContext context) {
    final corriente = tipo == 'corriente';
    return EntradaBro(
      child: CristalBro(
        padding: EdgeInsets.all(compacta ? 16 : 22),
        color: corriente
            ? const Color(0xFFEEEAFB).withValues(alpha: .78)
            : const Color(0xFFFFE9DA).withValues(alpha: .8),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push(
            cuenta == null
                ? '/apertura/${corriente ? 'corriente' : 'ahorros'}'
                : '/cuentas/${cuenta!.id}',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    corriente
                        ? Icons.business_outlined
                        : Icons.savings_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      corriente ? 'Cuenta corriente' : 'Cuenta de ahorros',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!compacta) const Icon(Icons.arrow_outward, size: 18),
                ],
              ),
              const SizedBox(height: 16),
              if (cuenta == null) ...[
                Text(
                  corriente
                      ? (compacta ? 'Tu empresa' : 'Un espacio para tu empresa')
                      : 'Empieza con tus ahorros',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  corriente
                      ? (compacta
                            ? 'Abre tu solicitud'
                            : 'Abre tu solicitud y guarda cada paso.')
                      : 'Estamos completando tu apertura.',
                  style: const TextStyle(fontSize: 11),
                ),
              ] else ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    mostrar ? dinero(cuenta!.saldoCentavos) : '••••••',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cuenta!.numero} · ${cuenta!.activa ? 'Disponible' : 'Temporal · depósito inicial'}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AccionBro extends StatelessWidget {
  const AccionBro(this.texto, this.icono, this.accion, {super.key});
  final String texto;
  final IconData icono;
  final VoidCallback accion;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: accion,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
    ),
    child: Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
          ),
          child: Icon(icono, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}
