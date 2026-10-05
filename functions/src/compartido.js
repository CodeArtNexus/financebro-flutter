import { createHash } from "node:crypto";
export class FalloBanco extends Error {
  constructor(codigo, mensaje) {
    super(mensaje);
    this.codigo = codigo;
  }
}
export const falla = (codigo, mensaje) => {
  throw new FalloBanco(codigo, mensaje);
};
export function texto(v, nombre, min = 2, max = 120) {
  if (
    typeof v !== "string" ||
    v.trim().length < min ||
    v.trim().length > max ||
    /[\x00-\x1f]/.test(v)
  )
    falla("invalid-argument", `Revisa ${nombre}.`);
  return v.trim();
}
export function entero(v, nombre, min, max) {
  if (!Number.isSafeInteger(v) || v < min || v > max)
    falla("invalid-argument", `Revisa ${nombre}.`);
  return v;
}
export function identificador(v) {
  if (typeof v !== "string" || !/^[a-zA-Z0-9_-]{1,80}$/.test(v))
    falla("invalid-argument", "Referencia inválida.");
  return v;
}
export function referencia(v) {
  texto(v, "la referencia", 8, 80);
  return identificador(v);
}
export function numeroCuenta(v) {
  if (typeof v !== "string" || !/^\d{14}$/.test(v))
    falla("invalid-argument", "El número de cuenta debe tener 14 dígitos.");
  return v;
}
export function qrCuenta(numero) {
  return `financebro://transferir?cuenta=${numeroCuenta(numero)}&v=1`;
}
export const DOCUMENTOS = [
  "constitucion",
  "estatutos",
  "nombramiento",
  "ruc",
  "balances",
];
export const COLORES = ["durazno", "lavanda", "menta", "noche"];
export const huella = (datos) =>
  createHash("sha256").update(JSON.stringify(datos)).digest("hex");
export const MAX_SALDO = 100000000;
export const periodo = (fecha) => fechaLocal(fecha).slice(0, 7);
export function fechaLocal(fecha) {
  const valores = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: "America/Guayaquil",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    })
      .formatToParts(fecha)
      .map((p) => [p.type, p.value]),
  );
  return `${valores.year}-${valores.month}-${valores.day}`;
}
export function proximoMes(fecha, dia) {
  const [a, m] = fechaLocal(fecha).split("-").map(Number);
  const siguiente = new Date(Date.UTC(a, m, dia, 14));
  return fechaLocal(siguiente);
}
