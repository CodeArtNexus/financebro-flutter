# Decisiones técnicas

Estas decisiones describen la solución construida y contrastan sus alternativas. Las alternativas se justifican como análisis arquitectónico; no se afirma haber desarrollado o comparado experimentalmente cada una. Las consecuencias futuras distinguen lo implementado de su evolución prevista.

## D01 · Flutter y organización por funcionalidad

**Problema.** Compartir experiencia entre Android e iOS y permitir que los productos evolucionen sin mezclar toda la interfaz.

**Alternativas.** Dos aplicaciones nativas; una aplicación Flutter con carpetas por capa global; módulos por funcionalidad dentro de Flutter.

**Elección.** Flutter, requerido por la prueba, con módulos de autenticación, cuentas, experiencia, divisas y banca. Los productos comparten componentes visuales y composición de dependencias.

**Compromisos.** Se comparte código y consistencia, pero permisos, firma, push y navegación necesitan comprobación por plataforma. Hay consultas directas a Firestore y casos de uso todavía concentrados que limitan la independencia de algunos módulos.

**Impacto futuro.** Extraer interfaces entre dominios antes de convertir cada carpeta en un paquete. Cada equipo debería poder ejecutar sus pruebas sin cargar todos los productos.

## D02 · Riverpod para estado y GoRouter para navegación

**Problema.** Coordinar sesión, streams, carga y errores; mantener rutas que identifican cada cuenta o contacto.

**Alternativas.** Estado local exclusivamente; BLoC con eventos explícitos; Riverpod con proveedores e inyección.

**Elección.** Riverpod para composición y estado asíncrono; GoRouter para redirecciones y rutas identificables. Las claves de página incluyen la URI para no reutilizar la consulta del producto anterior. Las pestañas reemplazan su contenido; los detalles conservan navegación nativa.

**Compromisos.** Facilita sustituciones en pruebas, pero exige controlar ciclo de vida, invalidación y aislamiento por sesión. BLoC ofrecería transiciones más explícitas a cambio de más estructura inicial.

**Impacto futuro.** Consolidar estados de negocio en casos de uso y contratos, evitando que un proveedor crezca como coordinador de todos los dominios.

## D03 · Firebase y un servidor de operaciones compartido

**Problema.** Ofrecer autenticación real, estado compartido y documentos privados sin depender del equipo local del evaluador.

**Alternativas.** Backend propio con API y SQL; escrituras directas desde móvil; Firebase con Functions como frontera bancaria.

**Elección.** Authentication, Firestore, Storage y Functions. Clientes leen registros autorizados; el servidor valida operaciones y rol de asesor.

**Compromisos.** Menor administración de infraestructura y actualizaciones en vivo, con dependencia del proveedor, consultas e índices específicos y consumo facturable. El Admin SDK elude las reglas de cliente: la seguridad del servidor debe validarse por separado.

**Impacto futuro.** Mantener adaptadores, contratos y datos exportables. Comparar un libro contable en SQL u otra base transaccional antes de custodiar dinero real, según auditoría, volumen y requisitos del producto.

## D04 · Centavos, transacciones y referencias idempotentes

**Problema.** Evitar redondeos, sobregiros concurrentes y registros incompletos o duplicados por una respuesta perdida.

**Alternativas.** Importes decimales de punto flotante; escrituras sucesivas independientes; transacción con importes enteros y comprobante único.

**Elección.** Centavos enteros, validaciones antes de mover fondos y transacción que incluye saldos, históricos, recibo y avisos. Repetir una referencia compatible recupera su resultado; no vuelve a mover fondos.

**Compromisos.** Las operaciones sobre la misma cuenta pueden competir y reintentarse. Crear proyecciones globales aumenta escrituras y requiere conciliación. Atomicidad no equivale a un libro contable certificado ni a entrega garantizada de notificaciones.

**Impacto futuro.** Medir contención, conservar invariantes y añadir un modelo contable formal si se amplía el alcance. Los cambios de almacenamiento deben preservar la relación entre referencia, fondos y registros.

## D05 · Autorización conservada antes del envío

**Problema.** Un usuario puede salir, perder conexión o no recibir la respuesta después de confirmar una transferencia.

**Alternativas.** Mantener el envío solo en memoria; descontar localmente y reconciliar después; conservar autorización y consultar al servidor.

