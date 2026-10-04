import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/proveedores.dart';
import 'configuracion.dart';
import 'control_red.dart';
import 'funciones_banca.dart';

enum EstadoConexion { revisando, conectado, sinConexion, servicioNoDisponible }

final redBancoProvider = Provider<RedBanco>((ref) {
  final r = RedBanco(
    ref.watch(firebaseAppProvider).options.projectId,
    ref.watch(controlRedProvider),
  );
  ref.onDispose(r.dispose);
  return r;
});
final conexionBancoProvider = StreamProvider<EstadoConexion>(
  (ref) => ref.watch(redBancoProvider).cambios,
);

class RedBanco extends ChangeNotifier with WidgetsBindingObserver {
  RedBanco(
    this.proyecto,
    this.laboratorio, {
    Future<EstadoConexion> Function()? comprobarConexion,
  }) : _sonda = comprobarConexion {
    WidgetsBinding.instance.addObserver(this);
    laboratorio.addListener(revisar);
    _suscripcion = Connectivity().onConnectivityChanged.listen(
      (_) => revisar(),
    );
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => revisar());
    unawaited(revisar());
  }
  final String proyecto;
  final ControlRed laboratorio;
  EstadoConexion estado = EstadoConexion.revisando;
  bool _cerrado = false;
  Future<void>? _revision;
  final Future<EstadoConexion> Function()? _sonda;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _suscripcion;
  final _cambios = StreamController<EstadoConexion>.broadcast();
  Stream<EstadoConexion> get cambios => Stream<EstadoConexion>.multi((c) {
    c.add(estado);
    final s = _cambios.stream.listen(c.add);
    c.onCancel = s.cancel;
  });
  bool get conectado => estado == EstadoConexion.conectado;
  void _estado(EstadoConexion v) {
    if (_cerrado || estado == v) return;
    estado = v;
    notifyListeners();
    _cambios.add(v);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(revisar());
  }

  Future<void> revisar() {
    if (_cerrado) return Future.value();
    return _revision ??= _revisar().whenComplete(() => _revision = null);
  }

  Future<void> _revisar() async {
    HttpClient? cliente;
    try {
      if (laboratorio.escenario == EscenarioRed.sinConexion) {
        _estado(EstadoConexion.sinConexion);
        return;
      }
      if (_sonda != null) {
        _estado(await _sonda());
        return;
      }
      final redes = await Connectivity().checkConnectivity();
      if (redes.isEmpty || redes.every((r) => r == ConnectivityResult.none)) {
        _estado(EstadoConexion.sinConexion);
        return;
      }
      final tls =
          usarEmuladores &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          !['localhost', '127.0.0.1', '::1'].contains(servidorEmuladores);
      SecurityContext? contexto;
      if (tls) {
        const cert = String.fromEnvironment('EMULATOR_TLS_CERT');
        if (proyecto != 'demo-financebro' ||
            !hostPrivado(servidorEmuladores) ||
            cert.isEmpty) {
          _estado(EstadoConexion.servicioNoDisponible);
          return;
        }
        contexto = SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificatesBytes(base64Decode(cert));
      }
      cliente = HttpClient(context: contexto)
        ..connectionTimeout = const Duration(seconds: 8);
      final uri = usarEmuladores
          ? Uri(
              scheme: tls ? 'https' : 'http',
              host: servidorEmuladores,
              port: tls
                  ? const int.fromEnvironment(
                      'FUNCTIONS_TLS_PORT',
                      defaultValue: 5443,
                    )
                  : puertoFunciones,
              path: '/$proyecto/us-central1/banca',
            )
          : Uri.https('us-central1-$proyecto.cloudfunctions.net', '/banca');
      final req = await cliente
          .postUrl(uri)
          .timeout(const Duration(seconds: 8));
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'data': {
            'operacion': 'destinatario',
            'datos': {'numero': '00000000000000'},
          },
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 20));
      final cuerpo = await utf8
          .decodeStream(res)
          .timeout(const Duration(seconds: 8));
      final datos = jsonDecode(cuerpo);
      _estado(
        res.statusCode == 401 &&
                datos is Map &&
                datos['error'] is Map &&
                datos['error']['status'] == 'UNAUTHENTICATED'
            ? EstadoConexion.conectado
            : EstadoConexion.servicioNoDisponible,
      );
    } on SocketException {
      _estado(EstadoConexion.sinConexion);
    } on TimeoutException {
      _estado(EstadoConexion.sinConexion);
    } catch (_) {
      _estado(EstadoConexion.servicioNoDisponible);
    } finally {
      cliente?.close(force: true);
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    WidgetsBinding.instance.removeObserver(this);
    laboratorio.removeListener(revisar);
    _timer?.cancel();
    _suscripcion?.cancel();
    _cambios.close();
    super.dispose();
  }
}
