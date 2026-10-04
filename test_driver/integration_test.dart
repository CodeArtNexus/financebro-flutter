import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final destino = Directory(
    Platform.environment['FINANCEBRO_EVIDENCIAS'] ?? 'evidencia-local',
  );
  await destino.create(recursive: true);
  await integrationDriver(
    onScreenshot:
        (
          String nombre,
          List<int> imagen, [
          Map<String, Object?>? argumentos,
        ]) async {
          await File('${destino.path}/$nombre.png').writeAsBytes(imagen);
          return true;
        },
    responseDataCallback: (datos) async {
      // Las capturas extensas de Android se transfieren como archivos, sin un JSON gigante.
      for (final captura in [
        for (final n in (datos?['capturasLocales'] as List<dynamic>? ?? []))
          {'nombre': n, 'carpeta': 'financebro_capturas'},
        for (final n in (datos?['capturasNextgen'] as List<dynamic>? ?? []))
          {'nombre': n, 'carpeta': 'financebro_nextgen'},
      ]) {
        final nombre = captura['nombre'];
        if (nombre is! String || !RegExp(r'^[a-z0-9-]+$').hasMatch(nombre)) {
          throw StateError('Nombre de captura inválido.');
        }
        final r = await Process.run('adb', [
          '-s',
          Platform.environment['FINANCEBRO_DISPOSITIVO'] ?? 'emulator-5554',
          'exec-out',
          'run-as',
          'ec.financebro.financebro',
          'cat',
          "files/${captura['carpeta']}/$nombre.png",
        ], stdoutEncoding: null);
        final bytes = r.stdout as List<int>;
        const png = [137, 80, 78, 71, 13, 10, 26, 10];
        if (r.exitCode != 0 ||
            bytes.length < png.length ||
            List.generate(png.length, (i) => bytes[i]).join(',') !=
                png.join(',')) {
          throw StateError(
            'No se pudo exportar una imagen PNG válida: $nombre.',
          );
        }
        await File('${destino.path}/$nombre.png').writeAsBytes(bytes);
      }
      final resultado = Map<String, dynamic>.of(datos ?? {})
        ..remove('screenshots');
      await writeResponseData(
        resultado,
        destinationDirectory: destino.path,
        testOutputFilename: 'resultado-e2e',
      );
    },
  );
}
