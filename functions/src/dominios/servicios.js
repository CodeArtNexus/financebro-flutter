// Casos de uso del dominio; BancoBase conserva las escrituras monetarias compartidas.
import {
  FalloBanco,
  falla,
  texto,
  entero,
  identificador,
  referencia,
  huella,
  periodo,
  fechaLocal,
  proximoMes,
} from "../compartido.js";

export async function guardarServicio(banco, auth, d) {
  const actor = banco.actor(auth, true),
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
    actualizado: banco.ahora(),
  };
  await banco.db.doc(`servicios/${id}`).set(servicio);
  return { id, ...servicio, actualizado: undefined };
}

export async function consultarFactura(banco, auth, d) {
  banco.actor(auth);
  return banco.obtenerFactura(
    identificador(d.servicio),
    texto(d.contrato, "el contrato", 4, 30),
  );
}

export async function obtenerFactura(banco, servicio, contrato) {
  if (!/^[a-zA-Z0-9-]{4,30}$/.test(contrato))
    falla("invalid-argument", "Revisa el código de contrato.");
  const per = periodo(banco.reloj()),
    id = huella([servicio, contrato, per]),
    ref = banco.db.doc(`facturas/${id}`);
  const resultado = await banco.db.runTransaction(async (tx) => {
    const s = await tx.get(banco.db.doc(`servicios/${servicio}`)),
      factura = await tx.get(ref);
    if (!s.exists || s.data().activo !== true)
      falla("failed-precondition", "Este servicio no está disponible.");
    if (factura.exists) return factura.data();
    // Proveedor sintético: cambia el valor por contrato y mes sin consultar una empresa real.
    const variacion = parseInt(huella([contrato, per]).slice(0, 6), 16) % 1500;
    const f = {
      servicio,
      contrato,
      periodo: per,
      centavos: s.data().baseCentavos + variacion,
      nombre: s.data().nombre,
      estado: "pendiente",
      simulado: true,
      creado: banco.ahora(),
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

export async function pagarServicio(banco, auth, d) {
  const uid = banco.actor(auth),
    cuenta = identificador(d.cuenta),
    factura = identificador(d.factura),
    id = referencia(d.referencia),
    fecha = banco.ahora(),
    fingerprint = huella([cuenta, factura]);
  return banco.db.runTransaction(async (tx) => {
    const operacion = banco.privado(uid, "operaciones", id),
      anterior = await tx.get(operacion);
    if (anterior.exists) {
      if (anterior.data().huella !== fingerprint)
        falla("already-exists", "La referencia ya fue usada.");
      return anterior.data().recibo;
    }
    const fRef = banco.db.doc(`facturas/${factura}`),
      f = await tx.get(fRef);
    if (!f.exists)
      falla("not-found", "Consulta el valor de la planilla antes de pagar.");
    const servicio = await tx.get(
        banco.db.doc(`servicios/${f.data().servicio}`),
      ),
      ref = banco.cuenta(uid, cuenta),
      c = banco.cuentaDisponible(await tx.get(ref));
    if (d.autopago) {
      const a = await tx.get(banco.db.doc(d.autopago));
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
    if (f.data().periodo !== periodo(banco.reloj()))
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
    banco.registrarMovimiento(tx, uid, cuenta, id, {
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

export async function configurarAutopago(banco, auth, d) {
  const uid = banco.actor(auth),
    recibo = await banco
      .privado(uid, "operaciones", referencia(d.referencia))
      .get();
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
  await banco.privado(uid, "autopagos", id).set(
    {
      uid,
      servicio: r.servicio,
      contrato: r.contrato,
      cuenta: r.cuenta,
      nombre: r.titular,
      maximoCentavos,
      dia,
      activo: true,
      siguiente: proximoMes(banco.reloj(), dia),
      consentimiento: banco.ahora(),
      actualizado: banco.ahora(),
    },
    { merge: true },
  );
  return { id };
}

export async function pausarAutopago(banco, auth, d) {
  const uid = banco.actor(auth),
    ref = banco.privado(uid, "autopagos", identificador(d.id));
  if (!(await ref.get()).exists)
    falla("not-found", "No encontramos el pago mensual.");
  await ref.update({ activo: false, actualizado: banco.ahora() });
  return { pausado: true };
}

export async function procesarAutopagos(banco) {
  const hoy = fechaLocal(banco.reloj()),
    docs = await banco.db
      .collectionGroup("autopagos")
      .where("activo", "==", true)
      .where("siguiente", "<=", hoy)
      .limit(100)
      .get();
  let procesados = 0;
  for (const doc of docs.docs) {
    const a = doc.data(),
      per = periodo(banco.reloj()),
      intento = doc.ref.collection("intentos").doc(per);
    const tomado = await banco.db.runTransaction(async (tx) => {
      const actual = await tx.get(doc.ref),
        previo = await tx.get(intento);
      if (
        !actual.data()?.activo ||
        (previo.exists &&
          (previo.data().estado !== "procesando" ||
            previo.data().fecha.toMillis() > banco.ahora().toMillis() - 300000))
      )
        return false;
      tx.set(intento, { estado: "procesando", fecha: banco.ahora() });
      return true;
    });
    if (!tomado) continue;
    let estado = "pagado",
      mensaje = "Pago mensual completado";
    try {
      const f = await banco.obtenerFactura(a.servicio, a.contrato);
      await banco.pagarServicio(
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
      await banco
        .privado(a.uid, "notificaciones", `auto_${doc.id}_${per}`)
        .set({
          titulo: "Revisa tu pago mensual",
          cuerpo: mensaje,
          destino: "/pagos",
          fecha: banco.ahora(),
        });
      await banco.db.doc(`enviosPush/${a.uid}_auto_${doc.id}_${per}`).set({
        uid: a.uid,
        titulo: "Revisa tu pago mensual",
        cuerpo: mensaje,
        destino: "/pagos",
        estado: "pendiente",
        creado: banco.ahora(),
      });
    }
    await banco.db.runTransaction(async (tx) => {
      tx.update(intento, { estado, mensaje, actualizado: banco.ahora() });
      tx.update(doc.ref, {
        ultimoEstado: estado,
        siguiente: proximoMes(banco.reloj(), a.dia),
        actualizado: banco.ahora(),
      });
    });
    procesados++;
  }
  return { procesados, hayMas: docs.size === 100 };
}
