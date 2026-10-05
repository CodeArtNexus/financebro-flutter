import { test } from "node:test";
import assert from "node:assert/strict";
import { observarOperacion } from "../src/observacion.js";
test("Los registros correlacionan una operación sin incluir su contenido", async () => {
  const logs = [],
    secreto = "nombre, cedula, fondos y token";
  const resultado = await observarOperacion(
    { operacion: "transferir", referencia: secreto },
    async () => ({ secreto }),
    {
      registrar: (_, d) => logs.push(d),
      reloj: () => 10,
      permitidas: { transferir: true },
    },
  );
  assert.equal(resultado.secreto, secreto);
  assert.equal(logs[0].correlacion.length, 20);
  assert.ok(!JSON.stringify(logs).includes(secreto));
  assert.equal(logs[0].duracion_ms, 0);
});
test("Los rechazos de negocio se distinguen de un fallo técnico y se conserva el error", async () => {
  for (const [codigo, categoria] of [
    ["failed-precondition", "negocio"],
    ["permission-denied", "acceso"],
    ["unavailable", "tecnico"],
  ]) {
    const error = Object.assign(new Error("dato privado"), { codigo }),
      logs = [];
    await assert.rejects(
      observarOperacion(
        { operacion: "entrada privada" },
        async () => {
          throw error;
        },
        { registrar: (_, d) => logs.push(d), reloj: () => 0, permitidas: {} },
      ),
      (e) => e === error,
    );
    assert.equal(logs[0].categoria, categoria);
    assert.equal(logs[0].operacion, "desconocida");
    assert.ok(!JSON.stringify(logs).includes("dato privado"));
  }
});

test("Un fallo del registro técnico no convierte una confirmación en un error bancario", async () => {
  const recibo = { referencia: "confirmada" };
  assert.equal(
    await observarOperacion({ operacion: "transferir" }, async () => recibo, {
      registrar: () => {
        throw Error("logger");
      },
      reloj: () => 0,
      permitidas: { transferir: true },
    }),
    recibo,
  );
});
