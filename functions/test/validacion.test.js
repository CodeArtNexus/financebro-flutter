import { test } from "node:test";
import assert from "node:assert/strict";
import {
  entero,
  numeroCuenta,
  referencia,
  qrCuenta,
  periodo,
  Banco,
} from "../src/banca.js";
test("Los montos son centavos enteros y el QR nunca lleva un saldo o monto", () => {
  assert.equal(entero(10, "monto", 10, 10000), 10);
  assert.equal(entero(10000, "monto", 10, 10000), 10000);
  for (const v of [9, 10001, 0.1, "10", NaN, Infinity])
    assert.throws(() => entero(v, "monto", 10, 10000));
  assert.equal(
    qrCuenta("10000000000001"),
    "financebro://transferir?cuenta=10000000000001&v=1",
  );
  assert.throws(() => numeroCuenta("10000000000001/otra"));
  assert.throws(() => referencia("../secreto"));
});
test("El período mensual usa la fecha de Ecuador, también al cambiar de año", () => {
  assert.equal(periodo(new Date("2027-01-01T02:00:00Z")), "2026-12");
  assert.equal(periodo(new Date("2027-01-01T06:00:00Z")), "2027-01");
});
test("Un visitante no ejecuta operaciones y un cliente no administra fondos", async () => {
  const banco = new Banco({});
  await assert.rejects(
    banco.transferir(null, {}),
    (e) => e.codigo === "unauthenticated",
  );
  await assert.rejects(
    banco.ajustar({ uid: "ana" }, {}),
    (e) => e.codigo === "permission-denied",
  );
  await assert.rejects(banco.ejecutar({ uid: "ana" }, "constructor", {}));
});
