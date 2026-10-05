# Decisiones técnicas

Cada decisión describe el problema, las opciones consideradas, la elección y sus consecuencias. Las alternativas corresponden al análisis de diseño; no todas se implementaron como prueba comparativa.

## D01 - Flutter y módulos por funcionalidad

**Problema.** Compartir la experiencia Android/iOS y mantener los productos separados.

**Alternativas.** Aplicaciones nativas; Flutter organizado por capas globales; Flutter con carpetas por funcionalidad.

**Elección.** Flutter, requerido por la prueba, con módulos de autenticación, cuentas, banca, experiencia, divisas y notificaciones. Comparten componentes de interfaz. Históricos y contactos tienen repositorios separados de sus pantallas.

**Costo y limitaciones.** Se comparte código, pero firma, permisos, notificaciones y navegación se verifican en cada sistema. Algunas pantallas aún consultan Firestore directamente.

**Evolución.** Completar las interfaces de cada producto antes de convertir los módulos en paquetes. Un equipo debe poder probar su dominio sin cargar el resto de la aplicación.

## D02 - Riverpod y GoRouter

**Problema.** Coordinar sesión, carga, errores y rutas que identifican una cuenta o contacto.

**Alternativas.** Estado local; BLoC; Riverpod con dependencias sustituibles.

**Elección.** Riverpod administra dependencias y estado asíncrono. GoRouter define rutas y redirecciones. La clave de página incluye la URI para renovar la consulta al cambiar de producto.

**Costo y limitaciones.** Las pruebas pueden sustituir repositorios, pero hay que controlar el ciclo de vida y limpiar estado cuando cambia la sesión. BLoC permite transiciones más explícitas a cambio de más código inicial.

**Evolución.** Extraer casos de uso cuando un proveedor empiece a coordinar demasiadas responsabilidades.

## D03 - Firebase y operaciones en Functions

**Problema.** Tener autenticación, datos compartidos y documentos privados sin un servidor local permanente.

**Alternativas.** API propia con SQL; escrituras monetarias desde el móvil; Firebase con operaciones en Functions.

**Elección.** Authentication, Firestore, Storage y Functions. Los clientes leen datos autorizados; el servidor valida las operaciones monetarias y administrativas.

**Costo y limitaciones.** Reduce trabajo de infraestructura, pero depende de Firebase, sus consultas e índices y su facturación. Admin SDK no usa las reglas del cliente: Functions debe validar sus propios permisos.

**Evolución.** Mantener interfaces y contratos. Evaluar un libro contable formal y almacenamiento apropiado antes de custodiar dinero real.

## D04 - Centavos, transacciones y referencias

**Problema.** Evitar redondeos, sobregiros y descuentos duplicados cuando se pierde una respuesta.

**Alternativas.** Punto flotante; escrituras separadas; centavos enteros y una transacción con comprobante.

**Elección.** Enteros en centavos y transacción para saldos, movimientos, comprobante y avisos. La misma referencia con los mismos datos devuelve el resultado anterior; datos distintos se rechazan.

**Costo y limitaciones.** Dos operaciones sobre la misma cuenta pueden competir. Los históricos globales añaden escrituras y deben conciliarse. Un comprobante único no garantiza que la push llegue una sola vez.

**Evolución.** Medir concurrencia y mantener las mismas garantías si cambia la base de datos. Añadir un modelo contable formal según los requisitos de producción.

## D05 - Guardar la autorización antes de enviar

**Problema.** El usuario puede cerrar una pantalla o perder la respuesta después de confirmar.

**Alternativas.** Guardar en memoria; descontar localmente; persistir la autorización y consultar al servidor.

**Elección.** Cola en almacenamiento seguro, separada por proyecto e identidad. Se guarda antes del envío, también con internet. El comprobante del servidor confirma el movimiento.

**Costo y limitaciones.** Hay que manejar datos dañados, cambios de sesión y resultado incierto. Una autorización sin intentar puede cancelarse; después de un intento debe consultarse el resultado. Las 24 h limitan autorizaciones nuevas, no comprobantes ya confirmados.

**Evolución.** El E2E actual reconstruye sesión y cola dentro del mismo proceso. Añadir cierre forzado del sistema, migración de formato y diagnóstico por referencia.

## D06 - Contenido remoto validado

