import 'dart:convert';

import 'package:financebro/core/funciones_banca.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String token(
    Map<String, dynamic> datos, {
    String alg = 'none',
    String firma = '',
  }) {
    String parte(Map<String, dynamic> v) =>
        base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
    return '${parte({'alg': alg})}.${parte(datos)}.$firma';
  }

  final datos = {
    'aud': 'demo-financebro',
    'iss': 'https://securetoken.google.com/demo-financebro',
    'sub': 'persona',
    'exp': 2524608000,
  };
  test(
    'La conexión privada no admite direcciones públicas ni nombres ambiguos',
    () {
      for (final h in [
        '10.0.0.5',
        '172.16.0.1',
        '172.31.255.254',
        '192.168.100.90',
      ]) {
        expect(hostPrivado(h), true);
      }
      for (final h in [
        '8.8.8.8',
        '192.168.300.1',
        '172.32.0.1',
        'financebro.test',
        '192.168.1.1.example',
      ]) {
        expect(hostPrivado(h), false);
      }
    },
  );
  test('El transporte local rechaza tokens reales, de otro proyecto, vencidos o de otra persona', () {
    expect(tokenDeEmulador(token(datos), 'persona'), true);
    expect(
      tokenDeEmulador(token(datos, alg: 'RS256', firma: 'firma'), 'persona'),
      false,
    );
    expect(
      tokenDeEmulador(token({...datos, 'aud': 'proyecto-real'}), 'persona'),
      false,
    );
    expect(tokenDeEmulador(token({...datos, 'exp': 1}), 'persona'), false);
    expect(tokenDeEmulador(token(datos), 'otra'), false);
    expect(tokenDeEmulador('malformado', 'persona'), false);
  });
  test('El protocolo conserva los centavos y los errores de autorización del servidor', () {
    expect(
      resultadoCallable({
        'result': {'centavos': 5},
      })['centavos'],
      5,
    );
    expect(
      () => resultadoCallable({
        'error': {'status': 'PERMISSION_DENIED', 'message': 'Solo asesores'},
      }),
      throwsA(
        isA<ErrorFuncionBanca>().having(
          (e) => e.codigo,
          'código',
          'permission-denied',
        ),
      ),
    );
    expect(
      () => resultadoCallable({'saldo': 999}),
      throwsA(isA<ErrorFuncionBanca>()),
    );
  });
}
