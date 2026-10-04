import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'banca.dart';
import 'componentes_banca.dart';

class ContactosPantalla extends ConsumerStatefulWidget {
  const ContactosPantalla({super.key});
  @override
  ConsumerState<ContactosPantalla> createState() => _ContactosEstado();
}

class _ContactosEstado extends EstadoBanco<ContactosPantalla> {
  final numero = TextEditingController(),
      nombre = TextEditingController(),
      banco = TextEditingController(),
      documento = TextEditingController();
  bool interno = true, agregar = false;
  @override
  void dispose() {
    numero.dispose();
    nombre.dispose();
    banco.dispose();
    documento.dispose();
    super.dispose();
  }

  Future<void> guardar() => trabajar(() async {
    await llamar('guardarContacto', {
      'tipo': interno ? 'interno' : 'externo',
      'numero': numero.text.trim(),
      'nombre': nombre.text,
      'banco': banco.text,
      'documento': documento.text,
    });
    if (mounted) setState(() => agregar = false);
    numero.clear();
    nombre.clear();
    banco.clear();
    documento.clear();
  });
  @override
  Widget build(BuildContext context) => pagina('Tus contactos', [
    const EncabezadoBro(
      'Tus personas, cerca',
      subtitulo: 'Verificamos las cuentas de FinanceBro por su número.',
    ),
    FilledButton.icon(
      onPressed: () => setState(() => agregar = !agregar),
      icon: Icon(agregar ? Icons.close : Icons.person_add_alt),
      label: Text(agregar ? 'Cerrar formulario' : 'Registrar contacto'),
    ),
    if (agregar)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('FinanceBro')),
                  ButtonSegment(value: false, label: Text('Otro banco')),
                ],
                selected: {interno},
                onSelectionChanged: ocupado
                    ? null
                    : (v) => setState(() => interno = v.first),
              ),
              campo(numero, 'Número de cuenta', teclado: TextInputType.number),
              if (!interno) ...[
                campo(nombre, 'Nombre del titular'),
                campo(banco, 'Banco'),
                campo(documento, 'Identificación del titular'),
                const Text(
                  'Revisa los datos del destinatario antes de guardarlos.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ocupado ? null : guardar,
                child: Text(
                  interno ? 'Verificar y guardar' : 'Guardar contacto',
                ),
              ),
            ],
          ),
        ),
      ),
    ref
        .watch(contactosBroProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensajeError(e)),
          data: (contactos) => Column(
            children: [
              if (contactos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Agrega una persona para encontrarla fácilmente.',
                  ),
                ),
              for (final c in contactos)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: CristalBro(
                    padding: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c['tipo'] == 'interno'
                            ? const Color(0xFFFFE0CC)
                            : const Color(0xFFE7E4FA),
                        child: Text((c['nombre'] as String).substring(0, 1)),
                      ),
                      title: Text(c['nombre'] as String),
                      subtitle: Text(
                        '${c['banco']} · ${c['numero']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_outward),
                      onTap: () => context.push(
                        c['tipo'] == 'interno'
                            ? '/transferir?numero=${c['numero']}'
                            : '/pagar-externo?tipo=contacto&id=${c['id']}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
  ]);
}

class PagoExternoPantalla extends ConsumerStatefulWidget {
  const PagoExternoPantalla({
    super.key,
    required this.tipo,
    required this.destino,
  });
  final String tipo, destino;
  @override
  ConsumerState<PagoExternoPantalla> createState() => _ExternoEstado();
}

class _ExternoEstado extends EstadoBanco<PagoExternoPantalla> {
  final monto = TextEditingController();
  String? cuenta;
  final referencia = nuevaReferencia();
  Map<String, dynamic>? recibo;
  @override
  void dispose() {
    monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => pagina(
    widget.tipo == 'tarjeta' ? 'Pagar tarjeta' : 'Transferencia externa',
    [
      if (recibo != null)
        ReciboBro(recibo!)
      else
        CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Revisa tu pago',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Revisa el destino y el importe. Guardaremos el recibo en el histórico de esta tarjeta o contacto.',
                style: TextStyle(fontSize: 12),
              ),
              campo(
                monto,
                'Monto en USD',
                teclado: const TextInputType.numberWithOptions(decimal: true),
              ),
              ElegirCuentaBro(
                valor: cuenta,
                cambiar: ocupado ? null : (v) => setState(() => cuenta = v),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: ocupado || cuenta == null
                    ? null
                    : () => trabajar(() async {
                        final centavos = montoCentavos(monto.text);
                        final si = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Confirmar pago'),
                            content: Text(
                              'Descontar USD ${(centavos / 100).toStringAsFixed(2)} de tu cuenta.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Volver'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Confirmar'),
                              ),
                            ],
                          ),
                        );
                        if (si != true) return;
                        final r = await llamar('pagarExterno', {
                          'tipo': widget.tipo,
                          'destino': widget.destino,
                          'cuenta': cuenta,
                          'centavos': centavos,
                          'referencia': referencia,
                        });
                        if (mounted) setState(() => recibo = r);
                      }),
                child: const Text('Revisar pago'),
              ),
            ],
          ),
        ),
    ],
  );
}
