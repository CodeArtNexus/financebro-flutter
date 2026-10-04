import { createHash } from "node:crypto";
import {
  FalloBanco,
  texto,
  entero,
  identificador,
  referencia,
  numeroCuenta,
} from "./banca.js";
import { fechaEcuador } from "./ciclo-tarjeta.js";
const fallo = (m, c = "failed-precondition") => {
  throw new FalloBanco(c, m);
};
const hash = (d) =>
  createHash("sha256").update(JSON.stringify(d)).digest("hex");
const MAX = 100000000;
export function fechaCheque(v) {
  if (
    typeof v !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(v) ||
    !Number.isFinite(Date.parse(v + "T12:00:00Z")) ||
    new Date(v + "T12:00:00Z").toISOString().slice(0, 10) !== v
  )
    fallo("Revisa la fecha de cobro.", "invalid-argument");
  return v;
}
export function sumarDias(v, n) {
  const f = new Date(fechaCheque(v) + "T12:00:00Z");
  f.setUTCDate(f.getUTCDate() + n);
  return f.toISOString().slice(0, 10);
}
export function mesCheque(v, n) {
  const [a, m, d] = fechaCheque(v).split("-").map(Number),
    ultimo = new Date(Date.UTC(a, m + n, 0)).getUTCDate();
  return new Date(Date.UTC(a, m - 1 + n, Math.min(d, ultimo), 12))
    .toISOString()
    .slice(0, 10);
}
const espejo = (c, rol) => ({
  id: c.id,
  grupo: c.grupo,
  numeroOrigen: c.numeroOrigen,
  numeroDestino: c.numeroDestino,
  emisor: c.emisor,
  receptor: c.receptor,
  concepto: c.concepto,
  centavos: c.centavos,
  fechaOriginal: c.fechaOriginal,
  fechaCobro: c.fechaCobro,
  estado: c.estado,
  creado: c.creado,
  actualizado: c.actualizado,
  rol,
  cuenta: rol === "emisor" ? c.cuentaOrigen : c.cuentaDestino,
});
function escribir(b, tx, c) {
  tx.set(b.privado(c.uidEmisor, "cheques", c.id), espejo(c, "emisor"));
  tx.set(b.privado(c.uidReceptor, "cheques", c.id), espejo(c, "receptor"));
}
function evento(b, tx, c, id, accion, mensaje) {
  const datos = {
    accion,
    mensaje,
    fecha: b.ahora(),
    estado: c.estado,
    fechaCobro: c.fechaCobro,
  };
  tx.create(b.db.doc(`cheques/${c.id}/eventos/${id}`), datos);
  for (const uid of [c.uidEmisor, c.uidReceptor])
    tx.create(
      b.privado(uid, "cheques", c.id).collection("eventos").doc(id),
      datos,
    );
}
function avisar(b, tx, c, id, titulo, cuerpo) {
  for (const uid of [c.uidEmisor, c.uidReceptor])
    b.avisarCliente(
      tx,
      uid,
      `${c.id}_${id}`,
      titulo,
      cuerpo,
      `/chequera/cheques/${c.id}`,
    );
}
export async function emitirCheques(b, auth, d) {
  const uid = b.actor(auth),
    ref = referencia(d.referencia),
    cuenta = identificador(d.cuenta ?? "corriente");
  if (d.aceptaEmision !== true) fallo("Confirma la emisión y sus condiciones.");
  if (
    !Array.isArray(d.cheques) ||
    d.cheques.length < 1 ||
    d.cheques.length > 24
  )
    fallo("Emite de 1 a 24 cheques por grupo.", "invalid-argument");
  const hoy = fechaEcuador(b.reloj()),
    lista = d.cheques.map((c) => ({
      centavos: entero(c.centavos, "el importe", 10, MAX),
      fecha: fechaCheque(c.fecha),
    }));
  for (const c of lista)
    if (c.fecha < hoy || c.fecha > sumarDias(hoy, 1096))
      fallo(
        "El cobro debe estar entre hoy y los próximos 3 años.",
        "invalid-argument",
      );
  const grupoId = d.grupo ? identificador(d.grupo) : `grupo_${ref}`,
    gRef = b.privado(uid, "gruposCheques", grupoId),
    op = b.privado(uid, "operaciones", `emision_${ref}`),
    huella = hash([
      d.grupo ?? null,
      d.numero ?? null,
      d.concepto ?? null,
      cuenta,
      lista,
    ]);
  return b.db.runTransaction(async (tx) => {
    const anterior = await tx.get(op);
    if (anterior.exists) {
      if (anterior.data().huella !== huella)
        fallo(
          "Esta referencia ya corresponde a otra emisión.",
          "already-exists",
        );
      return anterior.data().recibo;
    }
    const g = await tx.get(gRef),
      origen = b.cuentaDisponible(await tx.get(b.cuenta(uid, cuenta)));
    if (origen.tipo !== "corriente")
      fallo("La chequera pertenece a tu cuenta corriente.");
    if (d.grupo && !g.exists)
      fallo("No encontramos esa agrupación.", "not-found");
    const numero = g.exists ? g.data().numeroDestino : numeroCuenta(d.numero),
      concepto = g.exists
        ? g.data().concepto
        : texto(d.concepto, "el concepto", 3, 100);
    if (g.exists && g.data().cuenta !== cuenta)
      fallo("La agrupación pertenece a otra cuenta.");
    const dir = await tx.get(b.db.doc(`directorioCuentas/${numero}`));
    if (!dir.exists) fallo("No encontramos la cuenta de destino.", "not-found");
    const destino = dir.data();
    if (destino.uid === uid)
      fallo("Elige la cuenta corriente de otra persona.", "invalid-argument");
    const receptora = b.cuentaDisponible(
        await tx.get(b.cuenta(destino.uid, destino.cuenta)),
      ),
      perfil = await tx.get(b.usuario(uid));
    if (receptora.tipo !== "corriente")
      fallo("El beneficiario necesita una cuenta corriente activa.");
    const total = lista.reduce((s, c) => s + c.centavos, 0),
      pendiente = (g.data()?.pendienteCentavos ?? 0) + total;
    entero(pendiente, "el total pendiente", 0, MAX);
    const fecha = b.ahora(),
      ids = lista.map((_, i) => `ch_${hash([uid, ref, i]).slice(0, 40)}`);
    const recibo = { grupo: grupoId, ids, totalCentavos: total };
    for (let i = 0; i < lista.length; i++) {
      const l = lista[i],
        c = {
          id: ids[i],
          grupo: grupoId,
          uidEmisor: uid,
          uidReceptor: destino.uid,
          cuentaOrigen: cuenta,
          cuentaDestino: destino.cuenta,
          numeroOrigen: origen.numeroCuenta,
          numeroDestino: numero,
          emisor: perfil.data()?.nombre ?? "FinanceBro",
          receptor: destino.titular,
          concepto,
          centavos: l.centavos,
          fechaOriginal: l.fecha,
          fechaCobro: l.fecha,
          estado: "pendiente",
          creado: fecha,
          actualizado: fecha,
        };
      tx.create(b.db.doc(`cheques/${c.id}`), c);
      escribir(b, tx, c);
      evento(
        b,
        tx,
        c,
        "emision",
        "emision",
        "Cheque emitido y autorizado por su titular.",
      );
      b.avisarCliente(
        tx,
        destino.uid,
        `${c.id}_emision`,
        "Tienes un cheque por cobrar",
        `${c.emisor} · USD ${(c.centavos / 100).toFixed(2)} · ${c.fechaCobro}`,
        `/chequera/cheques/${c.id}`,
        fecha,
      );
    }
    tx.set(gRef, {
      id: grupoId,
      cuenta,
      numeroDestino: numero,
      receptor: destino.titular,
      concepto,
      emitidos: (g.data()?.emitidos ?? 0) + lista.length,
      emitidoCentavos: (g.data()?.emitidoCentavos ?? 0) + total,
      pendienteCentavos: pendiente,
      cobradoCentavos: g.data()?.cobradoCentavos ?? 0,
      canceladoCentavos: g.data()?.canceladoCentavos ?? 0,
      ultimaFecha: [g.data()?.ultimaFecha ?? "", ...lista.map((c) => c.fecha)]
        .sort()
        .at(-1),
      actualizado: fecha,
    });
    tx.create(op, { huella, recibo, fecha });
    return recibo;
  });
}
export async function gestionarCheque(b, auth, d) {
  const uid = b.actor(auth),
    id = identificador(d.id),
    ref = referencia(d.referencia),
    accion = d.accion,
    nota = texto(d.nota ?? "Gestión del titular", "el motivo", 3, 120),
    cRef = b.db.doc(`cheques/${id}`),
    op = b.privado(uid, "operaciones", `cheque_${ref}`),
    huella = hash([id, accion, d.fecha ?? null, nota]);
  if (!["posponer", "bloquear", "desbloquear", "cancelar"].includes(accion))
    fallo("Acción no disponible.", "invalid-argument");
  return b.db.runTransaction(async (tx) => {
    const anterior = await tx.get(op);
    if (anterior.exists) {
      if (anterior.data().huella !== huella)
        fallo("La referencia pertenece a otra gestión.", "already-exists");
      return anterior.data().recibo;
    }
    const doc = await tx.get(cRef);
    if (!doc.exists) fallo("No encontramos el cheque.", "not-found");
    const c = doc.data();
    if (uid !== c.uidEmisor)
      fallo("Solo el emisor puede gestionar el cheque.", "permission-denied");
    if (["cobrado", "cancelado"].includes(c.estado))
      fallo("Este cheque ya está cerrado.");
    const gRef = b.privado(uid, "gruposCheques", c.grupo),
      g = await tx.get(gRef);
    if (accion === "posponer") {
      const fecha = fechaCheque(d.fecha);
      if (
        fecha < c.fechaOriginal ||
        fecha > sumarDias(c.fechaOriginal, 5) ||
        fecha < fechaEcuador(b.reloj())
      )
        fallo(
          "Puedes moverlo hasta 5 días después de su fecha original, sin elegir un día pasado.",
        );
      if (fecha === c.fechaCobro) fallo("Elige una fecha diferente.");
      c.fechaCobro = fecha;
    }
    if (accion === "bloquear") {
      if (c.estado === "bloqueado") fallo("El cheque ya está bloqueado.");
      c.estado = "bloqueado";
    }
    if (accion === "desbloquear") {
      if (c.estado !== "bloqueado") fallo("El cheque no está bloqueado.");
      c.estado = "pendiente";
    }
    if (accion === "cancelar") {
      c.estado = "cancelado";
      tx.update(gRef, {
        pendienteCentavos: g.data().pendienteCentavos - c.centavos,
        canceladoCentavos: g.data().canceladoCentavos + c.centavos,
        actualizado: b.ahora(),
      });
    }
    c.actualizado = b.ahora();
    tx.set(cRef, c);
    escribir(b, tx, c);
    evento(b, tx, c, ref, accion, nota);
    avisar(
      b,
      tx,
      c,
      ref,
      "Tu cheque tiene una actualización",
      `${nota} · ${c.estado.replaceAll("_", " ")} · cobro ${c.fechaCobro}`,
    );
    const recibo = { id, estado: c.estado, fechaCobro: c.fechaCobro };
    tx.create(op, { huella, recibo, fecha: b.ahora() });
    return recibo;
  });
}
export async function cobrarCheque(b, auth, d, { automatico = false } = {}) {
  const uid = automatico ? null : b.actor(auth),
    id = identificador(d.id),
    cRef = b.db.doc(`cheques/${id}`);
  return b.db.runTransaction(async (tx) => {
    const doc = await tx.get(cRef);
    if (!doc.exists) fallo("No encontramos el cheque.", "not-found");
    const c = doc.data();
    entero(c.centavos, "el importe registrado del cheque", 10, MAX);
    fechaCheque(c.fechaCobro);
    if (!automatico && ![c.uidEmisor, c.uidReceptor].includes(uid))
      fallo("Este cheque no pertenece a tu cuenta.", "permission-denied");
    if (c.estado === "cobrado") return { id, estado: "cobrado" };
    if (["cancelado", "bloqueado"].includes(c.estado))
      return { id, estado: c.estado };
    if (c.fechaCobro > fechaEcuador(b.reloj()))
      fallo("El cheque aún no llega a su fecha de cobro.");
    const oRef = b.cuenta(c.uidEmisor, c.cuentaOrigen),
      dRef = b.cuenta(c.uidReceptor, c.cuentaDestino),
      gRef = b.privado(c.uidEmisor, "gruposCheques", c.grupo);
    const [oSnap, dSnap, g] = await Promise.all([
        tx.get(oRef),
        tx.get(dRef),
        tx.get(gRef),
      ]),
      o = oSnap.data(),
      destino = dSnap.data();
    if (
      !o ||
      !destino ||
      o.estado !== "activa" ||
      destino.estado !== "activa" ||
      o.saldoCentavos < c.centavos ||
      destino.saldoCentavos + c.centavos > MAX
    ) {
      if (c.estado !== "pendiente_fondos") {
        c.estado = "pendiente_fondos";
        c.actualizado = b.ahora();
        tx.set(cRef, c);
        escribir(b, tx, c);
        const eid = `fondos_${c.actualizado.toMillis()}`;
        evento(
          b,
          tx,
          c,
          eid,
          "pendiente_fondos",
          "No se realizó ningún descuento. Revisa los fondos y el estado de las cuentas.",
        );
        avisar(
          b,
          tx,
          c,
          eid,
          "Cheque pendiente de cobro",
          "Revisa los fondos y el estado de las cuentas. Se reintentará el cobro.",
        );
      }
      return { id, estado: "pendiente_fondos" };
    }
    // Una inconsistencia no debe convertirse en un débito o un abono parcial.
    b.cuentaDisponible(oSnap);
    b.cuentaDisponible(dSnap);
    if (oRef.path === dRef.path || o.numeroCuenta !== c.numeroOrigen ||
        destino.numeroCuenta !== c.numeroDestino || o.tipo !== "corriente" ||
        destino.tipo !== "corriente" || !g.exists)
      fallo("No pudimos verificar las cuentas y la agrupación del cheque.");
    const agrupacion = g.data();
    entero(agrupacion.pendienteCentavos, "el total pendiente", c.centavos, MAX);
    entero(agrupacion.cobradoCentavos, "el total cobrado", 0, MAX - c.centavos);
    const fecha = b.ahora(),
      mov = `cheque_${id}`;
    tx.update(oRef, {
      saldoCentavos: o.saldoCentavos - c.centavos,
      actualizado: fecha,
      ultimoMovimiento: mov,
    });
    tx.update(dRef, {
      saldoCentavos: destino.saldoCentavos + c.centavos,
      actualizado: fecha,
      ultimoMovimiento: mov,
    });
    const comun = {
      categoria: "Cheques",
      tipo: "cheque",
      cheque: id,
      grupo: c.grupo,
      nota: c.concepto,
      fecha,
      actor: c.uidEmisor,
    };
    b.registrarMovimiento(tx, c.uidEmisor, c.cuentaOrigen, mov, {
      ...comun,
      centavos: -c.centavos,
      descripcion: `Cheque a ${c.receptor}`,
      numeroDestino: c.numeroDestino,
    });
    b.registrarMovimiento(tx, c.uidReceptor, c.cuentaDestino, mov, {
      ...comun,
      centavos: c.centavos,
      descripcion: `Cheque de ${c.emisor}`,
      numeroOrigen: c.numeroOrigen,
    });
    c.estado = "cobrado";
    c.actualizado = fecha;
    c.cobrado = fecha;
    tx.set(cRef, c);
    escribir(b, tx, c);
    evento(b, tx, c, "cobro", "cobrado", "Fondos abonados al beneficiario.");
    tx.update(gRef, {
      pendienteCentavos: g.data().pendienteCentavos - c.centavos,
      cobradoCentavos: g.data().cobradoCentavos + c.centavos,
      actualizado: fecha,
    });
    return { id, estado: "cobrado" };
  });
}
export async function procesarCheques(
  b,
  auth,
  d = {},
  { programado = false } = {},
) {
  if (!programado) b.actor(auth, true);
  const hoy = fechaEcuador(b.reloj());
  let q = b.db
    .collection("cheques")
    .where("estado", "in", ["pendiente", "pendiente_fondos"])
    .where("fechaCobro", "<=", sumarDias(hoy, 3))
    .orderBy("fechaCobro")
    .orderBy("__name__")
    .limit(100);
  if (d.cursor) {
    q = q.startAfter(fechaCheque(d.cursor.fecha), identificador(d.cursor.id));
  }
  const docs = await q.get();
  let cobrados = 0,
    recordados = 0;
  for (const doc of docs.docs) {
    const c = doc.data();
    if (c.fechaCobro <= hoy) {
      const r = await cobrarCheque(
        b,
        null,
        { id: doc.id },
        { automatico: true },
      );
      if (r.estado === "cobrado") cobrados++;
    } else {
      const recordatorio = await b.db.runTransaction(async (tx) => {
        const s = await tx.get(doc.ref),
          v = s.data(),
          rid = `recordatorio_${v.fechaCobro}`,
          n = b.privado(v.uidEmisor, "notificaciones", `${v.id}_${rid}`),
          previo = await tx.get(n);
        if (
          previo.exists ||
          !["pendiente", "pendiente_fondos"].includes(v.estado) ||
          v.fechaCobro > sumarDias(hoy, 3)
        )
          return false;
        avisar(
          b,
          tx,
          v,
          rid,
          "Tu cheque se acerca",
          `Cobro ${v.fechaCobro} · USD ${(v.centavos / 100).toFixed(2)} · ${v.concepto}`,
        );
        return true;
      });
      if (recordatorio) recordados++;
    }
  }
  const ultimo = docs.docs.at(-1);
  return {
    cobrados,
    recordados,
    hayMas: docs.size === 100,
    cursor: ultimo ? { fecha: ultimo.data().fechaCobro, id: ultimo.id } : null,
  };
}
export async function solicitarAsesor(b, auth, d) {
  const uid = b.actor(auth),
    id = referencia(d.referencia),
    motivo = texto(d.motivo, "tu consulta", 5, 400),
    ref = b.privado(uid, "solicitudes", `asesoria_${id}`);
  return b.db.runTransaction(async (tx) => {
    const [c, anterior, p] = await Promise.all([
      tx.get(b.cuenta(uid, "corriente")),
      tx.get(ref),
      tx.get(b.usuario(uid)),
    ]);
    if (b.cuentaDisponible(c).tipo !== "corriente")
      fallo("Necesitas una cuenta corriente.");
    if (anterior.exists) return { id: ref.id };
    tx.create(ref, {
      uid,
      tipo: "asesoria",
      nombre: p.data()?.nombre ?? "Cliente",
      motivo,
      estado: "abierta",
      actualizado: b.ahora(),
    });
    return { id: ref.id };
  });
}
export async function responderAsesoria(b, auth, d) {
  const actor = b.actor(auth, true),
    uid = identificador(d.uid),
    id = identificador(d.id),
    respuesta = texto(d.respuesta, "la respuesta", 5, 400),
    ref = b.privado(uid, "solicitudes", id);
  return b.db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if (!s.exists || s.data().tipo !== "asesoria")
      fallo("No encontramos la consulta.", "not-found");
    if (s.data().estado === "respondida") return { estado: "respondida" };
    tx.update(ref, {
      respuesta,
      actor,
      estado: "respondida",
      actualizado: b.ahora(),
    });
    b.avisarCliente(tx, uid, id, "Tu asesor respondió", respuesta, "/chequera");
    return { estado: "respondida" };
  });
}