**Problema.** Cambiar mensajes, recomendaciones y servicios sin publicar la app por cada cambio.

**Alternativas.** Contenido fijo; código remoto; configuración con componentes conocidos.

**Elección.** Esquema versionado, tipos y destinos permitidos y última configuración válida como respaldo. El panel administra catálogo y temporadas.

**Costo y limitaciones.** Solo se pueden activar componentes que el cliente conoce. Un nuevo componente nativo requiere una versión móvil.

**Evolución.** Probar compatibilidad por versión antes de publicar y ampliar segmentos sin exponer datos personales.

## D07 - Eventos persistidos para push

**Problema.** Avisar de una operación sin depender de FCM para confirmar los fondos.

**Alternativas.** Enviar antes de confirmar; aviso local; guardar el evento y entregarlo después.

**Elección.** Evento en `enviosPush`, reserva transaccional y reintentos por dispositivo. Android usa FCM real. iOS recibe avisos nativos con la app conectada hasta habilitar APNs.

**Costo y limitaciones.** La transferencia puede completarse aunque falle el aviso. Un fallo después de la aceptación del transporte puede repetir la notificación. El histórico de la operación permanece disponible.

**Evolución.** Configurar APNs, medir pendientes y revisar cuánto detalle mostrar en una pantalla bloqueada.

## D08 - Servicios ficticios y planes mensuales

**Problema.** Demostrar consulta, pago y consentimiento sin acuerdos con bancos o empresas de servicios.

**Alternativas.** Respuestas fijas; proveedores comerciales; proveedor ficticio en servidor y divisas externas reales.

**Elección.** Planillas calculadas por servidor, pagos confirmados por el titular y datos persistidos. Los planes mensuales no cobran; los cheques se procesan desde administración.

**Costo y limitaciones.** Comprueba lógica e históricos, pero no la liquidación o disponibilidad de un proveedor comercial. Desactivar tareas no elimina todos los cargos de Firebase.

**Evolución.** Incorporar acuerdos, validación de proveedores, conciliación y consentimiento antes de activar débitos periódicos.

## D09 - Trunk Based Development y CI

**Problema.** Conservar una versión integrada mientras cambian productos, permisos y datos.

**Alternativas.** Rama de entrega larga; revisión solo manual; cambios pequeños en `main` con pruebas.

**Elección.** Commits por etapas, archivos de bloqueo y cinco trabajos de CI. Emulator Suite aísla las pruebas; Android ejecuta registro interrumpido y recuperación de transferencia.

**Costo y limitaciones.** CI no comprueba FCM remoto: ese caso usa el servidor publicado en un recorrido separado con accesos de prueba. Un historial lineal por sí solo no demuestra colaboración entre varios equipos.

**Evolución.** Añadir recorridos según el riesgo y mantener el tiempo de verificación compatible con cambios frecuentes.

## D10 - Separación gradual del código

**Problema.** Las operaciones crecían en una clase y las pantallas mezclaban consultas y presentación.

**Alternativas.** Microservicios inmediatos; migración completa a paquetes; extracción gradual dentro del servidor actual.

**Elección.** Casos de uso por dominio, fachada compatible y repositorios de históricos/contactos. CI protege los límites extraídos.

**Costo y limitaciones.** Mejora mantenimiento sin romper transacciones, pero conserva una base compartida y vistas pendientes de migrar.

**Evolución.** Extraer interfaces de lecturas cruzadas antes de separar infraestructura y mantener contratos compatibles con clientes instalados.

## D11 - Cristal y accesibilidad

**Problema.** El desenfoque repetido cuesta tiempo gráfico y el texto grande puede ocultar importes o acciones.

**Alternativas.** Retirar cristal; filtros por fila; compartir filtros y ofrecer fondos opacos en alto contraste.

**Elección.** BackdropGroup en filas independientes. Los importes cambian de distribución según el espacio. Alto contraste elimina desenfoque y reducir movimiento desactiva animaciones.

**Costo y limitaciones.** Los elementos superpuestos no pueden compartir la misma clave de filtro. La medición en emulador tiene cuadros lentos y no garantiza fluidez física. Las pruebas de etiquetas no sustituyen TalkBack o VoiceOver.

**Evolución.** Medir equipos físicos y revisar todos los productos con lectores de pantalla. [Resultados de calidad](calidad.md).
