# Presentación audiovisual y evidencia conectada

[Ver los videos, descargar y navegar por capítulos](https://financebro-sb-20261003.web.app/presentacion/).

| Pieza | Duración | Propósito |
| --- | --- | --- |
| Presentación comercial | 1 min 44 s | Marca, productos, históricos y experiencia compartida |
| Recorrido funcional | 5 min 10 s | Apertura, envío conciliado, productos, conectividad, panel y push Android |

Ambas piezas se montaron y exportaron con Adobe After Effects 2026, en 1920 × 1080 a 30 cuadros por segundo. Se utilizan la marca `fb.`, naranja suave, Poppins, superficies claras y animación de textos, logo y encuadres. La música se compuso por síntesis para esta entrega, sin muestras, loops ni grabaciones de terceros. La tipografía conserva su licencia OFL. No hay locución: la explicación aparece en pantalla y los capítulos permiten revisar cada función.

## Operaciones que se muestran

El registro completa datos, domicilio y consentimiento. El servidor crea una sola cuenta de ahorros en cero y su tarjeta de débito. El envío de USD 0,10 se confirma contra Functions y Firestore: se comprueban un débito de 10 centavos, un abono de 10 centavos y el mismo total entre ambos extremos. El [resultado de conciliación](https://financebro-sb-20261003.web.app/presentacion/transferencia.json) conserva la fecha de la verificación.

Las capturas móviles proceden de la app ejecutándose en un emulador Android con Google Play Services. El montaje recorta esperas y conserva las confirmaciones. Se grabó por tramos para separar productos y estados. La autorización del dispositivo se automatiza exclusivamente en el recorrido audiovisual; la compilación distribuida solicita desbloqueo nativo y no incorpora ese reemplazo. El panel se muestra mediante una secuencia de capturas del sitio publicado. Los fondos, identidades, tarjetas, contratos y planillas son ficticios.

La temporada se publica con `guardarDecoracion` desde una identidad de asesor. La aplicación recibe el cambio por Firestore sin reinstalar y se restaura la configuración previa. Las reglas impiden escribir esa configuración directamente desde el SDK del cliente.

## Notificación remota Android

La comprobación utiliza FCM real y registra los pasos por separado:

1. La app registra un token y recibe el primer mensaje en primer plano.
2. Al pasar a segundo plano, Android publica un segundo aviso nativo.
3. UI Automator pulsa el aviso del sistema.
4. Flutter confirma que la aplicación volvió al primer plano y abrió el perfil.

Aceptar un mensaje en FCM no basta para considerar recibida una notificación. La [verificación fechada](https://financebro-sb-20261003.web.app/presentacion/push-android.json) refleja recepción, publicación y apertura observadas. La escena del aviso se conserva hasta la pantalla de destino.

Para reproducirla se necesita Firebase real, una sesión propietaria de Firebase CLI, Google Play Services, un perfil de evaluación con ahorros y un archivo privado con `DEMO_EMAIL`, `DEMO_PASSWORD` y `DEMO_UID`. El script concede el permiso nativo únicamente al APK instalado para la prueba y comprueba identidad, productos y pantalla de destino.

```sh
FINANCEBRO_DEVICE_ID=<dispositivo-android> \
FINANCEBRO_PRUEBA_DEFINES=.secrets/prueba-real.json \
./scripts/prueba-remota.sh
```

El emulador de Firebase no entrega FCM. Las credenciales y registros privados permanecen fuera de Git. La push remota de iOS requiere APNs y continúa pendiente.

## Conectividad y límites

El recorrido consulta divisas reales y después induce latencia, caída parcial y desconexión de forma controlada. Se muestran carga, respaldo con fecha y aviso de desactualización, continuidad de cuentas, estado de datos guardados y recuperación. Estos escenarios no representan una caída real del proveedor. Las pruebas de cola, respuesta perdida y transacciones complementan la evidencia visual.

Los pagos mensuales conservan programación y consentimiento, pero no ejecutan cargos automáticos. Los cobros de cheques requieren una acción expresa del asesor. La solicitud física no equivale a emisión bancaria ni entrega logística. Wallet, liquidación bancaria e integraciones con proveedores reales no se atribuyen a esta versión.

## Publicación y conservación

La página, capítulos, carátulas y verificaciones se versionan. Los MP4 se publican en Hosting y quedan excluidos de Git para conservar un historial manejable. `node tooling/preparar-videos.mjs` descarga los dos MP4 de la entrega y verifica sus huellas SHA-256 contra el manifiesto versionado. Si ya están disponibles, comprueba las copias existentes; si difieren, se detiene sin sustituirlas. `scripts/preparar-publicacion.sh` incluye este paso antes de compilar el panel para evitar una publicación sin videos. No se descargan medios durante la comprobación de compilación en CI.

El paquete editable conserva el proyecto `.aep`, capturas originales, música, guion y licencias. El proyecto audiovisual se entrega por separado y no contiene archivos de acceso. La versión móvil permanece en 1.6.3; esta etapa actualiza evidencia, documentación y reproducibilidad del recorrido remoto.
