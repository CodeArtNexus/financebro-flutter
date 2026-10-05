# Verificación de calidad · 1.7.0

Esta revisión comprueba resultados financieros, recuperación, límites de módulos y presentación. Los datos de pruebas son sintéticos. Las comprobaciones no constituyen una auditoría bancaria ni una certificación de accesibilidad.

## Verificaciones automáticas

| Grupo | Casos | Resultado comprobado |
| --- | ---: | --- |
| Flutter: reglas, estado y widgets | 64 | Validación, cola segura, cambios de identidad, contenido remoto, histórico, contacto y accesibilidad |
| Servidor: unitarias | 14 | Validaciones, entrega parcial de avisos y diagnóstico sin contenido privado |
| Servidor: integración con Firebase emulado | 38 | Fondos, concurrencia, comprobantes, permisos, productos y reservas de avisos |
| Firestore y Storage: reglas | 23 | Lecturas privadas y rechazo de escrituras financieras desde clientes |
| Panel: importes e integración | 3 | Conversión exacta de importes y operaciones de asesor |
| Conciliación de históricos | 5 | Plan de lectura, copias ausentes, idempotencia y rechazo de conflictos |
| **Total** | **147** | Las ejecuciones móviles se informan aparte |

[CI](https://github.com/CodeArtNexus/financebro-flutter/actions) ejecuta cinco trabajos: Flutter, reglas, panel, servidor y recuperación Android. El quinto construye y ejecuta una app real en Android con Emulator Suite, sin accesos de nube. Conserva el resultado durante siete días. La comprobación de contratos evita perder operaciones de la fachada o volver a introducir consultas de almacenamiento en las dos pantallas migradas.

## Recuperación nativa

[El recorrido Android](../integration_test/recuperacion_test.dart) verifica dos fallos controlados:

1. Authentication crea el acceso y la apertura bancaria se interrumpe. El formulario conserva la identidad; el reintento crea una sola cuenta de ahorros con USD 0 y una tarjeta de débito.
2. El servidor confirma una transferencia, pero el adaptador descarta su respuesta. La app conserva una autorización pendiente en FlutterSecureStorage. Se destruye y recrea la composición de dependencias, identidad y cola. Tras ingresar de nuevo, recupera el mismo comprobante: un débito y un abono de USD 0,10, sin repetir el descuento.

La comprobación de la contraparte se realiza ingresando con su propia sesión; intentar leerla desde la cuenta emisora devuelve `permission-denied`. Esta prueba recrea la composición de la app, **no mata el proceso desde el sistema operativo**. Un ensayo de cierre forzado y restauración del dispositivo es una ampliación pendiente.

```sh
tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  './scripts/prueba-recuperacion.sh'
```

Se necesita un Android iniciado. `FINANCEBRO_DISPOSITIVO` selecciona otro identificador y las variables de puertos permiten una suite aislada.

## Accesibilidad

Las pruebas comprueban contraste, etiquetas y objetivos táctiles de 48 dp en Android y 44 pt en iOS para ingreso, registro y comprobantes, con temas claro y oscuro. Primero comprueban distribución a 360 × 800 con letra al 200 %; para medir todos los objetivos completos del formulario amplían la altura, evitando medir un campo parcialmente recortado por el desplazamiento como si ese fuera su tamaño total.

Históricos y conversaciones separan importe y descripción cuando falta ancho. La referencia utiliza una acción de copia etiquetada; las tarjetas exponen una acción única con banco, tipo y últimos dígitos. El modo de alto contraste ofrece superficies opacas y desactiva el desenfoque; reducir movimiento retira animaciones de entrada y transferencia. Las capturas nativas de [la galería](https://financebro-sb-20261003.web.app/revision/) muestran históricos y conversación al 200 %.

Estos controles cubren recorridos concretos. Una revisión manual integral con TalkBack y VoiceOver, teclado, tecnologías de apoyo y todos los productos todavía es necesaria antes de certificar el conjunto. Se utiliza la [API de pautas de Flutter](https://docs.flutter.dev/ui/accessibility/accessibility-testing).

## Rendimiento medido

La medición del 5 de octubre de 2026 utiliza Flutter 3.47.5 en modo `profile`, Android 36, emulador ARM64 de 720 × 1600 y Emulator Suite local. Prepara 45 ajustes y una transferencia mediante el servidor, además de los fondos iniciales. Comprueba páginas de 30 y 17 registros sin identificadores repetidos. Por tema realiza cuatro desplazamientos de calentamiento y doce medidos, con `watchPerformance`.

| Medida | Resultado de esta ejecución |
| --- | --- |
| Lecturas del servidor, cinco muestras | 81, 58, 48, 36 y 32 ms; mediana 48 ms |
| Primera emisión de caché ya cargada | 19 ms |
| Construcción media por cuadro, claro / oscuro | 0,562 / 0,618 ms |
| Rasterización media, claro / oscuro | 11,217 / 11,406 ms |
| Percentil 90 de rasterización, claro / oscuro | 49,494 / 42,711 ms |
| Cuadros por encima del presupuesto gráfico de 60 Hz | 11 de 36 / 11 de 35 |

Una observación previa con filtros independientes mostró 20,794 ms de rasterización media en claro. Compartir el fondo entre filas reduce trabajo manteniendo el estilo; las variaciones entre ejecuciones y la muestra pequeña impiden atribuir una mejora universal. **Persisten cuadros lentos**: las medias no acreditan 60 fps. El emulador y el servidor local tampoco representan una red móvil ni un dispositivo físico. La medición no establece un SLA de producción.

El [resultado completo](https://financebro-sb-20261003.web.app/revision/calidad/rendimiento.json) conserva tiempos de cada cuadro y contexto. Para reproducirlo:

```sh
tooling/node_modules/.bin/firebase emulators:exec \
  --only auth,firestore,functions,storage --project demo-financebro \
  './scripts/prueba-calidad.sh'
```

La compilación de perfil permite HTTP únicamente para los emuladores; el APK de entrega utiliza la compilación `release`. El recorrido nunca debe emplearse para preparar datos en el proyecto publicado.

## Alcance operativo

El servidor emite diagnóstico estructurado y la bandeja de avisos conserva reservas, intentos y estados por dispositivo. La [guía de operación](operacion.md) explica cómo investigar una referencia sin repetir el movimiento. No hay alertas automáticas nuevas, respaldo periódico verificado, APNs iOS, Wallet ni integraciones bancarias reales declaradas.

Los videos publicados corresponden a la versión 1.6.3 y documentan las funciones conectadas de esa entrega. El APK y las capturas de esta revisión incluyen las mejoras de la 1.7.0. Cada evidencia mantiene su versión y alcance.
