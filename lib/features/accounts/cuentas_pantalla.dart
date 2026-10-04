import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import 'cuentas.dart';

class CuentasPantalla extends ConsumerWidget {
  const CuentasPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      leading: const VolverBro(),
      title: const Text('Tus cuentas'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ref
            .watch(cuentasProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  PanelError(e, () => ref.invalidate(cuentasProvider)),
              data: (datos) => Column(
                children: [
                  if (datos.desdeCache) AvisoCache(datos.actualizado),
                  if (datos.valor.isEmpty)
                    PanelEstado(
                      titulo: datos.desdeCache
                          ? 'Necesitamos conexión'
                          : 'Tu espacio está listo',
                      mensaje: datos.desdeCache
                          ? 'Todavía no hay cuentas guardadas en este dispositivo. Recupera la conexión para consultarlas.'
                          : 'Abre una cuenta para transferir, pagar y empezar tus planes.',
                    ),
                  for (final cuenta in datos.valor) TarjetaCuenta(cuenta),
                  if (!datos.valor.any((c) => c.tipo == 'corriente'))
                    OutlinedButton.icon(
                      onPressed: () => context.push('/apertura/corriente'),
                      icon: const Icon(Icons.business_outlined),
                      label: const Text('Solicitar cuenta corriente'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/contactos'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 19),

                    label: const Text('Mis contactos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/tarjetas'),
                    icon: const Icon(Icons.credit_card_outlined, size: 19),

                    label: const Text('Gestionar tarjetas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/historial'),
                    icon: const Icon(Icons.history_rounded, size: 19),

                    label: const Text('Todos mis movimientos'),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class TarjetaCuenta extends ConsumerWidget {
  const TarjetaCuenta(this.cuenta, {super.key});
  final Cuenta cuenta;
  @override
  Widget build(BuildContext context, WidgetRef ref) => TarjetaCristalBro(
    child: ListTile(
      contentPadding: const EdgeInsets.all(20),
      leading: Icon(
        cuenta.tipo == 'corriente'
            ? Icons.business_outlined
            : Icons.savings_outlined,
      ),
      title: Text(cuenta.nombre),
      subtitle: Text(
        '${cuenta.numero} · ${cuenta.activa ? 'Activa' : 'Temporal'}\n${(ref.watch(perfilProvider).value?.valor.mostrarSaldo ?? false) ? dinero(cuenta.saldoCentavos) : "••••••"}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/cuentas/${cuenta.id}'),
    ),
  );
}
