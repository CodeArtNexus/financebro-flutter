import '../core/conexion_pantalla.dart';
import '../features/banking/pendientes_pantalla.dart';
import '../features/banking/chequera_pantallas.dart';

import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPage;

import '../features/banking/contacto_detalle_pantalla.dart';

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
        '/conexion',
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
      pantalla('/conexion', (_) => const ConexionPantalla()),
      pantalla('/bienvenida', (_) => const BienvenidaPantalla()),
      pantalla('/ingresar', (_) => const AccesoPantalla()),
      pantalla('/registrar', (_) => const AccesoPantalla(registro: true)),
      pantalla('/qr-acceso', (_) => const QrPantalla(accesoRapido: true)),
      ShellRoute(
        builder: (context, state, child) =>
            NavegacionPantalla(state.uri.path, child),
        routes: [
          pantalla('/pendientes', (_) => const PendientesPantalla()),
          pantalla('/inicio', (_) => const InicioPantalla()),
          pantalla('/cuentas', (_) => const CuentasPantalla()),
          pantalla(
            '/cuentas/:cuenta',
            (s) => HistorialPantalla(cuenta: s.pathParameters['cuenta']!),
          ),
          pantalla('/divisas', (_) => const DivisasPantalla()),
          pantalla(
            '/qr',
            (s) => QrPantalla(
              recibirInicial: s.uri.queryParameters['recibir'] == 'true',
            ),
          ),
          pantalla(
            '/transferir',
            (s) => QrPantalla(numeroInicial: s.uri.queryParameters['numero']),
          ),
          pantalla('/pagos', (_) => const PagosPantalla()),
          pantalla(
            '/pagos/:servicio',
            (s) => ServicioPagoPantalla(s.pathParameters['servicio']!),
          ),
          pantalla('/metas', (_) => const MetasPantalla()),
          pantalla('/perfil', (_) => const PerfilPantalla()),
          pantalla('/notificaciones', (_) => const NotificacionesPantalla()),
          GoRoute(path: '/apertura/ahorros', redirect: (_, _) => '/cuentas'),
          pantalla(
            '/apertura/corriente',
            (_) => const AperturaCorrientePantalla(),
          ),
          pantalla('/chequera', (_) => const ChequeraPantalla()),
          pantalla(
            '/chequera/emitir',
            (s) => EmitirChequesPantalla(grupo: s.uri.queryParameters['grupo']),
          ),
          pantalla(
            '/chequera/grupos/:grupo',
            (s) => GrupoChequesPantalla(s.pathParameters['grupo']!),
          ),
          pantalla(
            '/chequera/cheques/:cheque',
            (s) => ChequeDetallePantalla(s.pathParameters['cheque']!),
          ),
          pantalla('/contactos', (_) => const ContactosPantalla()),
          pantalla(
            '/contactos/:contacto',
            (s) => ContactoDetallePantalla(s.pathParameters['contacto']!),
          ),
          pantalla('/tarjetas', (_) => const TarjetasPantalla()),
          pantalla(
            '/tarjetas/credito',
            (_) => const CreditoSolicitudPantalla(),
          ),
          pantalla(
            '/tarjetas/credito/detalle',
            (s) => CreditoDetallePantalla(
              pagoInicial: s.uri.queryParameters['pagar'] == 'true',
            ),
          ),
          pantalla(
            '/tarjetas/fisica/:tarjeta',
            (s) => FisicaSolicitudPantalla(s.pathParameters['tarjeta']!),
          ),
          pantalla(
            '/historial',
            (s) => HistorialPantalla(
              tipo: s.uri.queryParameters['tipo'],
              destino: s.uri.queryParameters['id'],
            ),
          ),
          pantalla(
            '/pagar-externo',
            (s) => PagoExternoPantalla(
              tipo: s.uri.queryParameters['tipo'] ?? 'contacto',
              destino: s.uri.queryParameters['id'] ?? '',
            ),
          ),
          if (habilitarLaboratorio)
            pantalla('/laboratorio', (_) => const LaboratorioPantalla()),
        ],
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
    const destinos = ['/inicio', '/tarjetas', '/qr', '/pagos', '/perfil'];
    final indice = destinos.indexWhere(
      (d) => ruta == d || ruta.startsWith('$d/'),
    );
    final seleccionado = indice < 0 ? 0 : indice;
    return Scaffold(
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: 84 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          children: [
            const AvisoConexion(),
            Expanded(child: child),
          ],
        ),
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
              selectedIndex: seleccionado,
              onDestinationSelected: (i) => context.go(destinos[i]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.credit_card_outlined),
                  label: 'Tarjetas',
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

GoRoute pantalla(String ruta, Widget Function(GoRouterState) construir) =>
    GoRoute(
      path: ruta,
      pageBuilder: (context, state) =>
          Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoPage<void>(key: state.pageKey, child: construir(state))
          : MaterialPage<void>(key: state.pageKey, child: construir(state)),
    );
