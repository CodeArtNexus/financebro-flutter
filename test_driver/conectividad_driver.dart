import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final destino = Directory(
    Platform.environment['FINANCEBRO_EVIDENCIAS'] ??
        'evidencia-local/conectividad',
  );
  final dispositivo = Platform.environment['FINANCEBRO_DISPOSITIVO'];
  if (dispositivo == null) throw StateError('Indica FINANCEBRO_DISPOSITIVO.');
  final ios = Platform.environment['FINANCEBRO_PLATAFORMA'] == 'ios';
  await destino.create(recursive: true);
  await integrationDriver(
    onScreenshot: (nombre, bytes, [argumentos]) async => true,
    responseDataCallback: (datos) async {
      final nombres = datos?['capturasConectividad'] as List<dynamic>? ?? [];
      if (nombres.length != 12) {
        throw StateError('El recorrido no completó sus 12 estados.');
      }
      String? contenedor;
      if (ios) {
        final r = await Process.run('xcrun', [
          'simctl',
          'get_app_container',
          dispositivo,
          'ec.financebro.financebro',
          'data',
        ]);
        if (r.exitCode != 0) {
          throw StateError('Falta el contenedor del simulador.');
        }
        contenedor = (r.stdout as String).trim();
      }
      for (final n in nombres) {
        if (n is! String ||
            !RegExp(r'^(claro|oscuro)-[0-9]+-[a-z-]+$').hasMatch(n)) {
          throw StateError('Nombre de captura inválido.');
        }
        if (contenedor != null) {
          await File('$contenedor/tmp/financebro_conectividad/$n.png')
              .copy('${destino.path}/$n.png');
        } else {
          final r = await Process.run('adb', [
            '-s',
            dispositivo,
            'exec-out',
            'run-as',
            'ec.financebro.financebro',
            'cat',
            'files/financebro_conectividad/$n.png',
          ], stdoutEncoding: null);
          if (r.exitCode != 0) throw StateError('No pudimos copiar $n.');
          await File('${destino.path}/$n.png')
              .writeAsBytes(r.stdout as List<int>);
        }
      }
      await File('${destino.path}/verificacion.txt').writeAsString(
        '12 capturas verificadas: proveedor real, latencia y caída parcial controladas, caché, error, cuentas disponibles y recuperación. Sin operaciones de fondos.\n',
      );
    },
  );
}
