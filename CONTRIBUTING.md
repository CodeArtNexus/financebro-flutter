# Colaborar en FinanceBro

El proyecto utiliza Trunk Based Development: `main` contiene la versión integrada y cada cambio debe poder revisarse y publicarse en poco tiempo. Las etiquetas identifican entregas; las etapas se registran en los mensajes de commit.

## Preparación

Instalar las versiones del [README](README.md) y resolver dependencias con los archivos de bloqueo. Desarrollar contra Emulator Suite con datos ficticios. Los scripts detectan herramientas instaladas; en Linux pueden requerirse `ANDROID_HOME` y `JAVA_HOME`. iOS necesita macOS y Xcode.

No incorporar claves de infraestructura, credenciales personales, firmas, archivos privados de acceso, documentos personales o la guía de defensa. La [guía de evaluación](documentacion/guia-evaluacion.md) contiene únicamente los accesos ficticios publicados para revisar la app y el panel; no conceden acceso a Firebase Console ni al despliegue.

## Flujo de trabajo

1. Actualizar `main` con `git pull --ff-only` después de conservar cualquier cambio local.
2. Definir el problema y el resultado esperado. Mantener el cambio pequeño; evitar ramas permanentes por producto.
3. Si hace falta revisión previa, crear una rama breve y un pull request hacia `main`. Integrar cuando pasen sus comprobaciones y eliminar la rama después.
4. Ejecutar las verificaciones del componente afectado y actualizar sus instrucciones o capturas.
5. Revisar `git diff` y los archivos añadidos. Cambiar los archivos de bloqueo solo cuando cambien las dependencias.
6. Integrar y revisar CI en ese commit. Corregir o revertir una regresión antes de continuar con otra función.

## Verificaciones por cambio

| Componente | Comprobación |
| --- | --- |
| Flutter | `./scripts/check.sh`; recorrido nativo si afecta permisos o comportamiento del dispositivo |
| Operaciones monetarias | Unitarias e integración de Functions; saldo, concurrencia, referencia y registros |
| Firestore o Storage | Pruebas de reglas con propietario, otra identidad y asesor |
| Panel | Pruebas, compilación e interacción modificada |
| Documentación o galería | Enlaces, datos de versión, coherencia con el código y visualización |

Los nuevos casos deben detectar un fallo de comportamiento o permisos. Para cambios de interfaz sin lógica nueva, realizar una revisión visual y reutilizar las comprobaciones existentes.

## Commits

Escribir mensajes en español que describan el resultado, por ejemplo: `Etapa 65: aclarar la documentación de entrega`. El texto de revisión debe explicar el problema, el cambio y cómo se verificó.

En una transferencia, revisar siempre identidad, centavos, saldo, referencia guardada e históricos. En una pantalla, comprobar carga, error, retorno, texto ampliado y reducción de movimiento cuando corresponda. [Recorrido completo](documentacion/evaluacion.md).
