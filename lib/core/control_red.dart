import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'errores.dart';

enum EscenarioRed { normal, sinConexion, latencia, divisasCaidas }

class ControlRed extends ChangeNotifier {
  ControlRed({this.cambiarFirestore});
  final Future<void> Function(bool habilitar)? cambiarFirestore;
  EscenarioRed escenario = EscenarioRed.normal;
  Future<void> cambiar(EscenarioRed nuevo) async {
    await cambiarFirestore?.call(nuevo != EscenarioRed.sinConexion);
    escenario = nuevo;
    registrarEvento('escenario_${nuevo.name}', servicio: 'laboratorio');
    notifyListeners();
  }

  Future<T> ejecutarDivisas<T>(Future<T> Function() operacion) async {
    if (escenario == EscenarioRed.sinConexion) {
      throw const FalloApp(
        'Sin conexión. Mostramos la última tasa guardada si está disponible.',
        transitorio: true,
      );
    }
    if (escenario == EscenarioRed.divisasCaidas) {
      throw const FalloApp(
        'El servicio de divisas no está disponible por el momento.',
        transitorio: true,
      );
    }
    if (escenario == EscenarioRed.latencia) {
      await Future<void>.delayed(const Duration(seconds: 4));
    }
    return operacion();
  }

  factory ControlRed.conFirestore(FirebaseFirestore datos) => ControlRed(
    cambiarFirestore: (habilitar) =>
        habilitar ? datos.enableNetwork() : datos.disableNetwork(),
  );
}
