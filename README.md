# FinanceBro

Aplicación Flutter para Android e iOS que reúne cuentas, tarjetas, transferencias por QR, pagos, ahorro e históricos. Su panel web comparte la marca `fb.`, las superficies translúcidas y la paleta blanco y naranja melocotón, y permite acompañar las operaciones desde administración.

FinanceBro es un prototipo para evaluación técnica. Los fondos, números de cuenta, tarjetas y proveedores son sintéticos: no custodia dinero ni ejecuta pagos bancarios reales. Para verificarlo deben utilizarse exclusivamente identidades y documentos ficticios.

## Experiencia actual · 1.4.0

- **Alta completa:** nombres, apellidos, correo, cédula, contraseña, teléfono y domicilio. Antes de confirmar se presenta el contrato y se requiere aceptación expresa. El servidor crea el perfil, una cuenta de ahorros con USD 0, su tarjeta de débito digital y el consentimiento versionado dentro de una transacción. Un reintento puede completar el alta con el mismo acceso y conserva cuenta, tarjeta y saldo.
- **Transferencias por QR:** cada cuenta dispone de un QR. El emisor verifica al destinatario y confirma un importe entre USD 0,10 y USD 100. Débito, crédito, históricos y avisos se registran juntos; una referencia evita repetir la operación. El comprobante incluye una animación del dinero y respeta la preferencia de reducir movimiento.
- **Históricos:** vista global y detalle por cuenta, contacto o tarjeta propia y externa, con filtros y carga de páginas anteriores. Los registros incluyen referencia, fecha e importe en centavos.
- **Tarjetas:** el débito de ahorros se puede visualizar, personalizar y solicitar en formato físico. La solicitud conserva el diseño y domicilio elegidos, exige envío desde tres días después y muestra sus estados. Un diseño personalizado pasa por revisión del asesor; la fecha de envío no garantiza una fecha de entrega. La solicitud de tarjeta de crédito registra ingresos, ocupación y autorización. Un asesor aprueba o rechaza; al aprobar asigna un cupo y emite una tarjeta digital. El titular recibe el aviso y elige un corte mensual del día 1 al 28 para activarla. Este producto es independiente de un préstamo.
- **Estado de cuenta de crédito:** cupo aprobado y disponible, saldo pendiente, consumos posteriores al corte, total facturado pendiente, mínimo y vencimiento. El mínimo es el 5 % del saldo al corte, con piso de USD 10 sin superar la deuda; vence 15 días después, sin intereses en esta versión. El servidor registra consumos sintéticos desde administración y abonos desde cuentas activas; cada referencia impide duplicados y el pago recupera cupo. Los cortes se conservan en documentos por fecha y se actualizan al consultar o con el programador diario preparado para despliegue.
- **Cuenta corriente:** expediente con cinco categorías de documentos privados y progreso persistente. El asesor puede pedir correcciones o aprobar una cuenta temporal. La validación de un depósito sintético de USD 1.000 para pyme o USD 2.000 para gran empresa permite activarla. La cuenta corriente no genera una tarjeta.
- **Pagos y contactos:** contactos internos verificados por número de cuenta; externos con datos del titular y banco. Las tarjetas externas se presentan como tarjetas de otro banco y guardan emisor y últimos cuatro dígitos; la app muestra sus pagos desde FinanceBro, sin atribuirse información sobre cupos o estados de cuenta externos. El catálogo de servicios se administra sin reinstalar la app. El proveedor sintético devuelve la planilla del período; el pago mensual requiere consentimiento, día y límite, se puede pausar y evita cobrar dos veces el mismo mes.
- **Acceso y avisos:** saludo recordado sin guardar saldos ni contraseñas en preferencias. Una sesión guardada puede desbloquearse con la autenticación nativa del dispositivo; el sistema decide entre biometría y código. Escanear QR antes de ingresar no autoriza una transferencia. Los avisos permanecen en el histórico y pueden mostrarse como notificaciones del sistema con permiso del usuario.
- **Personalización:** metas de ahorro, preferencias, contenido remoto y consulta de divisas con estados de carga, error, caché y conectividad.

## Ejecutar con Emulator Suite

Requisitos: Flutter 3.47.5 / Dart 3.13.4, Node 22, npm 11.18.0 y Java 21. Android requiere SDK 36; iOS, Xcode y un equipo de firma para dispositivos físicos. Los lockfiles fijan las dependencias y Poppins incluye su licencia OFL.

