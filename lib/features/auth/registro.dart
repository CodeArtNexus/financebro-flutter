class DatosRegistro {
  const DatosRegistro({
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.cedula,
    required this.clave,
    required this.direccion,
    required this.ciudad,
    required this.telefono,
  });
  final String nombres,
      apellidos,
      correo,
      cedula,
      clave,
      direccion,
      ciudad,
      telefono;
  String get nombre => '${nombres.trim()} ${apellidos.trim()}';
  Map<String, dynamic> get apertura => {
    'nombres': nombres.trim(),
    'apellidos': apellidos.trim(),
    'correo': correo.trim(),
    'cedula': cedula.trim(),
    'direccion': direccion.trim(),
    'ciudad': ciudad.trim(),
    'telefono': telefono.trim(),
    'aceptaContrato': true,
    'versionContrato': '2026-10-v1',
  };
}

const contratoVersion = '2026-10-v1';
const contratoRegistro = '''Tu cuenta de ahorros y tu tarjeta digital

Al crear tu cuenta se abre tu cuenta de ahorros con saldo inicial de USD 0 y se emite tu tarjeta de débito digital. Puedes recibir fondos, consultar tus movimientos y realizar transferencias entre USD 0,10 y USD 100. Cada operación requiere tu confirmación y conserva un comprobante.

Tus datos y tu acceso

Declaro que soy mayor de edad y que los nombres, cédula, correo, teléfono y domicilio ingresados me corresponden. Autorizo su tratamiento para gestionar mi cuenta, solicitudes y comunicaciones relacionadas con mis operaciones. Soy responsable de mantener segura mi contraseña y de revisar los destinatarios antes de confirmar un pago.

Tarjetas y solicitudes

La solicitud de crédito está sujeta a revisión; solicitarla no concede un cupo. La tarjeta física requiere confirmar un domicilio y una fecha de envío desde tres días después de la solicitud. Un diseño personalizado pasa por aprobación antes del envío. Recibirás avisos sobre el estado de tus solicitudes.

Preferencias y autorización

Los pagos mensuales y las notificaciones del dispositivo requieren autorizaciones adicionales que puedes gestionar. Al aceptar este contrato, autorizo la apertura de mi cuenta de ahorros y la emisión de mi tarjeta de débito digital conforme a estos términos.''';
