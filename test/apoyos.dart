import 'dart:async';

import 'package:financebro/features/auth/identidad.dart';
import 'package:financebro/features/accounts/cuentas.dart';

class IdentidadPrueba implements RepositorioIdentidad {
  final controlador = StreamController<Identidad?>.broadcast();
  Identidad? usuario;
  bool rechazar = false;
  @override
  Identidad? get actual => usuario;
  @override
  Stream<Identidad?> get cambios async* {
    yield usuario;
    yield* controlador.stream;
  }

  @override
  Future<void> ingresar(String correo, String clave) async {
    if (rechazar) throw Exception('acceso rechazado');
    usuario = const Identidad('usuario-prueba', 'Sebastian');
    controlador.add(usuario);
  }

  @override
  Future<void> registrar(String nombre, String correo, String clave) =>
      ingresar(correo, clave);
  @override
  Future<void> recuperar(String correo) async {}
  @override
  Future<void> salir() async {
    usuario = null;
    controlador.add(null);
  }
}

class CuentasPrueba implements RepositorioCuentas {
  @override
  Stream<DatosGuardados<List<Cuenta>>> observarCuentas(String uid) =>
      Stream.value(
        DatosGuardados(
          [
            const Cuenta(
              id: 'principal',
              nombre: 'Cuenta del día a día',
              numero: '•••• 2048',
              saldoCentavos: 253050,
            ),
          ],
          desdeCache: false,
          actualizado: DateTime(2026, 10, 3),
        ),
      );
  @override
  Stream<DatosGuardados<List<Movimiento>>> observarMovimientos(
    String uid,
    String cuenta,
  ) => Stream.value(
    DatosGuardados(
      [
        Movimiento(
          id: 'm1',
          descripcion: 'Compra de prueba',
          centavos: -2500,
          fecha: DateTime(2026, 10, 3),
          categoria: 'Compras',
        ),
      ],
      desdeCache: false,
      actualizado: DateTime(2026, 10, 3),
    ),
  );
}
