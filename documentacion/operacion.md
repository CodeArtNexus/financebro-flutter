# Despliegue y operación

La app y el panel utilizan un mismo proyecto Firebase. Este documento describe cómo publicar una versión, investigar fallos y ampliar la operación. El diagnóstico del servidor está implementado; las alertas, respaldos y objetivos de producción indicados más abajo son propuestas.

## Ambientes

| Ambiente | Uso | Datos y acceso |
| --- | --- | --- |
| `demo-financebro` en Emulator Suite | Desarrollo, reglas, integración y E2E | Datos ficticios, servicios locales y sin credenciales remotas |
| `financebro-sb-20261003` publicado | Evaluación conectada de móvil y panel | Firebase real, fondos ficticios y rol de asesor separado |
| Producción financiera | No está creada | Requiere integraciones reales y controles legales, contables y operativos |

CI ejecuta los emuladores y no tiene acceso al proyecto publicado. Las pruebas que preparan datos deben ejecutarse en el ambiente local.

## Publicar

1. Seleccionar un commit revisado con CI correcto. Comprobar el recorrido nativo afectado cuando cambien permisos u operaciones.
2. Revisar reglas, índices y compatibilidad de contratos con clientes ya instalados.
3. Preparar el panel y consultar el plan:

```sh
./scripts/preparar-publicacion.sh
./scripts/publicar-banca.sh --proyecto financebro-sb-20261003
```

4. Confirmar los componentes y el consumo permitido, y ejecutar:

```sh
./scripts/publicar-banca.sh --proyecto financebro-sb-20261003 --ejecutar
```

5. Esperar a que los índices estén listos. Revisar acceso, transferencia pequeña, saldo e históricos de ambas personas, comprobante, aviso y cambio de catálogo.
6. Compilar el cliente sin defines privados ni `USE_EMULATORS`. Android se distribuye como APK; iOS utiliza firma de desarrollo. No hay TestFlight configurado.

Functions exporta `banca` y `enviarAviso` en `us-central1`: cero instancias mínimas, una máxima, 256 MiB y 60 s por función. `programacion.js` no se importa. No hay cobros o cortes diarios desplegados. Una consulta puede actualizar un corte vencido; el asesor procesa cheques de forma expresa.

Hosting no despliega Functions, reglas o índices. Si cambia solo la galería o la presentación, compilar el panel y publicar únicamente Hosting.

## Recuperar una versión

| Componente | Acción | Límite |
| --- | --- | --- |
| Hosting | Seleccionar una versión anterior | No revierte datos ni servidor |
| Functions | Preparar un commit compatible en otro checkout, verificar y desplegar | No existe una reversión conjunta de toda la plataforma |
| Reglas | Desplegar la versión compatible revisada | Una regla anterior puede reabrir permisos |
| Cliente | Detener distribución y entregar corrección compatible | Las versiones instaladas pueden coexistir |
| Datos | Conciliar y reparar con registro de procedencia | Volver al código anterior no deshace un movimiento |

