// Casos de uso del dominio; BancoBase conserva las escrituras monetarias compartidas.
import {
  falla,
  texto,
  entero,
  identificador,
  referencia,
  COLORES,
  huella,
  fechaLocal,
} from "../compartido.js";
import {
  POLITICA_TARJETA,
  fechaEcuador,
  siguienteCorte,
  ultimoCorte,
  vencimiento,
  pagoMinimo,
} from "../ciclo-tarjeta.js";
import { randomBytes } from "node:crypto";

export async function solicitarCredito(banco, auth, d) {
  const uid = banco.actor(auth),
    fecha = banco.ahora(),
    ref = banco.privado(uid, "solicitudes", "credito");
  const ingresosCentavos = entero(
      d.ingresosCentavos,
      "tus ingresos mensuales",
      100,
      100000000,
    ),
    ocupacion = texto(d.ocupacion, "tu ocupación", 2, 80);
  if (d.aceptaEvaluacion !== true)
    falla("failed-precondition", "Autoriza la revisión de tu solicitud.");
  return banco.db.runTransaction(async (tx) => {
    const [cuenta, personal, anterior] = await Promise.all([
      tx.get(banco.cuenta(uid, "ahorros")),
      tx.get(banco.privado(uid, "datosPersonales", "identidad")),
      tx.get(ref),
    ]);
    banco.cuentaDisponible(cuenta);
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
    banco.avisarCliente(
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

export async function solicitarFisica(banco, auth, d) {
  const uid = banco.actor(auth),
    tarjeta = identificador(d.tarjeta),
    id = referencia(d.referencia),
    fecha = banco.ahora();
  const envio = texto(d.fechaEnvio, "la fecha de envío", 10, 10),
    fechaMinima = fechaLocal(new Date(banco.reloj().getTime() + 3 * 86400000));
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(envio) ||
    !Number.isFinite(Date.parse(`${envio}T12:00:00Z`)) ||
    new Date(`${envio}T12:00:00Z`).toISOString().slice(0, 10) !== envio ||
    envio < fechaMinima ||
    envio > fechaLocal(new Date(banco.reloj().getTime() + 90 * 86400000))
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
  const ref = banco.privado(uid, "solicitudes", `fisica_${tarjeta}`);
  return banco.db.runTransaction(async (tx) => {
    const [t, p, s] = await Promise.all([
      tx.get(banco.privado(uid, "tarjetas", tarjeta)),
      tx.get(banco.usuario(uid)),
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
        ...(t.data().fondoRuta ? { fondoRuta: t.data().fondoRuta } : {}),
      },
      aceptado: fecha,
      actualizado: fecha,
    });
    banco.avisarCliente(
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

export async function revisarTarjeta(banco, auth, d) {
  const actor = banco.actor(auth, true),
    uid = identificador(d.uid),
    id = identificador(d.id),
    accion = d.accion;
  const nota = texto(d.nota, "la observación", 5, 160),
    fecha = banco.ahora(),
    ref = banco.privado(uid, "solicitudes", id);
  return banco.db.runTransaction(async (tx) => {
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
        const tarjetaRef = banco.privado(uid, "tarjetas", "bro_credito"),
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
      if (accion === "enviar" && fechaLocal(banco.reloj()) < datos.fechaEnvio)
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
    banco.avisarCliente(
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

export function tarjetaCredito(banco, snapshot) {
  if (
    !snapshot.exists ||
    snapshot.data().clase !== "credito" ||
    snapshot.data().tipo !== "propia"
  )
    falla("not-found", "No encontramos tu tarjeta de crédito FinanceBro.");
  const t = snapshot.data();
  entero(t.cupoCentavos, "el cupo registrado", 1, 5000000);
  entero(t.deudaCentavos, "la deuda registrada", 0, t.cupoCentavos);
  entero(t.totalPagarCentavos, "el total facturado", 0, t.deudaCentavos);
  entero(
    t.minimoPagarCentavos,
    "el mínimo registrado",
    0,
    t.totalPagarCentavos,
  );
  return t;
}

export async function elegirCorteTarjeta(banco, auth, d) {
  const uid = banco.actor(auth),
    dia = entero(d.dia, "el día de corte", 1, 28),
    fecha = banco.ahora();
  if (d.aceptaCondiciones !== true)
    falla("failed-precondition", "Acepta las condiciones de corte y pago.");
  const ref = banco.privado(uid, "tarjetas", "bro_credito");
  return banco.db.runTransaction(async (tx) => {
    const t = banco.tarjetaCredito(await tx.get(ref));
    if (t.estado === "activa") {
      if (t.diaCorte === dia) return { dia, proximoCorte: t.proximoCorte };
      falla(
        "failed-precondition",
        "Tu corte ya está elegido. Contacta a un asesor para cambiarlo.",
      );
    }
    const proximoCorte = siguienteCorte(fechaEcuador(banco.reloj()), dia);
    tx.update(ref, {
      estado: "activa",
      diaCorte: dia,
      proximoCorte,
      condicionesAceptadas: fecha,
      actualizado: fecha,
    });
    banco.avisarCliente(
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

export async function sincronizarCorte(banco, uid) {
  const ref = banco.privado(uid, "tarjetas", "bro_credito"),
    hoy = fechaEcuador(banco.reloj()),
    fecha = banco.ahora();
  return banco.db.runTransaction(async (tx) => {
    const t = banco.tarjetaCredito(await tx.get(ref));
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
    banco.avisarCliente(
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

export async function consultarTarjetaCredito(banco, auth) {
  return banco.sincronizarCorte(banco.actor(auth));
}

export async function procesarCortesTarjetas(banco, auth) {
  if (auth) banco.actor(auth, true);
  const hoy = fechaEcuador(banco.reloj()),
    tarjetas = await banco.db
      .collectionGroup("tarjetas")
      .where("clase", "==", "credito")
      .get();
  let procesados = 0;
  for (const doc of tarjetas.docs)
    if (doc.data().estado === "activa" && doc.data().proximoCorte <= hoy) {
      await banco.sincronizarCorte(doc.ref.parent.parent.id);
      procesados++;
    }
  return { procesados };
}

export async function registrarConsumoTarjeta(banco, auth, d) {
  const actor = banco.actor(auth, true),
    uid = identificador(d.uid),
    id = referencia(d.referencia),
    centavos = entero(d.centavos, "el importe del consumo", 10, 5000000),
    comercio = texto(d.comercio, "el comercio", 2, 80),
    fecha = banco.ahora();
  await banco.sincronizarCorte(uid);
  const ref = banco.privado(uid, "tarjetas", "bro_credito"),
    fingerprint = huella(["consumo_credito", uid, centavos, comercio]);
  return banco.db.runTransaction(async (tx) => {
    const operacion = banco.privado(uid, "operaciones", id),
      previo = await tx.get(operacion);
    if (previo.exists) {
      if (previo.data().huella !== fingerprint)
        falla("already-exists", "La referencia ya fue usada.");
      return previo.data().recibo;
    }
    const t = banco.tarjetaCredito(await tx.get(ref));
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
      banco.privado(uid, "movimientosGlobales", `credito_${id}`),
      movimiento,
    );
    tx.create(operacion, { huella: fingerprint, recibo, fecha });
    banco.avisarCliente(
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

export async function pagarTarjetaCredito(banco, auth, d) {
  const uid = banco.actor(auth),
    cuenta = identificador(d.cuenta),
    id = referencia(d.referencia),
    importe = entero(d.centavos, "el importe del pago", 1, 5000000),
    fecha = banco.ahora(),
    fingerprint = huella(["pago_credito", cuenta, importe]);
  await banco.sincronizarCorte(uid);
  return banco.db.runTransaction(async (tx) => {
    const operacion = banco.privado(uid, "operaciones", id),
      previo = await tx.get(operacion);
    if (previo.exists) {
      if (previo.data().huella !== fingerprint)
        falla("already-exists", "La referencia ya fue usada.");
      return previo.data().recibo;
    }
    const tarjetaRef = banco.privado(uid, "tarjetas", "bro_credito"),
      cuentaRef = banco.cuenta(uid, cuenta);
    const [ts, cs] = await Promise.all([tx.get(tarjetaRef), tx.get(cuentaRef)]),
      t = banco.tarjetaCredito(ts),
      c = banco.cuentaDisponible(cs);
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
    banco.registrarMovimiento(tx, uid, cuenta, id, {
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

export async function guardarTarjeta(banco, auth, d) {
  const uid = banco.actor(auth),
    id = d.id ? identificador(d.id) : randomBytes(12).toString("hex"),
    color = d.color ?? "durazno",
    nombre = texto(d.nombre, "el nombre", 2, 40),
    fecha = banco.ahora();
  if (!COLORES.includes(color))
    falla("invalid-argument", "Selecciona un color disponible.");
  const ref = banco.privado(uid, "tarjetas", id);
  if (d.tipo === "propia") {
    if (d.fondoRuta != null) {
      const ruta = texto(d.fondoRuta, "el fondo de tarjeta", 10, 240);
      if (
        !new RegExp(
          `^tarjetas/${uid}/${id}/fondos/[a-zA-Z0-9_-]{8,80}\\.(png|jpg)$`,
        ).test(ruta)
      )
        falla("permission-denied", "El fondo debe pertenecer a esta tarjeta.");
      if (!banco.bucket)
        falla(
          "unavailable",
          "No pudimos guardar el fondo. Vuelve a intentarlo.",
        );
      const [m] = await banco.bucket.file(ruta).getMetadata();
      if (
        !["image/png", "image/jpeg"].includes(m.contentType) ||
        Number(m.size) <= 0 ||
        Number(m.size) > 2 * 1024 * 1024
      )
        falla("invalid-argument", "El fondo debe ser PNG o JPG de hasta 2 MB.");
    }
    if (!d.id)
      falla(
        "failed-precondition",
        "Tu tarjeta FinanceBro se emite al abrir ahorros o al aprobar tu solicitud de crédito.",
      );
    return banco.db.runTransaction(async (tx) => {
      const anterior = await tx.get(ref);
      if (!anterior.exists || anterior.data().tipo !== "propia")
        falla("not-found", "No encontramos tu tarjeta FinanceBro.");
      const t = anterior.data(),
        c = banco.cuentaDisponible(
          await tx.get(banco.cuenta(uid, identificador(t.cuenta))),
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
        ...(Object.hasOwn(d, "fondoRuta")
          ? { fondoRuta: d.fondoRuta ?? null }
          : {}),
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
  return banco.db.runTransaction(async (tx) => {
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
