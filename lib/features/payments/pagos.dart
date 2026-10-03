import '../../core/errores.dart';

class SolicitudQr {
  const SolicitudQr(this.comercio, this.centavos, this.referencia);
  final String comercio, referencia;
  final int centavos;
  static final identificador = RegExp(r'^[a-zA-Z0-9_-]{8,80}$');
  factory SolicitudQr.leer(String contenido) {
    final uri = Uri.tryParse(contenido);
    if (contenido.length > 512 ||
        uri == null ||
        uri.scheme != 'financebro' ||
        uri.host != 'pagar' ||
        uri.path.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.queryParametersAll.length != 3 ||
        !uri.queryParameters.keys.toSet().containsAll([
          'comercio',
          'centavos',
          'referencia',
        ]) ||
        uri.queryParametersAll.values.any((v) => v.length != 1)) {
      throw const FalloApp('Este QR no es un pago de FinanceBro.');
    }
    final comercio = uri.queryParameters['comercio']!;
    final importe = uri.queryParameters['centavos']!;
    final centavos = int.tryParse(importe);
    final referencia = uri.queryParameters['referencia']!;
    if (!RegExp(r'^[a-z0-9-]{2,60}$').hasMatch(comercio) ||
        !RegExp(r'^[1-9][0-9]{0,6}$').hasMatch(importe) ||
        centavos == null ||
        centavos > 1000000 ||
        !identificador.hasMatch(referencia)) {
      throw const FalloApp(
        'El QR tiene un importe o una referencia inválidos.',
      );
    }
    return SolicitudQr(comercio, centavos, referencia);
  }
  String get contenido => Uri(
    scheme: 'financebro',
    host: 'pagar',
    queryParameters: {
      'comercio': comercio,
      'centavos': '$centavos',
      'referencia': referencia,
    },
  ).toString();
}

class ReciboPago {
  const ReciboPago({
    required this.referencia,
    required this.cuenta,
    required this.comercio,
    required this.nombre,
    required this.centavos,
  });
  final String referencia, cuenta, comercio, nombre;
  final int centavos;
}

abstract interface class RepositorioPagos {
  Future<String> consultarComercio(String id);
  Future<ReciboPago> pagar(String uid, String cuenta, SolicitudQr solicitud);
}
