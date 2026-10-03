import '../features/exchange/divisas_pantalla.dart';
import '../features/payments/qr_pantalla.dart';
import '../features/savings/metas_pantalla.dart';
import '../features/notifications/notificaciones_pantalla.dart';
import '../core/laboratorio_pantalla.dart';
import '../core/configuracion.dart';
import '../features/experience/perfil_pantalla.dart';
import '../features/accounts/inicio_pantalla.dart';
export '../features/accounts/inicio_pantalla.dart';
import '../features/auth/bienvenida_pantalla.dart';
import '../core/diseno_bro.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/acceso_pantalla.dart';
import '../features/accounts/cuentas_pantalla.dart';
import '../features/accounts/movimientos_pantalla.dart';
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
          GoRoute(path: '/divisas', builder: (_, _) => const DivisasPantalla()),
          GoRoute(path: '/qr', builder: (_, _) => const QrPantalla()),
          GoRoute(path: '/metas', builder: (_, _) => const MetasPantalla()),
          GoRoute(path: '/perfil', builder: (_, _) => const PerfilPantalla()),
        ],
      ),
      if (habilitarLaboratorio)
        GoRoute(
          path: '/laboratorio',
          builder: (_, _) => const LaboratorioPantalla(),
        ),
      GoRoute(
        path: '/notificaciones',
        builder: (_, _) => const NotificacionesPantalla(),
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

class NavegacionPantalla extends StatelessWidget {
  const NavegacionPantalla(this.ruta, this.child, {super.key});
  final String ruta;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    const destinos = ['/inicio', '/cuentas', '/qr', '/metas', '/perfil'];
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: CristalBro(
          radio: 28,
          padding: EdgeInsets.zero,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 74,
            indicatorColor: naranjaFinanceBro.withValues(alpha: .45),
            selectedIndex: destinos.indexOf(ruta).clamp(0, 4),
            onDestinationSelected: (i) => context.go(destinos[i]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Cuentas',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_rounded),
                label: 'QR',
              ),
              NavigationDestination(
                icon: Icon(Icons.savings_outlined),
                label: 'Metas',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Mi perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
