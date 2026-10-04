import * as chequera from "./chequera.js";
import { randomBytes, createHash } from "node:crypto";
import { Timestamp } from "firebase-admin/firestore";
import {
  POLITICA_TARJETA,
  fechaEcuador,
  siguienteCorte,
  ultimoCorte,
  vencimiento,
  pagoMinimo,
} from "./ciclo-tarjeta.js";

export class FalloBanco extends Error {
  constructor(codigo, mensaje) {
    super(mensaje);
    this.codigo = codigo;
  }
}
const falla = (codigo, mensaje) => {
  throw new FalloBanco(codigo, mensaje);
};
export function texto(v, nombre, min = 2, max = 120) {
  if (
    typeof v !== "string" ||
    v.trim().length < min ||
    v.trim().length > max ||
    /[\x00-\x1f]/.test(v)
  )
    falla("invalid-argument", `Revisa ${nombre}.`);
  return v.trim();
}
export function entero(v, nombre, min, max) {
  if (!Number.isSafeInteger(v) || v < min || v > max)
    falla("invalid-argument", `Revisa ${nombre}.`);
  return v;
}
export function identificador(v) {
  if (typeof v !== "string" || !/^[a-zA-Z0-9_-]{1,80}$/.test(v))
    falla("invalid-argument", "Referencia inválida.");
  return v;
}
export function referencia(v) {
  texto(v, "la referencia", 8, 80);
  return identificador(v);
}
export function numeroCuenta(v) {
  if (typeof v !== "string" || !/^\d{14}$/.test(v))
    falla("invalid-argument", "El número de cuenta debe tener 14 dígitos.");
  return v;
}
export function qrCuenta(numero) {
  return `financebro://transferir?cuenta=${numeroCuenta(numero)}&v=1`;
}
export const DOCUMENTOS = [
  "constitucion",
  "estatutos",
  "nombramiento",
  "ruc",
  "balances",
];
export const COLORES = ["durazno", "lavanda", "menta", "noche"];
const huella = (datos) =>
  createHash("sha256").update(JSON.stringify(datos)).digest("hex");
const MAX_SALDO = 100000000;
export const periodo = (fecha) => fechaLocal(fecha).slice(0, 7);
function fechaLocal(fecha) {
  const valores = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: "America/Guayaquil",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    })
      .formatToParts(fecha)
      .map((p) => [p.type, p.value]),
  );
  return `${valores.year}-${valores.month}-${valores.day}`;
}
function proximoMes(fecha, dia) {
  const [a, m] = fechaLocal(fecha).split("-").map(Number);
  const siguiente = new Date(Date.UTC(a, m, dia, 14));
  return fechaLocal(siguiente);
}

