import 'diseno_bro.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'errores.dart';

String dinero(int centavos) => NumberFormat.currency(
  locale: 'es_EC',
  symbol: 'USD ',
  decimalDigits: 2,
).format(centavos / 100);

class PanelEstado extends StatelessWidget {
  const PanelEstado({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.reintentar,
    this.icono = Icons.info_outline,
  });
  final String titulo;
  final String mensaje;
  final VoidCallback? reintentar;
  final IconData icono;
  @override
  Widget build(BuildContext context) => TarjetaCristalBro(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icono, size: 36),
          const SizedBox(height: 12),
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(mensaje, textAlign: TextAlign.center),
          if (reintentar != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: reintentar,
                icon: const Icon(Icons.refresh_rounded, size: 19),

                label: const Text('Reintentar'),
              ),
            ),
        ],
      ),
    ),
  );
}

class PanelError extends StatelessWidget {
  const PanelError(this.error, this.reintentar, {super.key});
  final Object error;
  final VoidCallback reintentar;
  @override
  Widget build(BuildContext context) => PanelEstado(
    titulo: 'Necesitamos un momento',
    mensaje: mensajeError(error),
    reintentar: reintentar,
    icono: Icons.wifi_off_outlined,
  );
}

class AvisoCache extends StatelessWidget {
  const AvisoCache(this.fecha, {super.key, this.pendiente = false});
  final DateTime fecha;
  final bool pendiente;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pendiente
                  ? 'Cambios guardados en el dispositivo. Pendientes de sincronización.'
                  : fecha.year == 1970
                  ? 'Consultando el servicio. Aún no hay información guardada.'
                  : 'Información guardada · ${DateFormat("dd/MM HH:mm").format(fecha)}. Se actualizará al conectar.',
            ),
          ),
        ],
      ),
    ),
  );
}
