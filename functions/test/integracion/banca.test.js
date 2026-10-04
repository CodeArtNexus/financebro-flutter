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
test("La apertura heredada conserva consentimiento, mayoría de edad y fondos existentes", async () => {
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
  const global = await banco
    .usuario(ana)
    .collection("movimientosGlobales")
    .where("referencia", "==", d.referencia)
    .get();
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
  assert.equal(
    (await banco.privado(bruno, "tarjetas", "bro_corriente").get()).exists,
    false,
  );
  assert.equal(
    (await banco.cuenta(bruno, "corriente").get()).data().tarjetaUltimos4,
    undefined,
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
  await banco.usuario(uid).set({ nombre: "Legado Demo" });
  const cuenta = banco.cuenta(uid, "principal");
  await cuenta.set({
    nombre: "Mis ahorros",
    numero: "•••• 1234",
    tarjetaUltimos4: "1234",
    saldoCentavos: 12345,
    moneda: "USD",
  });
  await cuenta.collection("movimientos").doc("historia_original").set({
    descripcion: "Fondos anteriores",
    centavos: 12345,
    fecha: banco.ahora(),
  });
  await banco.migrarCuentas(admin, { uid });
  const preparado = (await cuenta.get()).data();
  assert.equal(preparado.saldoCentavos, 12345);
  assert.equal(preparado.tarjetaUltimos4, "1234");
  const tarjeta = banco.privado(uid, "tarjetas", "bro_principal");
  await tarjeta.update({ color: "menta" });
  await cuenta.collection("movimientos").doc("pagina_pendiente").set({
    descripcion: "Movimiento pendiente de preparar",
    centavos: 0,
    fecha: banco.ahora(),
  });
  await banco.migrarCuentas(admin, { uid });
  await banco.migrarCuentas(admin, { uid });
  assert.equal(
    (await cuenta.get()).data().numeroCuenta,
    preparado.numeroCuenta,
  );
  assert.equal((await cuenta.get()).data().saldoCentavos, 12345);
  assert.equal((await tarjeta.get()).data().color, "menta");
  assert.equal(
    (await banco.usuario(uid).collection("movimientosGlobales").get()).size,
    2,
  );
});

test("El registro crea ahorros, débito y contrato juntos; reintentos conservan fondos y una cédula no se comparte", async () => {
  const b = new Banco(db, { reloj: () => new Date("2026-10-03T14:00:00Z") });
  const uid = `registro_${marca}`,
    email = `${uid}@financebro.test`,
    actor = { uid, token: { email } };
  const d = {
    nombres: "Lucía",
    apellidos: "Pérez",
    correo: email,
    cedula: String(Date.now() % 10000000000).padStart(10, "0"),
    direccion: "Calle Naranjos 120",
    ciudad: "Quito",
    telefono: "0991234567",
    aceptaContrato: true,
    versionContrato: "2026-10-v1",
  };
  await assert.rejects(
    b.registrarCliente(actor, { ...d, aceptaContrato: false }),
  );
  await assert.rejects(
    b.registrarCliente(actor, { ...d, correo: "otra@financebro.test" }),
  );
  assert.equal((await b.usuario(uid).collection("cuentas").get()).size, 0);
  const [a, c] = await Promise.all([
    b.registrarCliente(actor, d),
    b.registrarCliente(actor, d),
  ]);
  assert.deepEqual(a, c);
  assert.equal((await b.usuario(uid).collection("cuentas").get()).size, 1);
  assert.equal((await b.usuario(uid).collection("tarjetas").get()).size, 1);
  const tarjeta = (
    await b.privado(uid, "tarjetas", "bro_ahorros").get()
  ).data();
  assert.equal(tarjeta.clase, "debito");
  assert.equal(tarjeta.personalizada, false);
  const contrato = (
    await b.privado(uid, "datosPersonales", "identidad").get()
  ).data();
  assert.equal(contrato.contratoVersion, "2026-10-v1");
  assert.equal(contrato.domicilio.direccion, d.direccion);
  assert.equal((await b.usuario(uid).get()).data().documento, undefined);
  await b.ajustar(admin, {
    uid,
    cuenta: "ahorros",
    centavos: 1000,
    motivo: "Fondos de verificación",
    referencia: `registro_fondos_${marca}`,
  });
  await b.registrarCliente(actor, d);
  assert.equal(
    (await b.cuenta(uid, "ahorros").get()).data().saldoCentavos,
    1000,
  );
  await assert.rejects(
    b.registrarCliente({ uid: `otro_${marca}`, token: { email } }, d),
    (e) => e.codigo === "already-exists",
  );
  await assert.rejects(
    b.guardarTarjeta(actor, {
      tipo: "propia",
      nombre: "Inventada",
      cuenta: "ahorros",
      color: "menta",
    }),
  );
  await b.guardarTarjeta(actor, {
    id: "bro_ahorros",
    tipo: "propia",
    nombre: "Mi diseño",
    color: "menta",
  });
  const pedido = {
    tarjeta: "bro_ahorros",
    referencia: `fisica_${marca}`,
    direccion: d.direccion,
    ciudad: d.ciudad,
    telefono: d.telefono,
    fechaEnvio: "2026-10-06",
    aceptaEnvio: true,
  };
  await assert.rejects(
    b.solicitarFisica(actor, { ...pedido, fechaEnvio: "2026-10-05" }),
  );
  await assert.rejects(
    b.solicitarFisica(actor, { ...pedido, fechaEnvio: "2026-10-32" }),
  );
  const fisica = await b.solicitarFisica(actor, pedido);
  assert.equal(fisica.estado, "revision_diseno");
  assert.deepEqual(await b.solicitarFisica(actor, pedido), fisica);
  await assert.rejects(
    b.solicitarFisica(actor, { ...pedido, referencia: `distinta_${marca}` }),
  );
  await b.guardarTarjeta(actor, {
    id: "bro_ahorros",
    tipo: "propia",
    nombre: "Otro diseño",
    color: "noche",
  });
  assert.equal(
    (await b.privado(uid, "solicitudes", fisica.id).get()).data().diseno.color,
    "menta",
  );
  await assert.rejects(
    b.revisarTarjeta(actor, {
      uid,
      id: fisica.id,
      accion: "aprobar_diseno",
      nota: "Diseño revisado",
    }),
  );
  await b.revisarTarjeta(admin, {
    uid,
    id: fisica.id,
    accion: "aprobar_diseno",
    nota: "Diseño aprobado por asesor",
  });
  await assert.rejects(
    b.revisarTarjeta(admin, {
      uid,
      id: fisica.id,
      accion: "enviar",
      nota: "Envío preparado",
    }),
  );
  const futuro = new Banco(db, {
    reloj: () => new Date("2026-10-06T14:00:00Z"),
  });
  await futuro.revisarTarjeta(admin, {
    uid,
    id: fisica.id,
    accion: "enviar",
    nota: "Salida de tarjeta registrada",
  });
  await futuro.revisarTarjeta(admin, {
    uid,
    id: fisica.id,
    accion: "entregar",
    nota: "Entrega de tarjeta registrada",
  });
  const credito = {
    ingresosCentavos: 150000,
    ocupacion: "Diseñadora",
    aceptaEvaluacion: true,
  };
  await assert.rejects(
    b.solicitarCredito(actor, { ...credito, aceptaEvaluacion: false }),
  );
  await b.solicitarCredito(actor, credito);
  await b.solicitarCredito(actor, credito);
  assert.equal((await b.usuario(uid).collection("tarjetas").get()).size, 1);
  await b.revisarTarjeta(admin, {
    uid,
    id: "credito",
    accion: "aprobar",
    cupoCentavos: 150000,
    nota: "Evaluación y cupo aprobados",
  });
  assert.equal(
    (await b.privado(uid, "solicitudes", "credito").get()).data().estado,
    "aprobada",
  );
  assert.ok(
    (await b.usuario(uid).collection("notificaciones").get()).size >= 6,
  );
});

test("El diseño predeterminado pasa a preparación y no se puede pedir una tarjeta ajena o externa", async () => {
  const b = new Banco(db, { reloj: () => new Date("2026-10-03T04:00:00Z") });
  const uid = `predeterminado_${marca}`,
    email = `${uid}@financebro.test`,
    actor = { uid, token: { email } };
  const domicilio = {
    direccion: "Avenida Aurora 50",
    ciudad: "Guayaquil",
    telefono: "0991234567",
  };
  await b.registrarCliente(actor, {
    nombres: "Pedro",
    apellidos: "López",
    correo: email,
    cedula: String((Date.now() + 1) % 10000000000).padStart(10, "0"),
    ...domicilio,
    aceptaContrato: true,
    versionContrato: "2026-10-v1",
  });
  const d = {
    tarjeta: "bro_ahorros",
    referencia: `pedido_default_${marca}`,
    fechaEnvio: "2026-10-05",
    aceptaEnvio: true,
    ...domicilio,
  };
  const s = await b.solicitarFisica(actor, d);
  assert.equal(s.estado, "preparacion");
  await assert.rejects(b.solicitarFisica({ uid: `sin_cuenta_${marca}` }, d));
  const externa = await b.guardarTarjeta(actor, {
    tipo: "externa",
    nombre: "Externa",
    banco: "Otro banco",
    ultimos4: "1234",
    color: "menta",
  });
  await assert.rejects(b.solicitarFisica(actor, { ...d, tarjeta: externa.id }));
});

test("La tarjeta aprobada tiene cupo, corte privado, consumos y pagos atómicos sin duplicación", async () => {
  let reloj = new Date("2026-12-20T14:00:00Z");
  const b = new Banco(db, { reloj: () => reloj }),
    uid = `tarjeta_${marca}`,
    actor = { uid, token: { email: `${uid}@financebro.test` } };
  await b.registrarCliente(actor, {
    nombres: "Andrea",
    apellidos: "Torres",
    correo: actor.token.email,
    cedula: String((Date.now() + 100) % 10000000000).padStart(10, "0"),
    direccion: "Calle Alborada 120",
    ciudad: "Quito",
    telefono: "0991234567",
    aceptaContrato: true,
    versionContrato: "2026-10-v1",
  });
  await b.solicitarCredito(actor, {
    ingresosCentavos: 220000,
    ocupacion: "Arquitecta",
    aceptaEvaluacion: true,
  });
  const decision = {
    uid,
    id: "credito",
    accion: "aprobar",
    cupoCentavos: 150000,
    nota: "Cupo aprobado tras revisión",
  };
  await assert.rejects(
    b.revisarTarjeta(actor, decision),
    (e) => e.codigo === "permission-denied",
  );
  await assert.rejects(
    b.revisarTarjeta(admin, { ...decision, cupoCentavos: 0 }),
  );
  await b.revisarTarjeta(admin, decision);
  await assert.rejects(b.revisarTarjeta(admin, decision));
  const ref = b.privado(uid, "tarjetas", "bro_credito");
  assert.equal((await ref.get()).data().cupoCentavos, 150000);
  const consumo = {
    uid,
    referencia: `compra_${marca}`,
    centavos: 20000,
    comercio: "Librería Alameda",
  };
  await assert.rejects(b.registrarConsumoTarjeta(admin, consumo));
  await assert.rejects(
    b.elegirCorteTarjeta(actor, { dia: 31, aceptaCondiciones: true }),
  );
  await assert.rejects(
    b.elegirCorteTarjeta(actor, { dia: 25, aceptaCondiciones: false }),
  );
  await b.elegirCorteTarjeta(actor, { dia: 25, aceptaCondiciones: true });
  assert.equal((await ref.get()).data().proximoCorte, "2026-12-25");
  await assert.rejects(b.registrarConsumoTarjeta(actor, consumo));
  await Promise.all([
    b.registrarConsumoTarjeta(admin, consumo),
    b.registrarConsumoTarjeta(admin, consumo),
  ]);
  await assert.rejects(
    b.registrarConsumoTarjeta(admin, { ...consumo, centavos: 20001 }),
    (e) => e.codigo === "already-exists",
  );
  await assert.rejects(
    b.registrarConsumoTarjeta(admin, {
      ...consumo,
      referencia: `exceso_${marca}`,
      centavos: 150000,
    }),
  );
  assert.equal((await ref.get()).data().deudaCentavos, 20000);
  await b.guardarTarjeta(actor, {
    id: "bro_credito",
    tipo: "propia",
    nombre: "Mis planes",
    color: "noche",
  });
  await assert.rejects(
    b.guardarTarjeta(actor, {
      id: "bro_credito",
      tipo: "externa",
      nombre: "Otro banco",
      banco: "Externo",
      ultimos4: "1234",
    }),
  );
  assert.equal((await ref.get()).data().clase, "credito");
  assert.equal((await ref.get()).data().cupoCentavos, 150000);
  reloj = new Date("2026-12-25T05:00:00Z");
  await Promise.all([
    b.consultarTarjetaCredito(actor),
    b.consultarTarjetaCredito(actor),
  ]);
  const corte = (await ref.get()).data();
  assert.equal(corte.totalPagarCentavos, 20000);
  assert.equal(corte.minimoPagarCentavos, 1000);
  assert.equal(corte.pagoHasta, "2027-01-09");
  assert.equal(corte.proximoCorte, "2027-01-25");
  assert.equal((await ref.collection("estadosCuenta").get()).size, 1);
  await b.registrarConsumoTarjeta(admin, {
    ...consumo,
    referencia: `posterior_${marca}`,
    centavos: 5000,
  });
  assert.equal((await ref.get()).data().totalPagarCentavos, 20000);
  await b.ajustar(admin, {
    uid,
    cuenta: "ahorros",
    centavos: 30000,
    motivo: "Fondos para abono",
    referencia: `abono_fondos_${marca}`,
  });
  const pago = {
    cuenta: "ahorros",
    referencia: `pago_tc_${marca}`,
    centavos: 1000,
  };
  await Promise.all([
    b.pagarTarjetaCredito(actor, pago),
    b.pagarTarjetaCredito(actor, pago),
  ]);
  assert.equal(
    (await b.cuenta(uid, "ahorros").get()).data().saldoCentavos,
    29000,
  );
  const abonada = (await ref.get()).data();
  assert.equal(abonada.deudaCentavos, 24000);
  assert.equal(abonada.totalPagarCentavos, 19000);
  assert.equal(abonada.minimoPagarCentavos, 0);
  await assert.rejects(
    b.pagarTarjetaCredito(actor, {
      ...pago,
      referencia: `sobrepago_${marca}`,
      centavos: 24001,
    }),
  );
  assert.equal((await ref.collection("movimientos").get()).size, 3);
  assert.equal(
    (
      await b
        .usuario(uid)
        .collection("movimientosGlobales")
        .where("tipo", "==", "pago_credito")
        .get()
    ).size,
    1,
  );
  const aviso = (
    await b.usuario(uid).collection("notificaciones").get()
  ).docs.find((d) => d.data().titulo === "Tu tarjeta de crédito está aprobada");
  assert.match(aviso.data().cuerpo, /1500.00/);
  assert.equal(aviso.data().destino, "/tarjetas/credito/detalle");
  // Un abono parcial puede dejar centavos residuales: también debe poder cancelarlos.
  await b.pagarTarjetaCredito(actor, {
    cuenta: "ahorros",
    referencia: `casi_total_${marca}`,
    centavos: 23995,
  });
  assert.equal((await ref.get()).data().deudaCentavos, 5);
  await b.pagarTarjetaCredito(actor, {
    cuenta: "ahorros",
    referencia: `saldo_residual_${marca}`,
    centavos: 5,
  });
  assert.equal((await ref.get()).data().deudaCentavos, 0);
  assert.equal((await ref.get()).data().totalPagarCentavos, 0);
  assert.equal(
    (await b.cuenta(uid, "ahorros").get()).data().saldoCentavos,
    5000,
  );
  reloj = new Date("2026-10-03T14:00:00Z");
  await b.procesarCortesTarjetas(admin);
  assert.equal((await ref.get()).data().proximoCorte, "2027-01-25");
  await assert.rejects(b.procesarCortesTarjetas(actor));
});

test("La actividad de un contacto conserva envíos y recibos por número de cuenta", async () => {
  await banco.ajustar(admin, {uid: bruno, cuenta: "ahorros", centavos: 1000, motivo: "Fondos para actividad de contactos", referencia: `contactof_${marca}`});
  const antesA=await saldo(ana), antesB=await saldo(bruno);
  const contacto=await banco.guardarContacto(authA,{tipo:"interno",numero:numeroB});
  assert.equal(contacto.nombre,"Bruno Demo");
  const datos={cuenta:"ahorros",numero:numeroA,centavos:100,referencia:`contactom_${marca}`,nota:"Pedido compartido"};
  await Promise.all([banco.transferir(authB,datos),banco.transferir(authB,datos)]);
  const recibidos=await banco.usuario(ana).collection("movimientosGlobales").where("numeroOrigen","==",numeroB).get();
  assert.equal(recibidos.docs.filter(d=>d.data().nota==="Pedido compartido").length,1);
  assert.equal(await saldo(ana),antesA+100);
  assert.equal(await saldo(bruno),antesB-100);
});
