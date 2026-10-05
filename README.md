# FinanceBro

Aplicación financiera en Flutter para Android e iOS, acompañada de un panel web de administración. Reúne cuentas, tarjetas, transferencias por QR, pagos, chequera digital y ahorro, con históricos por persona, cuenta, contacto y tarjeta.

FinanceBro es un prototipo para evaluación técnica. Los fondos, cuentas, tarjetas, documentos y proveedores utilizados en el recorrido son sintéticos: no custodia dinero ni ejecuta pagos bancarios reales. Deben emplearse exclusivamente identidades y documentos ficticios.

## Versión actual · 1.6.3

El [panel de administración](https://financebro-sb-20261003.web.app) y la aplicación móvil comparten Firebase Authentication, Firestore, Storage y Functions. La compilación normal utiliza este servidor; no requiere mantener encendido un servidor en el equipo del evaluador. Los accesos de evaluación se proporcionan por separado, sin publicar credenciales en este repositorio. Hay perfiles con productos e históricos cargados, una contraparte para transferencias y cheques, y solicitudes pendientes para el asesor.

La identidad visual usa la marca `fb.`, naranja, superficies de cristal, iconos y espacios consistentes. Tarjetas y acciones están dentro del mismo bloque. Los temas claro, oscuro y automático se eligen en el perfil y se conservan en el dispositivo; el panel dispone de su propio selector. El logo tiene una entrada animada y las transiciones respetan la preferencia de reducir movimiento. Las pestañas sustituyen su contenido sin superponer la vista anterior; las pantallas de detalle conservan la navegación nativa y el gesto de volver en iOS.

## Revisión visual para evaluadores

[**Abrir pantallas e interacciones de FinanceBro**](https://financebro-sb-20261003.web.app/revision/)

La galería pública reúne 210 capturas nativas de Android e iOS en temas claro y oscuro, junto con las vistas del panel publicado. Permite filtrar por función, plataforma y apariencia, ampliar cada imagen y recorrer estados de registro, contrato, productos, transferencias, comprobantes, pagos, crédito, contactos, chequera, personalización y conectividad. Las solicitudes pendientes y la elección del corte muestran etapas diferentes del mismo producto. El recorrido de conectividad incorpora carga con latencia, caída parcial, cuentas disponibles, error sin caché, desconexión y recuperación, en ambos sistemas y apariencias. Los datos son ficticios; las capturas reflejan el momento de la revisión.

Las operaciones se ejecutan desde la aplicación y el panel con los accesos entregados por separado. La galería permite revisar la interfaz sin iniciar sesión y no contiene contraseñas ni documentación personal. [Descargar la versión Android](https://github.com/CodeArtNexus/financebro-flutter/releases/tag/v1.6.3-entrega).

## Documentación para la evaluación

| Documento | Qué permite revisar |
| --- | --- |
| [Arquitectura y diagramas](documentacion/arquitectura.md) | Componentes, dependencias, flujo de transferencia y evolución por dominios |
| [Decisiones técnicas](documentacion/decisiones.md) | Problemas, alternativas, elecciones, compromisos e impacto futuro |
| [Despliegue, operación y monitoreo](documentacion/operacion.md) | Ambientes, publicación, recuperación, señales operativas, riesgos y escalamiento |
| [Recorrido y conectividad](documentacion/evaluacion.md) | Pasos reproducibles, latencia, caída parcial, caché, reintentos y recuperación |
| [Uso de IA](documentacion/uso-ia.md) | Aplicación de IA a implementación, investigación, documentación y pruebas; resultados verificados |
| [Correspondencia con la prueba](documentacion/requisitos.md) | Localización de cada requisito y límites actuales |
| [Colaborar](CONTRIBUTING.md) | Trunk Based Development, cambios pequeños, revisión y verificaciones |

La documentación describe la implementación, sus decisiones y la evidencia disponible. Distingue las capacidades conectadas de las medidas previstas para producción. La demostración remota de push se realiza en Android; APNs para iOS y el video de presentación permanecen pendientes.

## Recorrido funcional

- **Registro:** nombres, apellidos, correo, cédula, contraseña, teléfono y domicilio. Se presenta el contrato antes de confirmar y se exige aceptación expresa. El servidor crea perfil, consentimiento versionado, cuenta de ahorros con USD 0 y tarjeta de débito en una transacción. El reintento conserva la misma cuenta, tarjeta y saldo.
- **Fondos e históricos:** el asesor selecciona una cuenta y registra un ajuste con motivo. Cada operación conserva actor, fecha, importe en centavos y referencia. Las vistas globales y específicas cargan páginas anteriores sin perder movimientos durante las actualizaciones en vivo. Los contactos muestran los envíos y recepciones como una conversación.
- **QR y transferencias:** cada cuenta tiene un QR. Se valida al destinatario antes de confirmar un importe entre USD 0,10 y USD 100. Débito, crédito, históricos y avisos se registran juntos. Repetir la misma referencia no duplica la operación. La app conserva cada autorización en almacenamiento seguro antes de enviarla, también con internet. Salir de la pantalla o perder la respuesta permite consultar el mismo comprobante desde los envíos guardados; una operación ya intentada no se presenta como cancelable ni caducada sin consultar al servidor. El comprobante incluye una animación del dinero.
- **Tarjetas:** el débito de ahorros se puede personalizar con color o una imagen privada. La solicitud física conserva diseño y domicilio, admite fechas desde tres días después y pasa por revisión cuando utiliza un diseño personalizado. Los estados representan gestión del prototipo, sin emisión bancaria ni mensajería física. La cuenta corriente no genera tarjeta.
- **Tarjeta de crédito:** solicitud con ingresos, ocupación y consentimiento; el asesor aprueba y asigna un cupo. El titular recibe un aviso y elige un corte entre los días 1 y 28. La vista distingue cupo disponible, deuda, consumos posteriores al corte, total facturado, mínimo y vencimiento. El mínimo es el 5 % del saldo al corte, con piso de USD 10 sin superar la deuda; vence 15 días después, sin intereses en esta versión. Consumos sintéticos y abonos conservan referencia e histórico, y los pagos recuperan cupo. La tarjeta es un producto distinto de un préstamo.
- **Cuenta corriente:** expediente privado con cinco categorías de documentos y progreso persistente. El asesor puede pedir correcciones o aprobar una cuenta temporal. Validar un depósito sintético de USD 1.000 para pyme o USD 2.000 para gran empresa permite activarla.
- **Chequera digital:** cuentas corrientes activas emiten hasta 24 cheques mensuales por lote, agrupados por beneficiario y concepto. La cuenta receptora se valida y también debe ser corriente. El emisor consulta sus obligaciones y el beneficiario sus cobros previstos. Bloqueo, reactivación, cancelación y cambios de fecha conservan eventos y avisos a ambas personas. El límite de cambio es cinco días después de la fecha original. Los fondos no se reservan al emitir. En esta entrega, el cobro se procesa expresamente desde administración; si faltan fondos queda pendiente. El proceso automático y sus recordatorios están preparados, pero no se despliegan tareas programadas. Estos registros no constituyen cheques legalmente certificados.
- **Servicios y contactos:** contactos internos verificados por número de cuenta; externos con titular y banco. Las tarjetas externas conservan banco y últimos cuatro dígitos y muestran los pagos realizados desde FinanceBro, sin atribuirse información del emisor externo. El catálogo de servicios se administra sin reinstalar. El proveedor sintético devuelve la planilla del período y el usuario confirma el pago. La programación mensual guarda contrato, día, límite y consentimiento como propuesta visual: **no realiza débitos automáticos** en esta entrega.
- **Acceso y avisos:** saludo recordado sin guardar saldos ni contraseñas en preferencias. Una sesión anterior se puede desbloquear con autenticación nativa; el sistema decide entre biometría y código. Escanear antes de ingresar no autoriza una transferencia. La navegación principal permanece visible y los avisos permiten regresar.
- **Personalización:** metas de ahorro, saludo según preferencia, temporadas y mensajes controlados por administración, contenido remoto y divisas con estados de carga, caché, error y conectividad.
- **Sin conexión:** el primer ingreso necesita internet. Una sesión nativa anterior puede desbloquear datos guardados y preparar transferencias a contactos internos ya verificados. La autorización pendiente se conserva en almacenamiento seguro, separada por identidad y proyecto, y caduca en 24 horas. Al reconectar el servidor vuelve a validar destinatario, fondos y límites con la misma referencia. No se confirma ni se descuenta una operación antes de esa validación. Si el primer intento ya había llegado al servidor, una consulta posterior a las 24 horas recupera el comprobante existente sin un segundo descuento. Si nunca se confirmó, el servidor rechaza la autorización vencida.

## Ejecutar con el servidor publicado

Requisitos: Flutter 3.47.5 / Dart 3.13.4, Node 22.20.0 o compatible (mínimo 22.12.0 para el panel), npm 11.18.0 y Java 21. Android requiere SDK 36; iOS requiere Xcode y firma de desarrollo para dispositivos físicos. Los lockfiles fijan las dependencias y Poppins incluye su licencia OFL.

```sh
git clone https://github.com/CodeArtNexus/financebro-flutter.git
cd financebro-flutter
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <identificador-del-dispositivo>
```

Para confirmar una transferencia, FinanceBro solicita el desbloqueo nativo del dispositivo. Configurar un PIN, código o biometría también en los dispositivos virtuales que se utilicen para el recorrido manual.

No añadir `USE_EMULATORS=true` para este recorrido. El usuario registra su identidad ficticia en la app; el asesor aporta fondos sintéticos desde el panel. Se recomienda usar dos identidades para comprobar transferencia, saldo e históricos en ambos extremos. Solicitudes, aprobaciones, ajustes y avisos se comparten entre móvil y panel.

```sh
npm ci --prefix admin
npm --prefix admin run dev
```

El panel local también conecta al servidor publicado cuando `VITE_USE_EMULATORS` no está activado. Se necesita un acceso con el custom claim `financebroAdmin`; crear un usuario corriente no concede permisos de asesor. [Operaciones del panel](admin/README.md).

## Desarrollo aislado con Emulator Suite

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

Accesos exclusivamente locales: `demo@financebro.test` y `valeria@financebro.test`, clave `FinanceBro-local-2026!`. Panel local: `admin@financebro.test`, clave `FinanceBro-admin-local-2026!`. La preparación conserva fondos e históricos existentes. Estas claves no corresponden al servidor publicado.

En simulador iOS añadir `--dart-define=EMULATOR_HOST=127.0.0.1`. Los puertos se pueden cambiar con `AUTH_PORT`, `FIRESTORE_PORT`, `FUNCTIONS_PORT` y `STORAGE_PORT`; el panel utiliza los equivalentes con prefijo `VITE_`. El entorno emulado debe permanecer en ejecución. El script conserva Auth, Firestore y Storage al cerrar con Ctrl+C.

Para emuladores desde un iPhone físico, `scripts/preparar-iphone-local.py` y `scripts/proxy-funciones-https.mjs` preparan un puente HTTPS privado de siete días. Se limita a `USE_EMULATORS=true`, el proyecto `demo-financebro`, direcciones privadas y tokens sintéticos. El acceso al servidor publicado mantiene los SDK de Firebase y no utiliza ese puente.

## Arquitectura y protección de datos

[Diagramas, límites de dominio y evolución](documentacion/arquitectura.md) · [Justificación de las decisiones](documentacion/decisiones.md).

La aplicación se organiza por funcionalidades, con Riverpod para estado y GoRouter para navegación. Authentication identifica al usuario; Firestore conserva perfiles y registros; Storage protege los expedientes e imágenes. Functions ejecuta las operaciones en transacciones, comprueba identidad y rol y mantiene una bandeja de avisos. Los importes son centavos enteros y los reintentos conservan su referencia.

Los clientes no pueden escribir saldos, movimientos, aprobaciones o tarjetas directamente. Identidad y domicilio solo son legibles por su propietario; una solicitud física comparte con el asesor el domicilio consentido. El registro de cédulas y el directorio interno no son públicos. La cédula se comprueba por formato y unicidad; la mayoría de edad es una declaración, sin validación contra servicios oficiales. El contrato requiere revisión jurídica antes de cualquier uso real.

El rol de administración se asigna desde una herramienta de confianza y se comprueba también en el servidor. Cambiar el perfil o el navegador no concede permisos. Las reglas e índices de Firestore y Storage forman parte del repositorio; deben desplegarse junto con Functions. Las imágenes de tarjetas no utilizan enlaces públicos permanentes.

## Comprobaciones de integridad

La versión 1.6.3 completa la documentación de evaluación y añade dos pruebas de contraste del aviso de conexión en temas claro y oscuro. Las 123 verificaciones automáticas se acompañan de recorridos nativos separados; el aviso ahora utiliza los colores de cada tema para conservar legibilidad.

La versión 1.6.2 añade escenarios que compiten por el mismo saldo con transferencias, ajustes y cobros de cheques. Confirman conservación de fondos, ausencia de sobregiros, correspondencia entre movimiento específico y global, comprobante único y bandeja de avisos. Un fallo al crear cualquiera de los registros revierte la transferencia completa. La cuenta receptora debe coincidir con el directorio; importes, saldos, deuda, cupo y totales de cheques se comprueban antes de mover fondos.

Al cambiar de cuenta, contacto o parámetros de una vista se renueva el estado de la pantalla y su consulta, evitando conservar movimientos del producto anterior. Esta regresión se comprueba en Android e iOS, junto con el regreso nativo y los cambios de pestaña.

Las pruebas móviles también cubren respuesta perdida, recuperación tras 24 horas, cambio de identidad durante el envío, lectura lenta de una sesión anterior, fallo al guardar y fallo al cancelar. Una cola dañada se conserva y bloquea nuevas escrituras. Las reglas impiden que un cliente, incluso con rol de asesor, escriba directamente saldos, movimientos, recibos, cupos o estados de cheques.

La revisión de los tres perfiles publicados encontró cinco cuentas sin diferencias entre saldo e histórico, y deudas de crédito consistentes con consumos y abonos. El [resultado fechado](https://financebro-sb-20261003.web.app/revision/integridad.json) es una fotografía de esos perfiles; las operaciones posteriores pueden cambiar los valores. Estas comprobaciones son parte de la evaluación del prototipo y no constituyen una certificación bancaria.

La revisión ampliada encontró nueve movimientos antiguos sin su copia global. Se reconstruyeron desde los originales, conservando fecha, importe y referencia y sin modificar fondos. La [conciliación global fechada](https://financebro-sb-20261003.web.app/revision/integridad-global.json) comprueba los seis perfiles y nueve cuentas conservadas.

Para mantenimiento, `tooling/reconciliar-historicos.mjs` presenta primero un plan de lectura. Requiere la sesión propietaria de Firebase CLI y el proyecto explícito; el acceso de asesor no permite escribir registros directamente. `--aplicar` vuelve a leer cuentas, originales y destinos dentro de una transacción; aborta si aparece un cambio concurrente, un descuadre o una copia distinta. Solo crea copias ausentes y conserva la procedencia. Las pruebas comprueban también que repetirlo no duplica registros.

```sh
node --test tooling/reconciliar-historicos.test.mjs
node tooling/reconciliar-historicos.mjs --proyecto financebro-sb-20261003
```

## Publicación

[Procedimiento, recuperación, monitoreo y escalamiento](documentacion/operacion.md).

`./scripts/preparar-publicacion.sh` valida y compila el panel remoto. `./scripts/publicar-banca.sh --proyecto <proyecto>` presenta los componentes; `--ejecutar` despliega servidor, reglas, índices y clientes cuando Blaze y Storage estén habilitados. Se deben esperar los índices y comprobar dos identidades antes de distribuir la compilación móvil.

El punto de entrada publicado exporta solo `banca` y `enviarAviso`, con cero instancias mínimas y una instancia máxima por función. El envío de avisos limita los reintentos. Las tareas futuras de pagos, cortes y cheques están separadas en `functions/src/programacion.js` y no se importan en el despliegue actual. La consulta de crédito puede actualizar un corte vencido y el asesor puede procesar cheques expresamente.

Blaze permite cargos por uso de Functions, Firestore, Storage, Hosting y otros recursos. Desactivar pagos programados no elimina todos los posibles cargos; deben revisarse cuotas, almacenamiento y alertas de presupuesto. [Precios de Firebase](https://firebase.google.com/pricing).

## Verificación

```sh
./scripts/check.sh
npm --prefix functions test
npm --prefix admin test
npm --prefix admin run build

tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  'npm --prefix functions run test:integracion && npm --prefix admin run test:integracion'

mkdir -p /tmp/financebro-reglas
TMPDIR=/tmp/financebro-reglas tooling/node_modules/.bin/firebase emulators:exec \
  --only firestore,storage --project demo-financebro-reglas \
  'npm --prefix tooling test'

./scripts/prueba-banca.sh
flutter test integration_test/registro_test.dart -d emulator-5554 --dart-define=USE_EMULATORS=true
flutter test integration_test/tarjeta_credito_funcional_test.dart -d emulator-5554 --dart-define=USE_EMULATORS=true
flutter test integration_test/producto_test.dart -d emulator-5554 --dart-define=USE_EMULATORS=true
./scripts/prueba-integral.sh
```

Detener los emuladores que ocupen los puertos antes de ejecutar `emulators:exec`. Los recorridos móviles necesitan un dispositivo iniciado y los cuatro emuladores. Verifican alta y reintento, contrato, transferencias, servicios, crédito y cupos, abonos, históricos, metas, preferencias, latencia y conectividad. `nextgen_test.dart` comprueba cheques, imágenes privadas, almacenamiento seguro y reconexión; `functions/preparar-nextgen.js` prepara sus perfiles ficticios únicamente en emuladores de loopback.

CI comprueba formato, análisis, pruebas Flutter, reglas, servidor y panel sin credenciales remotas. Las pruebas incluyen conservación de fondos, concurrencia, privacidad, aprobación corporativa, solicitudes físicas, cupos y cortes, pagos de tarjetas y paginación durante actualizaciones en vivo.

## Alcance de las integraciones

Android utiliza FCM para push remotas cuando el usuario concede permiso y el dispositivo registra su token. En iOS, mientras no exista la membresía y configuración APNs, los avisos nativos se generan al recibir cambios de Firestore con la aplicación conectada; **no se garantiza entrega con la app cerrada**. La activación remota en iOS requiere configurar esas capacidades y `IOS_PUSH_ENABLED=true`. [Configuración de FCM](https://firebase.google.com/docs/cloud-messaging/flutter/client).

Apple Wallet, Google Wallet, NFC, emisión bancaria, logística física y proveedores reales requieren integraciones adicionales. Esta versión registra diseños, solicitudes y decisiones, conserva los históricos y verifica la lógica con datos sintéticos. El video funcional se incorporará como fase final de presentación. Las etiquetas permiten revisar las etapas de desarrollo; `main` contiene el README vigente. Las credenciales y guías personales permanecen fuera de Git.
