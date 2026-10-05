import { test } from "node:test";
import assert from "node:assert/strict";
import { procesarAviso, EntregaPendiente } from "../src/avisos.js";

function escenario(tokens = ["a", "b"]) {
  const envio = {
    uid: "persona",
    titulo: "Movimiento",
    cuerpo: "Revisa tu actividad",
    destino: "/perfil",
    estado: "pendiente",
    intentos: 0,
  };
  let reserva;
  const descartados = [],
    mensajes = [];
  const repositorio = {
    async reservar(_, intento) {
      if (
        ["enviado", "fallido", "sin_dispositivo", "demostracion"].includes(
          envio.estado,
        )
      )
        return null;
      if (reserva) throw new EntregaPendiente();
      reserva = intento;
      envio.intentos++;
      envio.estado = "procesando";
      return { ...envio };
    },
    async finalizar(_, intento, estado, pendientes) {
      assert.equal(intento, reserva);
      reserva = null;
      envio.estado = estado;
      if (pendientes !== undefined) envio.tokensPendientes = pendientes;
      return true;
    },
    async dispositivos() {
      return tokens
        .filter((t) => !descartados.includes(t))
        .map((token) => ({ id: token, token }));
    },
    async descartar(_, d) {
      descartados.push(d.token);
    },
  };
  let responder = (mensaje) => ({
    responses: mensaje.tokens.map(() => ({ success: true })),
  });
  const mensajeria = {
    async sendEachForMulticast(m) {
      mensajes.push(m);
      return responder(m);
    },
  };
  return {
    envio,
    mensajes,
    descartados,
    ejecutar: () => procesarAviso("evento", { repositorio, mensajeria }),
    responder: (fn) => (responder = fn),
  };
}
test("Un evento confirmado no vuelve a enviarse y conserva su destino", async () => {
  const e = escenario();
  await e.ejecutar();
  await e.ejecutar();
  assert.equal(e.mensajes.length, 1);
  assert.equal(e.envio.estado, "enviado");
  assert.equal(e.mensajes[0].data.ruta, "/perfil");
});
test("Un token inválido se descarta sin reintentar al dispositivo válido", async () => {
  const e = escenario();
  e.responder(() => ({
    responses: [
      {
        success: false,
        error: { code: "messaging/registration-token-not-registered" },
      },
      { success: true },
    ],
  }));
  await e.ejecutar();
  assert.deepEqual(e.descartados, ["a"]);
  assert.equal(e.envio.estado, "enviado");
});
test("El fallo parcial reintenta solo el token pendiente", async () => {
  const e = escenario();
  e.responder(() => ({
    responses: [
      { success: true },
      { success: false, error: { code: "messaging/unavailable" } },
    ],
  }));
  await assert.rejects(e.ejecutar(), EntregaPendiente);
  e.responder((m) => ({ responses: m.tokens.map(() => ({ success: true })) }));
  await e.ejecutar();
  assert.deepEqual(e.mensajes[1].tokens, ["b"]);
  assert.equal(e.envio.estado, "enviado");
});
test("Un fallo completo del transporte termina después de tres intentos", async () => {
  const e = escenario();
  e.responder(() => {
    throw new Error("transporte");
  });
  await assert.rejects(e.ejecutar());
  await assert.rejects(e.ejecutar());
  await e.ejecutar();
  await e.ejecutar();
  assert.equal(e.envio.estado, "fallido");
  assert.equal(e.mensajes.length, 3);
});
test("Sin dispositivos no se invoca FCM", async () => {
  const e = escenario([]);
  await e.ejecutar();
  assert.equal(e.envio.estado, "sin_dispositivo");
  assert.equal(e.mensajes.length, 0);
});
test("Dos entregas simultáneas reservan un único envío", async () => {
  const e = escenario();
  let terminar;
  e.responder(() => new Promise((resolve) => (terminar = resolve)));
  const primero = e.ejecutar();
  await new Promise((resolve) => setImmediate(resolve));
  await assert.rejects(e.ejecutar(), EntregaPendiente);
  terminar({ responses: [{ success: true }, { success: true }] });
  await primero;
  assert.equal(e.mensajes.length, 1);
});
