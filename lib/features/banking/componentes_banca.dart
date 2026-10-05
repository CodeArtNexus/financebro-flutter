import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Widget pagina(
    String titulo,
    List<Widget> contenido, {
    bool agruparCristal = false,
  }) {
    final lista = ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      children: [...contenido, estado()],
    );
    return Scaffold(
      appBar: AppBar(leading: const VolverBro(), title: Text(titulo)),
      body: agruparCristal ? BackdropGroup(child: lista) : lista,
    );
  }

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
                  const Text('Tu cuenta debe estar activa para operar.'),
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
          if (recibo['tipo'] == 'transferencia')
            const DineroViajandoBro()
          else
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
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
          ),
          Text(
            recibo['titular'] as String? ?? 'FinanceBro',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Divider(),
          ReferenciaBro(recibo['referencia'] as String),
          if (recibo['periodo'] != null)
            Text('Planilla: ${recibo['periodo']} · ${recibo['contrato']}'),
          const SizedBox(height: 16),
          const Text('Guardado en tu histórico.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/cuentas/${recibo['cuenta']}'),
            icon: const Icon(Icons.history_rounded, size: 19),

            label: const Text('Ver movimientos'),
          ),
          ?extra,
          if (otra != null)
            TextButton.icon(
              onPressed: otra,
              icon: const Icon(Icons.arrow_forward_rounded, size: 19),

              label: const Text('Hacer otra operación'),
            ),
        ],
      ),
    ),
  );
}

class DineroViajandoBro extends StatefulWidget {
  const DineroViajandoBro({super.key});
  @override
  State<DineroViajandoBro> createState() => _DineroViajandoEstado();
}

class _DineroViajandoEstado extends State<DineroViajandoBro>
    with SingleTickerProviderStateMixin {
  late final AnimationController controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controlador.value = 1;
    } else if (!controlador.isAnimating && controlador.value == 0) {
      controlador.forward();
    }
  }

  @override
  void dispose() {
    controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Transferencia confirmada',
    child: SizedBox(
      height: 90,
      child: AnimatedBuilder(
        animation: controlador,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(controlador.value);
          return LayoutBuilder(
            builder: (context, c) => Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 44,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Positioned(
                  right: 0,
                  child: Icon(
                    Icons.account_balance_outlined,
                    size: 44,
                    color: Color(0xFF356B53),
                  ),
                ),
                Positioned(
                  left: 30 + t * (c.maxWidth - 100),
                  top: 24 - 18 * (1 - (2 * t - 1).abs()),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFCEAE),
                    ),
                    child: Icon(
                      t < 1 ? Icons.attach_money_rounded : Icons.check_rounded,
                      color: const Color(0xFF356B53),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class ReferenciaBro extends StatelessWidget {
  const ReferenciaBro(this.valor, {super.key});
  final String valor;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () async {
      await Clipboard.setData(ClipboardData(text: valor));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Referencia copiada')));
      }
    },
    icon: const Icon(Icons.copy_outlined, size: 18),
    label: Text('Referencia: $valor'),
    style: TextButton.styleFrom(alignment: Alignment.centerLeft),
  );
}
