import { before, test } from "node:test";
import assert from "node:assert/strict";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { Banco, DOCUMENTOS } from "../../src/banca.js";
if (
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST
)
  throw new Error(
    "Estas pruebas requieren los emuladores; nunca usar un proyecto remoto.",
  );
const app = initializeApp({
    projectId: "demo-financebro",
    storageBucket: "demo-financebro.appspot.com",
  }),
  db = getFirestore(app),
  bucket = getStorage(app).bucket();
let ahora = new Date("2026-10-03T14:00:00Z");
const banco = new Banco(db, { bucket, reloj: () => ahora });
const marca = Date.now().toString(36),
  ana = `ana_${marca}`,
  bruno = `bruno_${marca}`,
  admin = { uid: `asesor_${marca}`, token: { financebroAdmin: true } };
const authA = { uid: ana },
  authB = { uid: bruno };
let numeroA, numeroB;
const apertura = (nombre) => ({
  nombre,
  telefono: "0991234567",
  documento: "1712345678",
  nacimiento: "1990-01-15",
  aceptaTerminos: true,
});
const saldo = async (uid, cuenta = "ahorros") =>
  (await banco.cuenta(uid, cuenta).get()).data().saldoCentavos;
const contar = async (uid) =>
  (await banco.cuenta(uid, "ahorros").collection("movimientos").get()).size;
