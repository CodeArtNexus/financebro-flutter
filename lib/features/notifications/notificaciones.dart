import '../../features/experience/experiencia.dart';

String destinoPush(Map<String, dynamic> datos) =>
    destinosPermitidos.contains(datos['ruta'])
    ? datos['ruta'] as String
    : '/notificaciones';

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
