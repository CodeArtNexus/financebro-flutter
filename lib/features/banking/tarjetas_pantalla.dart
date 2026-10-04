import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'banca.dart';
import 'componentes_banca.dart';

const coloresTarjeta = {
  'durazno': Color(0xFFFFCEAE),
  'lavanda': Color(0xFFDDD8F6),
  'menta': Color(0xFFCDE8DB),
  'noche': Color(0xFF323749),
};

class TarjetaVisualBro extends StatelessWidget {
  const TarjetaVisualBro(
    this.tarjeta, {
    super.key,
    this.titular = 'FinanceBro',
    this.onTap,
    this.compacta = false,
  });
  final Map<String, dynamic> tarjeta;
  final String titular;
  final VoidCallback? onTap;
  final bool compacta;
  @override
  Widget build(BuildContext context) {
    final color =
            coloresTarjeta[tarjeta['color']] ?? coloresTarjeta['durazno']!,
        oscuro = tarjeta['color'] == 'noche';
    return Semantics(
      label: 'Tarjeta ${tarjeta['banco']} terminada en ${tarjeta['ultimos4']}',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          constraints: const BoxConstraints(minHeight: 190),
          padding: EdgeInsets.all(compacta ? 20 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: .72)],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Poppins',
              color: oscuro ? Colors.white : const Color(0xFF242735),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tarjeta['banco'] == 'FinanceBro'
                            ? 'fb.'
                            : tarjeta['banco'] as String? ?? 'Banco',
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    Icon(
                      tarjeta['tipo'] == 'propia'
                          ? Icons.shield_outlined
                          : Icons.credit_card,
                    ),
                  ],
                ),
                SizedBox(height: compacta ? 16 : 24),
                Text(
                  tarjeta['nombre'] as String? ?? 'Mi tarjeta',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '••••  ••••  ••••  ${tarjeta['ultimos4']}',
                    style: const TextStyle(fontSize: 18, letterSpacing: 1.2),
                  ),
                ),
                SizedBox(height: compacta ? 14 : 18),
                Text(
                  titular.toUpperCase(),
                  style: const TextStyle(fontSize: 10, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  tarjeta['tipo'] == 'propia'
                      ? 'DÉBITO · FINANCEBRO'
                      : 'TARJETA ASOCIADA',
                  style: TextStyle(fontSize: 8, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TarjetasPantalla extends ConsumerStatefulWidget {
  const TarjetasPantalla({super.key});
  @override
  ConsumerState<TarjetasPantalla> createState() => _TarjetasEstado();
}

class _TarjetasEstado extends EstadoBanco<TarjetasPantalla> {
  final nombre = TextEditingController(),
      banco = TextEditingController(),
      ultimos = TextEditingController();
  String tipo = 'externa', color = 'durazno';
  String? cuenta, editar;
  bool formulario = false;
  @override
  void dispose() {
    nombre.dispose();
    banco.dispose();
    ultimos.dispose();
    super.dispose();
  }

  Future<void> guardar() => trabajar(() async {
    await llamar('guardarTarjeta', {
      'id': editar,
      'tipo': tipo,
      'nombre': nombre.text,
      'banco': banco.text,
      'ultimos4': ultimos.text,
      'cuenta': cuenta,
      'color': color,
    });
    if (mounted) setState(() => formulario = false);
  });
  void personalizar(Map<String, dynamic> t) {
    setState(() {
      formulario = true;
      editar = t['id'] as String;
      tipo = t['tipo'] as String;
      nombre.text = t['nombre'] as String;
      banco.text = t['banco'] as String;
      ultimos.text = t['ultimos4'] as String;
      cuenta = t['cuenta'] as String?;
      color = t['color'] as String;
    });
  }

  void abrirTarjeta(Map<String, dynamic> t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TarjetaVisualBro(
                t,
                titular:
                    ref.read(identidadProvider).actual?.nombre ?? 'FinanceBro',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  context.push(
                    t['tipo'] == 'propia'
                        ? '/qr'
                        : '/pagar-externo?tipo=tarjeta&id=${t['id']}',
                  );
                },
                icon: Icon(
                  t['tipo'] == 'propia'
                      ? Icons.qr_code
                      : Icons.payments_outlined,
                ),
                label: Text(
                  t['tipo'] == 'propia' ? 'Transferir con QR' : 'Pagar tarjeta',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  personalizar(t);
                },
                child: const Text('Personalizar diseño'),
              ),
              if (t['tipo'] == 'propia')
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    context.push('/tarjetas/fisica/${t['id']}');
                  },
                  child: const Text('Solicitar copia física'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.push(
                    t['tipo'] == 'propia'
                        ? '/cuentas/${t['cuenta']}'
                        : '/historial?tipo=tarjeta&id=${t['id']}',
                  );
                },
                child: const Text('Ver movimientos'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => pagina('Mis tarjetas', [
    const EncabezadoBro(
      'Tu estilo también cuenta',
      subtitulo: 'Personaliza FinanceBro y distingue tus otros bancos.',
    ),
    FilledButton.icon(
      onPressed: () => setState(() {
        formulario = !formulario;
        editar = null;
        tipo = 'externa';
        color = 'durazno';
        nombre.clear();
        banco.clear();
        ultimos.clear();
      }),
      icon: const Icon(Icons.add_card),
      label: const Text('Asociar tarjeta'),
    ),
    TextButton.icon(
      onPressed: () => context.push('/tarjetas/credito'),
      icon: const Icon(Icons.auto_awesome_outlined),
      label: const Text('Solicitar tarjeta de crédito'),
    ),
    if (formulario)
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tipo == 'propia'
                    ? 'Personaliza tu tarjeta de débito'
                    : 'Asocia una tarjeta de otro banco',
              ),
              campo(nombre, 'Nombre de tu tarjeta'),
              if (tipo == 'externa') ...[
                campo(banco, 'Banco emisor'),
                campo(
                  ultimos,
                  'Últimos 4 dígitos',
                  teclado: TextInputType.number,
                  maximo: 4,
                ),
                const Text(
                  'Guarda solo los últimos cuatro dígitos. No ingreses claves ni códigos de seguridad.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: color,
                decoration: const InputDecoration(
                  labelText: 'Color de tu tarjeta',
                ),
                items: coloresTarjeta.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            CircleAvatar(radius: 8, backgroundColor: e.value),
                            const SizedBox(width: 10),
                            Text(e.key),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: ocupado ? null : (v) => setState(() => color = v!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ocupado ? null : guardar,
                child: const Text('Guardar tarjeta'),
              ),
            ],
          ),
        ),
      ),
    ref
        .watch(tarjetasBroProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensajeError(e)),
          data: (tarjetas) => Column(
            children: [
              if (tarjetas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Asocia una tarjeta para personalizarla o guardar sus pagos.',
                  ),
                ),
              for (final t in tarjetas)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      TarjetaVisualBro(
                        t,
                        onTap: () => abrirTarjeta(t),
                        titular:
                            ref.watch(sesionProvider).value?.nombre ?? 'Bro',
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => personalizar(t),
                            child: const Text('Personalizar'),
                          ),
                          if (t['tipo'] == 'externa')
                            TextButton(
                              onPressed: () => context.push(
                                '/pagar-externo?tipo=tarjeta&id=${t['id']}',
                              ),
                              child: const Text('Pagar tarjeta'),
                            ),
                          TextButton(
                            onPressed: () => context.push(
                              t['tipo'] == 'propia'
                                  ? '/cuentas/${t['cuenta']}'
                                  : '/historial?tipo=tarjeta&id=${t['id']}',
                            ),
                            child: const Text('Movimientos'),
                          ),
                          if (t['tipo'] == 'propia')
                            TextButton(
                              onPressed: () =>
                                  context.push('/tarjetas/fisica/${t['id']}'),
                              child: const Text('Pedir tarjeta física'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
  ]);
}