before(async () => {
  for (const [uid, nombre] of [
    [ana, "Ana Demo"],
    [bruno, "Bruno Demo"],
  ])
    await banco
      .usuario(uid)
      .set({ nombre, segmento: "equilibrio", mostrarSaldo: true });
  numeroA = (await banco.abrirAhorros(authA, apertura("Ana Demo"))).numero;
  numeroB = (await banco.abrirAhorros(authB, apertura("Bruno Demo"))).numero;
  await banco.ajustar(admin, {
    uid: ana,
    cuenta: "ahorros",
    centavos: 50000,
    motivo: "Fondos sintéticos para pruebas",
    referencia: `fondos_${marca}`,
  });
});
test("La apertura no obliga a crear una cuenta y no la duplica ni cambia sus fondos", async () => {
  const visitante = `nuevo_${marca}`;
  await banco.usuario(visitante).set({ nombre: "Nueva Persona" });
  assert.equal(
    (await banco.usuario(visitante).collection("cuentas").get()).size,
    0,
  );
  await assert.rejects(
    banco.abrirAhorros(
      { uid: visitante },
      { ...apertura("Nueva Persona"), aceptaTerminos: false },
    ),
  );
  await assert.rejects(
    banco.abrirAhorros(
      { uid: visitante },
      { ...apertura("Nueva Persona"), nacimiento: "2020-01-15" },
    ),
  );
  const antes = await saldo(ana);
  assert.equal(
    (await banco.abrirAhorros(authA, apertura("Ana Demo"))).numero,
    numeroA,
  );
  assert.equal(await saldo(ana), antes);
});
test("La consulta verifica titular sin revelar saldo, UID ni identificación privada", async () => {
  const r = await banco.destinatario(authA, { numero: numeroB });
  assert.deepEqual(Object.keys(r).sort(), [
    "estado",
    "numero",
    "tipo",
    "titular",
  ]);
  assert.equal(r.titular, "Bruno Demo");
});
test("Dos reintentos concurrentes debitan una vez y conservan el dinero entre cuentas", async () => {
  const antesA = await saldo(ana),
    antesB = await saldo(bruno),
    n = await contar(ana);
  const d = {
    cuenta: "ahorros",
    numero: numeroB,
    centavos: 10,
    nota: "Prueba de transferencia",
    referencia: `qr_${marca}`,
  };
  const [r1, r2] = await Promise.all([
    banco.transferir(authA, d),
    banco.transferir(authA, d),
  ]);
  assert.deepEqual(r1, r2);
  assert.equal(await saldo(ana), antesA - 10);
  assert.equal(await saldo(bruno), antesB + 10);
  assert.equal(await contar(ana), n + 1);
  assert.equal((await saldo(ana)) + (await saldo(bruno)), antesA + antesB);
  await assert.rejects(
    banco.transferir(authA, { ...d, centavos: 100 }),
    (e) => e.codigo === "already-exists",
  );
});
test("Un monto inválido o fondos insuficientes no generan movimientos", async () => {
  const n = await contar(bruno),
    antes = await saldo(bruno);
  for (const centavos of [9, 10001, 0.5, "100"])
    await assert.rejects(
      banco.transferir(authB, {
        cuenta: "ahorros",
        numero: numeroA,
        centavos,
        referencia: `limite_${marca}`,
      }),
    );
  await assert.rejects(
    banco.transferir(authB, {
      cuenta: "ahorros",
      numero: numeroA,
      centavos: 10000,
      referencia: `sin_fondos_${marca}`,
    }),
  );
  assert.equal(await contar(bruno), n);
  assert.equal(await saldo(bruno), antes);
});
test("Los contactos internos se verifican y las tarjetas externas guardan solo últimos cuatro dígitos", async () => {
  const interno = await banco.guardarContacto(authA, {
    tipo: "interno",
    numero: numeroB,
  });
  assert.equal(interno.nombre, "Bruno Demo");
  await assert.rejects(
    banco.guardarContacto(authA, {
      tipo: "externo",
      numero: "123456789",
      nombre: "Luisa",
      banco: "Banco Demo",
    }),
  );
  const tarjeta = await banco.guardarTarjeta(authA, {
    tipo: "externa",
    nombre: "Mi tarjeta externa",
    banco: "Banco Demo",
    ultimos4: "4321",
    color: "menta",
  });
  await assert.rejects(
    banco.guardarTarjeta(authA, {
      tipo: "externa",
      nombre: "Tarjeta",
      banco: "Banco Demo",
      ultimos4: "1234567890123456",
    }),
  );
  const d = {
    cuenta: "ahorros",
    destino: tarjeta.id,
    tipo: "tarjeta",
    centavos: 100,
    referencia: `tarjeta_${marca}`,
  };
  await banco.pagarExterno(authA, d);
  await banco.pagarExterno(authA, d);
  const global = await banco.usuario(ana).collection("movimientosGlobales").where("referencia", "==", d.referencia).get();
  assert.equal(global.size, 1);
  assert.equal(
    (
      await banco
        .privado(ana, "tarjetas", tarjeta.id)
        .collection("movimientos")
        .get()
    ).size,
    1,
  );
});
test("La solicitud guarda progreso; requiere documentos y asesor antes de activar la cuenta", async () => {
  await banco.guardarSolicitud(authB, {
    empresa: "Empresa de prueba",
    ruc: "1791234567001",
    representante: "Bruno Demo",
    escala: "pyme",
  });
  await assert.rejects(banco.enviarSolicitud(authB, { acepta: true }));
  for (const categoria of DOCUMENTOS) {
    const ruta = `expedientes/${bruno}/corriente/${categoria}/archivo_${marca}.pdf`;
    await bucket
      .file(ruta)
      .save(Buffer.from("%PDF-1.7\nDocumento sintético de prueba\n%%EOF"), {
        metadata: { contentType: "application/pdf" },
      });
    await banco.registrarDocumento(authB, {
      categoria,
      ruta,
      nombre: `${categoria}.pdf`,
    });
  }
  const borrador = (
    await banco.privado(bruno, "solicitudes", "corriente").get()
  ).data();
  assert.equal(Object.keys(borrador.documentos).length, 5);
  await banco.enviarSolicitud(authB, { acepta: true });
  await assert.rejects(
    banco.revisarSolicitud(authB, {
      uid: bruno,
      accion: "aprobar",
      nota: "Documentos revisados",
    }),
  );
  await banco.revisarSolicitud(admin, {
    uid: bruno,
    accion: "aprobar",
    nota: "Documentación sintética revisada",
  });
  assert.equal(
    (await banco.cuenta(bruno, "corriente").get()).data().estado,
    "temporal",
  );
  await assert.rejects(
    banco.revisarSolicitud(admin, {
      uid: bruno,
      accion: "activar",
      nota: "Validación del depósito inicial",
    }),
  );
  await banco.ajustar(admin, {
    uid: bruno,
    cuenta: "corriente",
    centavos: 100000,
    motivo: "Depósito corporativo sintético",
    referencia: `deposito_${marca}`,
  });
  await assert.rejects(
    banco.transferir(authB, {
      cuenta: "corriente",
      numero: numeroA,
      centavos: 10,
      referencia: `temporal_${marca}`,
    }),
  );
  await banco.revisarSolicitud(admin, {
    uid: bruno,
    accion: "activar",
    nota: "Depósito inicial validado por el asesor",
  });
  assert.equal(
    (await banco.cuenta(bruno, "corriente").get()).data().estado,
    "activa",
  );
});
test("Una planilla pagada no se vuelve a cobrar con otra referencia", async () => {
  await banco.guardarServicio(admin, {
    id: `luz_${marca}`,
    nombre: "Luz de prueba",
    icono: "luz",
    activo: true,
    baseCentavos: 1000,
  });
  const f = await banco.consultarFactura(authA, {
      servicio: `luz_${marca}`,
      contrato: "CONTRATO1234",
    }),
    antes = await saldo(ana);
  const d = {
    cuenta: "ahorros",
    factura: f.id,
    referencia: `planilla_${marca}`,
  };
  await banco.pagarServicio(authA, d);
  await banco.pagarServicio(authA, d);
  assert.equal(await saldo(ana), antes - f.centavos);
  await assert.rejects(
    banco.pagarServicio(authB, { ...d, referencia: `otra_planilla_${marca}` }),
  );
  await banco.configurarAutopago(authA, {
    referencia: d.referencia,
    maximoCentavos: 3000,
    dia: 3,
    acepta: true,
  });
});
test("El pago mensual se procesa una vez y alerta si supera el límite autorizado", async () => {
  ahora = new Date("2026-11-03T14:00:00Z");
  const antes = await saldo(ana);
  await Promise.all([banco.procesarAutopagos(), banco.procesarAutopagos()]);
  const despues = await saldo(ana);
  assert.ok(despues < antes);
  await banco.procesarAutopagos();
  assert.equal(await saldo(ana), despues);
  const auto = (await banco.usuario(ana).collection("autopagos").get()).docs[0];
  await auto.ref.update({ maximoCentavos: 10 });
  ahora = new Date("2026-12-03T14:00:00Z");
  await banco.procesarAutopagos();
  assert.equal(await saldo(ana), despues);
  assert.equal((await auto.ref.get()).data().ultimoEstado, "requiere_atencion");
  await banco.pausarAutopago(authA, { id: auto.id });
  assert.equal((await auto.ref.get()).data().activo, false);
});
test("Un ajuste crea histórico global, notificación y envío push sin duplicarlos", async () => {
  const d = {
    uid: ana,
    cuenta: "ahorros",
    centavos: -10,
    motivo: "Prueba de disminución de fondos",
    referencia: `disminucion_${marca}`,
  };
  await banco.ajustar(admin, d);
  await banco.ajustar(admin, d);
  assert.ok(
    (
      await banco
        .privado(ana, "movimientosGlobales", `ahorros_${d.referencia}`)
        .get()
    ).exists,
  );
  assert.ok(
    (
      await banco
        .privado(ana, "notificaciones", `ahorros_${d.referencia}`)
        .get()
    ).exists,
  );
  assert.ok(
    (await db.doc(`enviosPush/${ana}_ahorros_${d.referencia}`).get()).exists,
  );
});
test("El endpoint callable exige sesión y ejecuta consultas con un token real del emulador", async () => {
  const base = `http://127.0.0.1:${process.env.FUNCTIONS_PORT ?? 5001}/demo-financebro/us-central1/banca`;
  const sin = await fetch(base, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      data: { operacion: "destinatario", datos: { numero: numeroA } },
    }),
  });
  assert.equal(sin.status, 401);
  const email = `${ana}@financebro.test`;
  await getAuth(app).createUser({
    uid: ana,
    email,
    password: "FinanceBro-test-2026!",
  });
  const login = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email,
        password: "FinanceBro-test-2026!",
        returnSecureToken: true,
      }),
    },
  );
  const token = (await login.json()).idToken;
  const r = await fetch(base, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      data: { operacion: "destinatario", datos: { numero: numeroB } },
    }),
  });
  const datos = await r.json();
  assert.equal(r.status, 200);
  assert.equal(datos.result.titular, "Bruno Demo");
});

