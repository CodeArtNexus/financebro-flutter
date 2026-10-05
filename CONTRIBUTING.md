# Colaborar en FinanceBro

FinanceBro utiliza Trunk Based Development: cambios pequeños, integración frecuente en `main` y verificación antes de publicar. El historial por etapas permite revisar producto, implementación y comprobaciones. Una etapa no exige una rama permanente.

## Preparar el entorno

Clonar el repositorio, utilizar las versiones del [README](README.md) e instalar dependencias con sus lockfiles. Para desarrollar usar Emulator Suite y datos ficticios. Un clon no concede rol de asesor ni permiso de desplegar en el proyecto publicado. Mantener claves, defines privados, firmas, expedientes y la guía personal fuera de Git.

Los scripts Bash detectan herramientas ya instaladas. En Linux indicar `ANDROID_HOME` y `JAVA_HOME` cuando no estén en el entorno; iOS requiere macOS y Xcode. `scripts/env.sh` permite `POSTULACION_TOOLCHAINS_DIR` para cambiar la ubicación de cachés. No se necesita reproducir el equipo del autor.

## Flujo de un cambio

1. Actualizar `main` con `git pull --ff-only` y comprobar que no hay cambios locales que deban conservarse.
2. Describir un problema concreto y su resultado esperado. Trabajar con un cambio que pueda integrarse pronto; evitar una rama por producto o una rama de entrega prolongada.
3. Si la colaboración exige revisión previa, usar una rama breve y una solicitud de cambios dirigida a `main`. Integrarla cuando sus comprobaciones pasen y eliminarla después. Mantener funcionalidad incompleta fuera del flujo activo mediante una condición explícita y probada.
4. Ejecutar las verificaciones aplicables. Actualizar contratos, documentación y capturas cuando cambie el resultado para el usuario.
5. Revisar el diff antes de incorporar archivos. No regenerar lockfiles sin necesidad, ni modificar históricos publicados para ocultar una corrección.
6. Integrar, comprobar CI en el commit exacto y publicar solo los componentes afectados. Si `main` falla, priorizar corrección o revertir el cambio compatible antes de añadir otra funcionalidad.

## Verificación proporcional

| Cambio | Verificación mínima |
| --- | --- |
| Cliente, estado o navegación | `./scripts/check.sh`; E2E nativo afectado si depende del dispositivo |
| Operación bancaria | Validaciones y pruebas de integración de Functions; concurrencia e idempotencia cuando corresponda |
| Permisos o documentos | Pruebas de reglas de Firestore y Storage y comprobación con propietario, contraparte y asesor |
| Panel | Pruebas, compilación y recorrido de la acción afectada |
| Documentación o galería | Enlaces locales, coherencia con código, diagramas, imágenes y navegación en web |

No ampliar pruebas sin un motivo ni añadir casos que solo reproduzcan el código. Las pruebas útiles deben detectar una regresión del resultado, un permiso indebido o una diferencia entre fondos y registros.

## Commits y revisión

Los commits deben expresar el cambio en español. Ejemplo: `Etapa 49: documentar decisiones de arquitectura y límites de operación`. Un mensaje describe el resultado concreto; la revisión explica problema, cambio, comprobaciones y limitaciones relevantes. Las etiquetas señalan entregas revisables, no una rama nueva para cada etapa.

Antes de integrar, revisar: identidad y rol en servidor; importes en centavos; referencia persistida antes de transferir; históricos completos; comportamiento de carga y error; retorno de navegación; texto ampliado y reducción de movimiento cuando proceda. Para el alcance completo consultar [evaluación](documentacion/evaluacion.md).
