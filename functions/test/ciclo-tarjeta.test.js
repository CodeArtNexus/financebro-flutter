import { test } from "node:test";
import assert from "node:assert/strict";
import {
  fechaEcuador,
  siguienteCorte,
  ultimoCorte,
  vencimiento,
  pagoMinimo,
} from "../src/ciclo-tarjeta.js";
test("Corte civil en Ecuador: medianoche, cambio de año y febrero", () => {
  assert.equal(fechaEcuador(new Date("2027-01-01T04:59:59Z")), "2026-12-31");
  assert.equal(siguienteCorte("2026-12-28", 28), "2027-01-28");
  assert.equal(siguienteCorte("2027-02-01", 28), "2027-02-28");
  assert.equal(ultimoCorte("2027-03-01", 28), "2027-02-28");
  assert.equal(vencimiento("2026-12-25"), "2027-01-09");
});
test("El mínimo nunca supera la deuda y redondea hacia arriba en centavos", () => {
  assert.equal(pagoMinimo(0), 0);
  assert.equal(pagoMinimo(10), 10);
  assert.equal(pagoMinimo(900), 900);
  assert.equal(pagoMinimo(20000), 1000);
  assert.equal(pagoMinimo(30001), 1501);
});
