// Calendario del producto: fechas civiles en Ecuador, días de corte del 1 al 28.
export const POLITICA_TARJETA = Object.freeze({
  porcentajeMinimo: 5,
  pisoMinimoCentavos: 1000,
  diasHastaPago: 15,
  version: "2026-10-v1",
});
export function fechaEcuador(fecha) {
  return new Date(fecha.getTime() - 5 * 3600000).toISOString().slice(0, 10);
}
export function siguienteCorte(hoy, dia) {
  const [a, m, d] = hoy.split("-").map(Number);
  return new Date(Date.UTC(a, m - 1 + (d >= dia ? 1 : 0), dia))
    .toISOString()
    .slice(0, 10);
}
export function ultimoCorte(hoy, dia) {
  const [a, m, d] = hoy.split("-").map(Number);
  return new Date(Date.UTC(a, m - 1 - (d < dia ? 1 : 0), dia))
    .toISOString()
    .slice(0, 10);
}
export function vencimiento(corte) {
  return new Date(
    Date.parse(`${corte}T12:00:00Z`) +
      POLITICA_TARJETA.diasHastaPago * 86400000,
  )
    .toISOString()
    .slice(0, 10);
}
export function pagoMinimo(deuda) {
  return Math.min(
    deuda,
    Math.max(
      POLITICA_TARJETA.pisoMinimoCentavos,
      Math.ceil((deuda * POLITICA_TARJETA.porcentajeMinimo) / 100),
    ),
  );
}
