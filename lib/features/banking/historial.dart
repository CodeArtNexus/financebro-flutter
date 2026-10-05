enum AmbitoHistorial { global, cuenta, tarjeta, contacto, contraparte }

class ConsultaHistorial {
  const ConsultaHistorial(
    this.uid, {
    this.ambito = AmbitoHistorial.global,
    this.destino,
    this.campo = 'numeroDestino',
  });
  final String uid;
  final AmbitoHistorial ambito;
  final String? destino;
  final String campo;
  String get clave => '$uid|${ambito.name}|$destino|$campo';
}

class MovimientoBanco {
  const MovimientoBanco({
    required this.id,
    required this.descripcion,
    required this.centavos,
    required this.fecha,
    required this.categoria,
    required this.referencia,
    this.cuenta = '',
    this.nota,
    this.automatico = false,
  });
  final String id, descripcion, categoria, referencia, cuenta;
  final int centavos;
  final DateTime fecha;
  final String? nota;
  final bool automatico;
  bool get ingreso => centavos > 0;
  static int ordenar(MovimientoBanco a, MovimientoBanco b) {
    final fecha = b.fecha.compareTo(a.fecha);
    return fecha == 0 ? b.id.compareTo(a.id) : fecha;
  }
}

class CursorHistorial {
  const CursorHistorial(
    this.consulta,
    this.fecha,
    this.id, {
    this.segundos,
    this.nanosegundos,
  });
  final String consulta, id;
  final int? segundos, nanosegundos;
  final DateTime fecha;
}

class PaginaHistorial {
  const PaginaHistorial(
    this.movimientos, {
    required this.desdeCache,
    required this.mas,
    this.cursor,
  });
  final List<MovimientoBanco> movimientos;
  final bool desdeCache, mas;
  final CursorHistorial? cursor;
}

abstract interface class RepositorioHistorial {
  Future<PaginaHistorial> pagina(
    ConsultaHistorial consulta, {
    CursorHistorial? despues,
  });
  Stream<PaginaHistorial> observar(ConsultaHistorial consulta);
}

class ContactoBro {
  const ContactoBro({
    required this.id,
    required this.nombre,
    required this.banco,
    required this.numero,
    required this.interno,
  });
  final String id, nombre, banco, numero;
  final bool interno;
}

class ContactoGuardado {
  const ContactoGuardado(this.contacto, this.desdeCache);
  final ContactoBro contacto;
  final bool desdeCache;
}

abstract interface class RepositorioContactos {
  Future<ContactoGuardado> leer(String uid, String id);
}
