const usarEmuladores = bool.fromEnvironment('USE_EMULATORS');
const habilitarLaboratorio = bool.fromEnvironment('ENABLE_LAB');
const servidorEmuladores = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);
