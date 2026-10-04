import { mkdir, readFile, writeFile } from "node:fs/promises";
import { deflateSync } from "node:zlib";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { Banco, DOCUMENTOS } from "./src/banca.js";

// Esta herramienta crea exclusivamente identidades ficticias en emuladores locales.
for (const nombre of [
  "FIREBASE_AUTH_EMULATOR_HOST",
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_STORAGE_EMULATOR_HOST",
]) {
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env[nombre] ?? "")) {
    throw Error(`${nombre} debe apuntar al emulador en loopback.`);
  }
}
const clave = process.env.NEXTGEN_CLAVE;
if (!clave || clave.length < 12)
  throw Error("Define NEXTGEN_CLAVE con al menos 12 caracteres.");
const app = initializeApp({
  projectId: "demo-financebro",
  storageBucket: "demo-financebro.appspot.com",
});
const db = getFirestore(app),
  auth = getAuth(app),
  bucket = getStorage(app).bucket();
const b = new Banco(db, { bucket });
const admin = {
  uid: (await auth.getUserByEmail("admin@financebro.test")).uid,
  token: { financebroAdmin: true },
};

// Fondo PNG sintético para comprobar descarga privada y representación nativa.
function fondoPng() {
  const crc = (buf) => {
    let c = 0xffffffff;
    for (const v of buf) {
      c ^= v;
      for (let i = 0; i < 8; i++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    return (c ^ 0xffffffff) >>> 0;
  };
  const bloque = (tipo, bytes) => {
    const contenido = Buffer.concat([Buffer.from(tipo), bytes]),
      cabecera = Buffer.alloc(4),
      firma = Buffer.alloc(4);
    cabecera.writeUInt32BE(bytes.length);
    firma.writeUInt32BE(crc(contenido));
    return Buffer.concat([cabecera, contenido, firma]);
  };
  const n = 64,
    filas = Buffer.alloc(n * (1 + n * 3)),
    ihdr = Buffer.alloc(13);
  for (let y = 0; y < n; y++)
    for (let x = 0; x < n; x++) {
      const p = y * (1 + n * 3) + 1 + x * 3;
      filas[p] = 240 - y;
      filas[p + 1] = 150 + x;
      filas[p + 2] = 130 + y;
    }
  ihdr.writeUInt32BE(n);
  ihdr.writeUInt32BE(n, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    bloque("IHDR", ihdr),
    bloque("IDAT", deflateSync(filas)),
    bloque("IEND", Buffer.alloc(0)),
  ]);
}
const fondo = process.env.NEXTGEN_FONDO
  ? await readFile(process.env.NEXTGEN_FONDO)
  : fondoPng();
let destino;
for (const [i, uid] of [
  "nextgen_ios",
  "nextgen_android",
  "nextgen_proveedor",
].entries()) {
  const correo = `${uid}@financebro.test`,
    nombres = i === 2 ? "Valeria" : "Sebastián",
    apellidos = i === 2 ? "Andrade" : "Torres";
  try {
    await auth.getUser(uid);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    await auth.createUser({
      uid,
      email: correo,
      password: clave,
      displayName: `${nombres} ${apellidos}`,
    });
  }
  const actor = { uid, token: { email: correo } };
  await b.registrarCliente(actor, {
    nombres,
    apellidos,
    correo,
    cedula: `${23 + i}23456790`,
    direccion: "Avenida Aurora 100",
    ciudad: "Quito",
    telefono: "0991234567",
    aceptaContrato: true,
    versionContrato: "2026-10-v1",
  });
  if (!(await db.doc(`ajustes/nextgen_ahorro_${uid}`).get()).exists) {
    await b.ajustar(admin, {
      uid,
      cuenta: "ahorros",
      centavos: 250000,
      motivo: "Fondos sintéticos para revisión",
      referencia: `nextgen_ahorro_${uid}`,
    });
  }
  if (!(await b.cuenta(uid, "corriente").get()).exists) {
    await b.guardarSolicitud(actor, {
      empresa: i === 2 ? "Valeria Insumos" : "Aurora Estudio",
      ruc: `17912345670${i}1`,
      representante: `${nombres} ${apellidos}`,
      escala: "pyme",
    });
    for (const categoria of DOCUMENTOS) {
      const ruta = `expedientes/${uid}/corriente/${categoria}/revision_nextgen.pdf`;
      await bucket
        .file(ruta)
        .save(Buffer.from("%PDF-1.7\nDocumento sintético de revisión"), {
          metadata: { contentType: "application/pdf" },
        });
      await b.registrarDocumento(actor, {
        categoria,
        ruta,
        nombre: `${categoria}.pdf`,
      });
    }
    await b.enviarSolicitud(actor, { acepta: true });
    await b.revisarSolicitud(admin, {
      uid,
      accion: "aprobar",
      nota: "Expediente sintético revisado",
    });
    await b.ajustar(admin, {
      uid,
      cuenta: "corriente",
      centavos: 200000,
      motivo: "Depósito corporativo sintético",
      referencia: `nextgen_corriente_${uid}`,
    });
    await b.revisarSolicitud(admin, {
      uid,
      accion: "activar",
      nota: "Depósito verificado",
    });
  }
  if (
    i < 2 &&
    !(await b.privado(uid, "tarjetas", "bro_credito").get()).exists
  ) {
    await b.solicitarCredito(actor, {
      ocupacion: "Diseñador de productos",
      ingresosCentavos: 250000,
      aceptaEvaluacion: true,
    });
    await b.revisarTarjeta(admin, {
      uid,
      id: "credito",
      accion: "aprobar",
      cupoCentavos: 150000,
      nota: "Tarjeta aprobada",
    });
    await b.elegirCorteTarjeta(actor, { dia: 2, aceptaCondiciones: true });
    await b.registrarConsumoTarjeta(admin, {
      uid,
      centavos: 24000,
      comercio: "Librería Alameda",
      referencia: `nextgen_compra_${uid}`,
    });
    await b.guardarTarjeta(actor, {
      id: "externa_alameda",
      tipo: "externa",
      nombre: "Mi tarjeta asociada",
      banco: "Banco Alameda",
      ultimos4: "4821",
      color: "menta",
    });
    await b.usuario(uid).update({ segmento: "viajes" });
  }
  if (i < 2) {
    const ruta = `tarjetas/${uid}/bro_ahorros/fondos/fondo_revision_nextgen.png`;
    if (!(await bucket.file(ruta).exists())[0])
      await bucket
        .file(ruta)
        .save(fondo, { metadata: { contentType: "image/png" } });
    await b.guardarTarjeta(actor, {
      id: "bro_ahorros",
      tipo: "propia",
      nombre: "Mi tarjeta Aurora",
      color: "durazno",
      fondoRuta: ruta,
    });
  } else destino = (await b.cuenta(uid, "corriente").get()).data().numeroCuenta;
}
for (const uid of ["nextgen_ios", "nextgen_android"]) {
  if (
    (
      await b
        .usuario(uid)
        .collection("contactos")
        .where("numero", "==", destino)
        .get()
    ).empty
  ) {
    await b.guardarContacto({ uid }, { tipo: "interno", numero: destino });
  }
}
await mkdir(".secrets", { recursive: true });
await writeFile(
  ".secrets/nextgen.json",
  JSON.stringify({ NEXTGEN_CLAVE: clave, NUMERO_CORRIENTE: destino }),
  { mode: 0o600 },
);
console.log(
  "Perfiles sintéticos preparados. Definiciones en .secrets/nextgen.json; saldos e históricos conservados.",
);