export class Banco {
  constructor(db, { bucket, reloj = () => new Date() } = {}) {
    this.db = db;
    this.bucket = bucket;
    this.reloj = reloj;
  }
  ahora() {
    return Timestamp.fromDate(this.reloj());
  }
  usuario(uid) {
    return this.db.doc(`usuarios/${identificador(uid)}`);
  }
  cuenta(uid, id) {
    return this.usuario(uid).collection("cuentas").doc(identificador(id));
  }
  privado(uid, coleccion, id) {
    return this.usuario(uid)
      .collection(coleccion)
      .doc(
        texto(id, "la referencia interna", 1, 240).replace(
          /[^a-zA-Z0-9_-]/g,
          "_",
        ),
      );
  }
  actor(auth, admin = false) {
    if (!auth?.uid) falla("unauthenticated", "Ingresa para continuar.");
    if (admin && auth.token?.financebroAdmin !== true)
      falla("permission-denied", "Necesitas una cuenta de administrador.");
    return identificador(auth.uid);
  }
  cuentaDisponible(snapshot, { entrada = false } = {}) {
    if (!snapshot.exists) falla("not-found", "No encontramos la cuenta.");
    const c = snapshot.data();
    if (c.estado !== "activa" && !(entrada && c.estado === "temporal"))
      falla("failed-precondition", "La cuenta todavía no está activa.");
    entero(c.saldoCentavos, "el saldo", 0, MAX_SALDO);
    return c;
  }
  nuevaCuenta(tipo, fecha) {
    const digitos =
      BigInt(`0x${randomBytes(8).toString("hex")}`) % 1000000000000n;
    const numero = `${tipo === "corriente" ? "20" : "10"}${digitos.toString().padStart(12, "0")}`;
    return {
      nombre: tipo === "corriente" ? "Cuenta corriente" : "Cuenta de ahorros",
      numero: `•••• ${numero.slice(-4)}`,
      numeroCuenta: numero,
      tipo,
      estado: "activa",
      saldoCentavos: 0,
      ...(tipo === "ahorro"
        ? { tarjetaUltimos4: numero.slice(-4), tarjetaRed: "BRO" }
        : {}),
      color: tipo === "corriente" ? "lavanda" : "durazno",
      actualizado: fecha,
    };
  }
  registrarMovimiento(tx, uid, cuenta, id, datos) {
    const movimiento = { ...datos, referencia: id, cuenta, uid };
    tx.create(
      this.cuenta(uid, cuenta).collection("movimientos").doc(id),
      movimiento,
    );
    tx.create(
      this.privado(uid, "movimientosGlobales", `${cuenta}_${id}`),
      movimiento,
    );
    const positivo = datos.centavos > 0;
    tx.create(this.privado(uid, "notificaciones", `${cuenta}_${id}`), {
      titulo: positivo ? "Recibiste fondos" : "Movimiento confirmado",
      cuerpo: `${datos.descripcion} · USD ${(Math.abs(datos.centavos) / 100).toFixed(2)}`,
      destino: `/cuentas/${cuenta}`,
      fecha: datos.fecha,
      evento: `${uid}_${cuenta}_${id}`,
    });
    tx.create(this.db.doc(`enviosPush/${uid}_${cuenta}_${id}`), {
      uid,
      cuenta,
      movimiento: id,
      titulo: positivo ? "Recibiste fondos" : "Movimiento confirmado",
      cuerpo: `${datos.descripcion} · USD ${(Math.abs(datos.centavos) / 100).toFixed(2)}`,
      destino: `/cuentas/${cuenta}`,
      estado: "pendiente",
      creado: datos.fecha,
    });
  }
  avisarCliente(tx, uid, id, titulo, cuerpo, destino, fecha = this.ahora()) {
    const evento = `${uid}_${id}`;
    tx.create(this.privado(uid, "notificaciones", id), {
      titulo,
      cuerpo,
      destino,
      fecha,
      evento,
    });
    tx.create(this.db.doc(`enviosPush/${evento}`), {
      uid,
      titulo,
      cuerpo,
      destino,
      estado: "pendiente",
      creado: fecha,
    });
  }
  async registrarCliente(auth, d) {
    const uid = this.actor(auth),
      nombres = texto(d.nombres, "tus nombres", 2, 28),
      apellidos = texto(d.apellidos, "tus apellidos", 2, 28);
    const correo = texto(d.correo, "tu correo", 5, 160).toLowerCase(),
      cedula = texto(d.cedula, "tu cédula", 10, 10);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo) || !/^\d{10}$/.test(cedula))
      falla("invalid-argument", "Revisa tu correo y tu cédula de 10 dígitos.");
    if (
      typeof auth.token?.email !== "string" ||
      auth.token.email.toLowerCase() !== correo
    )
      falla("permission-denied", "El correo debe corresponder a tu acceso.");
    if (d.aceptaContrato !== true || d.versionContrato !== "2026-10-v1")
      falla(
        "failed-precondition",
        "Lee y acepta el contrato y los términos antes de continuar.",
      );
    const domicilio = {
      direccion: texto(d.direccion, "tu dirección", 8, 180),
      ciudad: texto(d.ciudad, "tu ciudad", 2, 60),
      telefono: texto(d.telefono, "tu teléfono", 7, 20),
    };
    if (!/^[+\d ()-]+$/.test(domicilio.telefono))
      falla("invalid-argument", "Revisa tu teléfono.");
    const nombre = `${nombres} ${apellidos}`,
      fecha = this.ahora(),
      c = this.nuevaCuenta("ahorro", fecha);
    const identidadRef = this.db.doc(
      `identidadesRegistradas/${huella([cedula])}`,
    );
    return this.db.runTransaction(async (tx) => {
      const cRef = this.cuenta(uid, "ahorros"),
        tarjetaRef = this.privado(uid, "tarjetas", "bro_ahorros"),
        personalRef = this.privado(uid, "datosPersonales", "identidad");
      const [anterior, identidad, perfil, tarjeta, personal, numero] =
        await Promise.all([
          tx.get(cRef),
          tx.get(identidadRef),
          tx.get(this.usuario(uid)),
          tx.get(tarjetaRef),
          tx.get(personalRef),
          tx.get(this.db.doc(`directorioCuentas/${c.numeroCuenta}`)),
        ]);
      if (anterior.exists && personal.data()?.contratoVersion === "2026-10-v1")
        return {
          cuenta: "ahorros",
          numero: anterior.data().numeroCuenta,
          nombre: perfil.data().nombre,
        };
      if (identidad.exists && identidad.data().uid !== uid)
        falla("already-exists", "Esta cédula ya está asociada a una cuenta.");
      if (!anterior.exists && numero.exists)
        falla("aborted", "Vuelve a intentar la apertura.");
      tx.set(this.usuario(uid), {
        nombre,
        segmento: perfil.data()?.segmento ?? "equilibrio",
        mostrarSaldo: perfil.data()?.mostrarSaldo ?? true,
        actualizado: fecha,
      });
      if (!identidad.exists) tx.create(identidadRef, { uid, creado: fecha });
      tx.set(personalRef, {
        nombres,
        apellidos,
        nombre,
        correo,
        documento: cedula,
        domicilio,
        contratoVersion: "2026-10-v1",
        aceptado: fecha,
      });
      if (!anterior.exists) {
        tx.create(cRef, c);
        tx.create(this.db.doc(`directorioCuentas/${c.numeroCuenta}`), {
          uid,
          cuenta: "ahorros",
          titular: nombre,
          tipo: "ahorro",
        });
      }
      const cuenta = anterior.exists ? anterior.data() : c;
      if (!tarjeta.exists)
        tx.create(tarjetaRef, {
          tipo: "propia",
          clase: "debito",
          cuenta: "ahorros",
          nombre: "Mi tarjeta de débito",
          banco: "FinanceBro",
          ultimos4: cuenta.tarjetaUltimos4,
          color: cuenta.color,
          personalizada: false,
          actualizado: fecha,
        });
      this.avisarCliente(
        tx,
        uid,
        "bienvenida_ahorros",
        "Tu cuenta está lista",
        "Ya tienes tu cuenta de ahorros y tu tarjeta de débito digital.",
        "/tarjetas",
        fecha,
      );
      return { cuenta: "ahorros", numero: cuenta.numeroCuenta, nombre };
    });
  }
  async solicitarCredito(auth, d) {
    const uid = this.actor(auth),
      fecha = this.ahora(),
      ref = this.privado(uid, "solicitudes", "credito");
    const ingresosCentavos = entero(
        d.ingresosCentavos,
        "tus ingresos mensuales",
        100,
        100000000,
      ),
      ocupacion = texto(d.ocupacion, "tu ocupación", 2, 80);
    if (d.aceptaEvaluacion !== true)
      falla("failed-precondition", "Autoriza la revisión de tu solicitud.");
    return this.db.runTransaction(async (tx) => {
      const [cuenta, personal, anterior] = await Promise.all([
        tx.get(this.cuenta(uid, "ahorros")),
        tx.get(this.privado(uid, "datosPersonales", "identidad")),
        tx.get(ref),
      ]);
      this.cuentaDisponible(cuenta);
      if (!personal.data()?.domicilio)
        falla(
          "failed-precondition",
          "Completa tus datos y dirección antes de solicitar una tarjeta.",
        );
      if (
        anterior.exists &&
        ["revision", "preaprobada", "aprobada"].includes(anterior.data().estado)
      )
        return { id: "credito", estado: anterior.data().estado };
      tx.set(ref, {
        tipo: "credito",
        uid,
        nombre: personal.data().nombre,
        ingresosCentavos,
        ocupacion,
        estado: "revision",
        aceptado: fecha,
        actualizado: fecha,
      });
      this.avisarCliente(
        tx,
        uid,
        `credito_${randomBytes(8).toString("hex")}`,
        "Recibimos tu solicitud",
        "Un asesor revisará tu solicitud de tarjeta de crédito.",
        "/tarjetas",
        fecha,
      );
      return { id: "credito", estado: "revision" };
    });
  }
  async solicitarFisica(auth, d) {
    const uid = this.actor(auth),
      tarjeta = identificador(d.tarjeta),
      id = referencia(d.referencia),
      fecha = this.ahora();
    const envio = texto(d.fechaEnvio, "la fecha de envío", 10, 10),
      fechaMinima = fechaLocal(new Date(this.reloj().getTime() + 3 * 86400000));
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(envio) ||
      !Number.isFinite(Date.parse(`${envio}T12:00:00Z`)) ||
      new Date(`${envio}T12:00:00Z`).toISOString().slice(0, 10) !== envio ||
      envio < fechaMinima ||
      envio > fechaLocal(new Date(this.reloj().getTime() + 90 * 86400000))
    )
      falla(
        "invalid-argument",
        "Selecciona una fecha de envío al menos 3 días después de hoy.",
      );
    if (d.aceptaEnvio !== true)
      falla(
        "failed-precondition",
        "Confirma tu dirección y la solicitud de envío.",
      );
    const domicilio = {
      direccion: texto(d.direccion, "tu dirección", 8, 180),
      ciudad: texto(d.ciudad, "tu ciudad", 2, 60),
      telefono: texto(d.telefono, "tu teléfono", 7, 20),
    };
    if (!/^[+\d ()-]+$/.test(domicilio.telefono))
      falla("invalid-argument", "Revisa tu teléfono.");
    const ref = this.privado(uid, "solicitudes", `fisica_${tarjeta}`);
    return this.db.runTransaction(async (tx) => {
      const [t, p, s] = await Promise.all([
        tx.get(this.privado(uid, "tarjetas", tarjeta)),
        tx.get(this.usuario(uid)),
        tx.get(ref),
      ]);
      if (!t.exists || t.data().tipo !== "propia")
        falla(
          "failed-precondition",
          "Selecciona una tarjeta FinanceBro emitida a tu nombre.",
        );
      if (s.exists && s.data().referencia === id)
        return { id: ref.id, estado: s.data().estado };
      if (
        s.exists &&
        !["cancelada", "entregada", "rechazada"].includes(s.data().estado)
      )
        falla(
          "already-exists",
          "Ya tienes una solicitud activa para esta tarjeta.",
        );
      const personalizada = t.data().personalizada === true,
        estado = personalizada ? "revision_diseno" : "preparacion";
      tx.set(ref, {
        tipo: "fisica",
        uid,
        tarjeta,
        nombre: p.data().nombre,
        domicilio,
        fechaEnvio: envio,
        fechaMinima,
        estado,
        referencia: id,
        personalizada,
        diseno: {
          nombre: t.data().nombre,
          color: t.data().color,
          ultimos4: t.data().ultimos4,
          ...(t.data().fondoRuta ? {fondoRuta:t.data().fondoRuta} : {}),
        },
        aceptado: fecha,
        actualizado: fecha,
      });
      this.avisarCliente(
        tx,
        uid,
        `fisica_${id}`,
        "Tu tarjeta física está en camino de preparación",
        personalizada
          ? "Revisaremos tu diseño en un plazo de 3 días. Te avisaremos cuando se apruebe."
          : `Prepararemos tu tarjeta para enviarla desde el ${envio}.`,
        "/tarjetas",
        fecha,
      );
      return { id: ref.id, estado };
    });
  }
  async revisarTarjeta(auth, d) {
    const actor = this.actor(auth, true),
      uid = identificador(d.uid),
      id = identificador(d.id),
      accion = d.accion;
    const nota = texto(d.nota, "la observación", 5, 160),
      fecha = this.ahora(),
      ref = this.privado(uid, "solicitudes", id);
    return this.db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      if (!s.exists) falla("not-found", "No encontramos la solicitud.");
      const datos = s.data();
      let estado;
      let cupoCentavos;
      if (
        datos.tipo === "credito" &&
        ["revision", "preaprobada"].includes(datos.estado) &&
        ["aprobar", "rechazar"].includes(accion)
      ) {
        estado = accion === "aprobar" ? "aprobada" : "rechazada";
        if (accion === "aprobar") {
          cupoCentavos = entero(
            d.cupoCentavos,
            "el cupo de la tarjeta",
            100,
            5000000,
          );
          const tarjetaRef = this.privado(uid, "tarjetas", "bro_credito"),
            existente = await tx.get(tarjetaRef);
          if (existente.exists)
            falla(
              "already-exists",
              "La persona ya tiene una tarjeta de crédito.",
            );
          tx.create(tarjetaRef, {
            tipo: "propia",
            clase: "credito",
            uid,
            titular: datos.nombre,
            cuenta: "ahorros",
            banco: "FinanceBro",
            nombre: "Mi tarjeta de crédito",
            ultimos4: String(randomBytes(2).readUInt16BE() % 10000).padStart(
              4,
              "0",
            ),
            color: "lavanda",
            personalizada: false,
            estado: "pendiente_corte",
            cupoCentavos,
            deudaCentavos: 0,
            totalPagarCentavos: 0,
            minimoPagarCentavos: 0,
            politica: POLITICA_TARJETA,
            actualizado: fecha,
          });
        }
      } else if (datos.tipo === "fisica") {
        const pasos = {
          aprobar_diseno: ["revision_diseno", "preparacion"],
          rechazar: ["revision_diseno", "rechazada"],
          enviar: ["preparacion", "enviada"],
          entregar: ["enviada", "entregada"],
        };
        const paso = pasos[accion];
        if (!paso || datos.estado !== paso[0])
          falla(
            "failed-precondition",
            "La acción no corresponde al estado actual.",
          );
        if (accion === "enviar" && fechaLocal(this.reloj()) < datos.fechaEnvio)
          falla(
            "failed-precondition",
            "Todavía no llega la fecha de envío elegida.",
          );
        estado = paso[1];
      } else falla("failed-precondition", "La solicitud ya fue revisada.");
      tx.update(ref, {
        estado,
        nota,
        ...(cupoCentavos ? { cupoCentavos, tarjeta: "bro_credito" } : {}),
        asesor: actor,
        actualizado: fecha,
      });
      tx.create(ref.collection("revision").doc(), {
        accion,
        estado,
        nota,
        actor,
        fecha,
      });
      this.avisarCliente(
        tx,
        uid,
        `${id}_${randomBytes(8).toString("hex")}`,
        datos.tipo === "credito"
          ? estado === "aprobada"
            ? "Tu tarjeta de crédito está aprobada"
            : "Tu solicitud de tarjeta de crédito"
          : "Tu tarjeta física",
        cupoCentavos
          ? `Tu cupo es USD ${(cupoCentavos / 100).toFixed(2)}. Elige tu corte mensual para activar tu tarjeta.`
          : nota,
        datos.tipo === "credito" && estado === "aprobada"
          ? "/tarjetas/credito/detalle"
          : "/tarjetas",
        fecha,
      );
      return { id, estado };
    });
  }
  tarjetaCredito(snapshot) {
    if (
      !snapshot.exists ||
      snapshot.data().clase !== "credito" ||
      snapshot.data().tipo !== "propia"
    )
      falla("not-found", "No encontramos tu tarjeta de crédito FinanceBro.");
    return snapshot.data();
  }
  async elegirCorteTarjeta(auth, d) {
    const uid = this.actor(auth),
      dia = entero(d.dia, "el día de corte", 1, 28),
      fecha = this.ahora();
    if (d.aceptaCondiciones !== true)
      falla("failed-precondition", "Acepta las condiciones de corte y pago.");
    const ref = this.privado(uid, "tarjetas", "bro_credito");
    return this.db.runTransaction(async (tx) => {
      const t = this.tarjetaCredito(await tx.get(ref));
      if (t.estado === "activa") {
        if (t.diaCorte === dia) return { dia, proximoCorte: t.proximoCorte };
        falla(
          "failed-precondition",
          "Tu corte ya está elegido. Contacta a un asesor para cambiarlo.",
        );
      }
      const proximoCorte = siguienteCorte(fechaEcuador(this.reloj()), dia);
      tx.update(ref, {
        estado: "activa",
        diaCorte: dia,
        proximoCorte,
        condicionesAceptadas: fecha,
        actualizado: fecha,
      });
      this.avisarCliente(
        tx,
        uid,
        "credito_activada",
        "Tu tarjeta está lista",
        `Tu corte será el día ${dia} de cada mes. Cupo USD ${(t.cupoCentavos / 100).toFixed(2)}.`,
        "/tarjetas/credito/detalle",
        fecha,
      );
      return { dia, proximoCorte };
    });
  }
  async sincronizarCorte(uid) {
    const ref = this.privado(uid, "tarjetas", "bro_credito"),
      hoy = fechaEcuador(this.reloj()),
      fecha = this.ahora();
    return this.db.runTransaction(async (tx) => {
      const t = this.tarjetaCredito(await tx.get(ref));
      if (t.estado !== "activa" || t.proximoCorte > hoy) return t;
      const corte = ultimoCorte(hoy, t.diaCorte),
        minimo = pagoMinimo(t.deudaCentavos),
        pagoHasta = vencimiento(corte);
      const cambios = {
        totalPagarCentavos: t.deudaCentavos,
        minimoPagarCentavos: minimo,
        ultimoCorte: corte,
        pagoHasta,
        proximoCorte: siguienteCorte(hoy, t.diaCorte),
        actualizado: fecha,
      };
      tx.create(ref.collection("estadosCuenta").doc(corte), {
        corte,
        totalCentavos: t.deudaCentavos,
        minimoCentavos: minimo,
        pagoHasta,
        politica: t.politica,
        fecha,
      });
      tx.update(ref, cambios);
      this.avisarCliente(
        tx,
        uid,
        `corte_credito_${corte}`,
        "Tu estado de cuenta está listo",
        `Total USD ${(t.deudaCentavos / 100).toFixed(2)} · mínimo USD ${(minimo / 100).toFixed(2)} · paga hasta ${pagoHasta}.`,
        "/tarjetas/credito/detalle",
        fecha,
      );
      return { ...t, ...cambios };
    });
  }
  async consultarTarjetaCredito(auth) {
    return this.sincronizarCorte(this.actor(auth));
  }
  async procesarCortesTarjetas(auth) {
    if (auth) this.actor(auth, true);
    const hoy = fechaEcuador(this.reloj()),
      tarjetas = await this.db
        .collectionGroup("tarjetas")
        .where("clase", "==", "credito")
        .get();
    let procesados = 0;
    for (const doc of tarjetas.docs)
      if (doc.data().estado === "activa" && doc.data().proximoCorte <= hoy) {
        await this.sincronizarCorte(doc.ref.parent.parent.id);
        procesados++;
      }
    return { procesados };
  }
  async registrarConsumoTarjeta(auth, d) {
    const actor = this.actor(auth, true),
      uid = identificador(d.uid),
      id = referencia(d.referencia),
      centavos = entero(d.centavos, "el importe del consumo", 10, 5000000),
      comercio = texto(d.comercio, "el comercio", 2, 80),
      fecha = this.ahora();
    await this.sincronizarCorte(uid);
    const ref = this.privado(uid, "tarjetas", "bro_credito"),
      fingerprint = huella(["consumo_credito", uid, centavos, comercio]);
    return this.db.runTransaction(async (tx) => {
      const operacion = this.privado(uid, "operaciones", id),
        previo = await tx.get(operacion);
      if (previo.exists) {
        if (previo.data().huella !== fingerprint)
          falla("already-exists", "La referencia ya fue usada.");
        return previo.data().recibo;
      }
      const t = this.tarjetaCredito(await tx.get(ref));
      if (t.estado !== "activa")
        falla(
          "failed-precondition",
          "La persona debe elegir el corte mensual para activar su tarjeta.",
        );
      if (t.deudaCentavos + centavos > t.cupoCentavos)
        falla("failed-precondition", "El consumo supera el cupo disponible.");
      const recibo = {
        referencia: id,
        centavos,
        titular: comercio,
        tipo: "consumo_credito",
        tarjeta: "bro_credito",
        fecha: fecha.toDate().toISOString(),
      };
      const movimiento = {
        uid,
        cuenta: "tarjeta_bro_credito",
        destino: "bro_credito",
        descripcion: `Compra · ${comercio}`,
        centavos: -centavos,
        categoria: "Compras con crédito",
        tipo: "consumo_credito",
        referencia: id,
        actor,
        fecha,
      };
      tx.update(ref, {
        deudaCentavos: t.deudaCentavos + centavos,
        actualizado: fecha,
      });
      tx.create(ref.collection("movimientos").doc(id), movimiento);
      tx.create(
        this.privado(uid, "movimientosGlobales", `credito_${id}`),
        movimiento,
      );
      tx.create(operacion, { huella: fingerprint, recibo, fecha });
      this.avisarCliente(
        tx,
        uid,
        `consumo_${id}`,
        "Compra con tu tarjeta de crédito",
        `${comercio} · USD ${(centavos / 100).toFixed(2)}. Disponible USD ${((t.cupoCentavos - t.deudaCentavos - centavos) / 100).toFixed(2)}.`,
        "/tarjetas/credito/detalle",
        fecha,
      );
      return recibo;
    });
  }
  async pagarTarjetaCredito(auth, d) {
    const uid = this.actor(auth),
      cuenta = identificador(d.cuenta),
      id = referencia(d.referencia),
      importe = entero(d.centavos, "el importe del pago", 1, 5000000),
      fecha = this.ahora(),
      fingerprint = huella(["pago_credito", cuenta, importe]);
    await this.sincronizarCorte(uid);
    return this.db.runTransaction(async (tx) => {
      const operacion = this.privado(uid, "operaciones", id),
        previo = await tx.get(operacion);
      if (previo.exists) {
        if (previo.data().huella !== fingerprint)
          falla("already-exists", "La referencia ya fue usada.");
        return previo.data().recibo;
      }
      const tarjetaRef = this.privado(uid, "tarjetas", "bro_credito"),
        cuentaRef = this.cuenta(uid, cuenta);
      const [ts, cs] = await Promise.all([
          tx.get(tarjetaRef),
          tx.get(cuentaRef),
        ]),
        t = this.tarjetaCredito(ts),
        c = this.cuentaDisponible(cs);
      if (importe > t.deudaCentavos)
        falla(
          "failed-precondition",
          "El pago no puede superar lo que debes en tu tarjeta.",
        );
      if (c.saldoCentavos < importe)
        falla("failed-precondition", "No tienes fondos suficientes.");
      const recibo = {
        referencia: id,
        cuenta,
        centavos: importe,
        titular: t.nombre,
        tipo: "pago_credito",
        destino: "bro_credito",
        fecha: fecha.toDate().toISOString(),
      };
      tx.update(cuentaRef, {
        saldoCentavos: c.saldoCentavos - importe,
        actualizado: fecha,
      });
      tx.update(tarjetaRef, {
        deudaCentavos: t.deudaCentavos - importe,
        totalPagarCentavos: Math.max(0, t.totalPagarCentavos - importe),
        minimoPagarCentavos: Math.max(0, t.minimoPagarCentavos - importe),
        actualizado: fecha,
      });
      this.registrarMovimiento(tx, uid, cuenta, id, {
        descripcion: `Pago · ${t.nombre}`,
        centavos: -importe,
        categoria: "Pago de tarjeta",
        tipo: "pago_credito",
        destino: "bro_credito",
        actor: uid,
        fecha,
      });
      // En la tarjeta el abono es positivo; en la cuenta y el histórico global es una única salida.
      tx.create(tarjetaRef.collection("movimientos").doc(id), {
        descripcion: `Pago desde ${c.nombre}`,
        centavos: importe,
        categoria: "Pago de tarjeta",
        tipo: "pago_credito",
        cuenta,
        referencia: id,
        uid,
        actor: uid,
        fecha,
      });
      tx.create(operacion, { huella: fingerprint, recibo, fecha });
      return recibo;
    });
  }
  async abrirAhorros(auth, d) {
    const uid = this.actor(auth),
      nombre = texto(d.nombre, "tu nombre", 2, 60);
    const telefono = texto(d.telefono, "tu teléfono", 7, 20),
      documento = texto(d.documento, "tu identificación", 6, 20);
    if (!/^[+\d ()-]+$/.test(telefono) || !/^[a-zA-Z0-9-]+$/.test(documento))
      falla("invalid-argument", "Revisa tus datos de identificación.");
    if (
      typeof d.nacimiento !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(d.nacimiento)
    )
      falla("invalid-argument", "Indica tu fecha de nacimiento.");
    const nacimiento = new Date(`${d.nacimiento}T12:00:00Z`);
    if (
      !Number.isFinite(nacimiento.getTime()) ||
      nacimiento.toISOString().slice(0, 10) !== d.nacimiento
    )
      falla("invalid-argument", "La fecha de nacimiento no es válida.");
    const hoy = fechaLocal(this.reloj()),
      limite = `${Number(hoy.slice(0, 4)) - 18}${hoy.slice(4)}`;
    if (d.nacimiento > limite || d.nacimiento < "1900-01-01")
      falla("failed-precondition", "La apertura requiere ser mayor de edad.");
    if (d.aceptaTerminos !== true)
      falla(
        "failed-precondition",
        "Acepta el contrato y los términos de la cuenta.",
      );
    const fecha = this.ahora(),
      c = this.nuevaCuenta("ahorro", fecha);
    return this.db.runTransaction(async (tx) => {
      const destino = this.cuenta(uid, "ahorros"),
        existente = await tx.get(destino);
      if (existente.exists)
        return { cuenta: "ahorros", numero: existente.data().numeroCuenta };
      const directorio = this.db.doc(`directorioCuentas/${c.numeroCuenta}`),
        ocupado = await tx.get(directorio),
        perfil = await tx.get(this.usuario(uid));
      if (ocupado.exists) falla("aborted", "Vuelve a intentar la apertura.");
      if (!perfil.exists)
        falla(
          "failed-precondition",
          "Completa tu perfil antes de abrir una cuenta.",
        );
      tx.create(destino, c);
      tx.create(this.privado(uid, "tarjetas", "bro_ahorros"), {
        tipo: "propia",
        clase: "debito",
        personalizada: false,
        cuenta: "ahorros",
        nombre: "Mi FinanceBro",
        banco: "FinanceBro",
        ultimos4: c.tarjetaUltimos4,
        color: c.color,
        actualizado: fecha,
      });
      tx.create(directorio, {
        uid,
        cuenta: "ahorros",
        titular: nombre,
        tipo: "ahorro",
      });
      tx.set(this.privado(uid, "datosPersonales", "identidad"), {
        nombre,
        telefono,
        documento,
        nacimiento: d.nacimiento,
        terminos: "demostracion-2026-10",
        aceptado: fecha,
      });
      return { cuenta: "ahorros", numero: c.numeroCuenta };
    });
  }
  async migrarCuentas(auth, d) {
    this.actor(auth, true);
    const uid = identificador(d.uid);
    const perfil = await this.usuario(uid).get();
    if (!perfil.exists) falla("not-found", "No encontramos a la persona.");
    const cuentas = await this.usuario(uid).collection("cuentas").get();
    for (const snapshot of cuentas.docs) {
      const propuesta = this.nuevaCuenta("ahorro", this.ahora());
      await this.db.runTransaction(async (tx) => {
        const actual = await tx.get(snapshot.ref);
        if (!actual.exists) return;
        const anterior = actual.data();
        const numero = anterior.numeroCuenta ?? propuesta.numeroCuenta;
        const tipo = anterior.tipo ?? propuesta.tipo;
        const directorio = this.db.doc(`directorioCuentas/${numero}`);
        const ocupado = await tx.get(directorio);
        const tarjetaRef = this.privado(uid, "tarjetas", `bro_${snapshot.id}`);
        const tarjeta = await tx.get(tarjetaRef);
        if (
          ocupado.exists &&
          (ocupado.data().uid !== uid || ocupado.data().cuenta !== snapshot.id)
        ) {
          falla("aborted", "Reintenta la preparación.");
        }
        if (!anterior.numeroCuenta)
          tx.update(snapshot.ref, {
            numeroCuenta: numero,
            tipo,
            estado: "activa",
            color: anterior.color ?? propuesta.color,
          });
        if (!ocupado.exists)
          tx.create(directorio, {
            uid,
            cuenta: snapshot.id,
            titular: perfil.data().nombre,
            tipo,
          });
        if (!tarjeta.exists && tipo !== "corriente" && anterior.tarjetaUltimos4)
          tx.create(tarjetaRef, {
            tipo: "propia",
            cuenta: snapshot.id,
            nombre: anterior.nombre,
            banco: "FinanceBro",
            ultimos4: anterior.tarjetaUltimos4,
            color: anterior.color ?? propuesta.color,
            actualizado: this.ahora(),
          });
      });
      // Una interrupción puede dejar páginas pendientes; reintentar completa
      // el histórico sin reemplazar registros existentes ni resetear saldos.
      const historial = await snapshot.ref.collection("movimientos").get();
      for (const m of historial.docs) {
        try {
          await this.privado(
            uid,
            "movimientosGlobales",
            `${snapshot.id}_${m.id}`,
          ).create({
            ...m.data(),
            referencia: m.data().referencia ?? m.id,
            uid,
            cuenta: snapshot.id,
          });
        } catch (error) {
          if (error.code !== 6 && error.code !== "already-exists") throw error;
        }
      }
    }
    return { preparadas: cuentas.size };
  }
  async destinatario(auth, d) {
    this.actor(auth);
    const numero = numeroCuenta(d.numero);
    const entrada = await this.db.doc(`directorioCuentas/${numero}`).get();
    if (!entrada.exists)
      falla("not-found", "No encontramos esa cuenta de FinanceBro.");
    const titular = entrada.data(),
      c = this.cuentaDisponible(
        await this.cuenta(titular.uid, titular.cuenta).get(),
        { entrada: true },
      );
    return { numero, titular: titular.titular, tipo: c.tipo, estado: c.estado };
  }
  async transferir(auth, d) {
    const uid = this.actor(auth),
      cuenta = identificador(d.cuenta),
      numero = numeroCuenta(d.numero),
      id = referencia(d.referencia);
    const importe = entero(
        d.centavos,
        "el monto (USD 0,10 a USD 100)",
        10,
        10000,
      ),
      nota = texto(d.nota || "Transferencia FinanceBro", "el concepto", 2, 100);
    const fingerprint = huella([uid, cuenta, numero, importe, nota]),
      fecha = this.ahora(),
      reciboRef = this.privado(uid, "operaciones", id);
    return this.db.runTransaction(async (tx) => {
      const anterior = await tx.get(reciboRef);
      if (anterior.exists) {
        if (anterior.data().huella !== fingerprint)
          falla(
            "already-exists",
            "La referencia corresponde a otra operación.",
          );
        return anterior.data().recibo;
      }
      const entrada = await tx.get(this.db.doc(`directorioCuentas/${numero}`));
      if (!entrada.exists)
        falla("not-found", "No encontramos la cuenta de destino.");
      const receptor = entrada.data();
      if (uid === receptor.uid && cuenta === receptor.cuenta)
        falla("invalid-argument", "Elige una cuenta diferente como destino.");
      const origenRef = this.cuenta(uid, cuenta),
        destinoRef = this.cuenta(receptor.uid, receptor.cuenta);
      const origen = this.cuentaDisponible(await tx.get(origenRef)),
        destino = this.cuentaDisponible(await tx.get(destinoRef), {
          entrada: true,
        });
      const perfil = await tx.get(this.usuario(uid));
      if (origen.saldoCentavos < importe)
        falla(
          "failed-precondition",
          "No tienes fondos suficientes en esa cuenta.",
        );
      if (destino.saldoCentavos + importe > MAX_SALDO)
        falla("failed-precondition", "El destino supera el saldo permitido.");
      const idCredito = `rec_${huella([uid, id]).slice(0, 40)}`,
        recibo = {
          referencia: id,
          cuenta,
          numero,
          titular: receptor.titular,
          centavos: importe,
          fecha: fecha.toDate().toISOString(),
          tipo: "transferencia",
        };
      tx.update(origenRef, {
        saldoCentavos: origen.saldoCentavos - importe,
        ultimoMovimiento: id,
        actualizado: fecha,
      });
      tx.update(destinoRef, {
        saldoCentavos: destino.saldoCentavos + importe,
        ultimoMovimiento: idCredito,
        actualizado: fecha,
      });
      this.registrarMovimiento(tx, uid, cuenta, id, {
        descripcion: `Transferencia a ${receptor.titular}`,
        centavos: -importe,
        categoria: "Transferencias",
        tipo: "transferencia",
        actor: uid,
        numeroDestino: numero,
        nota,
        fecha,
      });
      this.registrarMovimiento(tx, receptor.uid, receptor.cuenta, idCredito, {
        descripcion: `Transferencia de ${perfil.data()?.nombre ?? "FinanceBro"}`,
        centavos: importe,
        categoria: "Transferencias",
        tipo: "transferencia",
        actor: uid,
        numeroOrigen: origen.numeroCuenta,
        nota,
        fecha,
      });
      tx.create(reciboRef, { huella: fingerprint, recibo, fecha });
      return recibo;
    });
  }
  async ajustar(auth, d) {
    const actor = this.actor(auth, true),
      uid = identificador(d.uid),
      cuenta = identificador(d.cuenta),
      id = referencia(d.referencia);
    const delta = entero(d.centavos, "el ajuste", -MAX_SALDO, MAX_SALDO);
    if (!delta) falla("invalid-argument", "El ajuste debe cambiar el saldo.");
    const motivo = texto(d.motivo, "el motivo", 5, 120),
      fingerprint = huella([actor, uid, cuenta, delta, motivo]),
      fecha = this.ahora();
    return this.db.runTransaction(async (tx) => {
      const recibo = this.db.doc(`ajustes/${id}`),
        previo = await tx.get(recibo);
      if (previo.exists) {
        if (previo.data().huella !== fingerprint)
          falla("already-exists", "Esa referencia ya fue usada.");
        return previo.data().resultado;
      }
      const ref = this.cuenta(uid, cuenta),
        actual = this.cuentaDisponible(await tx.get(ref), {
          entrada: delta > 0,
        });
      const saldo = actual.saldoCentavos + delta;
      if (saldo < 0 || saldo > MAX_SALDO)
        falla("failed-precondition", "El ajuste excede el saldo permitido.");
      const resultado = { referencia: id, saldoCentavos: saldo };
      tx.update(ref, {
        saldoCentavos: saldo,
        actualizado: fecha,
        ultimoMovimiento: id,
      });
      this.registrarMovimiento(tx, uid, cuenta, id, {
        descripcion: `Ajuste de fondos · ${motivo}`,
        centavos: delta,
        categoria: "Ajuste de fondos",
        tipo: "ajuste",
        actor,
        motivo,
        fecha,
      });
      tx.create(recibo, { huella: fingerprint, resultado, fecha });
      return resultado;
    });
  }
  async guardarContacto(auth, d) {
    const uid = this.actor(auth),
      id = d.id ? identificador(d.id) : randomBytes(12).toString("hex");
    let contacto;
    if (d.tipo === "interno") {
      const receptor = await this.destinatario(auth, d);
      contacto = {
        tipo: "interno",
        nombre: receptor.titular,
        numero: receptor.numero,
        banco: "FinanceBro",
      };
    } else if (d.tipo === "externo")
      contacto = {
        tipo: "externo",
        nombre: texto(d.nombre, "el nombre", 2, 60),
        numero: texto(d.numero, "el número de cuenta", 6, 30),
        banco: texto(d.banco, "el banco", 2, 60),
        documento: texto(d.documento, "la identificación", 6, 20),
      };
    else falla("invalid-argument", "Elige el tipo de contacto.");
    await this.privado(uid, "contactos", id).set({
      ...contacto,
      actualizado: this.ahora(),
    });
    return { id, ...contacto };
  }
  async guardarTarjeta(auth, d) {
    const uid = this.actor(auth),
      id = d.id ? identificador(d.id) : randomBytes(12).toString("hex"),
      color = d.color ?? "durazno",
      nombre = texto(d.nombre, "el nombre", 2, 40),
      fecha = this.ahora();
    if (!COLORES.includes(color))
      falla("invalid-argument", "Selecciona un color disponible.");
    const ref = this.privado(uid, "tarjetas", id);
    if (d.tipo === "propia") {
      if(d.fondoRuta != null) {
        const ruta=texto(d.fondoRuta,"el fondo de tarjeta",10,240);
        if(!new RegExp(`^tarjetas/${uid}/${id}/fondos/[a-zA-Z0-9_-]{8,80}\\.(png|jpg)$`).test(ruta)) falla("permission-denied","El fondo debe pertenecer a esta tarjeta.");
        if(!this.bucket) falla("unavailable","No pudimos guardar el fondo. Vuelve a intentarlo.");
        const [m]=await this.bucket.file(ruta).getMetadata();
        if(!['image/png','image/jpeg'].includes(m.contentType) || Number(m.size)<=0 || Number(m.size)>2*1024*1024) falla("invalid-argument","El fondo debe ser PNG o JPG de hasta 2 MB.");
      }
      if (!d.id)
        falla(
          "failed-precondition",
          "Tu tarjeta FinanceBro se emite al abrir ahorros o al aprobar tu solicitud de crédito.",
        );
      return this.db.runTransaction(async (tx) => {
        const anterior = await tx.get(ref);
        if (!anterior.exists || anterior.data().tipo !== "propia")
          falla("not-found", "No encontramos tu tarjeta FinanceBro.");
        const t = anterior.data(),
          c = this.cuentaDisponible(
            await tx.get(this.cuenta(uid, identificador(t.cuenta))),
          );
        if (c.tipo === "corriente")
          falla(
            "failed-precondition",
            "Esta cuenta no emite una tarjeta automáticamente.",
          );
        // Cambiar el diseño nunca reescribe deuda, cupo ni corte leídos antes de un pago concurrente.
        const cambios = {
          nombre,
          color,
          personalizada: true,
          ...(Object.hasOwn(d,'fondoRuta') ? {fondoRuta: d.fondoRuta ?? null} : {}),
          actualizado: fecha,
        };
        tx.update(ref, cambios);
        return { id, ...t, ...cambios };
      });
    }
    if (d.tipo !== "externa")
      falla("invalid-argument", "Revisa el tipo de tarjeta.");
    if (typeof d.ultimos4 !== "string" || !/^\d{4}$/.test(d.ultimos4))
      falla("invalid-argument", "Ingresa solo los últimos cuatro dígitos.");
    const tarjeta = {
      tipo: "externa",
      nombre,
      banco: texto(d.banco, "el banco", 2, 60),
      ultimos4: d.ultimos4,
      color,
      actualizado: fecha,
    };
    return this.db.runTransaction(async (tx) => {
      const anterior = await tx.get(ref);
      if (anterior.exists && anterior.data().tipo === "propia")
        falla(
          "failed-precondition",
          "Una tarjeta FinanceBro no se puede convertir en una tarjeta externa.",
        );
      tx.set(ref, tarjeta);
      return { id, ...tarjeta };
    });
  }
  async pagarExterno(auth, d) {
    const uid = this.actor(auth),
      cuenta = identificador(d.cuenta),
      id = referencia(d.referencia),
      destino = identificador(d.destino),
      tipo = d.tipo;
    if (!["tarjeta", "contacto"].includes(tipo))
      falla("invalid-argument", "Revisa el destino del pago.");
    const importe = entero(d.centavos, "el monto", 10, 10000),
      fecha = this.ahora(),
      fingerprint = huella([cuenta, destino, tipo, importe]);
    return this.db.runTransaction(async (tx) => {
      const refRecibo = this.privado(uid, "operaciones", id),
        previo = await tx.get(refRecibo);
      if (previo.exists) {
        if (previo.data().huella !== fingerprint)
          falla("already-exists", "La referencia ya fue usada.");
        return previo.data().recibo;
      }
      const entidad = await tx.get(
        this.privado(
          uid,
          tipo === "tarjeta" ? "tarjetas" : "contactos",
          destino,
        ),
      );
      if (
        !entidad.exists ||
        !["externa", "externo"].includes(entidad.data().tipo)
      )
        falla(
          "failed-precondition",
          "Este pago requiere un destino externo registrado.",
        );
      const ref = this.cuenta(uid, cuenta),
        c = this.cuentaDisponible(await tx.get(ref));
      if (c.saldoCentavos < importe)
        falla("failed-precondition", "No tienes fondos suficientes.");
      const recibo = {
        referencia: id,
        cuenta,
        centavos: importe,
        titular: entidad.data().nombre,
        tipo,
        destino,
        fecha: fecha.toDate().toISOString(),
        simulado: true,
      };
      const movimiento = {
        descripcion: `Pago · ${entidad.data().nombre}`,
        centavos: -importe,
        categoria: tipo === "tarjeta" ? "Tarjetas" : "Transferencias externas",
        tipo,
        destino,
        actor: uid,
        fecha,
        simulado: true,
      };
      tx.update(ref, {
        saldoCentavos: c.saldoCentavos - importe,
        actualizado: fecha,
        ultimoMovimiento: id,
      });
      this.registrarMovimiento(tx, uid, cuenta, id, movimiento);
      tx.create(
        this.privado(
          uid,
          tipo === "tarjeta" ? "tarjetas" : "contactos",
          destino,
        )
          .collection("movimientos")
          .doc(id),
        movimiento,
      );
      tx.create(refRecibo, { huella: fingerprint, recibo, fecha });
      return recibo;
    });
  }
  async guardarSolicitud(auth, d) {
    const uid = this.actor(auth);
    const datos = {
      empresa: texto(d.empresa, "la razón social", 2, 100),
      ruc: texto(d.ruc, "el RUC", 13, 13),
      representante: texto(d.representante, "el representante", 2, 60),
      escala: d.escala,
    };
    if (
      !/^\d{13}$/.test(datos.ruc) ||
      !["pyme", "empresa"].includes(datos.escala)
    )
      falla("invalid-argument", "Revisa el RUC y el tipo de empresa.");
    return this.db.runTransaction(async (tx) => {
      const ref = this.privado(uid, "solicitudes", "corriente"),
        previo = await tx.get(ref);
      if (
        previo.exists &&
        !["borrador", "correcciones"].includes(previo.data().estado)
      )
        falla("failed-precondition", "La solicitud ya está en revisión.");
      tx.set(
        ref,
        {
          ...datos,
          uid,
          estado: "borrador",
          actualizado: this.ahora(),
          documentos: previo.data()?.documentos ?? {},
        },
        { merge: true },
      );
      return { id: "corriente", estado: "borrador" };
    });
  }
  async registrarDocumento(auth, d) {
    const uid = this.actor(auth),
      categoria = d.categoria;
    if (
      !DOCUMENTOS.includes(categoria) ||
      typeof d.ruta !== "string" ||
      !new RegExp(
        `^expedientes/${uid}/corriente/${categoria}/[a-zA-Z0-9_-]{8,80}\\.(pdf|png|jpg)$`,
      ).test(d.ruta)
    )
      falla("invalid-argument", "El documento no corresponde a tu solicitud.");
    if (!this.bucket)
      falla("unavailable", "El almacenamiento aún no está disponible.");
    const archivo = this.bucket.file(d.ruta);
    let metadatos;
    try {
      [metadatos] = await archivo.getMetadata();
    } catch {
      falla("not-found", "Primero sube el documento.");
    }
    if (
      Number(metadatos.size) > 5 * 1024 * 1024 ||
      !["application/pdf", "image/png", "image/jpeg"].includes(
        metadatos.contentType,
      )
    )
      falla("invalid-argument", "Usa PDF, PNG o JPG de hasta 5 MB.");
    const [inicio] = await archivo.download({ start: 0, end: 7 });
    const firmaValida =
      metadatos.contentType === "application/pdf"
        ? inicio.subarray(0, 5).toString() === "%PDF-"
        : metadatos.contentType === "image/png"
          ? inicio
              .subarray(0, 8)
              .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
          : inicio[0] === 255 && inicio[1] === 216 && inicio[2] === 255;
    if (!firmaValida)
      falla(
        "invalid-argument",
        "El contenido no corresponde al tipo de archivo.",
      );
    await this.db.runTransaction(async (tx) => {
      const ref = this.privado(uid, "solicitudes", "corriente"),
        s = await tx.get(ref);
      if (!s.exists || !["borrador", "correcciones"].includes(s.data().estado))
        falla(
          "failed-precondition",
          "La solicitud no admite cambios en este momento.",
        );
      tx.update(ref, {
        [`documentos.${categoria}`]: {
          ruta: d.ruta,
          nombre: texto(d.nombre, "el nombre del archivo", 1, 120),
          bytes: Number(metadatos.size),
          tipo: metadatos.contentType,
          actualizado: this.ahora(),
        },
        actualizado: this.ahora(),
      });
    });
    return { categoria, guardado: true };
  }
  async enviarSolicitud(auth, d = {}) {
    const uid = this.actor(auth);
    if (d.acepta !== true)
      falla(
        "failed-precondition",
        "Autoriza la revisión de tus documentos antes de enviar.",
      );
    return this.db.runTransaction(async (tx) => {
      const ref = this.privado(uid, "solicitudes", "corriente"),
        s = await tx.get(ref);
      if (!s.exists) falla("not-found", "Guarda los datos de tu empresa.");
      if (!["borrador", "correcciones"].includes(s.data().estado))
        falla("failed-precondition", "La solicitud ya fue enviada.");
      if (!DOCUMENTOS.every((k) => s.data().documentos?.[k]?.ruta))
        falla(
          "failed-precondition",
          "Completa todos los documentos antes de enviar.",
        );
      tx.update(ref, {
        estado: "revision",
        consentimiento: this.ahora(),
        enviado: this.ahora(),
        actualizado: this.ahora(),
      });
      return { estado: "revision" };
    });
  }
  async revisarSolicitud(auth, d) {
    const actor = this.actor(auth, true),
      uid = identificador(d.uid),
      accion = d.accion,
      nota = texto(d.nota, "la observación", 5, 200),
      fecha = this.ahora();
    if (!["aprobar", "corregir", "activar"].includes(accion))
      falla("invalid-argument", "Revisa la acción.");
    if (actor === uid)
      falla("permission-denied", "Otro asesor debe revisar tu solicitud.");
    const nueva = this.nuevaCuenta("corriente", fecha);
    return this.db.runTransaction(async (tx) => {
      const solicitudRef = this.privado(uid, "solicitudes", "corriente"),
        s = await tx.get(solicitudRef);
      if (!s.exists) falla("not-found", "No encontramos la solicitud.");
      const cRef = this.cuenta(uid, "corriente"),
        c = await tx.get(cRef),
        directorio = this.db.doc(`directorioCuentas/${nueva.numeroCuenta}`),
        ocupado = await tx.get(directorio);
      if (accion === "activar") {
        if (
          s.data().estado !== "deposito" ||
          !c.exists ||
          c.data().estado !== "temporal"
        )
          falla(
            "failed-precondition",
            "La cuenta todavía no espera un depósito.",
          );
        if (c.data().saldoCentavos < s.data().depositoCentavos)
          falla(
            "failed-precondition",
            "El depósito inicial todavía está incompleto.",
          );
        tx.update(cRef, {
          estado: "activa",
          activado: fecha,
          actualizado: fecha,
        });
        tx.update(solicitudRef, {
          estado: "activa",
          asesor: actor,
          nota,
          actualizado: fecha,
        });
      } else {
        if (s.data().estado !== "revision")
          falla("failed-precondition", "Solo se revisan solicitudes enviadas.");
        if (accion === "aprobar") {
          if (c.exists || ocupado.exists)
            falla("already-exists", "La cuenta ya existe.");
          const depositoCentavos = s.data().escala === "pyme" ? 100000 : 200000;
          tx.create(cRef, { ...nueva, estado: "temporal", depositoCentavos });
          tx.create(directorio, {
            uid,
            cuenta: "corriente",
            titular: s.data().empresa,
            tipo: "corriente",
          });
          tx.update(solicitudRef, {
            estado: "deposito",
            numeroCuenta: nueva.numeroCuenta,
            depositoCentavos,
            asesor: actor,
            nota,
            actualizado: fecha,
          });
        } else
          tx.update(solicitudRef, {
            estado: "correcciones",
            asesor: actor,
            nota,
            actualizado: fecha,
          });
      }
      tx.create(solicitudRef.collection("revision").doc(), {
        accion,
        actor,
        nota,
        fecha,
      });
      tx.create(
        this.privado(
          uid,
          "notificaciones",
          `solicitud_${randomBytes(8).toString("hex")}`,
        ),
        {
          titulo: "Tu cuenta corriente",
          cuerpo: nota,
          destino: "/apertura/corriente",
          fecha,
        },
      );
      return {
        estado:
          accion === "activar"
            ? "activa"
            : accion === "aprobar"
              ? "deposito"
              : "correcciones",
      };
    });
  }
  async guardarDecoracion(auth,d) {
    const actor=this.actor(auth,true);
    if(typeof d.activa!=='boolean' || !['habitual','navidad','aniversario'].includes(d.tema)) falla('invalid-argument','Revisa el tema y su disponibilidad.');
    function fecha(v) {
      if(typeof v!=='string' || !/^\d{4}-\d{2}-\d{2}$/.test(v) || !Number.isFinite(Date.parse(`${v}T05:00:00Z`)) || new Date(`${v}T05:00:00Z`).toISOString().slice(0,10)!==v) falla('invalid-argument','Revisa las fechas de la temporada.');
      return v;
    }
    const desde=fecha(d.desde),hasta=fecha(d.hasta);
    if(hasta<desde || Date.parse(hasta)-Date.parse(desde)>90*86400000) falla('invalid-argument','La temporada admite hasta 90 días.');
    const configuracion={activa:d.activa,tema:d.tema,desde,hasta,titulo:texto(d.titulo,'el saludo de temporada',2,60),mensaje:texto(d.mensaje,'el mensaje de temporada',2,140),actor,actualizado:this.ahora()};
    await this.db.doc('experiencias/decoracion').set(configuracion);
    return {guardada:true};
  }
  async guardarServicio(auth, d) {
    const actor = this.actor(auth, true),
      id = identificador(d.id);
    if (!["luz", "agua", "internet", "telefono"].includes(d.icono))
      falla("invalid-argument", "Selecciona un icono disponible.");
    if (typeof d.activo !== "boolean")
      falla("invalid-argument", "Revisa la disponibilidad.");
    const servicio = {
      nombre: texto(d.nombre, "el nombre", 2, 60),
      icono: d.icono,
      activo: d.activo,
      baseCentavos: entero(d.baseCentavos, "el valor base", 10, 100000),
      proveedor: "demostracion",
      visibleEnApp: d.visibleEnApp !== false,
      actor,
      actualizado: this.ahora(),
    };
    await this.db.doc(`servicios/${id}`).set(servicio);
    return { id, ...servicio, actualizado: undefined };
  }
  async consultarFactura(auth, d) {
    this.actor(auth);
    return this.obtenerFactura(
      identificador(d.servicio),
      texto(d.contrato, "el contrato", 4, 30),
    );
  }
  async obtenerFactura(servicio, contrato) {
    if (!/^[a-zA-Z0-9-]{4,30}$/.test(contrato))
      falla("invalid-argument", "Revisa el código de contrato.");
    const per = periodo(this.reloj()),
      id = huella([servicio, contrato, per]),
      ref = this.db.doc(`facturas/${id}`);
    const resultado = await this.db.runTransaction(async (tx) => {
      const s = await tx.get(this.db.doc(`servicios/${servicio}`)),
        factura = await tx.get(ref);
      if (!s.exists || s.data().activo !== true)
        falla("failed-precondition", "Este servicio no está disponible.");
      if (factura.exists) return factura.data();
      // Proveedor sintético: cambia el valor por contrato y mes sin consultar una empresa real.
      const variacion =
        parseInt(huella([contrato, per]).slice(0, 6), 16) % 1500;
      const f = {
        servicio,
        contrato,
        periodo: per,
        centavos: s.data().baseCentavos + variacion,
        nombre: s.data().nombre,
        estado: "pendiente",
        simulado: true,
        creado: this.ahora(),
      };
      tx.create(ref, f);
      return f;
    });
    return {
      id,
      servicio,
      contrato,
      periodo: per,
      centavos: resultado.centavos,
      nombre: resultado.nombre,
      estado: resultado.estado,
      simulado: true,
    };
  }
  async pagarServicio(auth, d) {
    const uid = this.actor(auth),
      cuenta = identificador(d.cuenta),
      factura = identificador(d.factura),
      id = referencia(d.referencia),
      fecha = this.ahora(),
      fingerprint = huella([cuenta, factura]);
    return this.db.runTransaction(async (tx) => {
      const operacion = this.privado(uid, "operaciones", id),
        anterior = await tx.get(operacion);
      if (anterior.exists) {
        if (anterior.data().huella !== fingerprint)
          falla("already-exists", "La referencia ya fue usada.");
        return anterior.data().recibo;
      }
      const fRef = this.db.doc(`facturas/${factura}`),
        f = await tx.get(fRef);
      if (!f.exists)
        falla("not-found", "Consulta el valor de la planilla antes de pagar.");
      const servicio = await tx.get(
          this.db.doc(`servicios/${f.data().servicio}`),
        ),
        ref = this.cuenta(uid, cuenta),
        c = this.cuentaDisponible(await tx.get(ref));
      if (d.autopago) {
        const a = await tx.get(this.db.doc(d.autopago));
        if (!a.exists || !a.data().activo || a.data().uid !== uid)
          falla("failed-precondition", "El pago mensual fue pausado.");
        if (f.data().centavos > a.data().maximoCentavos)
          falla(
            "failed-precondition",
            "El valor supera el límite mensual autorizado.",
          );
      }
      if (!servicio.exists || !servicio.data().activo)
        falla("failed-precondition", "El servicio fue deshabilitado.");
      if (f.data().periodo !== periodo(this.reloj()))
        falla("failed-precondition", "Consulta la planilla del mes actual.");
      if (f.data().estado === "pagada")
        falla("already-exists", "Esta planilla ya fue pagada.");
      const importe = entero(f.data().centavos, "el monto", 10, 101500);
      if (d.maximoCentavos !== undefined && importe > d.maximoCentavos)
        falla(
          "failed-precondition",
          "El valor supera el límite mensual autorizado.",
        );
      if (c.saldoCentavos < importe)
        falla(
          "failed-precondition",
          "No tienes fondos suficientes para pagar la planilla.",
        );
      const recibo = {
        referencia: id,
        cuenta,
        centavos: importe,
        titular: f.data().nombre,
        servicio: f.data().servicio,
        contrato: f.data().contrato,
        periodo: f.data().periodo,
        factura,
        tipo: "servicio",
        simulado: true,
        fecha: fecha.toDate().toISOString(),
      };
      tx.update(ref, {
        saldoCentavos: c.saldoCentavos - importe,
        actualizado: fecha,
        ultimoMovimiento: id,
      });
      this.registrarMovimiento(tx, uid, cuenta, id, {
        descripcion: `Pago · ${f.data().nombre}`,
        centavos: -importe,
        categoria: "Servicios",
        tipo: "servicio",
        actor: uid,
        servicio: f.data().servicio,
        contrato: f.data().contrato,
        periodo: f.data().periodo,
        automatico: d.automatico === true,
        simulado: true,
        fecha,
      });
      tx.update(fRef, { estado: "pagada", uid, referencia: id, pagada: fecha });
      tx.create(operacion, { huella: fingerprint, recibo, fecha });
      return recibo;
    });
  }
  async configurarAutopago(auth, d) {
    const uid = this.actor(auth),
      recibo = await this.privado(
        uid,
        "operaciones",
        referencia(d.referencia),
      ).get();
    if (!recibo.exists || recibo.data().recibo.tipo !== "servicio")
      falla("failed-precondition", "Primero realiza el pago de una planilla.");
    if (d.acepta !== true)
      falla("failed-precondition", "Autoriza expresamente el pago mensual.");
    const maximoCentavos = entero(
        d.maximoCentavos,
        "el límite mensual",
        10,
        101500,
      ),
      dia = entero(d.dia, "el día del mes", 1, 28),
      r = recibo.data().recibo;
    const id = huella([r.servicio, r.contrato]).slice(0, 40);
    await this.privado(uid, "autopagos", id).set(
      {
        uid,
        servicio: r.servicio,
        contrato: r.contrato,
        cuenta: r.cuenta,
        nombre: r.titular,
        maximoCentavos,
        dia,
        activo: true,
        siguiente: proximoMes(this.reloj(), dia),
        consentimiento: this.ahora(),
        actualizado: this.ahora(),
      },
      { merge: true },
    );
    return { id };
  }
  async pausarAutopago(auth, d) {
    const uid = this.actor(auth),
      ref = this.privado(uid, "autopagos", identificador(d.id));
    if (!(await ref.get()).exists)
      falla("not-found", "No encontramos el pago mensual.");
    await ref.update({ activo: false, actualizado: this.ahora() });
    return { pausado: true };
  }
  async procesarAutopagos() {
    const hoy = fechaLocal(this.reloj()),
      docs = await this.db
        .collectionGroup("autopagos")
        .where("activo", "==", true)
        .where("siguiente", "<=", hoy)
        .limit(100)
        .get();
    let procesados = 0;
    for (const doc of docs.docs) {
      const a = doc.data(),
        per = periodo(this.reloj()),
        intento = doc.ref.collection("intentos").doc(per);
      const tomado = await this.db.runTransaction(async (tx) => {
        const actual = await tx.get(doc.ref),
          previo = await tx.get(intento);
        if (
          !actual.data()?.activo ||
          (previo.exists &&
            (previo.data().estado !== "procesando" ||
              previo.data().fecha.toMillis() >
                this.ahora().toMillis() - 300000))
        )
          return false;
        tx.set(intento, { estado: "procesando", fecha: this.ahora() });
        return true;
      });
      if (!tomado) continue;
      let estado = "pagado",
        mensaje = "Pago mensual completado";
      try {
        const f = await this.obtenerFactura(a.servicio, a.contrato);
        await this.pagarServicio(
          { uid: a.uid },
          {
            cuenta: a.cuenta,
            factura: f.id,
            referencia: `auto_${doc.id}_${per}`,
            maximoCentavos: a.maximoCentavos,
            automatico: true,
            autopago: doc.ref.path,
          },
        );
      } catch (error) {
        if (!(error instanceof FalloBanco)) {
          // Las interrupciones técnicas se reintentan; la referencia del pago evita un segundo débito.
          await intento.delete();
          throw error;
        }
        estado = "requiere_atencion";
        mensaje = error.message;
        await this.privado(
          a.uid,
          "notificaciones",
          `auto_${doc.id}_${per}`,
        ).set({
          titulo: "Revisa tu pago mensual",
          cuerpo: mensaje,
          destino: "/pagos",
          fecha: this.ahora(),
        });
        await this.db.doc(`enviosPush/${a.uid}_auto_${doc.id}_${per}`).set({
          uid: a.uid,
          titulo: "Revisa tu pago mensual",
          cuerpo: mensaje,
          destino: "/pagos",
          estado: "pendiente",
          creado: this.ahora(),
        });
      }
      await this.db.runTransaction(async (tx) => {
        tx.update(intento, { estado, mensaje, actualizado: this.ahora() });
        tx.update(doc.ref, {
          ultimoEstado: estado,
          siguiente: proximoMes(this.reloj(), a.dia),
          actualizado: this.ahora(),
        });
      });
      procesados++;
    }
    return { procesados, hayMas: docs.size === 100 };
  }
  async emitirCheques(auth,d) { return chequera.emitirCheques(this,auth,d); }
  async gestionarCheque(auth,d) { return chequera.gestionarCheque(this,auth,d); }
  async cobrarCheque(auth,d) { return chequera.cobrarCheque(this,auth,d); }
  async procesarCheques(auth,d) { return chequera.procesarCheques(this,auth,d); }
  async solicitarAsesor(auth,d) { return chequera.solicitarAsesor(this,auth,d); }
  async responderAsesoria(auth,d) { return chequera.responderAsesoria(this,auth,d); }
  async ejecutar(auth, operacion, datos = {}) {
    const metodos = {
      emitirCheques: "emitirCheques",
      gestionarCheque: "gestionarCheque",
      cobrarCheque: "cobrarCheque",
      procesarCheques: "procesarCheques",
      solicitarAsesor: "solicitarAsesor",
      responderAsesoria: "responderAsesoria",

      registrarCliente: "registrarCliente",
      solicitarCredito: "solicitarCredito",
      solicitarTarjetaCredito: "solicitarCredito",
      elegirCorteTarjeta: "elegirCorteTarjeta",
      consultarTarjetaCredito: "consultarTarjetaCredito",
      registrarConsumoTarjeta: "registrarConsumoTarjeta",
      pagarTarjetaCredito: "pagarTarjetaCredito",
      procesarCortesTarjetas: "procesarCortesTarjetas",
      solicitarFisica: "solicitarFisica",
      revisarTarjeta: "revisarTarjeta",
      abrirAhorros: "abrirAhorros",
      destinatario: "destinatario",
      transferir: "transferir",
      guardarContacto: "guardarContacto",
      guardarTarjeta: "guardarTarjeta",
      pagarExterno: "pagarExterno",
      guardarSolicitud: "guardarSolicitud",
      registrarDocumento: "registrarDocumento",
      enviarSolicitud: "enviarSolicitud",
      consultarFactura: "consultarFactura",
      pagarServicio: "pagarServicio",
      configurarAutopago: "configurarAutopago",
      pausarAutopago: "pausarAutopago",
      ajustar: "ajustar",
      migrarCuentas: "migrarCuentas",
      revisarSolicitud: "revisarSolicitud",
      guardarServicio: "guardarServicio",
      guardarDecoracion: "guardarDecoracion",
      procesarAutopagos: "procesarAutopagos",
    };
    if (
      !Object.hasOwn(metodos, operacion) ||
      typeof datos !== "object" ||
      datos === null ||
      Array.isArray(datos)
    )
      falla("invalid-argument", "Operación no disponible.");
    if (["procesarAutopagos", "procesarCortesTarjetas"].includes(operacion))
      this.actor(auth, true);
    if (operacion === "pagarServicio") {
      datos = {
        cuenta: datos.cuenta,
        factura: datos.factura,
        referencia: datos.referencia,
      };
    }
    return this[metodos[operacion]](auth, datos);
  }
}
