import { mkdir, writeFile } from "node:fs/promises";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { Banco } from "./src/banca.js";
if (
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST
)
  throw new Error("Solo se preparan datos sintéticos en emuladores.");
const app = initializeApp({
    projectId: "demo-financebro",
    storageBucket: "demo-financebro.appspot.com",
  }),
  db = getFirestore(app),
  auth = getAuth(app),
  banco = new Banco(db),
  admin = { uid: "asesor_demo", token: { financebroAdmin: true } };
for (const [correo, nombre, clave, fondos] of [
  ["demo@financebro.test", "Sebastian Demo", "FinanceBro-local-2026!", 300000],
  ["valeria@financebro.test", "Valeria Demo", "FinanceBro-local-2026!", 50000],
  [
    "admin@financebro.test",
    "Asesor FinanceBro",
    "FinanceBro-admin-local-2026!",
    0,
  ],
]) {
  let usuario;
  try {
    usuario = await auth.getUserByEmail(correo);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    const legado = await db
      .collection("usuarios")
      .where("nombre", "==", nombre)
      .limit(1)
      .get();
    usuario = await auth.createUser({
      ...(legado.empty ? {} : { uid: legado.docs[0].id }),
      email: correo,
      password: clave,
      displayName: nombre,
    });
  }
  if (correo.startsWith("admin")) {
    await auth.setCustomUserClaims(usuario.uid, { financebroAdmin: true });
    continue;
  }
  const perfil = db.doc(`usuarios/${usuario.uid}`);
  if (!(await perfil.get()).exists)
    await perfil.set({
      nombre,
      segmento: "equilibrio",
      mostrarSaldo: true,
      actualizado: new Date(),
    });
  const cuenta = await banco.registrarCliente(
    { uid: usuario.uid, token: { email: correo } },
    {
      nombres: nombre.split(" ")[0],
      apellidos: "Demo",
      correo,
      cedula: correo.startsWith("demo") ? "1723456789" : "1823456789",
      direccion: "Avenida Aurora 100",
      ciudad: "Quito",
      telefono: "0991234567",
      aceptaContrato: true,
      versionContrato: "2026-10-v1",
    },
  );
  await banco.ajustar(admin, {
    uid: usuario.uid,
    cuenta: cuenta.cuenta,
    centavos: fondos,
    motivo: "Fondos iniciales de demostración",
    referencia: `inicial_${usuario.uid}`,
  });
}
for (const [id, nombre, icono, baseCentavos] of [
  ["luz", "Energía eléctrica", "luz", 2000],
  ["agua", "Agua potable", "agua", 1200],
  ["internet", "Internet del hogar", "internet", 2500],
])
  if (!(await db.doc(`servicios/${id}`).get()).exists)
    await banco.guardarServicio(admin, {
      id,
      nombre,
      icono,
      baseCentavos,
      activo: true,
    });
if (!(await db.doc("experiencias/actual").get()).exists)
  await db.doc("experiencias/actual").set({
    schemaVersion: 1,
    revision: 2,
    actualizado: new Date(),
    tarjetas: [
      {
        id: "ahorro",
        tipo: "recomendacion",
        titulo: "Un paso más cerca de tu meta",
        texto: "Configura un plan de ahorro que vaya contigo.",
        segmento: "todos",
        destino: "/cuentas",
        orden: 1,
      },
    ],
  });
console.log(
  "Personas, cuentas y servicios locales preparados sin restablecer saldos ni históricos.",
);

const receptora = await auth.getUserByEmail("valeria@financebro.test");
const receptoraCuenta = (
  await db.doc(`usuarios/${receptora.uid}/cuentas/ahorros`).get()
).data();
await mkdir(".secrets", { recursive: true });
await writeFile(
  ".secrets/banca-local.json",
  JSON.stringify({ NUMERO_DESTINO: receptoraCuenta.numeroCuenta }),
  { mode: 0o600 },
);
