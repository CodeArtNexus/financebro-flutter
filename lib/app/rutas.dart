import 'dart:ui';

import '../features/auth/acceso_rapido.dart';
import '../features/banking/apertura_pantallas.dart';
import '../features/banking/contactos_pantalla.dart';
import '../features/banking/pagos_pantalla.dart';
import '../features/banking/tarjetas_pantalla.dart';
import '../features/banking/solicitudes_tarjetas.dart';
import '../features/banking/credito_pantalla.dart';
import '../features/banking/historial_pantalla.dart';
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/acceso_pantalla.dart';
import '../features/accounts/cuentas_pantalla.dart';

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
    initialLocation:
        RecuerdoAcceso.leer(ref.read(preferenciasLocalesProvider)) == null
        ? '/bienvenida'
        : '/ingresar',
    refreshListenable: actualizar,
    redirect: (context, state) {
      final acceso = [
        '/bienvenida',
        '/ingresar',
        '/registrar',
        '/qr-acceso',
      ].contains(state.matchedLocation);
      if (identidad.actual == null && !acceso) return '/ingresar';
      if (identidad.actual != null && identidad.requiereRegistro) {
        return state.matchedLocation == '/registrar' ? null : '/registrar';
      }
      if (identidad.actual != null && acceso) {
        final preferencias = ref.read(preferenciasLocalesProvider);
        if (preferencias.containsKey('qr_pendiente')) return '/qr';
        return '/inicio';
      }
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
      GoRoute(
        path: '/qr-acceso',
        builder: (_, _) => const QrPantalla(accesoRapido: true),
      ),
      GoRoute(path: '/apertura/ahorros', redirect: (_, _) => '/registrar'),
      GoRoute(
        path: '/apertura/corriente',
        builder: (_, _) => const AperturaCorrientePantalla(),
      ),
      GoRoute(path: '/contactos', builder: (_, _) => const ContactosPantalla()),
      GoRoute(
        path: '/tarjetas/credito/detalle',
        builder: (_, _) => const CreditoDetallePantalla(),
      ),
      GoRoute(path: '/tarjetas', builder: (_, _) => const TarjetasPantalla()),
      GoRoute(
        path: '/tarjetas/credito',
        builder: (_, _) => const CreditoSolicitudPantalla(),
      ),
      GoRoute(
        path: '/tarjetas/fisica/:tarjeta',
        builder: (_, s) =>
            FisicaSolicitudPantalla(s.pathParameters['tarjeta']!),
      ),
      GoRoute(
        path: '/historial',
        builder: (_, s) => HistorialPantalla(
          tipo: s.uri.queryParameters['tipo'],
          destino: s.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/transferir',
        builder: (_, s) =>
            QrPantalla(numeroInicial: s.uri.queryParameters['numero']),
      ),
      GoRoute(
        path: '/pagar-externo',
        builder: (_, s) => PagoExternoPantalla(
          tipo: s.uri.queryParameters['tipo'] ?? 'contacto',
          destino: s.uri.queryParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/pagos/:servicio',
        builder: (_, s) => ServicioPagoPantalla(s.pathParameters['servicio']!),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            NavegacionPantalla(state.uri.path, child),
        routes: [
          GoRoute(path: '/inicio', builder: (_, _) => const InicioPantalla()),
          GoRoute(path: '/cuentas', builder: (_, _) => const CuentasPantalla()),
          GoRoute(path: '/divisas', builder: (_, _) => const DivisasPantalla()),
          GoRoute(
            path: '/qr',
            builder: (_, s) => QrPantalla(
              recibirInicial: s.uri.queryParameters['recibir'] == 'true',
            ),
          ),
          GoRoute(path: '/pagos', builder: (_, _) => const PagosPantalla()),
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
            HistorialPantalla(cuenta: state.pathParameters['cuenta']!),
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
    const destinos = ['/inicio', '/cuentas', '/qr', '/pagos', '/perfil'];
    return Scaffold(
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: 84 + MediaQuery.paddingOf(context).bottom,
        ),
        child: child,
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MediaQuery.highContrastOf(context)
                  ? Colors.white
                  : Colors.white.withValues(alpha: .82),
              border: const Border(top: BorderSide(color: Colors.white)),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 80,
              indicatorColor: naranjaFinanceBro.withValues(alpha: .42),
              selectedIndex: destinos.indexOf(ruta).clamp(0, 4),
              onDestinationSelected: (i) => context.go(destinos[i]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  label: 'Cuentas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_scanner_rounded),
                  label: 'QR',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Pagos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Mi perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
