# Panel de administración

El [panel publicado](https://financebro-sb-20261003.web.app/) comparte Firebase con la app. Permite consultar personas y cuentas, ajustar fondos ficticios con un motivo, revisar solicitudes, consultar movimientos y administrar servicios, temporadas y cheques.

El acceso exige el claim `financebroAdmin`. Functions comprueba ese rol en cada operación administrativa. Las reglas impiden modificar saldos o aprobaciones directamente desde el navegador. El correo y la contraseña del asesor están en la [Guía de evaluación y accesos](../documentacion/guia-evaluacion.md#panel-de-administración).

## Ejecutar

Desde la raíz del repositorio, contra el servidor publicado:

```sh
npm ci --prefix admin
npm --prefix admin run dev
```

Para trabajar contra Emulator Suite, iniciar y preparar los cuatro emuladores según el [README principal](../README.md), y ejecutar:

```sh
VITE_USE_EMULATORS=true npm --prefix admin run dev
```

Acceso local: `admin@financebro.test` / `FinanceBro-admin-local-2026!`. Los puertos alternativos se configuran con `VITE_AUTH_PORT`, `VITE_FIRESTORE_PORT`, `VITE_FUNCTIONS_PORT` y `VITE_STORAGE_PORT`. El tema claro u oscuro se elige en la cabecera.

## Operaciones

| Vista | Acción y resultado |
| --- | --- |
| Cuentas y fondos | Ajuste positivo o negativo con motivo y referencia. No permite saldo negativo; registra actor, fecha y movimientos. |
| Actividad global | Consulta paginada de operaciones. El detalle de cuenta conserva su propio histórico. |
| Solicitudes | Revisión de documentos, correcciones, aprobación temporal y activación de corriente tras el depósito requerido. También permite responder consultas de asesoría. |
| Tarjetas de crédito | Aprobar cupo de USD 1 a USD 50.000 y registrar consumos ficticios. El titular elige corte y realiza sus abonos desde la app. |
| Tarjetas físicas | Revisar diseño y domicilio autorizados. Guardar estados de preparación, envío y entrega. El servidor impide registrar envío antes de la fecha elegida. |
| Servicios | Habilitar catálogo y revisar planes mensuales. Cada pago necesita confirmación del titular; los planes no generan débitos automáticos. |
| Chequera | Consultar grupos y eventos y procesar cheques vencidos. El emisor gestiona emisión, bloqueo, fecha y cancelación desde la app. |
| Temporadas | Publicar fechas, apariencia y mensaje que reciben los clientes conectados sin reinstalar. |

Los documentos se descargan con una sesión autorizada, sin enlaces públicos permanentes. Las cuentas, fondos, proveedores y consumos son ficticios. Los estados de entrega física no están conectados a una empresa de mensajería.

## Verificar y publicar

```sh
npm --prefix admin test
npm --prefix admin run build
npm --prefix admin run test:integracion
```

La integración necesita Auth y Firestore emulados y las dependencias de `functions/`. Comprueba un ajuste recibido en vivo y la paginación por cuenta y global.

`scripts/preparar-publicacion.sh` compila el panel remoto. Hosting, Functions, reglas e índices se publican por componentes, como describe [operación](../documentacion/operacion.md). Las tareas periódicas están desactivadas; Firebase puede generar cargos por consumo.
