# Videos de FinanceBro 1.7.0

[Ver presentación y recorrido técnico](https://financebro-sb-20261003.web.app/presentacion/).

| Video | Duración | Contenido |
| --- | --- | --- |
| Presentación comercial | 1:45 | Marca, productos e interacciones principales |
| Recorrido técnico | 22:30 | 16 procesos completos, 18 capítulos y 89 pasos señalados |

Ambos archivos tienen resolución 1920 × 1080 a 30 cuadros por segundo. Incluyen textos explicativos, animaciones y música original. El recorrido móvil se muestra a velocidad normal. Los capítulos permiten ir directamente a cada proceso.

## Procesos grabados

| Inicio | Proceso | Qué se muestra |
| --- | --- | --- |
| 00:06 | Registro | Datos, domicilio, contrato, consentimiento, ahorros y débito |
| 02:22 | Ingreso | Autenticación y entrada al resumen |
| 03:01 | Cuentas e históricos | Productos, filtros y movimientos globales y específicos |
| 04:26 | Transferencia | QR propio, número receptor, titular validado, importe, origen, revisión, confirmación, comprobante e históricos |
| 06:59 | Contactos | Cuenta interna verificada y conversación de movimientos |
| 07:51 | Tarjetas | Nombre y color guardados; histórico de tarjeta |
| 09:24 | Crédito | Cupo, deuda, abono, comprobante y movimiento |
| 10:47 | Ahorro | Creación de meta y datos del objetivo |
| 11:41 | Servicios | Contrato, planilla, revisión, pago, comprobante y plan mensual |
| 13:44 | Chequera | Beneficiario, lote, fechas, emisión, bloqueo y eventos |
| 16:43 | Preferencias | Prioridad, saludo y modo oscuro |
| 18:34 | Conectividad | Consulta real, latencia, fallo parcial, caché, desconexión y recuperación |
| 19:57 | Temporada | Cambio recibido desde administración sin reinstalar |
| 20:27 | Panel | Ajuste con motivo, revisión, confirmación e históricos |
| 21:09 | Push Android | Recepción, aviso nativo y apertura del perfil |
| 21:47 | Recuperación | Respuesta perdida, envío pendiente y recuperación del comprobante único |

La transferencia ocupa 2:33. Conserva la revisión del destinatario, el formulario, el diálogo de confirmación y el resultado; no sustituye la operación por una imagen estática.

## Resultados comprobados

La [transferencia de USD 0,10](https://financebro-sb-20261003.web.app/presentacion/transferencia.json) produjo un débito de 10 centavos y un abono de 10 centavos. El total de ambas cuentas se conservó.

La [recuperación](https://financebro-sb-20261003.web.app/presentacion/recuperacion.json) utiliza Firebase local. La prueba descarta la respuesta después de que el servidor confirma y vuelve a crear sesión, proveedores y cola. FlutterSecureStorage conserva la referencia. El resultado contiene una operación, un débito y un abono; la cuenta emisora no puede leer los datos privados del receptor. La prueba no cierra el proceso desde el sistema operativo.

La [push Android](https://financebro-sb-20261003.web.app/presentacion/push-android.json) utiliza FCM real y Google Play Services. Verifica recepción en primer plano, aviso del sistema con la app en segundo plano y apertura de `/perfil` al tocarlo. La aceptación de FCM se comprueba por separado de la recepción en el dispositivo. APNs iOS está pendiente.

## Repetir la prueba remota

Se necesita un dispositivo Android con Google Play Services, una sesión propietaria de Firebase CLI y un archivo privado con `DEMO_EMAIL`, `DEMO_PASSWORD` y `DEMO_UID`:

```sh
FINANCEBRO_DEVICE_ID=<dispositivo-android> \
FINANCEBRO_PRUEBA_DEFINES=.secrets/prueba-real.json \
./scripts/prueba-remota.sh
```

## Alcance de la grabación

Las tomas móviles proceden de la app 1.7.0 ejecutada en un emulador Android. Utilizan el servidor publicado, salvo el caso de recuperación local. Los fallos de conexión se inducen para demostrar carga, error y recuperación. Las identidades, documentos, tarjetas, contratos y fondos son ficticios.

La prueba de captura automatiza la autorización del dispositivo en los procesos de productos y recuperación. El APK distribuido conserva el desbloqueo nativo. La prueba de notificaciones utiliza la implementación nativa. El panel se presenta mediante capturas consecutivas del sitio publicado.

Los planes mensuales no ejecutan cargos automáticos. Los cheques se cobran por acción del asesor. El video no demuestra Wallet, liquidación bancaria, entrega física ni proveedores de servicios reales.

## Archivos publicados

Los MP4 se distribuyen en Hosting y en la [release audiovisual](https://github.com/CodeArtNexus/financebro-flutter/releases/tag/v1.7.0-audiovisual), fuera del historial de código. Página, capítulos, pasos y resultados se versionan en el repositorio.

`node tooling/preparar-videos.mjs` descarga los archivos y comprueba SHA-256 contra `exportaciones.json`. `scripts/preparar-publicacion.sh` ejecuta esa preparación antes de compilar el panel. Una huella distinta detiene el proceso para evitar publicar otra copia por error.
