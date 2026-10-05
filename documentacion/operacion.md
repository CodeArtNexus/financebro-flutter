# Despliegue, operación y monitoreo

La versión conectada comparte Firebase entre móvil y panel. Este documento describe el despliegue actual y la estrategia que se aplicaría al ampliar la operación. Las métricas, alertas y respaldos propuestos no se presentan como habilitados en el proyecto de evaluación.

## Estado actual y ambientes

| Ambiente | Uso | Protección y límites |
| --- | --- | --- |
| Emulator Suite `demo-financebro` | Desarrollo y pruebas de reglas, operaciones y E2E | Loopback, datos ficticios, dependencias fijadas; ninguna credencial de servidor publicada |
| Proyecto publicado `financebro-sb-20261003` | Evaluación móvil y panel compartidos | Auth, reglas, Storage privado y Functions; fondos ficticios y acceso de asesor separado |
| Producción bancaria futura | No existe en esta entrega | Requiere proyecto independiente, contratos reales, evaluación legal, contable y de seguridad |

No se usa el proyecto publicado como banco real ni como entorno para probar escrituras destructivas. CI ejecuta emuladores con identidad local y no dispone de acceso al proyecto publicado.

## Publicar y comprobar una versión

1. Partir de un commit revisado, con lockfiles y comprobaciones de CI correctas. Ejecutar el E2E afectado cuando cambien permisos, navegación, operaciones o comportamiento del dispositivo.
2. Revisar reglas, índices, contratos y compatibilidad con el cliente anterior. Una nueva lectura dependiente de un índice se habilita después de que el índice esté listo.
3. Preparar panel y servidor desde la raíz:

```sh
./scripts/preparar-publicacion.sh
./scripts/publicar-banca.sh --proyecto financebro-sb-20261003
```

4. Tras revisar el plan y el consumo autorizado, ejecutar el despliegue:

```sh
./scripts/publicar-banca.sh --proyecto financebro-sb-20261003 --ejecutar
```

5. Esperar los índices y comprobar con dos identidades: acceso, transferencia pequeña, saldo e históricos en ambos extremos, comprobante único, aviso y cambio de catálogo desde asesor. No repetir una operación incierta con una referencia nueva.
6. Compilar el cliente normal sin definiciones privadas ni `USE_EMULATORS`, comprobar permisos y distribuir una versión identificable. Android dispone de APK; la distribución iOS de esta evaluación utiliza firma de desarrollo. TestFlight no está preparado.

El despliegue actual exporta `banca` y `enviarAviso`, en `us-central1`, con `minInstances: 0`, `maxInstances: 1`, 256 MiB y 60 segundos por función. `programacion.js` no se importa en el punto de entrada. No hay pagos periódicos, cortes o cobros diarios desplegados. La consulta puede actualizar un corte vencido y el asesor puede procesar un cheque expresamente.

Un despliegue de Hosting no despliega por sí mismo reglas, índices ni Functions. Para cambios únicamente de galería, compilar el panel y publicar solo Hosting evita sustituir innecesariamente el servidor.

## Recuperar una publicación

