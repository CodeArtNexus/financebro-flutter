# Correspondencia con la prueba técnica

Esta matriz relaciona los requisitos de la prueba con la implementación, la documentación y la evidencia disponible. Las funciones adicionales y los límites del prototipo se describen en el [README](../README.md).

| Requisito | Implementación o documento | Comprobación y límite |
| --- | --- | --- |
| Flutter | Cliente en `lib/`, plataformas Android e iOS | Compilación y recorridos nativos; firma de desarrollo en iOS |
| Onboarding y autenticación | Firebase Auth, registro, contrato, apertura idempotente | Registro nativo y pruebas del servidor; datos ficticios |
| Cuentas, saldos y movimientos | Functions, Firestore, históricos y comprobantes | Pruebas de integridad, concurrencia, paginación y conciliación |
| Personalización dinámica | Perfil, metas, esquema de contenido, catálogo y temporadas | Cambios en vivo, contenido validado y respaldo compatible |
| Servicio externo | HTTP de Frankfurter | Consulta real, validación de respuesta, fecha y caché |
| Push | Bandeja persistente y FCM | Android remoto en primer y segundo plano; APNs iOS pendiente |
| Monitoreo en producción | [Operación](operacion.md) | Señales, métricas y procedimiento propuestos; no se presentan como habilitados |
| Comportamiento degradado | [Evaluación](evaluacion.md), red, divisas y cola segura | Carga, reintentos, caché, caída parcial y recuperación; no confirmar dinero localmente |
| Unitarias, widgets y E2E | `test/`, `integration_test/`, pruebas de servidor, reglas y panel | CI y recorridos móviles identificados por separado |
| Uso e impacto de IA | [Uso de IA](uso-ia.md) | Productividad, calidad, documentación y pruebas; impacto cualitativo y resultados verificados |
| Arquitectura y decisiones | [Arquitectura](arquitectura.md), [decisiones](decisiones.md) | Problemas, alternativas, selección, compromisos e impacto futuro; diagramas de componentes, flujo y datos |
| Despliegue y operación | [Operación](operacion.md) | Ambientes, componentes, publicación, reversión, riesgos, respaldos y escalamiento |
| README reproducible y colaboración | [README](../README.md), [colaboración](../CONTRIBUTING.md) | Dependencias fijadas, ejecución, pruebas y cambios pequeños en main |
| Historial y Trunk Based Development | Historial de `main` y etapas | Integración frecuente e historial lineal; etiquetas de entregas |
| Demostración funcional | APK, app, panel y [recorrido](evaluacion.md) | Accesos separados y galería pública; video final pendiente |
| No basarse únicamente en respuestas estáticas | Auth, Firestore, Storage, Functions y divisas externas | Operaciones compartidas y procesamiento dinámico con fondos sintéticos |

## Personalización, automatización y alcance adicional

Las preferencias, metas, tarjetas personalizables, campañas y contenido por segmento aportan personalización avanzada. CI, scripts de publicación, capturas reproducibles y conciliación automatizan desarrollo y verificación. El catálogo remoto y las temporadas incorporan experiencias dentro del esquema admitido sin reinstalar.

Chequera digital, crédito y solicitudes físicas amplían producto y trazabilidad. Sus límites se explicitan: no son cheques certificados, crédito real ni envíos de mensajería. La programación mensual es visual y los cobros de cheques requieren acción de asesor. APNs, Wallet y proveedores reales no se declaran terminados.

