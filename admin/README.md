# Administración de FinanceBro

Panel web con acceso de asesor para consultar personas, cuentas y actividad global; ajustar fondos con un motivo; revisar cuentas corrientes, solicitudes de crédito y tarjetas físicas; generar QR y administrar servicios y pagos mensuales. Comparte datos e identidad visual con el cliente móvil.

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

Las solicitudes de crédito muestran ingresos declarados, ocupación y consentimiento; preaprobar registra una evaluación inicial y no concede un cupo. Las solicitudes físicas conservan el diseño y domicilio autorizados, con revisión para diseños personalizados. El servidor impide registrar un envío antes de la fecha seleccionada; cada decisión deja una revisión y avisa al cliente. Registrar envío o entrega representa un estado del prototipo, sin integración con mensajería física.

El catálogo habilita servicios sin reinstalar la app. Los pagos mensuales conservan consentimiento, cuenta, contrato, día y límite. El servidor evita pagar dos veces un período y registra incidencias cuando no puede completar el pago. El panel puede procesar pagos vencidos con el mismo flujo preparado para el programador.

## Verificación y despliegue

```sh
npm --prefix admin test
npm --prefix admin run build
npm --prefix admin run test:integracion
```

La prueba de integración requiere las dependencias de `functions/`, Auth y Firestore emulados. Comprueba paginación y un ajuste recibido en vivo, por cuenta y en la actividad global.

La versión actual se ejecuta localmente. El panel remoto conserva 1.1.0 hasta desplegar conjuntamente Functions, Storage, reglas y clientes después de revisar Blaze. Credenciales, firmas locales y la guía personal no forman parte del repositorio.
