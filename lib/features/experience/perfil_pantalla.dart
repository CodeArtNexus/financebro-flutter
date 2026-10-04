import 'package:go_router/go_router.dart';

import '../../core/configuracion.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/proveedores.dart';
import '../../core/componentes.dart';
import '../../core/diseno_bro.dart';
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
  Future<void> _salir() async {
    setState(() => _guardando = true);
    try {
      await ref.read(notificacionesRepositorioProvider).desconectar();
      await ref.read(identidadProvider).salir();
    } catch (e) {
      if (mounted) setState(() => _mensaje = mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

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
    appBar: AppBar(leading: const VolverBro(), title: const Text('Mi perfil')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CristalBro(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFFFDCC4),
                child: Text(
                  (ref.watch(sesionProvider).value?.nombre ?? 'Bro')
                      .split(' ')
                      .where((v) => v.isNotEmpty)
                      .take(2)
                      .map((v) => v[0])
                      .join(),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ref.watch(sesionProvider).value?.nombre ?? 'Tu perfil',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Tus datos, tus preferencias, tu espacio.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => context.push('/cuentas'),
          icon: const Icon(Icons.account_balance_outlined),
          label: const Text('Mis cuentas'),
        ),
        const SizedBox(height: 20),
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
        ListTile(
          title: const Text('Divisas'),
          leading: const Icon(Icons.currency_exchange_rounded),
          onTap: () => context.push('/divisas'),
        ),
        ListTile(
          title: const Text('Olvidar mi saludo en este dispositivo'),
          leading: const Icon(Icons.person_remove_outlined),
          onTap: () async {
            await ref.read(preferenciasLocalesProvider).remove('saludo_bro_v1');
            ref.invalidate(recuerdoAccesoProvider);
            if (mounted) {
              setState(() => _mensaje = 'Tu saludo recordado se ha eliminado.');
            }
          },
        ),
        if (habilitarLaboratorio)
          ListTile(
            title: const Text('Laboratorio de conexión'),
            leading: const Icon(Icons.science_outlined),
            onTap: () => context.push('/laboratorio'),
          ),
        ListTile(
          title: const Text('Notificaciones'),
          leading: const Icon(Icons.notifications_outlined),
          onTap: () => context.push('/notificaciones'),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: _guardando ? null : _salir,
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
}
