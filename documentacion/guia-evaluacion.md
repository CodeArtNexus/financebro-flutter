# Guía de evaluación y accesos

FinanceBro 1.7.0 · Perfiles verificados en el servidor publicado el 5 de octubre de 2026.

Esta guía permite revisar la aplicación y el panel web con cuentas preparadas. Android, iOS y el panel comparten el mismo servidor y los mismos datos. No se necesita iniciar un servidor local ni los emuladores de Firebase. Las identidades, fondos, documentos, tarjetas y planillas de este entorno son ficticios.

## 1. Accesos

### Aplicación Android e iOS

Elegir **«Ya tengo una cuenta» / «Ingresar»** e introducir uno de estos accesos. No volver a registrar estos correos.

| Perfil | Correo | Contraseña | Qué permite revisar |
| --- | --- | --- | --- |
| Sebastián Torres | `sebas@financebro.test` | `Bro2026!` | Ahorros y corriente activas; débito personalizable, crédito activo con corte y abonos, tarjeta externa, pagos, metas, contactos, movimientos y cheques emitidos y recibidos. |
| Valeria Andrade | `valeria@financebro.test` | `Bro2026!` | Contraparte para transferencias, QR y cheques. Tiene ahorros y corriente activas, débito, tarjeta externa y crédito aprobado pendiente de elegir corte. |
| Mateo Rivera | `mateo@financebro.test` | `Bro2026!` | Ahorros y débito activos. Solicitudes de tarjeta de crédito y cuenta corriente en revisión, para probar las aprobaciones desde el panel. |

Si el dispositivo conserva otra sesión, abrir **Mi perfil → Cerrar sesión** y entrar con el perfil elegido. Para autorizar transferencias, configurar PIN, código o biometría en el dispositivo.

### Panel de administración

