import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/errores.dart';
import 'experiencia.dart';

class PerfilPantalla extends ConsumerStatefulWidget {
  const PerfilPantalla({super.key});
  @override
  ConsumerState<PerfilPantalla> createState() => _PerfilEstado();
}

class _PerfilEstado extends ConsumerState<PerfilPantalla> {
  String? _segmento;
  bool? _mostrar;
  bool _guardando = false;
  String? _mensaje;
  Future<void> _guardar(Perfil perfil) async {
    setState(() {
      _guardando = true;
      _mensaje = null;
    });
    try {
      await ref
          .read(experienciaRepositorioProvider)
          .guardarPerfil(
            ref.read(identidadProvider).actual!.uid,
            Perfil(
              nombre: perfil.nombre,
              segmento: _segmento ?? perfil.segmento,
              mostrarSaldo: _mostrar ?? perfil.mostrarSaldo,
            ),
          );
      if (mounted) {
        setState(() => _mensaje = 'Tus preferencias están actualizadas.');
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _mensaje = 'Guardadas en el dispositivo. Se sincronizarán al recuperar la conexión.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _mensaje = mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi perfil')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Una experiencia hecha para ti',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Elige qué te interesa. Tu inicio mostrará contenido relevante para ese momento de tu vida.',
        ),
        const SizedBox(height: 24),
        ref
            .watch(perfilProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  PanelError(e, () => ref.invalidate(perfilProvider)),
              data: (datos) {
                final perfil = datos.valor;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _segmento ?? perfil.segmento,
                      decoration: const InputDecoration(
                        labelText: 'Mi prioridad',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'equilibrio',
                          child: Text('Organizar mis finanzas'),
                        ),
                        DropdownMenuItem(
                          value: 'ahorro',
                          child: Text('Ahorrar con intención'),
                        ),
                        DropdownMenuItem(
                          value: 'viajes',
                          child: Text('Preparar mi próximo viaje'),
                        ),
                      ],
                      onChanged: _guardando
                          ? null
                          : (v) => setState(() => _segmento = v),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Mostrar mis saldos'),
                      value: _mostrar ?? perfil.mostrarSaldo,
                      onChanged: _guardando
                          ? null
                          : (v) => setState(() => _mostrar = v),
                    ),
                    if (datos.pendiente || datos.desdeCache)
                      AvisoCache(datos.actualizado, pendiente: datos.pendiente),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _guardando ? null : () => _guardar(perfil),
                      child: Text(
                        _guardando ? 'Guardando…' : 'Guardar preferencias',
                      ),
                    ),
                  ],
                );
              },
            ),
        if (_mensaje != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(liveRegion: true, child: Text(_mensaje!)),
          ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: _guardando
              ? null
              : () => ref.read(identidadProvider).salir(),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
}
