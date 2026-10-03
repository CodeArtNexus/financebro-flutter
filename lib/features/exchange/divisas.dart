import '../../core/errores.dart';

class Cotizacion {
  const Cotizacion({
    required this.moneda,
    required this.tasa,
    required this.fecha,
    required this.consultada,
    this.desdeCache = false,
    this.aviso,
  });
  final String moneda;
  final double tasa;
  final DateTime fecha;
  final DateTime consultada;
  final bool desdeCache;
  final String? aviso;
  factory Cotizacion.desdeMapa(
    Map<String, dynamic> mapa,
    String moneda,
    DateTime ahora,
  ) {
    final tasa = mapa['rate'];
    final fecha = DateTime.tryParse(mapa['date'] as String? ?? '');
    if (mapa['base'] != 'USD' ||
        mapa['quote'] != moneda ||
        tasa is! num ||
        !tasa.isFinite ||
        tasa <= 0 ||
        fecha == null) {
      throw const FalloApp('El servicio devolvió una tasa inválida.');
    }
    return Cotizacion(
      moneda: moneda,
      tasa: tasa.toDouble(),
      fecha: fecha,
      consultada: ahora,
    );
  }
  int convertirCentavos(int centavos) {
    if (centavos < 0 || centavos > 100000000) {
      throw const FalloApp('Ingresa un monto entre 0 y 1.000.000 USD.');
    }
    return (centavos * tasa).round();
  }

  Map<String, dynamic> aMapa() => {
    'base': 'USD',
    'quote': moneda,
    'rate': tasa,
    'date': fecha.toIso8601String(),
    'consultada': consultada.toIso8601String(),
  };
}

int? leerCentavos(String entrada) {
  final texto = entrada.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(texto)) return null;
  final partes = texto.split('.');
  final centavos =
      int.parse(partes[0]) * 100 +
      (partes.length == 1 ? 0 : int.parse(partes[1].padRight(2, '0')));
  return centavos <= 100000000 ? centavos : null;
}

abstract interface class CacheCotizaciones {
  Cotizacion? leer(String moneda);
  Future<void> guardar(Cotizacion cotizacion);
}

abstract interface class RepositorioDivisas {
  Future<Cotizacion> consultar(String moneda);
}