| Componente | Procedimiento | Precaución |
| --- | --- | --- |
| Hosting | Volver a una versión anterior desde las versiones de Hosting | La reversión del sitio no revierte saldos ni servidor; [versiones y canales](https://firebase.google.com/docs/hosting/manage-hosting-resources) |
| Functions | Preparar el código de un commit compatible en un checkout aislado, verificar y volver a desplegar las funciones afectadas | No existe una reversión conjunta automática de toda la plataforma |
| Reglas | Revisar y desplegar el archivo versionado compatible | Volver a una regla anterior puede reabrir permisos; evitarlo sin evaluar su alcance |
| Cliente móvil | Suspender distribución y corregir o entregar versión compatible | Clientes ya instalados pueden coexistir; conservar contratos compatibles |
| Datos | Conciliar y reparar con procedimiento trazable; restaurar primero en ambiente aislado | Volver al código anterior no deshace movimientos. No reemplazar un saldo por un cálculo local ni repetir un cobro |

## Monitoreo propuesto para producción

Hoy existen categorías técnicas en Flutter, duración de consultas de divisas, captura básica de errores, registros de Functions y estados persistidos de avisos. No se exporta telemetría móvil a Crashlytics o a un sistema de analítica, ni se documenta una política de alertas ya activa.

La ampliación propuesta combina fallos técnicos con resultado del recorrido. Los objetivos siguientes son umbrales iniciales de diseño, no mediciones ni acuerdos de disponibilidad de esta entrega:

| Señal | Medición prevista | Aviso y diagnóstico |
| --- | --- | --- |
| Fallos fatales y errores no controlados | Crashlytics o equivalente, por versión, sistema y pantalla | Investigar regresiones nuevas y aumento de sesiones afectadas |
| Operaciones bancarias | Duración p50/p95, fallos técnicos y contención por tipo de operación | Aviso si errores técnicos superan 1 % durante 10 minutos con al menos 20 intentos, o p95 supera 3 s durante 10 minutos |
| Integridad | Conciliación de saldos, movimientos, comprobantes y proyecciones | Cualquier diferencia requiere investigación; detener operaciones afectadas si se verifica riesgo |
| Avisos | Cantidad fallida, sin dispositivo, reintentos y antigüedad de pendientes | Revisar eventos pendientes más de 5 minutos; distinguir dispositivo sin permiso de fallo del transporte |
| Registro y transferencias | Inicio, finalización y abandono, sin contenido de formularios | Comparar versiones y latencia; caídas de conversión no se interpretan automáticamente como fallos |
| Divisas | Tiempo, error por código HTTP, uso y edad de caché | Detectar caída del proveedor manteniendo independientes las operaciones de cuentas |
| Consumo | Lecturas, escrituras, almacenamiento, invocaciones y tráfico | Revisar cuotas y alertas de presupuesto; un presupuesto no impone un tope de gasto |

Los rechazos por fondos insuficientes o datos inválidos son resultados de negocio, separados de los errores técnicos. Se registrarían referencias opacas, versión y categoría para correlacionar incidentes, sin nombres, cédulas, contraseñas, tokens, documentos, saldos ni texto de transferencias. El acceso y la retención de telemetría deben definirse antes de su activación. Los [registros de Functions](https://firebase.google.com/docs/functions/writing-and-viewing-logs) permiten consultar errores del servidor; su existencia no acredita un tablero ni alertas configuradas.

## Procedimiento ante incidentes

1. Identificar versión, plataforma, operación y referencia; conservar evidencia sin copiar información personal en logs o tickets.
2. Consultar comprobante e históricos. Si existe confirmación, tratar el problema como recuperación de respuesta o presentación; no enviar de nuevo con otra referencia.
3. Si no se puede determinar el resultado, conservar la autorización y volver a consultar con la misma referencia cuando el servidor responda.
4. Revisar estado de Functions, índices, permisos y proveedor afectado. Limitar la investigación al dominio que falla; una caída de divisas no justifica alterar cuentas.
5. Corregir y comprobar en emuladores; publicar una versión compatible y conciliar los registros involucrados. Documentar causa, alcance y prueba que evita regresión.

No hay un interruptor bancario global de mantenimiento implementado. Si una operación debe suspenderse, se requiere una validación del servidor revisada; ocultar un botón del cliente no bloquea su endpoint.

## Respaldos y continuidad

El entorno local conserva exportaciones de Emulator Suite. No se atribuye al proyecto publicado un respaldo periódico o recuperación puntual que no se ha configurado.

Para producción se propone exportación o respaldo administrado de Firestore, protección y retención de Storage, inventario de configuración y procedimiento autorizado para identidades. Objetivos iniciales: RPO de 24 horas y RTO de 4 horas, pendientes de costos y de una prueba de restauración. Reducir el RPO requiere evaluar respaldos o recuperación puntual; no basta conservar Git. Una restauración debe probarse primero en otro ambiente, conciliar y verificar permisos antes de decidir una recuperación del ambiente principal. Las [exportaciones e importaciones de Firestore](https://firebase.google.com/docs/firestore/manage-data/export-import) son un mecanismo de datos, no una copia completa de Auth, archivos y configuración.

## Escalamiento y costos

Antes de aumentar capacidad: medir consultas, tamaño de páginas, listeners, escrituras por operación y contención sobre cuentas frecuentes. Mantener transacciones pequeñas, revisar índices y evitar concentrar todo el tráfico en un único documento. Estos criterios se apoyan en las [prácticas de Firestore](https://firebase.google.com/docs/firestore/best-practices).

El límite de una instancia por función prioriza un consumo acotado para evaluación y puede limitar capacidad o elevar latencia. Incrementarlo requiere prueba de carga, validación de concurrencia y presupuesto. Después, extraer dominios conforme a los contratos descritos en [arquitectura](arquitectura.md), conservar idempotencia y separar procesos no monetarios de la confirmación de fondos.

Blaze permite cargos por Functions, Firestore, Storage, Hosting y otros recursos. Instancias mínimas en cero y ausencia de tareas periódicas reducen consumo recurrente, pero no garantizan costo cero. No se activaron nuevas alertas, planes ni servicios facturables como consecuencia de esta documentación.
