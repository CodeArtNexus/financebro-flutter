# Calidad y verificaciones - 1.7.0

Las pruebas comprueban operaciones, permisos, recuperación, navegación y presentación. Usan datos ficticios. Los resultados de rendimiento corresponden al entorno indicado; no son una medición de producción.

## Pruebas automáticas

| Grupo | Casos | Comprobación |
| --- | ---: | --- |
| Flutter | 66 | Validaciones, estado, widgets, cola, identidad, históricos, contactos y accesibilidad |
| Servidor: unitarias | 14 | Validaciones, avisos y logs sin datos privados |
| Servidor: integración | 38 | Fondos, transacciones, concurrencia, productos, permisos y reservas de avisos |
| Reglas de Firestore y Storage | 23 | Lecturas privadas y rechazo de escrituras financieras directas |
| Panel | 3 | Importes y ajuste recibido en vivo con paginación |
| Conciliación | 5 | Plan, copias ausentes, repetición y rechazo de conflictos |
| **Total** | **149** | Los recorridos móviles se registran por separado |

[CI](https://github.com/CodeArtNexus/financebro-flutter/actions) ejecuta cinco trabajos: Flutter, servidor, reglas, panel y recuperación Android. El E2E utiliza Android 35, perfil Pixel 5 y Emulator Suite. No contiene accesos del proyecto publicado. Su resultado se conserva como artefacto durante siete días.

`tooling/comprobar-limites.mjs` comprueba que las operaciones del catálogo tengan implementación y que las pantallas de históricos y contacto no vuelvan a consultar Firestore directamente. Dos pruebas de ingreso comprueban que el formulario espere el primer resultado de conexión y conserve sus datos cuando no hay red.

## Integridad financiera

Los casos de servidor incluyen transferencias concurrentes, ajuste y transferencia sobre el mismo saldo, cobros repetidos, respuesta perdida y fallos al crear registros. Comprueban que no haya sobregiros, que débito y abono coincidan, que exista un solo comprobante y que no queden escrituras parciales.

Una referencia existente con datos diferentes se rechaza. Las pruebas también rechazan cuentas corruptas, destinatario incompatible, saldo fuera de rango y deuda o cupo incoherentes. Las reglas impiden escrituras monetarias directas desde clientes, incluido el asesor.

La [conciliación publicada](https://financebro-sb-20261003.web.app/revision/integridad-global.json) conserva fecha y alcance. Encontró nueve copias globales ausentes de movimientos antiguos; se reconstruyeron desde sus originales sin modificar fondos. Las operaciones posteriores pueden cambiar los saldos de esos perfiles.

## E2E de recuperación

[recuperacion_test.dart](../integration_test/recuperacion_test.dart) ejecuta dos fallos controlados:

1. Se crea la identidad en Authentication y falla la apertura bancaria. Reintentar conserva el acceso y crea una sola cuenta de ahorros en USD 0 y un débito.
2. El servidor confirma la transferencia, pero la app no recibe la respuesta. Se reconstruyen sesión, proveedores y cola usando FlutterSecureStorage nativo. El mismo comprobante se recupera con un débito y un abono de USD 0,10.

La contraparte se revisa con su propia sesión. Leer sus datos desde el emisor produce `permission-denied`. Este E2E reconstruye el estado dentro del mismo proceso; el cierre forzado por el sistema operativo está pendiente.

Con Android iniciado y los puertos libres:

```sh
tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  './scripts/prueba-recuperacion.sh'
```

`FINANCEBRO_DISPOSITIVO` permite elegir otro dispositivo. Las variables de puertos permiten ejecutar una suite separada.

## Accesibilidad

Las pruebas de ingreso, registro y comprobantes comprueban contraste, etiquetas y objetivos táctiles de 48 dp en Android y 44 pt en iOS, en ambos temas. Revisan el diseño a 360 × 800 con texto al 200 %. Para medir controles completos de un formulario desplazable, amplían la altura de la prueba.

Históricos y contactos separan importe y descripción cuando falta espacio. Copiar una referencia tiene una acción etiquetada. Alto contraste utiliza fondos opacos y desactiva el desenfoque; reducir movimiento desactiva las animaciones de entrada y transferencia. La [galería](https://financebro-sb-20261003.web.app/revision/) incluye históricos y contactos con texto al 200 % en Android.

Queda pendiente una revisión manual completa con TalkBack y VoiceOver. Las pruebas actuales cubren pantallas concretas. [Pautas de pruebas de accesibilidad de Flutter](https://docs.flutter.dev/ui/accessibility/accessibility-testing).

## Rendimiento

Medición del 5 de octubre de 2026: Flutter 3.47.5 en modo `profile`, emulador Android 36 ARM64 de 720 × 1600 y Firebase local. Se preparan 45 ajustes y una transferencia. Se verifican páginas de 30 y 17 registros sin identificadores repetidos. Por tema se hacen cuatro desplazamientos de calentamiento y doce medidos con `watchPerformance`.

| Medida | Resultado |
| --- | --- |
| Cinco lecturas del servidor | 81, 58, 48, 36 y 32 ms; mediana 48 ms |
| Primera respuesta de caché cargada | 19 ms |
| Construcción media por cuadro, claro / oscuro | 0,562 / 0,618 ms |
| Rasterización media, claro / oscuro | 11,217 / 11,406 ms |
| Percentil 90 de rasterización, claro / oscuro | 49,494 / 42,711 ms |
| Cuadros por encima del presupuesto de 60 Hz | 11 de 36 / 11 de 35 |

Compartir el desenfoque entre filas redujo trabajo en esta medición respecto a filtros independientes. Persisten cuadros lentos. La muestra es pequeña y el emulador no representa un teléfono físico; estos resultados no garantizan 60 fps ni tiempos de respuesta en producción.

[Resultado con tiempos y contexto](https://financebro-sb-20261003.web.app/revision/calidad/rendimiento.json). Para repetirlo:

```sh
tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  './scripts/prueba-calidad.sh'
```

Este comando prepara datos únicamente en emuladores. La compilación de perfil admite HTTP local; el APK de entrega es `release`.

## Evidencia conectada

El APK y los [videos publicados](https://financebro-sb-20261003.web.app/presentacion/) corresponden a 1.7.0. La galería conserva estados de Android, iOS y panel, incluidas cuatro capturas nuevas de accesibilidad. [Videos](audiovisual.md) identifica los procesos y las pruebas remotas.

Android tiene FCM remoto comprobado. El servidor registra diagnóstico y estados de entrega. No se han configurado nuevas alertas automáticas, un respaldo periódico probado ni APNs iOS. [Operación](operacion.md) describe esos pendientes y el procedimiento de diagnóstico.
