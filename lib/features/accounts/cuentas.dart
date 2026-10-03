class Cuenta {
  const Cuenta({
    required this.id,
    required this.nombre,
    required this.numero,
    required this.saldoCentavos,
    this.tarjetaUltimos4,
    this.tarjetaRed = 'BRO',
    this.numeroCuenta,
    this.tipo = 'ahorro',
    this.estado = 'activa',
    this.color = 'durazno',
  });
  final String id;
  final String nombre;
  final String numero;
  final int saldoCentavos;
  final String? tarjetaUltimos4;
  final String tarjetaRed;
  final String? numeroCuenta;
  final String tipo, estado, color;
  bool get activa => estado == 'activa';
  factory Cuenta.desdeMapa(String id, Map<String, dynamic> m) => Cuenta(
    id: id,
    nombre: m['nombre'] as String,
    numero: m['numero'] as String,
    saldoCentavos: (m['saldoCentavos'] as num).toInt(),
    tarjetaUltimos4: m['tarjetaUltimos4'] as String?,
    tarjetaRed: m['tarjetaRed'] as String? ?? 'BRO',
    numeroCuenta: m['numeroCuenta'] as String?,
    tipo: m['tipo'] as String? ?? 'ahorro',
    estado: m['estado'] as String? ?? 'activa',
    color: m['color'] as String? ?? 'durazno',
  );
}

class Movimiento {
  const Movimiento({
    required this.id,
    required this.descripcion,
    required this.centavos,
    required this.fecha,
    required this.categoria,
  });
  final String id;
  final String descripcion;
  final int centavos;
  final DateTime fecha;
  final String categoria;
}

class DatosGuardados<T> {
  const DatosGuardados(
    this.valor, {
    required this.desdeCache,
    required this.actualizado,
    this.pendiente = false,
  });
  final T valor;
  final bool desdeCache;
  final DateTime actualizado;
  final bool pendiente;
}

abstract interface class RepositorioCuentas {
  Stream<DatosGuardados<List<Cuenta>>> observarCuentas(String uid);
  Stream<DatosGuardados<List<Movimiento>>> observarMovimientos(
    String uid,
    String cuenta,
  );
}