**Elección.** Cola en almacenamiento seguro, separada por proyecto e identidad. Se guarda antes de llamar al servidor, aun con internet. Solo se confirma el movimiento cuando existe comprobante del servidor.

**Compromisos.** Requiere manejar archivo dañado, cambios de sesión y estados inciertos. Sin internet solo se prepara una transferencia a un destinatario ya verificado. Una autorización no intentada puede cancelarse; una ya intentada requiere comprobar el resultado antes de presentarla como cancelable. El plazo de 24 horas no invalida un comprobante que ya existe.

**Impacto futuro.** Ampliar pruebas de reinicio y migraciones de formato. Añadir soporte operativo por referencia; no usar el saldo en caché para autorizar definitivamente una transferencia.

## D06 · Contenido remoto con esquema limitado

**Problema.** Cambiar recomendaciones, servicios y campañas sin una publicación móvil para cada mensaje.

**Alternativas.** Contenido fijo; código remoto arbitrario; contenido declarativo con componentes instalados.

**Elección.** Esquema versionado, tipos y destinos permitidos, segmentos y respaldo del último contenido válido. Administración controla catálogo y temporadas.

**Compromisos.** Menor libertad que descargar cualquier interfaz, pero permite validar compatibilidad y proteger navegación. Una experiencia nativa que no existe en el cliente requiere una versión nueva.

**Impacto futuro.** Versionar compatibilidad por cliente y probar una publicación antes de activarla. Añadir segmentos sin exponer datos privados en la configuración compartida.

## D07 · Bandeja de avisos y degradación por plataforma

**Problema.** Comunicar un cambio bancario sin perder el registro si FCM falla y permitir navegar al producto relacionado.

**Alternativas.** Enviar push dentro de la operación antes de confirmar; registrar solo una notificación local; persistir el evento y entregarlo después.

**Elección.** Evento persistente y Functions de envío con reintentos acotados. Android utiliza FCM; iOS conserva avisos nativos al recibir cambios con la app conectada hasta configurar APNs.

**Compromisos.** La operación financiera puede completarse y la push no llegar. El histórico de avisos conserva el hecho; un reintento del transporte puede producir duplicación visible si hay fallo tras la entrega. APNs es una habilitación pendiente, no una capacidad que se simula como remota.

**Impacto futuro.** Medir antigüedad y fallos de la bandeja, configurar APNs y revisar contenido sensible antes de mostrarlo en una pantalla bloqueada.

## D08 · Proveedores sintéticos y programación mensual visual

**Problema.** Demostrar consulta de planillas, consentimientos y estados sin integraciones bancarias o contratos con empresas de servicios.

**Alternativas.** Respuestas fijas en la pantalla; integraciones comerciales reales; proveedor sintético procesado por el servidor y una integración externa real de divisas.

**Elección.** Planillas dinámicas sintéticas, pagos confirmados por el titular y persistencia compartida. La programación mensual es visual; no se exportan tareas periódicas. Los cheques se procesan expresamente desde administración.

**Compromisos.** Permite verificar lógica e históricos; no prueba disponibilidad ni liquidación de un proveedor real. Reduce tareas activas, pero no garantiza costo cero de Firebase.

**Impacto futuro.** Incorporar contratos de proveedor, límites, conciliación y consentimiento de débitos antes de activar cobros programados. La experiencia ya separa consulta, confirmación y resultado.

## D09 · Pruebas aisladas y verificación por etapas en main

**Problema.** Mantener una versión revisable mientras cambian productos, reglas y datos.

**Alternativas.** Rama de entrega prolongada; validación exclusivamente manual; trunk con pruebas automáticas y recorridos nativos separados.

**Elección.** Integración frecuente en `main`, commits por etapas, lockfiles y cuatro tareas de CI. Los emuladores aíslan reglas y operaciones; los dispositivos cubren navegación, SDK y presentación.

**Compromisos.** CI sin dispositivo no ejecuta los E2E móviles ni acredita una push real. Estos necesitan un recorrido adicional y credenciales privadas cuando se verifica el servidor publicado. Un historial lineal no sustituye explicar y revisar los cambios.

**Impacto futuro.** Añadir ejecución móvil automatizada cuando su costo y mantenimiento se justifiquen, con revisiones pequeñas y contratos de regresión por dominio.
