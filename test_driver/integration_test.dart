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
      await writeResponseData(
        datos,
        destinationDirectory: destino.path,
        testOutputFilename: 'resultado-e2e',
      );
    },
  );
}