test("Preparar cuentas antiguas conserva saldos, tarjetas e históricos y completa un reintento", async () => {
  const uid = `legado_${marca}`;
  await banco.usuario(uid).set({nombre: "Legado Demo"});
  const cuenta = banco.cuenta(uid, "principal");
  await cuenta.set({nombre: "Mis ahorros", numero: "•••• 1234", tarjetaUltimos4: "1234", saldoCentavos: 12345, moneda: "USD"});
  await cuenta.collection("movimientos").doc("historia_original").set({descripcion: "Fondos anteriores", centavos: 12345, fecha: banco.ahora()});
  await banco.migrarCuentas(admin, {uid});
  const preparado = (await cuenta.get()).data();
  assert.equal(preparado.saldoCentavos, 12345);
  assert.equal(preparado.tarjetaUltimos4, "1234");
  const tarjeta = banco.privado(uid, "tarjetas", "bro_principal");
  await tarjeta.update({color: "menta"});
  await cuenta.collection("movimientos").doc("pagina_pendiente").set({descripcion: "Movimiento pendiente de preparar", centavos: 0, fecha: banco.ahora()});
  await banco.migrarCuentas(admin, {uid});
  await banco.migrarCuentas(admin, {uid});
  assert.equal((await cuenta.get()).data().numeroCuenta, preparado.numeroCuenta);
  assert.equal((await cuenta.get()).data().saldoCentavos, 12345);
  assert.equal((await tarjeta.get()).data().color, "menta");
  assert.equal((await banco.usuario(uid).collection("movimientosGlobales").get()).size, 2);
});
