import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../app/tema.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../experience/tarjeta_remota.dart';
import 'cuentas.dart';
import 'cuentas_pantalla.dart';

class InicioPantalla extends ConsumerWidget {
  const InicioPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).value;
    final nombre = usuario?.nombre.split(' ').first ?? 'Bro';
    final mostrar =
        ref.watch(perfilProvider).value?.valor.mostrarSaldo ?? false;
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
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          EntradaBro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $nombre ✨',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.9,
                  ),
                ),
                const Text(
                  'Tu dinero, tus planes. Vamos a cuidarlos.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6E7181)),
                ),
                const SizedBox(height: 22),
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
                  final tarjetas = datos.valor
                      .where((c) => c.tarjetaUltimos4 != null)
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (datos.valor.isNotEmpty)
                        CristalBro(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 16,
                                    color: naranjaTextoBro,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tu saldo total',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Spacer(),
                                  Text(
                                    'USD',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF757989),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  mostrar
                                      ? dinero(
                                          datos.valor.fold(
                                            0,
                                            (s, c) => s + c.saldoCentavos,
                                          ),
                                        )
                                      : '••••••',
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Disponible en tus cuentas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6E7181),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (datos.desdeCache) AvisoCache(datos.actualizado),
                      if (tarjetas.isNotEmpty) ...[
                        const EncabezadoBro(
                          'Mis tarjetas',
                          subtitulo: 'Siempre a mano',
                        ),
                        SizedBox(
                          height:
                              150 +
                              72 * MediaQuery.textScalerOf(context).scale(1),
                          child: PageView.builder(
                            itemCount: tarjetas.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: TarjetaBro(
                                tarjetas[i],
                                nombre: usuario?.nombre ?? 'Bro',
                                indice: i,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          AccionBro(
                            'Pagar QR',
                            Icons.qr_code_scanner_rounded,
                            () => context.go('/qr'),
                          ),
                          AccionBro(
                            'Divisas',
                            Icons.currency_exchange_rounded,
                            () => context.push('/divisas'),
                          ),
                          AccionBro(
                            'Mis metas',
                            Icons.savings_outlined,
                            () => context.go('/metas'),
                          ),
                        ],
                      ),
                      EncabezadoBro(
                        'Tus cuentas',
                        accion: TextButton(
                          onPressed: () => context.go('/cuentas'),
                          child: const Text('Ver todas'),
                        ),
                      ),
                      if (datos.valor.isEmpty)
                        PanelEstado(
                          titulo: datos.desdeCache
                              ? 'Necesitamos conexión'
                              : 'Tu espacio está listo',
                          mensaje: datos.desdeCache
                              ? 'Todavía no hay cuentas guardadas. Conéctate para consultarlas.'
                              : 'Todavía no tienes cuentas asignadas.',
                        ),
                      for (final cuenta in datos.valor) TarjetaCuenta(cuenta),
                    ],
                  );
                },
              ),
          const EncabezadoBro('Para ti', subtitulo: 'Ideas que van contigo'),
          ref
              .watch(contenidoProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    PanelError(e, () => ref.invalidate(contenidoProvider)),
                data: (experiencia) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in experiencia.paraPerfil(
                      ref.watch(perfilProvider).value?.valor.segmento ??
                          'equilibrio',
                    ))
                      TarjetaContenido(t),
                    if (experiencia.respaldo)
                      const Text(
                        'Tu contenido disponible mientras conectamos.',
                        style: TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
        ],
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: accion,
      borderRadius: BorderRadius.circular(20),
      child: CristalBro(
        radio: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 19, color: naranjaTextoBro),
            const SizedBox(width: 8),
            Text(
              texto,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}

class TarjetaBro extends StatelessWidget {
  const TarjetaBro(
    this.cuenta, {
    super.key,
    required this.nombre,
    this.indice = 0,
  });
  final Cuenta cuenta;
  final String nombre;
  final int indice;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Tarjeta de demostración ${cuenta.tarjetaRed}, termina en ${cuenta.tarjetaUltimos4}',
    button: true,
    child: InkWell(
      onTap: () => context.push('/cuentas/${cuenta.id}'),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: indice.isEven
                ? [
                    const Color(0xFFFFE9D9),
                    const Color(0xFFFFC29F),
                    const Color(0xFFFFDEC8),
                  ]
                : [
                    const Color(0xFFEEECFA),
                    const Color(0xFFCDC8EB),
                    const Color(0xFFE7E4F6),
                  ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'financebro',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -.8,
                  ),
                ),
                const Spacer(),
                Text(
                  cuenta.tarjetaRed,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Row(
              children: [
                Icon(Icons.memory_rounded, size: 30, color: Color(0xFF987A55)),
                SizedBox(width: 9),
                Icon(Icons.contactless_outlined, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              child: Text(
                '••••  ••••  ••••  ${cuenta.tarjetaUltimos4}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    nombre.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, letterSpacing: 1),
                  ),
                ),
                const Text(
                  'DEMO',
                  style: TextStyle(fontSize: 9, letterSpacing: 1),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
