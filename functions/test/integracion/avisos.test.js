import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import {
  FirebaseBandejaAvisos,
  procesarAviso,
  EntregaPendiente,
} from "../../src/avisos.js";
if (
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST
)
  throw Error("Solo ejecutar en Emulator Suite.");
const db = getFirestore(initializeApp({ projectId: "demo-financebro" }));
async function preparar() {
  const evento = randomUUID(),
    uid = `aviso_${evento}`,
    repositorio = new FirebaseBandejaAvisos(db, { coleccion: "avisosPrueba" });
  await db
    .doc(`avisosPrueba/${evento}`)
    .set({
      uid,
      titulo: "Actividad",
      cuerpo: "Revisa tu cuenta",
      destino: "/perfil",
      estado: "pendiente",
    });
  return { evento, uid, repositorio, ref: db.doc(`avisosPrueba/${evento}`) };
}
test("Firestore concede una sola reserva concurrente y recupera una reserva vencida", async () => {
  const e = await preparar(),
    ahora = Date.now();
  const resultados = await Promise.allSettled([
    e.repositorio.reservar(e.evento, "uno", ahora),
    e.repositorio.reservar(e.evento, "dos", ahora),
  ]);
  assert.equal(resultados.filter((r) => r.status === "fulfilled").length, 1);
  assert.ok(
    resultados.find((r) => r.status === "rejected").reason instanceof
      EntregaPendiente,
  );
  const recuperado = await e.repositorio.reservar(
    e.evento,
    "recuperado",
    ahora + 90001,
  );
  assert.equal(recuperado.intentos, 2);
  assert.equal(
    await e.repositorio.finalizar(e.evento, "uno", "enviado"),
    false,
  );
  assert.equal(
    await e.repositorio.finalizar(e.evento, "recuperado", "enviado"),
    true,
  );
});
test("Un token renovado no se elimina por la respuesta del token anterior", async () => {
  const e = await preparar(),
    ref = db.doc(`usuarios/${e.uid}/dispositivos/telefono`);
  await ref.set({ token: "actual" });
  await e.repositorio.descartar(e.uid, { id: "telefono", token: "anterior" });
  assert.equal((await ref.get()).data().token, "actual");
  await e.repositorio.descartar(e.uid, { id: "telefono", token: "actual" });
  assert.equal((await ref.get()).exists, false);
});
test("La entrega parcial conserva solo pendientes y un evento repetido no reenvía", async () => {
  const e = await preparar();
  for (const token of ["a", "b"])
    await db.doc(`usuarios/${e.uid}/dispositivos/${token}`).set({ token });
  const envios = [];
  const mensajeria = {
    async sendEachForMulticast(m) {
      envios.push(m.tokens);
      return {
        responses: m.tokens.map((token) => ({
          success: envios.length > 1 || token === "a",
          error: { code: "messaging/unavailable" },
        })),
      };
    },
  };
  const ejecutar = () =>
    procesarAviso(e.evento, { repositorio: e.repositorio, mensajeria });
  await assert.rejects(ejecutar(), EntregaPendiente);
  await ejecutar();
  await ejecutar();
  assert.deepEqual(envios, [["a", "b"], ["b"]]);
  assert.equal((await e.ref.get()).data().estado, "enviado");
  assert.equal((await e.ref.get()).data().tokensPendientes, undefined);
});
