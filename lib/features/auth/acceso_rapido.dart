import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecuerdoAcceso {
  const RecuerdoAcceso(this.uid, this.nombre);
  final String uid, nombre;
  String get saludo => nombre.trim().split(RegExp(r'\s+')).first;
  static RecuerdoAcceso? leer(SharedPreferences preferencias) {
    try {
      final valor = jsonDecode(
        preferencias.getString('saludo_bro_v1') ?? 'null',
      );
      if (valor is! Map ||
          valor['uid'] is! String ||
          valor['nombre'] is! String ||
          (valor['uid'] as String).isEmpty ||
          (valor['nombre'] as String).trim().isEmpty ||
          (valor['nombre'] as String).length > 60) {
        return null;
      }
      return RecuerdoAcceso(valor['uid'], valor['nombre']);
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(SharedPreferences preferencias) async {
    await preferencias.setString(
      'saludo_bro_v1',
      jsonEncode({'uid': uid, 'nombre': nombre}),
    );
  }
}
