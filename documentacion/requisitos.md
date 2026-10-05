# Correspondencia con la prueba técnica

Esta matriz indica dónde está implementado cada requisito y cómo revisarlo. El alcance corresponde a la versión 1.7.0.

| Requisito | Implementación | Comprobación |
| --- | --- | --- |
| Flutter | Cliente Android e iOS en `lib/` | APK Android y capturas nativas de ambas plataformas |
| Onboarding y autenticación | Firebase Auth, contrato y apertura de ahorros | Registro y reintento sin duplicar cuenta o débito |
| Cuentas, saldos y movimientos | Functions y Firestore | Transferencia, histórico por cuenta/global y conciliación |
| Personalización dinámica | Preferencias, metas, contenido por segmento y temporadas | Cambio de saludo y contenido; publicación desde el panel sin reinstalar |
| Servicio externo | Frankfurter mediante HTTP | EUR, GBP y COP con fuente, fecha y caché |
| Push | Eventos persistidos y FCM | Recepción y apertura remota en Android; APNs iOS pendiente |
| Monitoreo y diagnóstico | Logs estructurados y [operación](operacion.md) | Búsqueda de operación y error; alertas y respaldos descritos como trabajo futuro |
| Conectividad limitada, latencia y caída parcial | Caché, reintentos y cola segura | Escenarios controlados en laboratorio y [recorrido](evaluacion.md) |
| Unitarias, widgets y E2E crítico | `test/`, `integration_test/` y pruebas del servidor | 149 casos automáticos; recuperación Android en CI y otros recorridos móviles separados |
| Uso e impacto de IA | [Uso de IA](uso-ia.md) | Tareas asistidas, comprobación de resultados e impacto cualitativo |
| Arquitectura y decisiones | [Arquitectura](arquitectura.md), [decisiones](decisiones.md) | Diagramas y problema, alternativas, elección, compromisos y evolución por decisión |
| Despliegue y operación | [Operación](operacion.md) | Ambientes, publicación por componente, recuperación, riesgos y escalamiento |
| README reproducible | [README](../README.md) | Versiones, instalación, ejecución conectada/local y pruebas |
| Colaboración y Trunk Based Development | [CONTRIBUTING](../CONTRIBUTING.md), historial de `main` | Integración por etapas, commits y etiquetas |
| Demostración funcional | APK, panel, galería y [videos](audiovisual.md) | Accesos separados y recorrido por capítulos |
| Procesamiento dinámico | Auth, Firestore, Storage, Functions y divisas externas | Datos compartidos y operaciones del servidor; no depende solo de respuestas estáticas |

## Funciones adicionales

La chequera digital organiza obligaciones y cobros entre cuentas corrientes. El crédito añade solicitud, cupo, corte, consumos y abonos. La personalización de tarjetas, las metas, el catálogo y las temporadas amplían la experiencia. CI, scripts y conciliación automatizan preparación y comprobaciones.

Estas funciones utilizan fondos y documentos ficticios. La programación mensual no cobra automáticamente; el asesor procesa los cheques. No se incluyen liquidación bancaria, Wallet, emisión física ni proveedores comerciales de servicios.
