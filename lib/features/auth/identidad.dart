class Identidad {
  const Identidad(this.uid, this.nombre);
  final String uid;
  final String nombre;
}

abstract interface class RepositorioIdentidad {
  Identidad? get actual;
  Stream<Identidad?> get cambios;
  Future<void> ingresar(String correo, String clave);
  Future<void> registrar(String nombre, String correo, String clave);
  Future<void> recuperar(String correo);
  Future<void> salir();
  bool get sesionGuardada;
  Future<void> reanudarDemostracion();
}

String? validarCorreo(String? valor) {
  if (valor == null ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(valor.trim())) {
    return 'Ingresa un correo válido.';
  }
  return null;
}

String? validarClave(String? valor) =>
    (valor?.length ?? 0) < 8 ? 'Usa al menos 8 caracteres.' : null;
