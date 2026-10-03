import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'experiencia.dart';

class TarjetaContenido extends StatelessWidget {
  const TarjetaContenido(this.tarjeta, {super.key});
  final TarjetaRemota tarjeta;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(switch (tarjeta.tipo) {
            'divisas' => Icons.flight_takeoff_outlined,
            'recomendacion' => Icons.savings_outlined,
            _ => Icons.lightbulb_outline,
          }),
          const SizedBox(height: 12),
          Text(tarjeta.titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(tarjeta.texto),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go(tarjeta.destino),
            child: const Text('Explorar'),
          ),
        ],
      ),
    ),
  );
}
