// Casos de uso del dominio; BancoBase conserva las escrituras monetarias compartidas.
import {
  falla,
  texto,
  identificador,
  numeroCuenta,
  DOCUMENTOS,
} from "../compartido.js";
import { randomBytes } from "node:crypto";

export async function guardarSolicitud(banco, auth, d) {
  const uid = banco.actor(auth);
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
  return banco.db.runTransaction(async (tx) => {
    const ref = banco.privado(uid, "solicitudes", "corriente"),
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
        actualizado: banco.ahora(),
        documentos: previo.data()?.documentos ?? {},
      },
      { merge: true },
    );
    return { id: "corriente", estado: "borrador" };
  });
}

export async function registrarDocumento(banco, auth, d) {
  const uid = banco.actor(auth),
    categoria = d.categoria;
  if (
    !DOCUMENTOS.includes(categoria) ||
    typeof d.ruta !== "string" ||
    !new RegExp(
      `^expedientes/${uid}/corriente/${categoria}/[a-zA-Z0-9_-]{8,80}\\.(pdf|png|jpg)$`,
    ).test(d.ruta)
  )
    falla("invalid-argument", "El documento no corresponde a tu solicitud.");
  if (!banco.bucket)
    falla("unavailable", "El almacenamiento aún no está disponible.");
  const archivo = banco.bucket.file(d.ruta);
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
  await banco.db.runTransaction(async (tx) => {
    const ref = banco.privado(uid, "solicitudes", "corriente"),
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
        actualizado: banco.ahora(),
      },
      actualizado: banco.ahora(),
    });
  });
  return { categoria, guardado: true };
}

export async function enviarSolicitud(banco, auth, d = {}) {
  const uid = banco.actor(auth);
  if (d.acepta !== true)
    falla(
      "failed-precondition",
      "Autoriza la revisión de tus documentos antes de enviar.",
    );
  return banco.db.runTransaction(async (tx) => {
    const ref = banco.privado(uid, "solicitudes", "corriente"),
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
      consentimiento: banco.ahora(),
      enviado: banco.ahora(),
      actualizado: banco.ahora(),
    });
    return { estado: "revision" };
  });
}

export async function revisarSolicitud(banco, auth, d) {
  const actor = banco.actor(auth, true),
    uid = identificador(d.uid),
    accion = d.accion,
    nota = texto(d.nota, "la observación", 5, 200),
    fecha = banco.ahora();
  if (!["aprobar", "corregir", "activar"].includes(accion))
    falla("invalid-argument", "Revisa la acción.");
  if (actor === uid)
    falla("permission-denied", "Otro asesor debe revisar tu solicitud.");
  const nueva = banco.nuevaCuenta("corriente", fecha);
  return banco.db.runTransaction(async (tx) => {
    const solicitudRef = banco.privado(uid, "solicitudes", "corriente"),
      s = await tx.get(solicitudRef);
    if (!s.exists) falla("not-found", "No encontramos la solicitud.");
    const cRef = banco.cuenta(uid, "corriente"),
      c = await tx.get(cRef),
      directorio = banco.db.doc(`directorioCuentas/${nueva.numeroCuenta}`),
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
      banco.privado(
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
