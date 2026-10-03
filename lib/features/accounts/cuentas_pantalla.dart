import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import 'cuentas.dart';

class CuentasPantalla extends ConsumerWidget {
  const CuentasPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Tus cuentas')),
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
                          : 'Aún no tienes cuentas asignadas. Aparecerán aquí cuando estén disponibles.',
                    ),
                  for (final cuenta in datos.valor) TarjetaCuenta(cuenta),
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
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(20),
      leading: const Icon(Icons.account_balance_outlined),
      title: Text(cuenta.nombre),
      subtitle: Text(
        '${cuenta.numero}\n${(ref.watch(perfilProvider).value?.valor.mostrarSaldo ?? false) ? dinero(cuenta.saldoCentavos) : "••••••"}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/cuentas/${cuenta.id}'),
    ),
  );
}
