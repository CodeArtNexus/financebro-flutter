import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'banca.dart';
import 'componentes_banca.dart';

String fechaDigital(DateTime v) =>
    '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
DateTime hoyEcuador() {
  final f = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  return DateTime(f.year, f.month, f.day);
}

DateTime mesDigital(DateTime base, int n) {
  final ultimo = DateTime(base.year, base.month + n + 1, 0).day;
  return DateTime(
    base.year,
    base.month + n,
    base.day > ultimo ? ultimo : base.day,
  );
}

String usdCheque(dynamic c) =>
    'USD ${((c as num? ?? 0) / 100).toStringAsFixed(2)}';
String estadoCheque(String v) => switch (v) {
  'pendiente_fondos' => 'Pendiente por fondos',
  'bloqueado' => 'Bloqueado',
  'cancelado' => 'Cancelado',
  'cobrado' => 'Cobrado',
  _ => 'Por cobrar',
};
final chequesBroProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, limite) {
      final uid = ref.watch(sesionProvider).value?.uid;
      return uid == null
          ? const Stream.empty()
          : ref
                .watch(bancaProvider)
                .observar(
                  'usuarios/$uid/cheques',
                  orden: 'creado',
                  limite: limite,
                );
    });
final gruposChequesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final uid = ref.watch(sesionProvider).value?.uid;
      return uid == null
          ? const Stream.empty()
          : ref
                .watch(bancaProvider)
                .observar(
                  'usuarios/$uid/gruposCheques',
                  orden: 'actualizado',
                  limite: 100,
                );
    });
final detalleChequeProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
      final uid = ref.watch(sesionProvider).value?.uid;
      return uid == null
          ? const Stream.empty()
          : ref
                .watch(datosProvider)
                .doc('usuarios/$uid/cheques/$id')
                .snapshots()
                .map((s) => s.data());
    });
final eventosChequeProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) {
      final uid = ref.watch(sesionProvider).value?.uid;
      return uid == null
          ? const Stream.empty()
          : ref
                .watch(bancaProvider)
                .observar(
                  'usuarios/$uid/cheques/$id/eventos',
                  orden: 'fecha',
                  limite: 100,
                );
    });

class ChequeraPantalla extends ConsumerStatefulWidget {
  const ChequeraPantalla({super.key});
  @override
  ConsumerState<ChequeraPantalla> createState() => _ChequeraEstado();
}