No repetir una operación incierta con otra referencia. Si existe comprobante, recuperar ese resultado. [Versiones de Hosting](https://firebase.google.com/docs/hosting/manage-hosting-resources).

## Diagnóstico implementado

`observacion.js` registra eventos `operacion_finalizada` con operación, duración en ms, resultado y categoría de error: negocio, acceso o técnico. La correlación utiliza los primeros 20 caracteres del SHA-256 de la referencia. Excluye nombres, cédulas, claves, tokens, documentos, saldos y conceptos. Un fallo del log no cambia la operación.

En Logs Explorer, seleccionar el proyecto y filtrar:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="banca"
jsonPayload.message="operacion_finalizada"
```

Agregar `jsonPayload.categoria="tecnico"` para errores técnicos o `jsonPayload.correlacion` para investigar una referencia. Calcular el hash localmente; no copiar referencias o datos privados en tickets públicos. [Logs de Functions](https://firebase.google.com/docs/functions/writing-and-viewing-logs).

`enviosPush` conserva estado, dispositivos pendientes, intentos y reserva de 90 s. Revisar permiso y registro del token si no hay dispositivo. Un estado enviado confirma aceptación de FCM, no lectura del usuario. El aviso puede fallar sin afectar el movimiento.

Flutter registra categorías técnicas y duración de consultas. No exporta todavía telemetría a Crashlytics o analítica. No hay un tablero nuevo ni alertas automáticas configuradas.

## Monitoreo previsto

Los siguientes umbrales son puntos de partida para producción y deben ajustarse con mediciones:

| Señal | Qué medir | Cuándo investigar |
| --- | --- | --- |
| Fallos móviles | Sesiones afectadas por versión, sistema y pantalla | Una regresión o aumento de errores no controlados |
| Operaciones | Duración p50/p95 y errores técnicos | Más de 1 % de errores durante 10 min con 20 intentos; p95 superior a 3 s durante 10 min |
| Integridad | Saldo, movimientos, recibos y copias globales | Cualquier diferencia confirmada |
| Push | Fallos, dispositivos pendientes y antigüedad | Eventos pendientes más de 5 min |
| Registro y transferencia | Inicio, finalización y abandono sin formularios | Cambios por versión o latencia |
| Divisas | Duración, HTTP, uso y edad de caché | Caída del proveedor sin afectar cuentas |
| Consumo | Lecturas, escrituras, archivos, invocaciones y tráfico | Desviación frente a cuotas y presupuesto |

Antes de activar telemetría, definir acceso y retención. Una alerta de presupuesto informa consumo; no impone un límite de gasto.

## Investigar un incidente

1. Identificar versión, plataforma, operación y referencia sin publicar datos personales.
2. Buscar comprobante e históricos. Si existe confirmación, recuperar el resultado y revisar la presentación.
3. Si el resultado es incierto, conservar la autorización y consultar con la misma referencia cuando responda el servidor.
4. Revisar Functions, índices, permisos y el proveedor afectado. Un fallo de divisas no requiere alterar cuentas.
5. Reproducir y corregir en emuladores. Añadir una prueba de regresión, publicar una versión compatible y conciliar los registros afectados.

No existe un interruptor global de mantenimiento. Suspender una operación exige una validación del servidor; ocultar el botón no bloquea el endpoint.

## Respaldos

El ambiente local conserva exportaciones de Emulator Suite. El proyecto publicado no tiene un respaldo periódico o una restauración de producción comprobados.

Para producción se propone respaldo administrado de Firestore, retención de Storage, inventario de configuración y recuperación de identidades. Objetivos iniciales: RPO de 24 h, es decir, pérdida máxima de datos tolerada; RTO de 4 h, tiempo previsto para recuperar el servicio. Dependen de costo y un ensayo de restauración.

Restaurar primero en un ambiente separado y comprobar fondos y permisos. Git no respalda datos. Una exportación de Firestore tampoco incluye por sí sola Auth, archivos y configuración. [Exportaciones de Firestore](https://firebase.google.com/docs/firestore/manage-data/export-import).

## Escalamiento y costos

Medir tamaño de páginas, listeners, lecturas, escrituras y operaciones concurrentes sobre la misma cuenta antes de aumentar capacidad. Mantener transacciones pequeñas, revisar índices y evitar un documento único para todo el tráfico. [Prácticas de Firestore](https://firebase.google.com/docs/firestore/best-practices).

Una instancia máxima limita capacidad y puede aumentar latencia. Subir el límite requiere prueba de carga y presupuesto. Separar dominios después de definir interfaces y compatibilidad; si cambian de base, también cambia la estrategia de transacciones. [Arquitectura](arquitectura.md).

Blaze puede facturar Functions, Firestore, Storage, Hosting y recursos relacionados. Cero instancias mínimas y tareas periódicas desactivadas reducen consumo, pero no garantizan costo cero. Esta documentación no activa servicios o políticas nuevas.
