# Administración de FinanceBro

Panel web con acceso de asesor para consultar personas, cuentas y actividad global; ajustar fondos con un motivo; revisar cuentas corrientes, solicitudes de tarjeta de crédito y tarjetas físicas; generar QR y administrar servicios, pagos mensuales, temporadas y cheques. Comparte datos e identidad visual con el cliente móvil.

Es parte del prototipo descrito en el [README principal](../README.md): los fondos y proveedores son sintéticos. No concede crédito real ni emite tarjetas bancarias o realiza envíos físicos.

## Acceso y ejecución

Iniciar los cuatro emuladores y preparar las cuentas según el README principal:

```sh
npm ci --prefix admin
VITE_USE_EMULATORS=true npm --prefix admin run dev
```

Acceso exclusivamente local: `admin@financebro.test` / `FinanceBro-admin-local-2026!`. El panel exige sesión y el custom claim `financebroAdmin`. Functions comprueba otra vez el rol; el navegador no puede modificar saldos, movimientos o aprobaciones directamente. Para puertos diferentes usar las variables `VITE_AUTH_PORT`, `VITE_FIRESTORE_PORT`, `VITE_FUNCTIONS_PORT` y `VITE_STORAGE_PORT`.

## Operaciones

Cada ajuste conserva actor, motivo, fecha, importe y referencia para evitar repetición. El panel impide retirar más fondos de los disponibles. La vista global y el detalle de cuenta cargan páginas anteriores y conservan movimientos que salen de la ventana en vivo durante una actualización.

Los documentos corporativos se descargan con sesión de asesor, sin enlaces públicos permanentes. El expediente puede recibir correcciones, aprobación temporal o activación después de comprobar el depósito inicial. La cuenta corriente no emite tarjeta.

Las solicitudes de tarjeta de crédito muestran ingresos declarados, ocupación y consentimiento. Aprobar exige un cupo entre USD 1 y USD 50.000, emite la tarjeta digital y avisa al titular para elegir el corte mensual. La vista de tarjetas distingue cupo disponible, deuda, total facturado y mínimo; permite registrar consumos sintéticos con comercio y referencia. La actualización de cortes vencidos usa el mismo proceso del programador. Cada compra y abono conserva su histórico; un pago desde ahorros recupera cupo. Las solicitudes físicas conservan el diseño y domicilio autorizados, con revisión para diseños personalizados. El servidor impide registrar un envío antes de la fecha seleccionada; cada decisión deja una revisión y avisa al cliente. Registrar envío o entrega representa un estado del prototipo, sin integración con mensajería física.

El catálogo habilita servicios sin reinstalar la app. Los pagos mensuales conservan consentimiento, cuenta, contrato, día y límite. El servidor evita pagar dos veces un período y registra incidencias cuando no puede completar el pago. El panel puede procesar pagos vencidos con el mismo flujo preparado para el programador.

Las temporadas admiten fechas de inicio y fin, tema visual y mensaje. Los clientes conectados reciben el cambio sin instalar otra versión. El catálogo separa disponibilidad y visibilidad para conservar los registros de servicios retirados.

La chequera global permite consultar estados, obligaciones y cobros por persona, procesar vencimientos y revisar los eventos de cada cheque. Una petición de asesor queda en Solicitudes y la respuesta genera un aviso al titular. Emisión, bloqueo, cancelación y cambios de fecha corresponden al emisor desde la app; el asesor no sustituye ese consentimiento.

## Verificación y despliegue

```sh
npm --prefix admin test
npm --prefix admin run build
npm --prefix admin run test:integracion
```

La prueba de integración requiere las dependencias de `functions/`, Auth y Firestore emulados. Comprueba paginación y un ajuste recibido en vivo, por cuenta y en la actividad global.

La versión 1.5.0 se ejecuta localmente. `scripts/preparar-publicacion.sh` compila la versión remota sin desplegar; el script `publicar-banca.sh` presenta primero los componentes. El panel remoto conserva 1.1.0 hasta desplegar conjuntamente Functions, Storage, reglas y clientes después de revisar Blaze. Credenciales, firmas locales y la guía personal no forman parte del repositorio.
