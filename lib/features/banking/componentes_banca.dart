import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import '../../core/componentes.dart';
import 'banca.dart';

abstract class EstadoBanco<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  bool ocupado = false;
  String? error;
  Future<void> trabajar(Future<void> Function() accion) async {
    if (ocupado) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => error = mensajeError(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<Map<String, dynamic>> llamar(
    String operacion, [
    Map<String, dynamic> datos = const {},
  ]) => ref.read(bancaProvider).ejecutar(operacion, datos);
  Widget estado() => Column(
    children: [
      if (ocupado)
        const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
    ],
  );
  Widget pagina(String titulo, List<Widget> contenido) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      children: [...contenido, estado()],
    ),
  );
  Widget campo(
    TextEditingController controller,
    String etiqueta, {
    TextInputType? teclado,
    int? maximo,
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      key: key,
      controller: controller,
      keyboardType: teclado,
      maxLength: maximo,
      enabled: !ocupado,
      decoration: InputDecoration(labelText: etiqueta),
    ),
  );
}

class ElegirCuentaBro extends ConsumerWidget {
  const ElegirCuentaBro({
    super.key,
    required this.valor,
    required this.cambiar,
    this.etiqueta = 'Desde tu cuenta',
  });
  final String? valor;
  final void Function(String?)? cambiar;
  final String etiqueta;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(cuentasProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => PanelError(e, () => ref.invalidate(cuentasProvider)),
        data: (datos) {
          final cuentas = datos.valor.where((c) => c.activa).toList();
          if (cuentas.isEmpty) {
            return CristalBro(
              child: Column(
                children: [
                  const Text('Abre una cuenta para transferir y pagar.'),
                  TextButton(
                    onPressed: () => context.push('/apertura/ahorros'),
                    child: const Text('Abrir cuenta de ahorros'),
                  ),
                ],
              ),
            );
          }
          return DropdownButtonFormField<String>(
            key: const Key('cuenta-pago'),
            initialValue: cuentas.any((c) => c.id == valor) ? valor : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: etiqueta),
            items: cuentas
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.tipo == 'corriente' ? 'Corriente' : 'Ahorros'} · ${c.numero}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: cambiar,
          );
        },
      );
}

class ReciboBro extends StatelessWidget {
  const ReciboBro(this.recibo, {super.key, this.otra, this.extra});
  final Map<String, dynamic> recibo;
  final VoidCallback? otra;
  final Widget? extra;
  @override
  Widget build(BuildContext context) => EntradaBro(
    child: CristalBro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: Color(0xFF356B53),
          ),
          const SizedBox(height: 16),
          const Text(
            'Operación confirmada',
            key: Key('recibo-pago'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            dinero((recibo['centavos'] as num).toInt()),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
          ),
          Text(
            recibo['titular'] as String? ?? 'FinanceBro',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Divider(),
          SelectableText(
            'Referencia: ${recibo['referencia']}',
            style: const TextStyle(fontSize: 10),
          ),
          if (recibo['periodo'] != null)
            Text('Planilla: ${recibo['periodo']} · ${recibo['contrato']}'),
          const SizedBox(height: 16),
          const Text('Guardado en tu histórico.', textAlign: TextAlign.center),
          if (recibo['simulado'] == true)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Liquidación externa de demostración. No envía dinero a un banco o proveedor real.',
                style: TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.push('/cuentas/${recibo['cuenta']}'),
            child: const Text('Ver movimientos'),
          ),
          ?extra,
          if (otra != null)
            TextButton(
              onPressed: otra,
              child: const Text('Hacer otra operación'),
            ),
        ],
      ),
    ),
  );
}
