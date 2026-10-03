import '../features/experience/perfil_pantalla.dart';
import '../features/experience/tarjeta_remota.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/acceso_pantalla.dart';
import '../features/accounts/cuentas_pantalla.dart';
import '../features/accounts/movimientos_pantalla.dart';
import '../core/componentes.dart';
import 'proveedores.dart';
import 'tema.dart';

class _ActualizarSesion extends ChangeNotifier {
  _ActualizarSesion(Stream<Object?> cambios) {
    _suscripcion = cambios.listen((_) => notifyListeners());
  }
  late final StreamSubscription<Object?> _suscripcion;
  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}

final rutasProvider = Provider<GoRouter>((ref) {
  final identidad = ref.watch(identidadProvider);
  final actualizar = _ActualizarSesion(identidad.cambios);
  final router = GoRouter(
    initialLocation: '/bienvenida',
    refreshListenable: actualizar,
    redirect: (context, state) {
      final acceso = [
        '/bienvenida',
        '/ingresar',
        '/registrar',
      ].contains(state.matchedLocation);
      if (identidad.actual == null && !acceso) return '/ingresar';
      if (identidad.actual != null && acceso) return '/inicio';
      return null;
    },
    routes: [
      GoRoute(
        path: '/bienvenida',
        builder: (_, _) => const BienvenidaPantalla(),
      ),
      GoRoute(path: '/ingresar', builder: (_, _) => const AccesoPantalla()),
      GoRoute(
        path: '/registrar',
        builder: (_, _) => const AccesoPantalla(registro: true),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            NavegacionPantalla(state.uri.path, child),
        routes: [
          GoRoute(path: '/inicio', builder: (_, _) => const InicioPantalla()),
          GoRoute(path: '/cuentas', builder: (_, _) => const CuentasPantalla()),
          GoRoute(
            path: '/divisas',
            builder: (_, _) => const _PendientePantalla('Divisas'),
          ),
          GoRoute(path: '/perfil', builder: (_, _) => const PerfilPantalla()),
        ],
      ),
      GoRoute(
        path: '/cuentas/:cuenta',
        builder: (_, state) =>
            MovimientosPantalla(state.pathParameters['cuenta']!),
      ),
    ],
    errorBuilder: (_, _) => const Scaffold(
      body: Center(child: Text('Esta página no está disponible.')),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    actualizar.dispose();
  });
  return router;
});

class BienvenidaPantalla extends StatelessWidget {
  const BienvenidaPantalla({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 80,
                  color: naranjaFinanceBro,
                ),
                const SizedBox(height: 24),
                Text(
                  'FinanceBro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tus finanzas, a tu ritmo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Todo tu dinero en un espacio. Descubre una experiencia que se adapta a ti.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go('/registrar'),
                  child: const Text('Empezar'),
                ),
                TextButton(
                  onPressed: () => context.go('/ingresar'),
                  child: const Text('Ya tengo una cuenta'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Entorno de evaluación. Los datos financieros son de prueba.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class NavegacionPantalla extends StatelessWidget {
  const NavegacionPantalla(this.ruta, this.child, {super.key});
  final String ruta;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    const destinos = ['/inicio', '/cuentas', '/divisas', '/perfil'];
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: destinos.indexOf(ruta).clamp(0, 3),
        onDestinationSelected: (i) => context.go(destinos[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Cuentas',
          ),
          NavigationDestination(
            icon: Icon(Icons.currency_exchange),
            label: 'Divisas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Mi perfil',
          ),
        ],
      ),
    );
  }
}

class InicioPantalla extends ConsumerWidget {
  const InicioPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).value;
    final mostrarSaldo =
        ref.watch(perfilProvider).value?.valor.mostrarSaldo ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('FinanceBro')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hola, ${usuario?.nombre ?? "bienvenido"}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Hoy es un buen día para cuidar tus finanzas.'),
          const SizedBox(height: 24),
          ref
              .watch(cuentasProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    PanelError(e, () => ref.invalidate(cuentasProvider)),
                data: (datos) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: naranjaFinanceBro,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tu saldo total',
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              mostrarSaldo
                                  ? dinero(
                                      datos.valor.fold(
                                        0,
                                        (s, c) => s + c.saldoCentavos,
                                      ),
                                    )
                                  : "••••••",
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (datos.desdeCache) AvisoCache(datos.actualizado),
                    const SizedBox(height: 16),
                    Text(
                      'Tus cuentas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (datos.valor.isEmpty)
                      const PanelEstado(
                        titulo: 'Tu espacio está listo',
                        mensaje: 'Todavía no tienes cuentas asignadas.',
                      ),
                    for (final cuenta in datos.valor) TarjetaCuenta(cuenta),
                  ],
                ),
              ),
          const SizedBox(height: 24),
          Text('Para ti', style: Theme.of(context).textTheme.titleLarge),
          ref
              .watch(contenidoProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    PanelError(e, () => ref.invalidate(contenidoProvider)),
                data: (experiencia) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final tarjeta in experiencia.paraPerfil(
                      ref.watch(perfilProvider).value?.valor.segmento ??
                          'equilibrio',
                    ))
                      TarjetaContenido(tarjeta),
                    if (experiencia.respaldo)
                      const Text(
                        'Mostramos el contenido disponible mientras actualizamos tu experiencia.',
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _PendientePantalla extends StatelessWidget {
  const _PendientePantalla(this.nombre);
  final String nombre;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(nombre)),
    body: const PanelEstado(
      titulo: 'En construcción',
      mensaje: 'Esta funcionalidad se integra en la siguiente etapa.',
    ),
  );
}
