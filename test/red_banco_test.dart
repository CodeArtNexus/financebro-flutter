import 'dart:async';

import 'package:financebro/core/control_red.dart';
import 'package:financebro/core/red_banco.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'El primer acceso espera la misma revisión de conexión ya iniciada',
    () async {
      final respuesta = Completer<EstadoConexion>();
      var consultas = 0;
      final red = RedBanco(
        'proyecto-ficticio',
        ControlRed(),
        comprobarConexion: () {
          consultas++;
          return respuesta.future;
        },
      );
      addTearDown(red.dispose);
      var termino = false;
      final ingreso = red.revisar().then((_) => termino = true),
          otro = red.revisar();
      await Future<void>.delayed(Duration.zero);
      expect(consultas, 1);
      expect(termino, false);
      expect(red.estado, EstadoConexion.revisando);
      respuesta.complete(EstadoConexion.conectado);
      await Future.wait([ingreso, otro]);
      expect(termino, true);
      expect(red.conectado, true);
    },
  );
  test('Una revisión posterior conserva el estado real y el laboratorio sin conexión', () async {
    var consultas = 0;
    final lab = ControlRed();
    final red = RedBanco(
      'proyecto-ficticio',
      lab,
      comprobarConexion: () async {
        consultas++;
        return EstadoConexion.servicioNoDisponible;
      },
    );
    addTearDown(red.dispose);
    await red.revisar();
    expect(red.estado, EstadoConexion.servicioNoDisponible);
    await lab.cambiar(EscenarioRed.sinConexion);
    await red.revisar();
    expect(red.estado, EstadoConexion.sinConexion);
    expect(consultas, 1);
    expect(red.conectado, false);
  });
}