class _ChequeraEstado extends EstadoBanco<ChequeraPantalla> {
  String rol = 'emisor';
  int limite = 100;
  Future<void> asesor() async {
    final motivo = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertaBro(
        title: const Text('Tu asesor de cuenta'),
        content: TextField(
          controller: motivo,
          maxLength: 400,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '¿En qué podemos ayudarte?',
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(c),
            icon: const Icon(Icons.close_rounded, size: 19),

            label: const Text('Volver'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, motivo.text),
            icon: const Icon(Icons.send_rounded, size: 19),

            label: const Text('Enviar consulta'),
          ),
        ],
      ),
    );
    motivo.dispose();
    if (v != null) {
      await trabajar(() async {
        await llamar('solicitarAsesor', {
          'motivo': v,
          'referencia': nuevaReferencia(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tu asesor recibió la consulta. Te avisaremos cuando responda.',
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activa =
        ref
            .watch(cuentasProvider)
            .value
            ?.valor
            .any((c) => c.tipo == 'corriente' && c.activa) ??
        false;
    return pagina('Tu chequera digital', [
      const EncabezadoBro(
        'Acuerdos más claros',
        subtitulo: 'Controla lo que pagas y lo que vas a recibir.',
      ),
      if (!activa)
        CristalBro(
          child: Column(
            children: [
              const Icon(Icons.business_outlined, size: 40),
              const Text('Tu cuenta corriente activa habilita la chequera.'),
              OutlinedButton.icon(
                onPressed: () => context.push('/apertura/corriente'),
                icon: const Icon(Icons.business_center_outlined),
                label: const Text('Revisar cuenta corriente'),
              ),
            ],
          ),
        )
      else ...[
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/chequera/emitir'),
                icon: const Icon(Icons.post_add),
                label: const Text('Emitir cheques'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Contactar asesor',
              onPressed: ocupado ? null : asesor,
              icon: const Icon(Icons.support_agent),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'emisor',
              label: Text('Por pagar'),
              icon: Icon(Icons.north_east),
            ),
            ButtonSegment(
              value: 'receptor',
              label: Text('Por cobrar'),
              icon: Icon(Icons.south_west),
            ),
          ],
          selected: {rol},
          onSelectionChanged: (v) => setState(() => rol = v.first),
        ),
        const SizedBox(height: 16),
        ref
            .watch(chequesBroProvider(limite))
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(mensajeError(e)),
              data: (todos) {
                final lista = todos.where((c) => c['rol'] == rol).toList()
                  ..sort(
                    (a, b) => (a['fechaCobro'] as String).compareTo(
                      b['fechaCobro'] as String,
                    ),
                  );
                final pendientes = lista
                    .where(
                      (c) => !['cobrado', 'cancelado'].contains(c['estado']),
                    )
                    .fold<int>(0, (s, c) => s + (c['centavos'] as int));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CristalBro(
                      child: Row(
                        children: [
                          Icon(
                            rol == 'emisor'
                                ? Icons.schedule_send
                                : Icons.account_balance_wallet_outlined,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rol == 'emisor'
                                      ? 'Pendiente por abonar'
                                      : 'Pendiente por recibir',
                                ),
                                Text(
                                  usdCheque(pendientes),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(
                                  'El dinero se mueve al confirmar el cobro.',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (lista.isEmpty)
                      const CristalBro(
                        child: Text(
                          'Tus cheques aparecerán aquí con sus fechas y estados.',
                        ),
                      ),
                    for (final c in lista) chequeFila(context, c),
                    if (todos.length >= limite)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => limite += 100),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Ver más cheques'),
                      ),
                  ],
                );
              },
            ),
        if (rol == 'emisor') ...[
          const SizedBox(height: 24),
          const EncabezadoBro(
            'Tus agrupaciones',
            subtitulo: 'Un proveedor, un concepto, todos sus cheques.',
          ),
          ref
              .watch(gruposChequesProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(mensajeError(e)),
                data: (grupos) => Column(
                  children: [
                    for (final g in grupos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CristalBro(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.folder_open),
                            title: Text(g['receptor'] as String),
                            subtitle: Text(
                              '${g['concepto']}\n${g['emitidos']} cheques · ${usdCheque(g['pendienteCentavos'])} por abonar',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/chequera/grupos/${g['id']}'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
        ],
        for (final s
            in ref.watch(solicitudesBroProvider).value ??
                <Map<String, dynamic>>[])
          if (s['tipo'] == 'asesoria')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CristalBro(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent),
                  title: Text(s['motivo'] as String),
                  subtitle: Text(
                    s['respuesta'] as String? ??
                        'Tu asesor está revisando la consulta.',
                  ),
                ),
              ),
            ),
      ],
    ]);
  }
}

Widget chequeFila(BuildContext context, Map<String, dynamic> c) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: CristalBro(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (c['estado']) {
        'cobrado' => Icons.check_circle_outline,
        'cancelado' => Icons.cancel_outlined,
        'bloqueado' => Icons.lock_outline,
        _ => Icons.receipt_long_outlined,
      }),
      title: Text(c[c['rol'] == 'emisor' ? 'receptor' : 'emisor'] as String),
      subtitle: Text(
        '${c['concepto']}\n${c['fechaCobro']} · ${estadoCheque(c['estado'] as String)}',
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            usdCheque(c['centavos']),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
      onTap: () => context.push('/chequera/cheques/${c['id']}'),
    ),
  ),
);

class EmitirChequesPantalla extends ConsumerStatefulWidget {
  const EmitirChequesPantalla({super.key, this.grupo});
  final String? grupo;
  @override
  ConsumerState<EmitirChequesPantalla> createState() => _EmitirEstado();
}

class _EmitirEstado extends EstadoBanco<EmitirChequesPantalla> {
  final numero = TextEditingController(), concepto = TextEditingController();
  final montos = <TextEditingController>[TextEditingController()];
  int cantidad = 1;
  DateTime fecha = hoyEcuador();
  Map<String, dynamic>? receptor, g;
  bool acepta = false;
  final referencia = nuevaReferencia();
  @override
  void initState() {
    super.initState();
    if (widget.grupo != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => trabajar(() async {
          final uid = ref.read(identidadProvider).actual!.uid,
              s = await ref
                  .read(datosProvider)
                  .doc('usuarios/$uid/gruposCheques/${widget.grupo}')
                  .get()
                  .timeout(const Duration(seconds: 8));
          if (!s.exists) throw const FalloApp('No encontramos la agrupación.');
          g = s.data();
          numero.text = g!['numeroDestino'] as String;
          concepto.text = g!['concepto'] as String;
          receptor = {'titular': g!['receptor'], 'numero': numero.text};
          final siguiente = mesDigital(
            DateTime.parse(g!['ultimaFecha'] as String),
            1,
          );
          if (siguiente.isAfter(fecha)) fecha = siguiente;
        }),
      );
    }
  }

  @override
  void dispose() {
    numero.dispose();
    concepto.dispose();
    for (final m in montos) {
      m.dispose();
    }
    super.dispose();
  }

  void cambiarCantidad(int n) {
    setState(() {
      while (montos.length < n) {
        montos.add(TextEditingController(text: montos.first.text));
      }
      cantidad = n;
    });
  }

  Future<void> seleccionar() async {
    final f = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: hoyEcuador(),
      lastDate: hoyEcuador().add(const Duration(days: 1096)),
    );
    if (f != null) setState(() => fecha = f);
  }

  Future<void> emitir() => trabajar(() async {
    final cheques = List.generate(
      cantidad,
      (i) => {
        'centavos': montoCentavos(montos[i].text, maximo: 100000000),
        'fecha': fechaDigital(mesDigital(fecha, i)),
      },
    );
    final r = await llamar('emitirCheques', {
      'cuenta': 'corriente',
      'numero': numero.text.trim(),
      'concepto': concepto.text.trim(),
      if (widget.grupo != null) 'grupo': widget.grupo,
      'referencia': referencia,
      'aceptaEmision': acepta,
      'cheques': cheques,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${cantidad == 1 ? 'Cheque emitido' : '$cantidad cheques emitidos'}. El beneficiario recibió el aviso.',
          ),
        ),
      );
      context.go('/chequera/grupos/${r['grupo']}');
    }
  });
  @override
  Widget build(BuildContext context) => pagina(
    widget.grupo == null ? 'Emitir cheques' : 'Agregar cheques al grupo',
    [
      const EncabezadoBro(
        'Tu acuerdo, organizado',
        subtitulo: 'La primera fecha define el día de los cobros mensuales.',
      ),
      if (widget.grupo == null) ...[
        campo(
          numero,
          'Cuenta corriente del beneficiario',
          teclado: TextInputType.number,
          maximo: 14,
          key: const Key('cheque-numero'),
        ),
        OutlinedButton.icon(
          onPressed: ocupado
              ? null
              : () => trabajar(() async {
                  final v = await llamar('destinatario', {
                    'numero': numero.text.trim(),
                  });
                  if (v['tipo'] != 'corriente' || v['estado'] != 'activa') {
                    throw const FalloApp(
                      'El beneficiario necesita una cuenta corriente activa.',
                    );
                  }
                  setState(() => receptor = v);
                }),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Validar beneficiario'),
        ),
      ],
      if (receptor != null)
        CristalBro(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_outlined),
            title: Text(receptor!['titular'] as String),
            subtitle: Text(receptor!['numero'] as String),
          ),
        ),
      if (widget.grupo == null)
        campo(
          concepto,
          'Concepto de la agrupación',
          maximo: 100,
          key: const Key('cheque-concepto'),
        )
      else if (g != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(g!['concepto'] as String),
        ),
      DropdownButtonFormField<int>(
        initialValue: cantidad,
        decoration: const InputDecoration(
          labelText: 'Cantidad de cheques mensuales',
        ),
        items: [1, 3, 6, 12, 24]
            .map(
              (n) => DropdownMenuItem(
                value: n,
                child: Text('$n ${n == 1 ? 'cheque' : 'cheques'}'),
              ),
            )
            .toList(),
        onChanged: ocupado ? null : (n) => cambiarCantidad(n!),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: ocupado ? null : seleccionar,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text('Primer cobro · ${fechaDigital(fecha)}'),
      ),
      for (int i = 0; i < cantidad; i++)
        campo(
          montos[i],
          'Cheque ${i + 1} · ${fechaDigital(mesDigital(fecha, i))} · USD',
          teclado: const TextInputType.numberWithOptions(decimal: true),
          key: Key('cheque-monto-$i'),
        ),
      const CristalBro(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('Así funciona el cobro'),
          subtitle: Text(
            'Se cobrará automáticamente en la fecha acordada si hay fondos. Puedes mover cada cheque hasta 5 días después de su fecha original, bloquearlo o cancelarlo. Ambas personas reciben avisos y conservan el registro.',
          ),
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: acepta,
        onChanged: ocupado ? null : (v) => setState(() => acepta = v ?? false),
        title: const Text(
          'Revisé los valores y autorizo estos cobros.',
          style: TextStyle(fontSize: 13),
        ),
      ),
      FilledButton.icon(
        onPressed: ocupado || !acepta || receptor == null ? null : emitir,
        icon: const Icon(Icons.send_outlined),
        label: const Text('Emitir y avisar al beneficiario'),
      ),
    ],
  );
}

