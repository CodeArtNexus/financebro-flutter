# FinanceBro

Aplicación financiera en Flutter para Android e iOS, con un panel web de administración. Permite abrir una cuenta de ahorros, consultar saldos, transferir por QR o número de cuenta y revisar movimientos por cuenta, tarjeta y contacto. También incluye crédito, servicios, metas de ahorro y chequera digital.

La versión **1.7.0** utiliza Firebase Authentication, Firestore, Storage y Functions. La app y el panel comparten datos: un ajuste del asesor o una transferencia se refleja en los históricos correspondientes. Los fondos, identidades, tarjetas, documentos y planillas del entorno de evaluación son ficticios. No se realizan pagos a bancos o proveedores reales.

## Revisar la aplicación

| Recurso | Contenido |
| --- | --- |
| [APK Android 1.7.0](https://github.com/CodeArtNexus/financebro-flutter/releases/tag/v1.7.0-calidad) | Aplicación conectada al servidor publicado |
| [Panel de administración](https://financebro-sb-20261003.web.app/) | Cuentas, fondos, solicitudes, movimientos y configuración |
| [Presentación y recorrido técnico](https://financebro-sb-20261003.web.app/presentacion/) | Video comercial de 1:45 y recorrido de 22:30, con procesos completos y capítulos |
| [Galería de interfaz](https://financebro-sb-20261003.web.app/revision/) | 214 capturas: 100 Android, 96 iOS y 18 del panel |
| [Pasos de evaluación](documentacion/evaluacion.md) | Recorrido conectado y demostración de errores, caché y recuperación |

### Accesos y perfiles del servidor publicado

Los tres perfiles de cliente y el asesor están creados en el servidor en línea. La app Android, la app iOS y el [panel web](https://financebro-sb-20261003.web.app/) utilizan el mismo proyecto de Firebase y comparten cuentas, solicitudes, fondos e históricos. No hace falta iniciar un servidor local ni los emuladores de Firebase.

Los correos y contraseñas se entregan por separado en **Accesos-evaluacion-FinanceBro.md**; no se publican en Git. Ingresar con esos accesos mediante «Ya tengo una cuenta» / «Ingresar», sin volver a registrar los perfiles preparados.

| Perfil | Funciones disponibles al iniciar la revisión |
| --- | --- |
| Sebastián Torres | Ahorros y corriente activas, débito personalizable, crédito activo con corte y pagos, tarjeta externa, servicios, metas, contactos y movimientos. Emite y recibe cheques. |
| Valeria Andrade | Segunda cuenta para transferencias, QR y cheques. Ahorros y corriente activas, débito, tarjeta externa y crédito aprobado pendiente de elegir corte. |
| Mateo Rivera | Ahorros y débito activos. Expedientes de cuenta corriente y tarjeta de crédito pendientes de revisión, para completar su aprobación desde el panel. |
| Asesor | Acceso al panel web para revisar cuentas y movimientos, ajustar fondos ficticios, aprobar solicitudes y gestionar tarjetas, servicios, cheques y temporadas. El servidor comprueba su rol administrativo; una cuenta de cliente no tiene esos permisos. |

1. **Android:** instalar el APK enlazado arriba o ejecutar la app desde este repositorio. La compilación normal conecta al servidor publicado.
2. **iOS:** ejecutar la app con Flutter y Xcode en un simulador o firmarla con una cuenta de Apple para instalarla en un iPhone físico. Usa los mismos accesos y datos que Android. No hay distribución de TestFlight ni un instalador iOS universal.
3. **Panel:** abrir el enlace publicado en un navegador e ingresar con el acceso de asesor. Un ajuste o aprobación se refleja en la app conectada del cliente correspondiente.

Para esta revisión **no activar `USE_EMULATORS` ni `VITE_USE_EMULATORS`**. Las claves indicadas en «Entorno aislado» solo sirven para los emuladores y no permiten entrar al servidor publicado. Los perfiles conservan los cambios entre sesiones; las operaciones de revisión modifican sus saldos, estados e históricos.

Se verificaron el 5 de octubre de 2026 los cuatro accesos en línea, los productos e históricos de cada cliente, el rol del asesor y la conexión del panel al mismo proyecto. La comprobación consultó datos sin cambiar fondos ni aprobar solicitudes.

## Funciones y reglas principales

| Función | Comportamiento |
| --- | --- |
| Registro | Solicita nombres, apellidos, correo, cédula, contraseña, teléfono y domicilio. Presenta el contrato y exige aceptación. El servidor crea perfil, consentimiento, ahorros en USD 0 y débito. Reintentar conserva la misma cuenta. |
| Transferencias | Valida el titular y admite USD 0,10 a USD 100. Guarda la autorización antes del envío. El servidor confirma saldos, movimientos, comprobante y avisos en una transacción. Repetir la referencia recupera el resultado sin descontar otra vez. |
| Históricos y contactos | Vistas globales y por producto, con páginas anteriores. Cada contacto muestra envíos y recepciones como una conversación. |
| Tarjetas | Débito con nombre, color o imagen privada. Solicitud física con domicilio y fecha desde tres días después; un diseño personalizado requiere revisión. Las tarjetas externas guardan banco y últimos cuatro dígitos, y muestran los pagos hechos desde FinanceBro. |
| Crédito | Solicitud, aprobación de cupo y corte del 1 al 28. Muestra deuda, cupo disponible, total facturado, mínimo y vencimiento. El mínimo es 5 % del saldo al corte, con piso de USD 10 sin superar la deuda; vence 15 días después. No calcula intereses. |
| Cuenta corriente | Expediente con progreso guardado. El asesor solicita correcciones o aprueba una cuenta temporal. Un depósito ficticio de USD 1.000 para pyme o USD 2.000 para gran empresa permite activarla. No genera tarjeta. |
| Chequera | Emisión por lotes de hasta 24 cheques mensuales a otra cuenta corriente. Agrupaciones, cambios de fecha hasta cinco días después de la original, bloqueo y cancelación con eventos y avisos. Emitir no reserva fondos; el asesor procesa los cobros. |
| Servicios | Catálogo administrable, consulta de planilla y pago confirmado por el titular. El plan mensual guarda contrato, día, límite y consentimiento; no ejecuta cargos automáticos. |
| Personalización | Marca `fb.`, naranja, superficies de cristal, temas claro/oscuro/automático, tarjetas, metas y saludo por preferencia. El panel publica temporadas y servicios sin reinstalar la app. |
| Divisas | Consulta real de EUR, GBP y COP mediante Frankfurter. Muestra fuente, fecha, carga, reintento y última tasa guardada cuando falla el proveedor. |
| Avisos | FCM remoto en Android, con recepción y apertura verificadas. iOS muestra avisos nativos al recibir cambios con la app conectada; APNs está pendiente. |

El primer ingreso requiere internet. Una sesión anterior puede desbloquear datos guardados mediante la seguridad del dispositivo y preparar una transferencia a un contacto interno ya verificado. La operación queda pendiente: el servidor valida fondos, destinatario y plazo al reconectar. Una autorización sin confirmar vence a las 24 horas; un comprobante existente sigue siendo recuperable después de ese plazo.

Apple Wallet, Google Wallet, NFC, emisión bancaria, mensajería física, cheques legalmente certificados y proveedores de servicios reales requieren integraciones adicionales.

## Configurar y ejecutar

Versiones utilizadas: Flutter 3.47.5, Dart 3.13.4, Node 22.20.0, npm 11.18.0 y Java 21. El panel requiere Node 22.12.0 o superior. Android utiliza SDK 36; iOS necesita macOS, Xcode y firma para dispositivos físicos. Los archivos de bloqueo fijan las dependencias.

### Servidor publicado

```sh
git clone https://github.com/CodeArtNexus/financebro-flutter.git
cd financebro-flutter
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <identificador-del-dispositivo>
```

Configurar PIN, código o biometría en el dispositivo para autorizar transferencias. Usar identidades ficticias y los accesos proporcionados. El asesor puede aportar fondos desde el panel. No activar `USE_EMULATORS` para este recorrido.

El panel puede ejecutarse localmente contra el mismo servidor:

```sh
npm ci --prefix admin
npm --prefix admin run dev
```

Requiere una sesión con el claim `financebroAdmin`. Registrar un cliente no concede permisos de administración. [Configuración del panel](admin/README.md).

### Entorno aislado

```sh
npm install --global npm@11.18.0
npm ci --prefix tooling
npm ci --prefix functions
npm ci --prefix admin
./scripts/servidor-local.sh
```

En otra terminal:

```sh
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
node functions/sembrar-local.js

flutter run -d emulator-5554 --dart-define=USE_EMULATORS=true
VITE_USE_EMULATORS=true npm --prefix admin run dev
```

Accesos locales: `demo@financebro.test` y `valeria@financebro.test`, clave `FinanceBro-local-2026!`. Asesor: `admin@financebro.test`, clave `FinanceBro-admin-local-2026!`. Estas claves solo funcionan en los emuladores. La preparación conserva los fondos e históricos existentes.

En simulador iOS añadir `--dart-define=EMULATOR_HOST=127.0.0.1`. Los puertos predeterminados son Auth 9099, Firestore 8080, Functions 5001 y Storage 9199. Admiten las variables `AUTH_PORT`, `FIRESTORE_PORT`, `FUNCTIONS_PORT` y `STORAGE_PORT`; el panel usa los equivalentes `VITE_`. El servidor local conserva los datos al cerrarlo con Ctrl+C.

Para un iPhone físico conectado a emuladores, `scripts/preparar-iphone-local.py` y `scripts/proxy-funciones-https.mjs` preparan un puente HTTPS privado. Solo admite `USE_EMULATORS=true`, el proyecto `demo-financebro`, direcciones privadas y tokens de emulador. La conexión publicada usa los SDK de Firebase.

## Arquitectura y seguridad

El cliente está organizado por funcionalidades. Riverpod administra dependencias y estado; GoRouter define rutas y redirecciones. Históricos y contactos utilizan repositorios tipados que se pueden sustituir en pruebas. Functions separa los casos de uso por dominio y comparte el acceso transaccional a Firestore.

Las operaciones monetarias se ejecutan en el servidor. Las reglas impiden que los clientes escriban saldos, movimientos, comprobantes, cupos o aprobaciones, incluso con una sesión de asesor. Functions comprueba identidad, rol, estado de cuenta, importes en centavos y referencia. La cédula se valida por formato y unicidad, sin consulta a un registro oficial. Los datos de identidad son privados; documentos e imágenes se descargan con sesión, sin enlaces públicos permanentes.

La app conserva las transferencias autorizadas en almacenamiento seguro antes de enviarlas. Una respuesta perdida se recupera con la misma referencia. El saludo guardado contiene nombre e identificador; no guarda contraseña ni saldo en preferencias. [Arquitectura](documentacion/arquitectura.md) y [decisiones](documentacion/decisiones.md).

## Ejecutar verificaciones

```sh
./scripts/check.sh
npm --prefix functions test
npm --prefix admin test
npm --prefix admin run build
node --test tooling/reconciliar-historicos.test.mjs
node tooling/comprobar-limites.mjs
```

Con los puertos de emuladores libres:

```sh
tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  'npm --prefix functions run test:integracion && npm --prefix admin run test:integracion'

tooling/node_modules/.bin/firebase emulators:exec \
  --only firestore,storage --project demo-financebro-reglas \
  'npm --prefix tooling test'
```

Con Android iniciado, los siguientes comandos preparan sus datos y ejecutan recuperación y rendimiento en emuladores:

```sh
tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  './scripts/prueba-recuperacion.sh'

tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  './scripts/prueba-calidad.sh'
```

`./scripts/prueba-integral.sh` y `./scripts/prueba-banca.sh` requieren un dispositivo y los cuatro emuladores en ejecución. `integration_test/` incluye recorridos de registro, productos, crédito, conectividad y chequera. CI ejecuta cinco trabajos, incluido recuperación Android, sin credenciales del proyecto publicado.

El desglose actual suma **149 pruebas automáticas**; las ejecuciones móviles se registran por separado. [Resultados, accesibilidad y rendimiento](documentacion/calidad.md).

## Publicar y mantener

`./scripts/preparar-publicacion.sh` verifica y compila el panel. `./scripts/publicar-banca.sh --proyecto <proyecto>` muestra el plan; añadir `--ejecutar` despliega los componentes. Para cambios exclusivamente del sitio, publicar solo Hosting. [Procedimiento completo](documentacion/operacion.md).

El proyecto publicado exporta `banca` y `enviarAviso`, con cero instancias mínimas y una máxima por función. Las tareas de `functions/src/programacion.js` no se despliegan. Blaze factura por consumo; esta configuración reduce actividad, pero no garantiza costo cero.

`tooling/reconciliar-historicos.mjs --proyecto <proyecto>` revisa copias globales ausentes sin modificar datos. La opción `--aplicar` vuelve a comprobar los registros dentro de una transacción y crea solo las copias compatibles. No reconstruye saldos. Requiere la sesión propietaria de Firebase CLI.

## Documentación

| Documento | Contenido |
| --- | --- |
| [Arquitectura](documentacion/arquitectura.md) | Componentes, datos y flujo de transferencia |
| [Decisiones](documentacion/decisiones.md) | Problema, alternativas, elección, costo y evolución |
| [Operación](documentacion/operacion.md) | Despliegue, diagnóstico, recuperación, escalamiento y costos |
| [Evaluación](documentacion/evaluacion.md) | Acciones y resultados que se pueden reproducir |
| [Calidad](documentacion/calidad.md) | Pruebas, accesibilidad, rendimiento y límites |
| [Requisitos](documentacion/requisitos.md) | Correspondencia con el documento de la prueba |
| [Uso de IA](documentacion/uso-ia.md) | Asistencia en desarrollo y forma de verificar sus resultados |
| [Videos](documentacion/audiovisual.md) | Procesos grabados, capítulos y verificaciones |
| [Colaboración](CONTRIBUTING.md) | Trunk Based Development y revisión de cambios |

Las credenciales, firmas y guías personales se conservan fuera de Git.
