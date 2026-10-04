import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import '../../core/red_banco.dart';
import 'banca.dart';
import 'cola_transferencias.dart';
import 'componentes_banca.dart';

final colaTransferenciasProvider = Provider<ColaTransferencias>((ref) {
  final red = ref.watch(redBancoProvider), banca = ref.watch(bancaProvider);
  final cola = ColaTransferencias(
    almacen: AlmacenSeguroCola(),
    proyecto: ref.watch(firebaseAppProvider).options.projectId,
    sesion: () => ref.read(identidadProvider).actual?.uid,
    conectado: () => red.conectado,
    desbloquear: ref.watch(autenticarDispositivoProvider),
    enviar: (d) => banca.ejecutar('transferir', d),
  );
  void procesar() => unawaited(
    cola.procesar().catchError((Object e) {
      registrarEvento('cola_pendiente', servicio: 'banca');
    }),
  );
  red.addListener(procesar);
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => procesar());
  ref.listen(sesionProvider, (_, s) async {
    try {
      await cola.cargar(s.value?.uid);
      procesar();
    } catch (_) {
      registrarEvento('cola_lectura_pendiente', servicio: 'banca');
    }
  }, fireImmediately: true);
  ref.onDispose(() {
    timer.cancel();
    red.removeListener(procesar);
    cola.dispose();
  });
  return cola;
});
final pendientesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final cola = ref.watch(colaTransferenciasProvider);
  return Stream.multi((c) {
    void emitir() =>
        c.add(cola.items.map((v) => Map<String, dynamic>.from(v)).toList());
    cola.addListener(emitir);
    emitir();
    c.onCancel = () => cola.removeListener(emitir);
  });
});

class PendientesPantalla extends ConsumerWidget {
  const PendientesPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      leading: const VolverBro(),
      title: const Text('Transferencias pendientes'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const EncabezadoBro(
          'Tus acuerdos viajan contigo',
          subtitulo: 'Autorizas aquí. FinanceBro valida y descuenta cuando vuelve la conexión. Caducan en 24 horas.',
        ),
        OutlinedButton.icon(
          onPressed: () => ref.read(colaTransferenciasProvider).procesar(),
          icon: const Icon(Icons.sync),
          label: const Text('Revisar conexión y enviar'),
        ),
        const SizedBox(height: 16),
        ref
            .watch(pendientesProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(mensajeError(e)),
              data: (items) => Column(
                children: [
                  if (items.isEmpty)
                    const CristalBro(
                      child: Text('No tienes transferencias pendientes.'),
                    ),
                  for (final v in items.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CristalBro(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                v['estado'] == 'confirmada'
                                    ? Icons.check_circle_outline
                                    : Icons.schedule_send,
                              ),
                              title: Text(v['titular'] as String),
                              subtitle: Text(
                                '${v['datos']['numero']}\n${v['mensaje']}',
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                'USD ${((v['datos']['centavos'] as int) / 100).toStringAsFixed(2)}',
                              ),
                            ),
                            if (v['estado'] == 'pendiente' &&
                                v['intentada'] != true)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(colaTransferenciasProvider)
                                        .cancelar(v['referencia'] as String);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(mensajeError(e)),
                                            ),
                                          );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancelar antes de enviar'),
                              ),
                            if (v['estado'] == 'confirmada')
                              ReciboBro(
                                Map<String, dynamic>.from(v['recibo'] as Map),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ],
    ),
  );
}