Abrir [FinanceBro · Administración](https://financebro-sb-20261003.web.app/) en un navegador e ingresar con este acceso:

| Perfil | Correo | Contraseña |
| --- | --- | --- |
| Asesor de evaluación | `asesor@financebro.test` | `PanelBro2026!` |

El asesor puede consultar cuentas y movimientos globales, ajustar fondos ficticios, revisar documentos, aprobar solicitudes y gestionar tarjetas físicas, servicios, cheques y temporadas. Este permiso se comprueba en el servidor. Los perfiles de cliente no pueden realizar esas acciones administrativas.

Los accesos publicados pertenecen al entorno de evaluación. No conceden acceso a Firebase Console, al despliegue del proyecto ni a las cuentas personales de desarrollo.

## 2. Instalar o ejecutar

- **Android:** instalar el [APK 1.7.0](https://github.com/CodeArtNexus/financebro-flutter/releases/tag/v1.7.0-calidad) o ejecutar el código con Flutter siguiendo el [README](../README.md#servidor-publicado). Para recibir push remotas, utilizar un dispositivo con Google Play Services y permitir las notificaciones.
- **iOS:** ejecutar el código con Flutter y Xcode en un simulador o firmarlo con una cuenta de Apple para instalarlo en un iPhone físico. Utiliza los mismos perfiles y datos. No hay distribución por TestFlight ni un instalador iOS universal.
- **Panel:** utilizar directamente el enlace web anterior; no necesita instalación.

La compilación normal conecta al servidor publicado. **No activar `USE_EMULATORS` ni `VITE_USE_EMULATORS`** para este recorrido. Los accesos de «Entorno aislado» en el README corresponden a otra base de datos.

## 3. Recorrido sugerido

| Paso | Acción | Resultado que se debe observar |
| --- | --- | --- |
| 1. Productos e históricos | Ingresar con Sebastián; abrir una cuenta, una tarjeta y el contacto de Valeria. | Saldo y movimientos por producto; los envíos y recepciones del contacto aparecen como una conversación. |
| 2. Transferencia o QR | Abrir Valeria en un segundo dispositivo y mostrar «Mi QR», o usar su número de ahorros. Desde Sebastián, enviar entre USD 0,10 y USD 100. | Validación del titular, revisión del importe, autorización, comprobante y animación. Ambos perfiles muestran el débito o abono y sus históricos. |
| 3. Fondos desde el panel | Ingresar como asesor, elegir una cuenta e indicar importe y motivo para un ajuste. | Saldo y movimiento actualizados en la app del cliente, con aviso de la operación. |
| 4. Tarjeta de crédito | Revisar deuda, corte, mínimo y abonos de Sebastián. En Valeria, elegir el corte de su tarjeta aprobada. En el panel, aprobar la solicitud de Mateo y asignar un cupo. | Cada perfil muestra el estado correspondiente; Mateo recibe el aviso y puede elegir su corte. |
| 5. Cuenta corriente | En el panel, abrir el expediente de Mateo, «Rivera Taller», y revisar sus cinco documentos ficticios. Aprobar, aportar al menos USD 1.000 a la cuenta temporal y validar el depósito. | La cuenta pasa de temporal a activa; el cambio también aparece en el móvil. |
| 6. Chequera digital | Con Sebastián o Valeria, revisar grupos, eventos, cheques emitidos y recibidos. Emitir un lote, cambiar una fecha dentro de su límite o bloquear un cheque. | Históricos y estados en ambos perfiles. El asesor procesa los cheques vencidos desde el panel. |
| 7. Servicios | Consultar una planilla con un contrato nuevo de al menos cuatro caracteres, confirmar el pago y guardar un plan mensual. | Consulta dinámica, comprobante y movimiento. El plan mensual conserva las condiciones sin ejecutar cargos automáticos. |
| 8. Tarjetas y entrega | Cambiar color o subir una imagen en una tarjeta propia; solicitar su copia física. Revisar la solicitud desde el panel. | Diseño guardado, domicilio y fecha elegida; el asesor puede registrar revisión, preparación y entrega. |
| 9. Personalización | Cambiar preferencia, meta y tema. Desde el panel, publicar una temporada o modificar un servicio. | El cliente conectado recibe contenido y cambios sin reinstalar la app. |
| 10. Divisas y avisos | Consultar EUR, GBP o COP. En Android, activar avisos y realizar una operación desde otra sesión, también con la app en segundo plano. | Fuente y fecha de Frankfurter; aviso FCM remoto y apertura del destino al tocarlo. |

Para probar el registro desde cero, utilizar otra identidad ficticia: la aceptación del contrato crea una cuenta de ahorros en USD 0 y su tarjeta de débito. El asesor puede aportar fondos a esa cuenta desde el panel.

## 4. Cuentas para transferencias

| Titular | Cuenta de ahorros | Cuenta corriente |
| --- | --- | --- |
| Sebastián Torres | `10429172018627` | `20437258835385` |
| Valeria Andrade | `10581041822640` | `20283377923505` |
| Mateo Rivera | `10274734669347` | Se genera al aprobar su expediente. |

Se puede introducir el número o escanear el QR. El servidor valida el titular antes de confirmar una transferencia.

## 5. Datos compartidos y alcance

Los perfiles conservan las operaciones entre sesiones. Este es un entorno compartido: al transferir, aprobar una solicitud o ajustar fondos cambian los saldos, estados e históricos. Las capturas muestran el estado durante su grabación; no representan saldos fijos ni se restablecen al iniciar sesión.

- Las transferencias entre cuentas de FinanceBro se procesan en el servidor y actualizan los dos extremos.
- Los pagos mensuales guardan una configuración; cada pago requiere confirmación del titular.
- Los cheques vencidos se procesan por una acción del asesor; no hay una tarea periódica publicada.
- Las tarjetas externas muestran los pagos hechos desde FinanceBro, sin consultar la deuda de otro banco.
- Las solicitudes de tarjetas físicas guardan estados de gestión; no están conectadas a una empresa de mensajería.
- Android utiliza push remotas con FCM. En iOS, los avisos nativos aparecen al recibir cambios con la app conectada; APNs está pendiente.
- No se realizan pagos a bancos, proveedores o tarjetas reales.

## 6. Evidencias y conectividad

- [Demostración en video](https://financebro-sb-20261003.web.app/presentacion/): presentación y recorrido técnico con los procesos completos y capítulos.
- [Galería de interfaz](https://financebro-sb-20261003.web.app/revision/): pantallas de Android, iOS y panel, por función y tema.
- [Recorrido de conectividad y recuperación](evaluacion.md#conectividad-y-recuperación): escenarios de latencia, fallo parcial, caché y envío pendiente.
- [Pruebas y resultados](calidad.md): verificaciones automáticas, recuperación, accesibilidad y rendimiento.
