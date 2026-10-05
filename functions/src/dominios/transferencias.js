// Casos de uso del dominio; BancoBase conserva las escrituras monetarias compartidas.
import {
  falla,
  texto,
  entero,
  identificador,
  referencia,
  numeroCuenta,
  huella,
  MAX_SALDO,
} from "../compartido.js";
import { randomBytes } from "node:crypto";

export async function destinatario(banco, auth, d) {
  banco.actor(auth);
  const numero = numeroCuenta(d.numero);
  const entrada = await banco.db.doc(`directorioCuentas/${numero}`).get();
  if (!entrada.exists)
    falla("not-found", "No encontramos esa cuenta de FinanceBro.");
  const titular = entrada.data(),
    c = banco.cuentaDisponible(
      await banco.cuenta(titular.uid, titular.cuenta).get(),
      { entrada: true },
    );
  if (c.numeroCuenta !== numero)
    falla("failed-precondition", "No pudimos verificar esa cuenta.");
  return { numero, titular: titular.titular, tipo: c.tipo, estado: c.estado };
}

export async function transferir(banco, auth, d) {
  const uid = banco.actor(auth),
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
    fecha = banco.ahora(),
    reciboRef = banco.privado(uid, "operaciones", id);
  return banco.db.runTransaction(async (tx) => {
    const anterior = await tx.get(reciboRef);
    if (anterior.exists) {
      if (anterior.data().huella !== fingerprint)
        falla("already-exists", "La referencia corresponde a otra operación.");
      return anterior.data().recibo;
    }
    if (d.colaCreada !== undefined) {
      const creada = new Date(d.colaCreada);
      if (
        typeof d.colaCreada !== "string" ||
        !Number.isFinite(creada.getTime()) ||
        banco.reloj().getTime() - creada.getTime() > 86400000 ||
        creada.getTime() > banco.reloj().getTime() + 300000
      )
        falla(
          "failed-precondition",
          "La autorización pendiente venció. Revisa y crea una nueva transferencia.",
        );
    }
    const entrada = await tx.get(banco.db.doc(`directorioCuentas/${numero}`));
    if (!entrada.exists)
      falla("not-found", "No encontramos la cuenta de destino.");
    const receptor = entrada.data();
    if (uid === receptor.uid && cuenta === receptor.cuenta)
      falla("invalid-argument", "Elige una cuenta diferente como destino.");
    const origenRef = banco.cuenta(uid, cuenta),
      destinoRef = banco.cuenta(receptor.uid, receptor.cuenta);
    const origen = banco.cuentaDisponible(await tx.get(origenRef)),
      destino = banco.cuentaDisponible(await tx.get(destinoRef), {
        entrada: true,
      });
    if (destino.numeroCuenta !== numero)
      falla(
        "failed-precondition",
        "No pudimos verificar el destino. Revisa la cuenta antes de continuar.",
      );
    const perfil = await tx.get(banco.usuario(uid));
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
    banco.registrarMovimiento(tx, uid, cuenta, id, {
      descripcion: `Transferencia a ${receptor.titular}`,
      referenciaOperacion: id,
      centavos: -importe,
      categoria: "Transferencias",
      tipo: "transferencia",
      actor: uid,
      numeroDestino: numero,
      nota,
      fecha,
    });
    banco.registrarMovimiento(tx, receptor.uid, receptor.cuenta, idCredito, {
      descripcion: `Transferencia de ${perfil.data()?.nombre ?? "FinanceBro"}`,
      referenciaOperacion: id,
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

export async function ajustar(banco, auth, d) {
  const actor = banco.actor(auth, true),
    uid = identificador(d.uid),
    cuenta = identificador(d.cuenta),
    id = referencia(d.referencia);
  const delta = entero(d.centavos, "el ajuste", -MAX_SALDO, MAX_SALDO);
  if (!delta) falla("invalid-argument", "El ajuste debe cambiar el saldo.");
  const motivo = texto(d.motivo, "el motivo", 5, 120),
    fingerprint = huella([actor, uid, cuenta, delta, motivo]),
    fecha = banco.ahora();
  return banco.db.runTransaction(async (tx) => {
    const recibo = banco.db.doc(`ajustes/${id}`),
      previo = await tx.get(recibo);
    if (previo.exists) {
      if (previo.data().huella !== fingerprint)
        falla("already-exists", "Esa referencia ya fue usada.");
      return previo.data().resultado;
    }
    const ref = banco.cuenta(uid, cuenta),
      actual = banco.cuentaDisponible(await tx.get(ref), {
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
    banco.registrarMovimiento(tx, uid, cuenta, id, {
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

export async function guardarContacto(banco, auth, d) {
  const uid = banco.actor(auth),
    id = d.id ? identificador(d.id) : randomBytes(12).toString("hex");
  let contacto;
  if (d.tipo === "interno") {
    const receptor = await banco.destinatario(auth, d);
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
  await banco.privado(uid, "contactos", id).set({
    ...contacto,
    actualizado: banco.ahora(),
  });
  return { id, ...contacto };
}

export async function pagarExterno(banco, auth, d) {
  const uid = banco.actor(auth),
    cuenta = identificador(d.cuenta),
    id = referencia(d.referencia),
    destino = identificador(d.destino),
    tipo = d.tipo;
  if (!["tarjeta", "contacto"].includes(tipo))
    falla("invalid-argument", "Revisa el destino del pago.");
  const importe = entero(d.centavos, "el monto", 10, 10000),
    fecha = banco.ahora(),
    fingerprint = huella([cuenta, destino, tipo, importe]);
  return banco.db.runTransaction(async (tx) => {
    const refRecibo = banco.privado(uid, "operaciones", id),
      previo = await tx.get(refRecibo);
    if (previo.exists) {
      if (previo.data().huella !== fingerprint)
        falla("already-exists", "La referencia ya fue usada.");
      return previo.data().recibo;
    }
    const entidad = await tx.get(
      banco.privado(
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
    const ref = banco.cuenta(uid, cuenta),
      c = banco.cuentaDisponible(await tx.get(ref));
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
    banco.registrarMovimiento(tx, uid, cuenta, id, movimiento);
    tx.create(
      banco
        .privado(uid, tipo === "tarjeta" ? "tarjetas" : "contactos", destino)
        .collection("movimientos")
        .doc(id),
      movimiento,
    );
    tx.create(refRecibo, { huella: fingerprint, recibo, fecha });
    return recibo;
  });
}
