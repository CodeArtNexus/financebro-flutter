import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';

class NotificacionesPantalla extends ConsumerStatefulWidget {
  const NotificacionesPantalla({super.key});
  @override
  ConsumerState<NotificacionesPantalla> createState() =>
      _NotificacionesEstado();
}

class _NotificacionesEstado extends ConsumerState<NotificacionesPantalla> {
  bool activando = false;
  String? mensaje;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const VolverBro(),
      title: const Text('Notificaciones'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Las novedades que te importan, en el momento indicado.'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: activando
              ? null
              : () async {
                  setState(() {
                    activando = true;
                    mensaje = null;
                  });
                  try {
                    final activado = await ref
                        .read(notificacionesRepositorioProvider)
                        .activar(ref.read(identidadProvider).actual!.uid);
                    if (mounted) {
                      setState(
                        () => mensaje = activado
                            ? 'Este dispositivo está listo para recibir notificaciones.'
                            : 'No diste permiso. Puedes activarlo en los ajustes del dispositivo.',
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => mensaje = mensajeError(e));
                  } finally {
                    if (mounted) setState(() => activando = false);
                  }
                },
          child: Text(activando ? 'Activando…' : 'Activar notificaciones'),
        ),
        if (mensaje != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(liveRegion: true, child: Text(mensaje!)),
          ),
        const SizedBox(height: 24),
        Text('Tu historial', style: Theme.of(context).textTheme.titleLarge),
        ref
            .watch(historialNotificacionesProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => PanelError(
                e,
                () => ref.invalidate(historialNotificacionesProvider),
              ),
              data: (avisos) => Column(
                children: [
                  if (avisos.isEmpty)
                    const PanelEstado(
                      titulo: 'Todo al día',
                      mensaje: 'Tus avisos aparecerán aquí.',
                    ),
                  for (final aviso in avisos)
                    Card(
                      child: ListTile(
                        title: Text(aviso.titulo),
                        subtitle: Text(
                          '${aviso.texto}\n${DateFormat("dd/MM HH:mm").format(aviso.fecha)}',
                        ),
                        onTap: () => context.push(aviso.destino),
                      ),
                    ),
                ],
              ),
            ),
      ],
    ),
  );
}