class GrupoChequesPantalla extends ConsumerWidget {
  const GrupoChequesPantalla(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref
        .watch(gruposChequesProvider)
        .value
        ?.where((v) => v['id'] == id)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: const VolverBro(),
        title: const Text('Tu agrupación'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (g != null) ...[
            EncabezadoBro(
              g['receptor'] as String,
              subtitulo: g['concepto'] as String,
            ),
            CristalBro(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${g['emitidos']} cheques emitidos'),
                  Text(
                    '${usdCheque(g['pendienteCentavos'])} por abonar',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${usdCheque(g['cobradoCentavos'])} cobrados · ${usdCheque(g['canceladoCentavos'])} cancelados',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: () => context.push('/chequera/emitir?grupo=$id'),
            icon: const Icon(Icons.add),
            label: const Text('Agregar otro lote de cheques'),
          ),
          const SizedBox(height: 20),
          ref
              .watch(chequesBroProvider(2400))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(mensajeError(e)),
                data: (lista) => Column(
                  children: [
                    for (final c
                        in lista
                            .where(
                              (c) => c['rol'] == 'emisor' && c['grupo'] == id,
                            )
                            .toList()
                          ..sort(
                            (a, b) => (a['fechaOriginal'] as String).compareTo(
                              b['fechaOriginal'] as String,
                            ),
                          ))
                      chequeFila(context, c),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class ChequeDetallePantalla extends ConsumerStatefulWidget {
  const ChequeDetallePantalla(this.id, {super.key});
  final String id;
  @override
  ConsumerState<ChequeDetallePantalla> createState() => _ChequeDetalleEstado();
}

class _ChequeDetalleEstado extends EstadoBanco<ChequeDetallePantalla> {
  Future<void> gestionar(Map<String, dynamic> c, String accion) async {
    DateTime? fecha;
    if (accion == 'posponer') {
      final base = DateTime.parse(c['fechaOriginal'] as String),
          hoy = hoyEcuador(),
          max = base.add(const Duration(days: 5)),
          min = base.isAfter(hoy) ? base : hoy;
      if (min.isAfter(max)) {
        setState(
          () => error = 'La ventana de cambio terminó. Puedes revisar los fondos o contactar a tu asesor.',
        );
        return;
      }
      fecha = await showDatePicker(
        context: context,
        initialDate: min,
        firstDate: min,
        lastDate: max,
      );
      if (fecha == null) return;
    }
    if (!mounted) return;
    final motivo = TextEditingController();
    final nota = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertaBro(
        title: Text(switch (accion) {
          'posponer' => 'Cambiar fecha de cobro',
          'bloquear' => 'Bloquear cheque',
          'desbloquear' => 'Reactivar cheque',
          _ => 'Cancelar cheque',
        }),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El beneficiario recibirá un aviso. El histórico se conserva.',
            ),
            TextField(
              controller: motivo,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close_rounded, size: 19),

            label: const Text('Volver'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, motivo.text),
            icon: const Icon(Icons.check_rounded, size: 19),

            label: const Text('Confirmar cambio'),
          ),
        ],
      ),
    );
    motivo.dispose();
    if (nota == null) return;
    await trabajar(() async {
      await llamar('gestionarCheque', {
        'id': widget.id,
        'accion': accion,
        'nota': nota,
        'referencia': nuevaReferencia(),
        if (fecha != null) 'fecha': fechaDigital(fecha),
      });
    });
  }

  @override
  Widget build(BuildContext context) => pagina('Detalle del cheque', [
    ref
        .watch(detalleChequeProvider(widget.id))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensajeError(e)),
          data: (c) {
            if (c == null) return const Text('No encontramos este cheque.');
            final cerrado = ['cobrado', 'cancelado'].contains(c['estado']),
                emisor = c['rol'] == 'emisor';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CristalBro(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              estadoCheque(c['estado'] as String),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        usdCheque(c['centavos']),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(c['concepto'] as String),
                      const Divider(height: 32),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          emisor
                              ? c['receptor'] as String
                              : c['emisor'] as String,
                        ),
                        subtitle: Text(
                          emisor
                              ? c['numeroDestino'] as String
                              : c['numeroOrigen'] as String,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: Text('Cobro ${c['fechaCobro']}'),
                        subtitle: Text(
                          'Fecha original ${c['fechaOriginal']} · cambio máximo ${fechaDigital(DateTime.parse(c['fechaOriginal'] as String).add(const Duration(days: 5)))}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!cerrado &&
                    c['estado'] != 'bloqueado' &&
                    (c['fechaCobro'] as String).compareTo(
                          fechaDigital(hoyEcuador()),
                        ) <=
                        0)
                  FilledButton.icon(
                    onPressed: ocupado
                        ? null
                        : () => trabajar(() async {
                            final r = await llamar('cobrarCheque', {
                              'id': widget.id,
                            });
                            if (r['estado'] == 'pendiente_fondos') {
                              throw const FalloApp(
                                'El cobro sigue pendiente. No descontamos fondos.',
                              );
                            }
                          }),
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Reintentar cobro ahora'),
                  ),
                if (emisor && !cerrado)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: ocupado
                            ? null
                            : () => gestionar(c, 'posponer'),
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Cambiar fecha'),
                      ),
                      OutlinedButton.icon(
                        onPressed: ocupado
                            ? null
                            : () => gestionar(
                                c,
                                c['estado'] == 'bloqueado'
                                    ? 'desbloquear'
                                    : 'bloquear',
                              ),
                        icon: Icon(
                          c['estado'] == 'bloqueado'
                              ? Icons.lock_open
                              : Icons.lock_outline,
                        ),
                        label: Text(
                          c['estado'] == 'bloqueado' ? 'Reactivar' : 'Bloquear',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: ocupado
                            ? null
                            : () => gestionar(c, 'cancelar'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar cheque'),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
    const SizedBox(height: 24),
    const EncabezadoBro('Cada paso queda registrado'),
    ref
        .watch(eventosChequeProvider(widget.id))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensajeError(e)),
          data: (items) => Column(
            children: [
              for (final v in items)
                CristalBro(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(v['mensaje'] as String),
                    subtitle: Text(
                      '${v['fechaCobro']} · ${estadoCheque(v['estado'] as String)}',
                    ),
                  ),
                ),
            ],
          ),
        ),
  ]);
}
