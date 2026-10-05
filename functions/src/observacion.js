import { createHash } from "node:crypto";
import { performance } from "node:perf_hooks";

const CODIGOS = new Set([
  "invalid-argument",
  "failed-precondition",
  "already-exists",
  "not-found",
  "unauthenticated",
  "permission-denied",
  "unavailable",
  "deadline-exceeded",
]);
export async function observarOperacion(
  { operacion, referencia },
  ejecutar,
  { registrar, reloj = () => performance.now(), permitidas },
) {
  const inicio = reloj();
  const anotar = (evento, datos) => {
    try {
      registrar(evento, datos);
    } catch {
      /* El diagnóstico no cambia una operación confirmada. */
    }
  };
  const contexto = {
    operacion: Object.hasOwn(permitidas, operacion) ? operacion : "desconocida",
    version: "1",
    ...(typeof referencia === "string" && referencia.length <= 80
      ? {
          correlacion: createHash("sha256")
            .update(referencia)
            .digest("hex")
            .slice(0, 20),
        }
      : {}),
  };
  try {
    const resultado = await ejecutar();
    anotar("operacion_finalizada", {
      ...contexto,
      resultado: "confirmada",
      duracion_ms: Math.max(0, Math.round(reloj() - inicio)),
    });
    return resultado;
  } catch (error) {
    const original = error.codigo ?? error.code;
    const codigo = CODIGOS.has(original) ? original : "internal";
    const categoria = ["internal", "unavailable", "deadline-exceeded"].includes(
      codigo,
    )
      ? "tecnico"
      : ["unauthenticated", "permission-denied"].includes(codigo)
        ? "acceso"
        : "negocio";
    anotar("operacion_finalizada", {
      ...contexto,
      resultado: "interrumpida",
      categoria,
      codigo,
      duracion_ms: Math.max(0, Math.round(reloj() - inicio)),
    });
    throw error;
  }
}
