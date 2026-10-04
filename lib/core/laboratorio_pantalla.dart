import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/proveedores.dart';
import 'control_red.dart';

class LaboratorioPantalla extends ConsumerStatefulWidget {
  const LaboratorioPantalla({super.key});
  @override
  ConsumerState<LaboratorioPantalla> createState() => _LaboratorioEstado();
}

class _LaboratorioEstado extends ConsumerState<LaboratorioPantalla> {
  bool cambiando = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final control = ref.watch(controlRedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Laboratorio de conexión')),
      body: ListenableBuilder(
        listenable: control,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Herramienta de evaluación. Estos controles se excluyen al compilar sin ENABLE_LAB.',
            ),
            const SizedBox(height: 24),
            for (final escenario in EscenarioRed.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: cambiando
                      ? null
                      : () async {
                          setState(() {
                            cambiando = true;
                            error = null;
                          });
                          try {
                            await control.cambiar(escenario);
                            ref.invalidate(cotizacionProvider);
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => error = 'No pudimos cambiar el escenario. Vuelve a intentar.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => cambiando = false);
                          }
                        },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 19),

                  label: Text(
                    '${control.escenario == escenario ? "✓ " : ""}${switch (escenario) {
                      EscenarioRed.normal => "Conexión normal / recuperar",
                      EscenarioRed.sinConexion => "Sin conexión",
                      EscenarioRed.latencia => "Alta latencia (4 segundos)",
                      EscenarioRed.divisasCaidas => "Fallo del servicio de divisas",
                    }}',
                  ),
                ),
              ),
            if (error != null) Text(error!),
            const SizedBox(height: 16),
            const Text(
              'Sin conexión deshabilita la red de Firestore y las consultas de divisas. La caída parcial afecta solo a divisas. La latencia demora ese servicio. La conexión normal permite volver a actualizar.',
            ),
          ],
        ),
      ),
    );
  }
}
