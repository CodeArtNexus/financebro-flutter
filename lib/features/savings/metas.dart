class MetaAhorro {
  const MetaAhorro({
    required this.id,
    required this.nombre,
    required this.cuenta,
    required this.objetivo,
    required this.aporteMensual,
    required this.fecha,
  });
  final String id, nombre, cuenta;
  final int objetivo, aporteMensual;
  final DateTime fecha;
  double progreso(int saldo) => (saldo / objetivo).clamp(0.0, 1.0);
  int mesesPendientes(int saldo) =>
      ((objetivo - saldo).clamp(0, objetivo) / aporteMensual).ceil();
}

abstract interface class RepositorioMetas {
  Stream<List<MetaAhorro>> observar(String uid);
  Future<void> guardar(String uid, MetaAhorro meta);
  Future<void> eliminar(String uid, String id);
}
