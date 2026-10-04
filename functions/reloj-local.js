import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { Banco } from "./src/banca.js";
import { procesarCheques } from "./src/chequera.js";
if (process.env.FINANCEBRO_COBROS_LOCALES !== "true") {
  throw Error("El reloj de cobros está detenido. Activarlo exige FINANCEBRO_COBROS_LOCALES=true y emuladores locales.");
}
for (const nombre of [
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_STORAGE_EMULATOR_HOST",
]) {
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env[nombre] ?? "")) {
    throw Error("El reloj local requiere emuladores en loopback.");
  }
}
const app = initializeApp({
    projectId: "demo-financebro",
    storageBucket: "demo-financebro.appspot.com",
  }),
  b = new Banco(getFirestore(app), { bucket: getStorage(app).bucket() });
let ocupado = false;
async function revisar() {
  if (ocupado) return;
  ocupado = true;
  try {
    let cursor;
    for (let p = 0; p < 20; p++) {
      const r = await procesarCheques(
        b,
        null,
        { cursor },
        { programado: true },
      );
      if (!r.hayMas) break;
      cursor = r.cursor;
    }
    await b.procesarAutopagos();
    await b.procesarCortesTarjetas();
    console.log("Fechas y cobros locales revisados.");
  } catch (error) {
    console.error(
      "reloj_local_pendiente",
      error.codigo ?? error.code ?? "conexion",
    );
  } finally {
    ocupado = false;
  }
}
setInterval(revisar, 60000);
await revisar();
