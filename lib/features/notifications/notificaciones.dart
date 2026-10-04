import '../../features/experience/experiencia.dart';

String destinoPush(Map<String, dynamic> datos) {
  final ruta = datos['ruta'] ?? datos['destino'];
  if (ruta is! String) return '/notificaciones';
  if (destinosPermitidos.contains(ruta) ||
      [
        '/chequera',
        '/tarjetas',
        '/tarjetas/credito/detalle',
        '/pagos',
        '/contactos',
        '/historial',
        '/apertura/corriente',
      ].contains(ruta) ||
      RegExp(r'^/chequera/cheques/[a-zA-Z0-9_-]{1,80}$').hasMatch(ruta) ||
      RegExp(r'^/cuentas/[a-zA-Z0-9_-]{1,80}$').hasMatch(ruta)) {
    return ruta;
  }
  return '/notificaciones';
}

class AvisoCliente {
  const AvisoCliente(this.titulo, this.texto, this.fecha, this.destino);
  final String titulo, texto, destino;
  final DateTime fecha;
}

abstract interface class RepositorioNotificaciones {
  Stream<AvisoCliente> get recibidas;
  Stream<List<AvisoCliente>> historial(String uid);
  Future<void> conectar(String uid, void Function(String) abrir);
  Future<bool> activar(String uid);
  Future<void> desconectar();
}
