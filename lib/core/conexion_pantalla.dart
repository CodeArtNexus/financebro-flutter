import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'red_banco.dart';
import 'diseno_bro.dart';

class ConexionPantalla extends ConsumerWidget {
  const ConexionPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(conexionBancoProvider).value;
    return Scaffold(
      appBar: AppBar(
        leading: const VolverBro(),
        title: const MarcaBro(compacta: true),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CristalBro(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  estado == EstadoConexion.servicioNoDisponible
                      ? Icons.cloud_off_outlined
                      : Icons.wifi_off_rounded,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  estado == EstadoConexion.servicioNoDisponible
                      ? 'Estamos recuperando el servicio'
                      : 'Volvemos cuando te conectes',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para ingresar y confirmar operaciones necesitamos conexión. Tus transferencias preparadas esperan su validación, sin descontar dinero.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(redBancoProvider).revisar();
                    if (context.mounted &&
                        ref.read(redBancoProvider).conectado) {
                      context.go('/ingresar');
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Volver a conectar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/ingresar'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Volver a mi acceso'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AvisoConexion extends ConsumerWidget {
  const AvisoConexion({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado =
        ref.watch(conexionBancoProvider).value ?? EstadoConexion.revisando;
    if (estado == EstadoConexion.conectado) return const SizedBox.shrink();
    final colores = Theme.of(context).colorScheme;
    return Material(
      color: colores.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: ListTile(
          dense: true,
          textColor: colores.onPrimaryContainer,
          iconColor: colores.primary,
          subtitleTextStyle: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colores.onSurfaceVariant),
          leading: Icon(
            estado == EstadoConexion.revisando ? Icons.sync : Icons.wifi_off,
          ),
          title: Text(switch (estado) {
            EstadoConexion.revisando => 'Revisando conexión',
            EstadoConexion.sinConexion => 'Sin conexión · datos guardados',
            _ => 'Servicio temporalmente no disponible',
          }),
          subtitle: const Text(
            'Los pagos se confirman cuando FinanceBro los acepta.',
          ),
          trailing: IconButton(
            tooltip: 'Revisar conexión',
            color: colores.primary,
            onPressed: () => ref.read(redBancoProvider).revisar(),
            icon: const Icon(Icons.refresh),
          ),
        ),
      ),
    );
  }
}
