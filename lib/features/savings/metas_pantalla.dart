import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/proveedores.dart';
import '../../app/tema.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import '../accounts/cuentas.dart';
import '../exchange/divisas.dart';
import 'metas.dart';

class MetasPantalla extends ConsumerWidget {
  const MetasPantalla({super.key});
  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    List<Cuenta> cuentas, [
    MetaAhorro? meta,
  ]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditorMeta(cuentas: cuentas, meta: meta),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(cuentasProvider).value;
    final cuentas = datos?.valor ?? <Cuenta>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Mis metas')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const EncabezadoBro(
            'Lo que sueñas, paso a paso.',
            subtitulo: 'Dale un nombre a tu próximo plan.',
          ),
          CristalBro(
            color: naranjaFinanceBro.withValues(alpha: .16),
            child: const Row(
              children: [
                Icon(Icons.savings_outlined, size: 42, color: naranjaTextoBro),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Configura un objetivo y un aporte mensual. Tú decides el ritmo.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('nueva-meta'),
            onPressed: cuentas.isEmpty
                ? null
                : () => _editar(context, ref, cuentas),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear una meta'),
          ),
          if (cuentas.isEmpty)
            ref
                .watch(cuentasProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) =>
                      PanelError(e, () => ref.invalidate(cuentasProvider)),
                  data: (_) =>
                      const Text('Asocia una cuenta para empezar tu plan.'),
                ),
          if (datos?.desdeCache == true) AvisoCache(datos!.actualizado),
          const SizedBox(height: 18),
          ref
              .watch(metasProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    PanelError(e, () => ref.invalidate(metasProvider)),
                data: (metas) => Column(
                  children: [
                    if (metas.isEmpty)
                      const PanelEstado(
                        titulo: 'Tus planes empiezan aquí',
                        mensaje: 'Un viaje, tu fondo de tranquilidad o ese próximo gran paso.',
                      ),
                    for (final meta in metas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CristalBro(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.flag_outlined,
                                    color: naranjaTextoBro,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      meta.nombre,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar ${meta.nombre}',
                                    onPressed: cuentas.isEmpty
                                        ? null
                                        : () => _editar(
                                            context,
                                            ref,
                                            cuentas,
                                            meta,
                                          ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Objetivo ${dinero(meta.objetivo)}',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (cuentas.any((c) => c.id == meta.cuenta)) ...[
                                Builder(
                                  builder: (_) {
                                    final cuenta = cuentas.firstWhere(
                                      (c) => c.id == meta.cuenta,
                                    );
                                    final mostrar =
                                        ref
                                            .watch(perfilProvider)
                                            .value
                                            ?.valor
                                            .mostrarSaldo ??
                                        false;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(
                                          value: mostrar
                                              ? meta.progreso(
                                                  cuenta.saldoCentavos,
                                                )
                                              : 0,
                                          minHeight: 8,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: naranjaTextoBro,
                                          backgroundColor: naranjaFinanceBro
                                              .withValues(alpha: .2),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '${cuenta.nombre} · ${mostrar ? dinero(cuenta.saldoCentavos) : '••••••'}',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        if (mostrar)
                                          Text(
                                            '${(meta.progreso(cuenta.saldoCentavos) * 100).round()}% del objetivo · ${meta.mesesPendientes(cuenta.saldoCentavos)} meses estimados',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                '${dinero(meta.aporteMensual)} al mes · ${DateFormat('dd/MM/yyyy').format(meta.fecha)}',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Proyección con el saldo de tu cuenta. Los fondos no están reservados y no hay débitos automáticos.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
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
}

class _EditorMeta extends ConsumerStatefulWidget {
  const _EditorMeta({required this.cuentas, this.meta});
  final List<Cuenta> cuentas;
  final MetaAhorro? meta;
  @override
  ConsumerState<_EditorMeta> createState() => _EditorEstado();
}

class _EditorEstado extends ConsumerState<_EditorMeta> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre, _objetivo, _aporte;
  late String _cuenta;
  late DateTime _fecha;
  bool _guardando = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final meta = widget.meta;
    _nombre = TextEditingController(text: meta?.nombre ?? '');
    _objetivo = TextEditingController(
      text: meta == null ? '' : (meta.objetivo / 100).toStringAsFixed(2),
    );
    _aporte = TextEditingController(
      text: meta == null ? '' : (meta.aporteMensual / 100).toStringAsFixed(2),
    );
    _cuenta = widget.cuentas.any((c) => c.id == meta?.cuenta)
        ? meta!.cuenta
        : widget.cuentas.first.id;
    _fecha = meta?.fecha ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _objetivo.dispose();
    _aporte.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final meta = MetaAhorro(
        id:
            widget.meta?.id ??
            'meta-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(999999)}',
        nombre: _nombre.text.trim(),
        cuenta: _cuenta,
        objetivo: leerCentavos(_objetivo.text)!,
        aporteMensual: leerCentavos(_aporte.text)!,
        fecha: _fecha,
      );
      await ref
          .read(metasRepositorioProvider)
          .guardar(ref.read(identidadProvider).actual!.uid, meta);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertaBro(
        title: const Text('¿Eliminar este plan?'),
        content: const Text('El saldo de tu cuenta se conserva.'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),

            label: const Text('Conservar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline, size: 19),

            label: const Text('Eliminar plan'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(metasRepositorioProvider)
          .eliminar(ref.read(identidadProvider).actual!.uid, widget.meta!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertaBro(
    title: Text(widget.meta == null ? 'Tu próxima meta' : 'Editar mi plan'),
    content: SingleChildScrollView(
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('nombre-meta'),
              controller: _nombre,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Nombre de tu plan'),
              validator: (v) => (v?.trim().length ?? 0) < 2
                  ? 'Dale un nombre de al menos 2 letras.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('objetivo-meta'),
              controller: _objetivo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Objetivo en USD'),
              validator: (v) {
                final valor = leerCentavos(v ?? '');
                return valor == null || valor < 100 || valor > 100000000
                    ? 'Usa un importe entre USD 1 y 1.000.000.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('aporte-meta'),
              controller: _aporte,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Aporte mensual en USD',
              ),
              validator: (v) {
                final valor = leerCentavos(v ?? '');
                return valor == null ||
                        valor < 100 ||
                        valor > (leerCentavos(_objetivo.text) ?? 0)
                    ? 'Usa un aporte entre USD 1 y tu objetivo.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cuenta,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cuenta de referencia',
              ),
              items: widget.cuentas
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _guardando
                  ? null
                  : (v) => setState(() => _cuenta = v!),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _guardando
                  ? null
                  : () async {
                      final manana = DateTime.now().add(
                        const Duration(days: 1),
                      );
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: _fecha.isBefore(manana) ? manana : _fecha,
                        firstDate: manana,
                        lastDate: DateTime.now().add(
                          const Duration(days: 3652),
                        ),
                      );
                      if (fecha != null && mounted) {
                        setState(() => _fecha = fecha);
                      }
                    },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Hasta ${DateFormat('dd/MM/yyyy').format(_fecha)}'),
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
          ],
        ),
      ),
    ),
    actions: [
      if (widget.meta != null)
        TextButton.icon(
          onPressed: _guardando ? null : _eliminar,
          icon: const Icon(Icons.delete_outline, size: 19),

          label: const Text('Eliminar'),
        ),
      TextButton.icon(
        onPressed: _guardando ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded, size: 19),

        label: const Text('Cancelar'),
      ),
      FilledButton.icon(
        key: const Key('guardar-meta'),
        onPressed: _guardando ? null : _guardar,
        icon: const Icon(Icons.check_circle_outline, size: 19),

        label: Text(_guardando ? 'Guardando…' : 'Guardar plan'),
      ),
    ],
  );
}