```sh
flutter pub get --enforce-lockfile
npm install --global npm@11.18.0
npm ci --prefix tooling
npm ci --prefix functions
npm ci --prefix admin
tooling/node_modules/.bin/firebase emulators:start \
  --only auth,firestore,functions,storage --project demo-financebro
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

Accesos exclusivamente locales: `demo@financebro.test` y `valeria@financebro.test`, clave `FinanceBro-local-2026!`. Panel: `admin@financebro.test`, clave `FinanceBro-admin-local-2026!`. La preparación conserva fondos e históricos existentes y guarda la cuenta receptora del recorrido en un archivo ignorado de `.secrets/`.

En simulador iOS añadir `--dart-define=EMULATOR_HOST=127.0.0.1`. En dispositivos físicos configurar un host accesible en la misma red privada. Los puertos se pueden cambiar con `AUTH_PORT`, `FIRESTORE_PORT`, `FUNCTIONS_PORT` y `STORAGE_PORT`; el panel utiliza `VITE_AUTH_PORT`, `VITE_FIRESTORE_PORT`, `VITE_FUNCTIONS_PORT` y `VITE_STORAGE_PORT`. El entorno local debe mantenerse en ejecución para registrar y operar.

## Arquitectura y protección de datos

La aplicación se organiza por funcionalidades, con Riverpod para estado y GoRouter para navegación. Firebase Authentication identifica al usuario; Firestore conserva perfiles y registros; Storage protege los expedientes. Functions ejecuta las operaciones en transacciones, comprueba identidad y rol, y mantiene una bandeja de avisos. El saldo se calcula en centavos enteros y los reintentos conservan su referencia.

Los clientes no pueden escribir saldos, movimientos, aprobaciones o tarjetas directamente. Los datos de identidad y el domicilio solo son legibles por su propietario; una solicitud física comparte el domicilio consentido con el asesor. El registro de cédulas y el directorio interno no son públicos. La cédula se comprueba por formato y unicidad; la mayoría de edad es una declaración del usuario, sin validación de identidad contra servicios oficiales. El contrato es contenido del prototipo y requiere revisión jurídica antes de cualquier uso real.

El panel exige el custom claim `financebroAdmin`, asignado desde una herramienta de confianza y comprobado otra vez por el servidor. Cambiar el perfil o el navegador no concede permisos. [Operaciones del panel](admin/README.md).

## Verificación

```sh
./scripts/check.sh
npm --prefix functions test
npm --prefix admin test
npm --prefix admin run build

tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  'npm --prefix functions run test:integracion && npm --prefix admin run test:integracion'

tooling/node_modules/.bin/firebase emulators:exec \
  --only firestore,storage --project demo-financebro-reglas \
  'npm --prefix tooling test'

./scripts/prueba-banca.sh
flutter test integration_test/registro_test.dart -d emulator-5554 --dart-define=USE_EMULATORS=true
flutter test integration_test/tarjeta_credito_funcional_test.dart -d emulator-5554 --dart-define=USE_EMULATORS=true
flutter test integration_test/producto_test.dart -d emulator-5554 --dart-define=USE_EMULATORS=true
./scripts/prueba-integral.sh
```

Los recorridos móviles necesitan un dispositivo iniciado y los cuatro emuladores. `registro_test.dart` verifica el contrato, la apertura obligatoria y solicitudes; `banca_test.dart`, transferencias, servicios e históricos; `tarjeta_credito_funcional_test.dart`, alta, aprobación con cupo, elección del corte, consumo, abono e histórico por tarjeta; `producto_test.dart`, metas y acceso recordado; `flujo_critico_test.dart`, preferencias, contenido remoto, divisas, latencia y conectividad. En Android, `AVISOS_NATIVOS=true` comprueba las notificaciones con permiso previamente concedido en el dispositivo de pruebas. En iPhone físico, `SDK_REGISTRO=true` permite comprobar los SDK nativos de alta y reintento en una compilación de evaluación. Estas opciones no alteran el flujo de la aplicación normal.

CI comprueba formato, análisis, pruebas Flutter, reglas, servidor y panel sin credenciales remotas. Las pruebas incluyen conservación de fondos, concurrencia, acceso privado, aprobación corporativa, solicitudes físicas, fechas, cupos y cortes de crédito, pagos de tarjetas, pagos mensuales y paginación durante actualizaciones en vivo.

## Alcance de las integraciones

La evolución 1.4.0 se verifica en el entorno local. Su despliegue de Functions, Storage y pagos programados requiere Blaze; no se ha activado facturación. El [panel publicado](https://financebro-sb-20261003.web.app) y los artefactos anteriores conservan la versión 1.1.0 hasta desplegar de forma coordinada servidor, reglas y clientes.

Las notificaciones nativas del entorno local se generan al recibir cambios de Firestore mientras la app mantiene conexión. No son push remotas y no garantizan entrega con la aplicación cerrada. FCM está preparado para el entorno remoto; iOS necesita membresía Apple Developer y APNs, y solo se activa con `IOS_PUSH_ENABLED=true` después de configurar esas capacidades. [Notificaciones locales](https://pub.dev/packages/flutter_local_notifications), [autenticación del dispositivo](https://pub.dev/packages/local_auth) y [configuración de FCM en Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/client).

Apple Wallet, Google Wallet, pago NFC, emisión bancaria de crédito y logística de tarjetas físicas requieren integraciones del emisor y proveedor correspondientes. El prototipo registra diseños, solicitudes y decisiones de administración; no incorpora esas redes ni realiza envíos físicos. El proveedor de planillas y pagos externos también es sintético.

Las siguientes evoluciones son el despliegue coordinado tras revisar costos, habilitar push remotas, integrar proveedores y integrar emisión bancaria y entrega física. La solicitud de préstamos constituye una evolución distinta de la tarjeta de crédito. El video funcional se incorpora como fase final de presentación. Las etiquetas anteriores permiten revisar las etapas de desarrollo; `main` contiene el README vigente.
