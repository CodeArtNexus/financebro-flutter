# Recorrido funcional y escenarios degradados

La evaluación puede realizarse con el [APK Android](https://github.com/CodeArtNexus/financebro-flutter/releases/tag/v1.7.0-calidad), Flutter y el [panel publicado](https://financebro-sb-20261003.web.app/). Los accesos de cliente, contraparte y asesor se entregan por separado. Todos los importes, identidades y documentos utilizados deben ser ficticios.

## Preparación

Instalar o ejecutar según el [README](../README.md). Configurar un PIN, código o biometría para autorizar transferencias, también en emuladores. Para Android remoto utilizar un dispositivo con Google Play Services y conceder permiso de notificaciones. En iOS la navegación y operaciones están disponibles; las push remotas no se presentan como habilitadas.

El recorrido utiliza dos clientes y un asesor. Al alternar sesiones se conserva la referencia de las operaciones. Las cuentas de evaluación tienen productos e históricos. Para probar un alta nueva usar otra identidad ficticia; la cuenta de ahorros y el débito se crean una sola vez.

## Recorrido conectado

| Paso | Acción | Qué observar |
| --- | --- | --- |
| 1 · Registro | Completar datos, leer contrato y aceptar antes de abrir | Ahorros en USD 0 y débito; reintentar no crea otra cuenta |
| 2 · Productos | Entrar con un perfil preparado y abrir cada cuenta y tarjeta | Resumen propio, movimientos específicos y globales; no mezclar consultas al cambiar de producto |
| 3 · Transferencia | Obtener QR o número de la contraparte; enviar entre USD 0,10 y USD 100 | Destinatario validado, confirmación, autorización nativa, comprobante y animación |
| 4 · Ambos extremos | Revisar saldo, histórico por cuenta, global y contacto | Débito y abono coherentes, referencia conservada y conversación de movimientos |
| 5 · Administración | Ajustar fondos ficticios con motivo, revisar expediente y aprobar cupo si corresponde | Estado compartido, rol de asesor comprobado y avisos al cliente |
| 6 · Crédito | Elegir corte en una tarjeta aprobada, consultar deuda y confirmar abono | Mínimo y total diferenciados, recuperación de cupo e histórico |
| 7 · Chequera | Consultar un grupo, emitir o gestionar un cheque y revisar la contraparte | Eventos, fechas originales y límite de cambio; el asesor procesa cobros expresamente |
| 8 · Experiencia | Cambiar preferencia; desde asesor activar temporada o modificar un servicio | Contenido compatible y catálogo actualizados sin reinstalar |
| 9 · Servicio externo | Consultar EUR, GBP o COP en Divisas | Fuente, fecha y resultado real; no es una compra de moneda |
| 10 · Avisos Android | Activarlos y registrar un ajuste o transferencia desde otra sesión | Recepción y apertura de la pantalla correspondiente; repetir con la app en segundo plano |

La programación mensual conserva condiciones y consentimiento, pero no cobra automáticamente. No se atribuyen Wallet, liquidación bancaria ni logística física al prototipo.

## Demostrar conectividad y recuperación

Para repetir fallos sin interrumpir el proyecto compartido, habilitar el laboratorio en una compilación de evaluación. No está visible en el APK normal:

```sh
flutter run -d <dispositivo> --dart-define=ENABLE_LAB=true
```

En Mi perfil → Laboratorio de conexión están los escenarios. El laboratorio aplica demora y fallo a divisas y puede desactivar la red de Firestore; no simula la caída de todos los servicios ni modifica el saldo. Siempre volver a «Conexión normal / recuperar» al terminar.

| Escenario | Preparación y acción | Resultado esperado |
| --- | --- | --- |
| Normal | Consultar primero una tasa | Resultado y fecha; se conserva caché local |
| Latencia | Activar alta latencia y actualizar Divisas | Estado «Consultando la tasa» antes del resultado. La demora controlada es de 4 s y se suma a la consulta externa |
| Caída parcial con caché | Activar fallo de divisas después de una consulta correcta | Reintentos acotados y última tasa guardada con aviso de posible desactualización; cuentas continúan disponibles |
| Caída parcial sin caché | Consultar una moneda nunca guardada durante el fallo, en un dispositivo limpio | Error visible y acción de reintento; no inventar una tasa ni interpretar un dato ausente como cero |
| Sin conexión recordada | Consultar antes cuentas y contactos, activar desconexión | Datos guardados con indicación de caché; puede prepararse envío a contacto interno ya verificado, sin confirmación monetaria |
| Primer ingreso sin red real | Usar dispositivo sin sesión y desactivar internet antes del ingreso | Bloqueo de acceso hasta recuperar conexión; el laboratorio del perfil no sustituye este escenario del sistema |
| Recuperación | Volver a conexión normal y actualizar | Consulta nueva; envío pendiente conserva referencia y el servidor revalida fondos, destinatario y plazo |

Las divisas reintentan errores transitorios hasta tres intentos, con espera incremental y variación; los errores definitivos no se reintentan. La caché se utiliza como respaldo hasta siete días y muestra su edad. El laboratorio no prueba por sí solo suspensión del proceso ni una pérdida real de respuesta: esos casos se verifican también mediante pruebas de cola y servidor.

## Respuesta perdida y fondos insuficientes

La app conserva cada autorización antes del envío, incluso conectada. Si el servidor confirmó pero se perdió la respuesta, se recupera el comprobante con la misma referencia. Si faltan fondos al reconectar, no se confirma ni se descuenta el envío. El dinero mostrado en caché no autoriza un débito definitivo.

Las pruebas cubren fallo de almacenamiento, archivo dañado, cambio de identidad, cancelación no guardada, expiración de una autorización sin confirmar y consulta de un recibo confirmado después de 24 horas.

## Pruebas reproducibles y capturas

[Verificaciones de CI](https://github.com/CodeArtNexus/financebro-flutter/actions) separan Flutter, reglas, panel y servidor. Las 123 pruebas automáticas de la entrega incluyen 52 Flutter, 35 operaciones bancarias, 5 validaciones, 23 reglas, 3 del panel y 5 de reconstrucción. Los recorridos móviles adicionales necesitan dispositivo; no se suman como si fueran tareas ejecutadas en CI.

```sh
./scripts/check.sh
./scripts/prueba-integral.sh
```

El segundo comando necesita los cuatro emuladores preparados, como describe el README. Comprueba ingreso, contenido remoto, divisas, latencia, desconexión, caída parcial, recuperación y registro.

Para repetir la captura de conectividad contra el servidor publicado usar `integration_test/conectividad_evaluacion_test.dart`. Solo consulta cuentas y divisas, y cambia estado local. El archivo privado de defines contiene `EVAL_CORREO` y `EVAL_CLAVE`; no se incorpora a Git:

```sh
FINANCEBRO_DISPOSITIVO=emulator-5554 \
FINANCEBRO_PLATAFORMA=android \
FINANCEBRO_EVIDENCIAS=evidencia-local/conectividad-android \
flutter drive -d emulator-5554 \
  --driver=test_driver/conectividad_driver.dart \
  --target=integration_test/conectividad_evaluacion_test.dart \
  --dart-define-from-file=.secrets/evaluacion.json
```

En simulador iOS sustituir identificador y plataforma por los correspondientes. Las capturas muestran una consulta externa real y fallos inducidos expresamente; no son pantallas ilustradas. El archivo `verificacion.txt` confirma que terminó el recorrido.

La galería reúne 210 capturas: 96 Android, 96 iOS y 18 del panel. El recorrido de conectividad conserva 14 estados por sistema y renueva también el aviso sin conexión en el resumen. La [galería pública](https://financebro-sb-20261003.web.app/revision/) complementa estos pasos con filtros y estados ampliables. Las imágenes reflejan el estado del recorrido en la fecha de captura; los perfiles pueden cambiar al utilizarse. La [presentación y el recorrido funcional](https://financebro-sb-20261003.web.app/presentacion/) añaden video conectado y capítulos; la [evidencia audiovisual](audiovisual.md) explica cómo se grabó y qué se verificó.

Las pruebas completas se apoyan en el [enfoque de integración de Flutter](https://docs.flutter.dev/cookbook/testing/integration/introduction); su ejecución no reemplaza comprobar los permisos y avisos nativos.
