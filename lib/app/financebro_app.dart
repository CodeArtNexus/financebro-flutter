import '../features/banking/pendientes_pantalla.dart';

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'rutas.dart';
import 'tema.dart';
import 'proveedores.dart';
import '../core/errores.dart';
import '../core/diseno_bro.dart';

final mensajero = GlobalKey<ScaffoldMessengerState>();

final avisosSesionProvider = Provider<void>((ref) {
  final usuario = ref.watch(sesionProvider).value;
  if (usuario == null) return;
  final repositorio = ref.watch(notificacionesRepositorioProvider);
  final router = ref.watch(rutasProvider);
  final suscripcion = repositorio.recibidas.listen((aviso) {
    mensajero.currentState?.showSnackBar(
      SnackBar(
        content: Text(aviso.texto),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => router.push(aviso.destino),
        ),
      ),
    );
  });
  unawaited(
    repositorio
        .conectar(usuario.uid, (ruta) {
          router.push(ruta);
        })
        .catchError((Object e) {
          registrarEvento('push_no_disponible', servicio: 'notificaciones');
        }),
  );
  ref.onDispose(suscripcion.cancel);
});

class FinanceBroApp extends ConsumerWidget {
  const FinanceBroApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(avisosSesionProvider);
    if (ref.watch(sesionProvider).value != null) {
      ref.watch(colaTransferenciasProvider);
    }
    return MaterialApp.router(
      scaffoldMessengerKey: mensajero,
      title: 'FinanceBro',
      debugShowCheckedModeBanner: false,
      theme: crearTema(),
      locale: const Locale('es', 'EC'),
      supportedLocales: const [Locale('es', 'EC')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(rutasProvider),
      builder: (context, child) => FondoBro(child: child!),
    );
  }
}
