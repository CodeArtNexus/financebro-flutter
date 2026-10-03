const usarEmuladores = bool.fromEnvironment('USE_EMULATORS');
const habilitarLaboratorio = bool.fromEnvironment('ENABLE_LAB');
const servidorEmuladores = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);
const puertoAuth = int.fromEnvironment('AUTH_PORT', defaultValue: 9099);
const puertoFirestore = int.fromEnvironment(
  'FIRESTORE_PORT',
  defaultValue: 8080,
);
const puertoFunciones = int.fromEnvironment(
  'FUNCTIONS_PORT',
  defaultValue: 5001,
);
const puertoStorage = int.fromEnvironment('STORAGE_PORT', defaultValue: 9199);
