# Presentación audiovisual y recorrido por etapas

[Ver ambos videos y navegar por capítulos](https://financebro-sb-20261003.web.app/presentacion/).

| Pieza | Duración | Propósito |
| --- | --- | --- |
| Presentación comercial 1.7.0 | 1 min 45 s | Marca, productos y experiencia conectada |
| Recorrido técnico 1.7.0 | 22 min 30 s | Procesos completos, pasos sincronizados y verificaciones del resultado |

Ambas piezas se montaron y exportaron con Adobe After Effects 2026, en 1920 × 1080 a 30 cuadros por segundo. La marca `fb.`, el naranja suave, Poppins y las animaciones de textos y encuadres mantienen la identidad de la aplicación. La música original se compuso mediante síntesis, sin muestras ni grabaciones de terceros; se repite dentro del recorrido largo. La tipografía conserva su licencia OFL. La explicación se presenta mediante rótulos, sin locución.

## Procesos completos

El recorrido técnico conserva las tomas móviles completas, a velocidad normal. Cada capítulo muestra sus formularios, revisiones, confirmaciones y resultados. Un indicador identifica el paso actual de acuerdo con el instante de la grabación. Los capítulos permiten revisar una función sin reproducir toda la pieza.

1. **Apertura:** datos, domicilio, lectura del contrato y consentimiento; el servidor crea una única cuenta de ahorros en cero y su tarjeta de débito.
2. **Ingreso e históricos:** autenticación, cuentas, filtros, cuenta corriente y movimientos globales.
3. **Transferencia:** acceso a QR, código para recibir, ingreso manual del número receptor, validación del titular, monto y concepto, selección de origen, revisión, confirmación, comprobante y registro en ahorros y contacto. Se muestra el proceso completo, sin sustituir la operación por una captura estática.
4. **Contactos y tarjetas:** cuenta interna verificada, conversación financiera, configuración de nombre y color y movimientos por tarjeta.
5. **Crédito y ahorro:** cupo, deuda, abono confirmado, comprobante e histórico; creación de un objetivo y sus aportes de referencia.
6. **Servicios:** contrato, consulta de planilla, revisión, pago, comprobante y programación mensual con consentimiento.
7. **Chequera:** beneficiario validado, lote con fechas e importes, emisión, bloqueo con motivo y trazabilidad.
8. **Preferencias:** prioridad, saludo adaptado, modo oscuro y navegación consistente.
9. **Conectividad:** consulta real de divisas, latencia y caída parcial inducidas, respaldo identificado, continuidad bancaria, desconexión controlada y recuperación.
10. **Experiencia remota y administración:** temporada publicada desde una identidad de asesor; ajuste de fondos sintéticos con revisión, confirmación e histórico de cuenta y global.
11. **Push Android:** registro, recepción en primer plano, aviso del sistema y apertura de la pantalla de destino.
12. **Recuperación financiera:** respuesta perdida después de confirmar, operación pendiente, reconstrucción de sesión, recuperación del mismo comprobante e históricos de emisor y receptor.

## Conciliación y recuperación

La [transferencia publicada de USD 0,10](https://financebro-sb-20261003.web.app/presentacion/transferencia.json) se comprueba contra el servidor: débito de 10 centavos, abono de 10 centavos y conservación del total entre ambos extremos.

La [recuperación financiera](https://financebro-sb-20261003.web.app/presentacion/recuperacion.json) utiliza Firebase local aislado. El arnés descarta una respuesta después de que el servidor haya confirmado la transferencia y reconstruye los proveedores de sesión; el almacenamiento seguro nativo conserva la referencia. Se recupera el mismo comprobante, con una única operación y un movimiento en cada extremo. Se comprueba además que el emisor no puede leer la cuenta del receptor. Este escenario es inducido y no representa un fallo ocurrido en el servidor público ni un cierre real del proceso del sistema operativo.

## Notificación remota Android

La [verificación fechada](https://financebro-sb-20261003.web.app/presentacion/push-android.json) utiliza FCM real en Android con Google Play Services. La aplicación registra el token y confirma la recepción del primer mensaje. Un segundo envío se publica como aviso nativo con la app en segundo plano; UI Automator pulsa el aviso y Flutter comprueba el regreso al primer plano y la apertura de `/perfil`.

Aceptar un mensaje en FCM no basta para darlo por recibido: la prueba verifica recepción, publicación y apertura en el dispositivo grabado. No garantiza entrega en cualquier equipo desconectado y no verifica APNs de iOS, cuya habilitación sigue pendiente.

Para reproducir la comprobación se requiere Firebase real, una sesión propietaria de Firebase CLI, Google Play Services, un perfil de evaluación y un archivo privado con `DEMO_EMAIL`, `DEMO_PASSWORD` y `DEMO_UID`:

```sh
FINANCEBRO_DEVICE_ID=<dispositivo-android> \
FINANCEBRO_PRUEBA_DEFINES=.secrets/prueba-real.json \
./scripts/prueba-remota.sh
```

## Captura y alcance

Las tomas móviles proceden de la aplicación 1.7.0 ejecutándose en un emulador Android. El recorrido principal usa el servidor publicado; solo la recuperación financiera usa Firebase local. Los fondos, identidades, tarjetas, contratos y planillas son ficticios. La autorización del dispositivo se automatiza exclusivamente en el arnés privado de captura de productos y recuperación; el APK distribuido conserva la autorización nativa. La prueba remota de notificaciones utiliza la implementación nativa.

La administración web se presenta mediante una secuencia de capturas del sitio publicado, que conserva el ingreso de importe y motivo, el diálogo, el saldo resultante y sus registros. La temporada visual se publica con `guardarDecoracion` y se restaura al terminar. La configuración no se escribe directamente desde el cliente.

La programación mensual conserva datos y consentimiento, pero no ejecuta cargos automáticos. Los cheques requieren una acción expresa del asesor para cobrar. Wallet, liquidación bancaria, emisión física, logística y proveedores de servicios reales requieren integraciones adicionales.

## Publicación reproducible

Página, capítulos, pasos, carátulas y verificaciones se versionan en Git. Los MP4 se distribuyen en Hosting y en la release `v1.7.0-audiovisual`, fuera del historial de código. `node tooling/preparar-videos.mjs` obtiene ambos archivos y comprueba sus huellas SHA-256 contra `exportaciones.json`; se detiene ante copias locales distintas. `scripts/preparar-publicacion.sh` incluye esa preparación antes de compilar el panel.

El paquete editable conserva el proyecto `.aep`, el guion, los materiales, la música original y las licencias. No contiene archivos de acceso. Las piezas anteriores se conservan en su entrega original; la página vigente reproduce los videos de la versión 1.7.0.
