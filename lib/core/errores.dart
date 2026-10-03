import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FalloApp implements Exception {
  const FalloApp(this.mensaje, {this.transitorio = false});
  final String mensaje;
  final bool transitorio;
  @override
  String toString() => mensaje;
}

String mensajeError(Object error) {
  if (error is FalloApp) return error.mensaje;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Revisa el correo electrónico.',
      'email-already-in-use' =>
        'Este correo ya tiene una cuenta. Intenta ingresar.',
      'weak-password' => 'Usa una contraseña de al menos 8 caracteres.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'No pudimos validar tus datos de acceso.',
      'network-request-failed' =>
        'No hay conexión. Revisa tu red y vuelve a intentar.',
      'too-many-requests' => 'Espera unos minutos antes de volver a intentar.',
      _ => 'No pudimos completar el acceso. Vuelve a intentar.',
    };
  }
  return 'No pudimos cargar esta información. Vuelve a intentar.';
}

// Solo registra categorías técnicas; nunca contenido financiero ni credenciales.
void registrarEvento(String evento, {String? servicio, int? duracionMs}) {
  debugPrint(
    'FinanceBro evento=$evento servicio=${servicio ?? "app"} duracion_ms=${duracionMs ?? 0}',
  );
}
