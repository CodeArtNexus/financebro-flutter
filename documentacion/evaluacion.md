# Recorrido de evaluación

Utilizar el [APK Android 1.7.0](https://github.com/CodeArtNexus/financebro-flutter/releases/tag/v1.7.0-calidad), la app ejecutada con Flutter y el [panel publicado](https://financebro-sb-20261003.web.app/). Los accesos de cliente, contraparte y asesor se entregan por separado. Los datos de registro, fondos y documentos deben ser ficticios.

## Preparar el dispositivo

Instalar según el [README](../README.md). Configurar PIN, código o biometría para autorizar transferencias. Android remoto necesita Google Play Services y permiso de notificaciones. iOS permite revisar los flujos y avisos de la app conectada; APNs sigue pendiente.

Los perfiles preparados tienen cuentas, productos e históricos. Para revisar un registro nuevo usar otra identidad ficticia. Repetir la apertura conserva una sola cuenta de ahorros y su débito.

## Flujo conectado

| Paso | Acción | Resultado que se debe revisar |
| --- | --- | --- |
| 1 | Completar registro, leer contrato y aceptar | Ahorros en USD 0 y tarjeta de débito |
| 2 | Entrar con un perfil preparado y abrir cuenta o tarjeta | Saldo y movimientos del producto seleccionado |
| 3 | Obtener QR o número de la contraparte y transferir USD 0,10 a USD 100 | Titular validado, revisión, autorización, comprobante y animación |
| 4 | Consultar ambas sesiones | Débito y abono, histórico global, detalle de cuenta y contacto |
| 5 | Ajustar fondos desde asesor con motivo | Saldo compartido, movimiento y aviso al cliente |
| 6 | Revisar solicitud de crédito, cupo y corte; confirmar un abono | Deuda, mínimo, total y cupo disponible actualizados |
| 7 | Emitir un lote de cheques y gestionar uno | Grupo, fechas, estado y eventos; la contraparte ve sus cobros previstos |
| 8 | Cambiar preferencia y publicar temporada o servicio | Saludo y contenido actualizados sin reinstalar |
| 9 | Consultar una divisa | Fuente y fecha del proveedor externo |
| 10 | Activar avisos Android y operar desde otra sesión | Recepción y apertura; repetir con la app en segundo plano |

El cobro de cheques se procesa desde el asesor. Los planes mensuales guardan condiciones, pero no generan débitos automáticos. Las tarjetas externas muestran pagos registrados en FinanceBro, no la deuda de otro banco.

## Conectividad y recuperación

El laboratorio permite introducir fallos controlados sin interrumpir el servidor compartido. Se habilita en una compilación específica; el APK normal no lo muestra:

```sh
flutter run -d <dispositivo> --dart-define=ENABLE_LAB=true
```

Abrir Mi perfil → Laboratorio de conexión. Los escenarios afectan a divisas y a la conexión de Firestore. Al terminar, seleccionar «Conexión normal / recuperar».

| Escenario | Acción | Resultado |
| --- | --- | --- |
| Normal | Consultar una tasa | Resultado y fecha; se guarda caché |
| Latencia | Activar alta latencia y actualizar | Carga visible; demora controlada de 4 s más el tiempo del proveedor |
| Fallo parcial con caché | Consultar primero y después activar fallo de divisas | Reintentos y última tasa con aviso; las cuentas siguen disponibles |
| Fallo parcial sin caché | Consultar una moneda no guardada durante el fallo | Error y botón de reintento, sin inventar un resultado |
| Desconexión con sesión anterior | Consultar cuentas/contactos y activar desconexión | Datos guardados identificados; envío pendiente a contacto interno verificado |
| Primer ingreso sin internet | Usar dispositivo sin sesión y desactivar su red | El ingreso espera conexión; este caso se prueba fuera del laboratorio |
| Recuperación | Volver a normal y actualizar | Consulta nueva y validación del envío pendiente con su misma referencia |

Divisas admite hasta tres intentos para fallos transitorios, con espera incremental. La última tasa se puede mostrar como respaldo durante siete días y señala su antigüedad. Un error definitivo no se reintenta.

La app guarda la autorización antes del envío. Si el servidor confirmó y se perdió la respuesta, recupera el comprobante con la misma referencia. Si faltan fondos al reconectar, rechaza la operación sin descontar. La información de saldo en caché no autoriza una transferencia definitiva.

## Ejecutar pruebas

```sh
./scripts/check.sh
./scripts/prueba-integral.sh
```

El segundo comando necesita dispositivo y los cuatro emuladores en ejecución. El desglose de [calidad](calidad.md) suma 149 pruebas automáticas. CI también ejecuta el E2E de recuperación Android. Los recorridos conectados con credenciales privadas y las mediciones de rendimiento se registran por separado.

Para capturar los escenarios de conexión contra el servidor publicado, utilizar un archivo privado con `EVAL_CORREO` y `EVAL_CLAVE`:

```sh
FINANCEBRO_DISPOSITIVO=emulator-5554 \
FINANCEBRO_PLATAFORMA=android \
FINANCEBRO_EVIDENCIAS=evidencia-local/conectividad-android \
flutter drive -d emulator-5554 \
  --driver=test_driver/conectividad_driver.dart \
  --target=integration_test/conectividad_evaluacion_test.dart \
  --dart-define-from-file=.secrets/evaluacion.json
```

En iOS sustituir dispositivo y plataforma. Esta prueba consulta cuentas y divisas y cambia el estado local de conexión; `verificacion.txt` confirma que terminó. Las capturas proceden de la app ejecutada y los fallos se inducen expresamente.

## Material de revisión

La [galería](https://financebro-sb-20261003.web.app/revision/) contiene 214 capturas: 100 Android, 96 iOS y 18 del panel. Permite filtrar por función, plataforma y tema. Las imágenes corresponden al momento de captura; el uso posterior de los perfiles puede cambiar sus valores.

El [recorrido técnico](https://financebro-sb-20261003.web.app/presentacion/) conserva procesos completos y capítulos. [Videos](audiovisual.md) detalla los tiempos, la conciliación de transferencia, la recepción de FCM y la recuperación local.
