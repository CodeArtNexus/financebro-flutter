import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const requiereServidor = createRequire(
  new URL("../../../functions/package.json", import.meta.url),
);
const { initializeApp: iniciarServidor } =
  requiereServidor("firebase-admin/app");
const { getAuth: authServidor } = requiereServidor("firebase-admin/auth");
const { getFirestore: datosServidor } = requiereServidor(
  "firebase-admin/firestore",
);
import { initializeApp, deleteApp } from "firebase/app";
import {
  getAuth,
  connectAuthEmulator,
  signInWithEmailAndPassword,
} from "firebase/auth";
import {
  getFirestore,
  connectFirestoreEmulator,
  collection,
  collectionGroup,
  terminate,
} from "firebase/firestore";
import { Banco } from "../../../functions/src/banca.js";
import { observarHistorial } from "../../src/historial.js";

test("El histórico pagina sin huecos ni duplicados cuando llega un ajuste en vivo", async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST &&
      process.env.FIREBASE_AUTH_EMULATOR_HOST,
    "Esta prueba solo usa emuladores.",
  );
  const uid = `historial_${Date.now()}`;
  const servidor = iniciarServidor({ projectId: "demo-financebro" }, uid);
  const db = datosServidor(servidor),
    banco = new Banco(db);
  const rol = { uid, token: { financebroAdmin: true } };
  const identidad = { uid, token: {} };
  await authServidor(servidor).createUser({
    uid,
    email: `${uid}@financebro.test`,
    password: "FinanceBro-historial-2026!",
  });
  await authServidor(servidor).setCustomUserClaims(uid, {
    financebroAdmin: true,
  });
  await db.doc(`usuarios/${uid}`).set({ nombre: "Histórico Demo" });
  await banco.abrirAhorros(identidad, {
    nombre: "Histórico Demo",
    telefono: "0999999999",
    documento: "TEST-HISTORIAL",
    nacimiento: "1990-01-01",
    aceptaTerminos: true,
  });
  for (let i = 0; i < 250; i++)
    await banco.ajustar(rol, {
      uid,
      cuenta: "ahorros",
      centavos: 100,
      motivo: "Verificación de páginas anteriores",
      referencia: `${uid}_${i}`,
    });
  const app = initializeApp(
    { apiKey: "demo-key", projectId: "demo-financebro" },
    uid,
  );
  const auth = getAuth(app);
  connectAuthEmulator(
    auth,
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`,
    { disableWarnings: true },
  );
  await signInWithEmailAndPassword(
    auth,
    `${uid}@financebro.test`,
    "FinanceBro-historial-2026!",
  );
  const cliente = getFirestore(app);
  const [host, puerto] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  connectFirestoreEmulator(cliente, host, Number(puerto));
  const esperar = async (condicion) => {
    const hasta = Date.now() + 10000;
    while (!condicion()) {
      if (Date.now() > hasta)
        throw new Error("El histórico no llegó al estado esperado.");
      await new Promise((r) => setTimeout(r, 30));
    }
  };
  let items = [],
    error;
  const historial = observarHistorial({
    origen: collection(cliente, `usuarios/${uid}/cuentas/ahorros/movimientos`),
    cambiar: (v) => {
      items = v;
    },
    estado: () => {},
    fallo: (e) => {
      error = e;
    },
  });
  try {
    await esperar(() => items.length === 100 || error);
    assert.equal(error, undefined);
    await banco.ajustar(rol, {
      uid,
      cuenta: "ahorros",
      centavos: 1,
      motivo: "Nuevo ajuste durante la consulta",
      referencia: `${uid}_en_vivo`,
    });
    await esperar(() => items.length === 101);
    await historial.mas();
    assert.equal(items.length, 201);
    await historial.mas();
    assert.equal(items.length, 251);
    assert.equal(new Set(items.map((m) => m.ruta)).size, 251);
    assert.equal(items[0].id, `${uid}_en_vivo`);
    assert.equal(
      items.reduce((s, m) => s + m.centavos, 0),
      (await db.doc(`usuarios/${uid}/cuentas/ahorros`).get()).data()
        .saldoCentavos,
    );
    let global = [],
      errorGlobal;
    const vistaGlobal = observarHistorial({
      origen: collectionGroup(cliente, "movimientos"),
      cambiar: (v) => {
        global = v;
      },
      estado: () => {},
      fallo: (e) => {
        errorGlobal = e;
      },
    });
    try {
      await esperar(() => global.length >= 100 || errorGlobal);
      assert.equal(errorGlobal, undefined);
      let paginas = 0;
      while (
        global.filter(
          (m) =>
            m.ruta.includes(`/usuarios/${uid}/`) ||
            m.ruta.startsWith(`usuarios/${uid}/`),
        ).length < 251
      ) {
        assert.ok(++paginas < 30, "Se debe alcanzar el final del histórico.");
        await vistaGlobal.mas();
      }
      assert.equal(new Set(global.map((m) => m.ruta)).size, global.length);
    } finally {
      vistaGlobal.detener();
    }
  } finally {
    historial.detener();
    await terminate(cliente);
    await deleteApp(app);
  }
});
