import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getMessaging } from "firebase-admin/messaging";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";
import { Banco, FalloBanco } from "./banca.js";

initializeApp();
setGlobalOptions({
  region: "us-central1",
  minInstances: 0,
  maxInstances: 2,
  memory: "256MiB",
  timeoutSeconds: 60,
});
const db = getFirestore();
const banco = new Banco(db, { bucket: getStorage().bucket() });
export const banca = onCall({ cors: true }, async (request) => {
  try {
    return await banco.ejecutar(
      request.auth,
      request.data?.operacion,
      request.data?.datos,
    );
  } catch (error) {
    if (error instanceof FalloBanco)
      throw new HttpsError(error.codigo, error.message);
    // No registrar documentos, identificaciones, saldos ni tokens en los logs.
    console.error("operacion_bancaria_interrumpida", {
      codigo: error.code ?? "desconocido",
    });
    throw new HttpsError(
      "unavailable",
      "No pudimos completar la operación. Reintenta con la misma referencia.",
    );
  }
});
export const pagosMensuales = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "America/Guayaquil",
    maxInstances: 1,
    timeoutSeconds: 300,
  },
  async () => banco.procesarAutopagos(),
);

export const enviarAviso = onDocumentCreated(
  { document: "enviosPush/{evento}", retry: true },
  async (event) => {
    const ref = event.data.ref,
      envio = (await ref.get()).data();
    if (
      !envio ||
      envio.estado === "enviado" ||
      envio.estado === "sin_dispositivo" ||
      envio.estado === "demostracion"
    )
      return;
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      await ref.update({
        estado: "demostracion",
        procesado: FieldValue.serverTimestamp(),
      });
      return;
    }
    const dispositivos = await db
      .collection(`usuarios/${envio.uid}/dispositivos`)
      .limit(100)
      .get();
    const validos = dispositivos.docs.filter(
      (d) => typeof d.data().token === "string" && d.data().token.length > 0,
    );
    const tokens = envio.tokensPendientes ?? validos.map((d) => d.data().token);
    if (!tokens.length) {
      await ref.update({
        estado: "sin_dispositivo",
        procesado: FieldValue.serverTimestamp(),
      });
      return;
    }
    const resultado = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: envio.titulo, body: envio.cuerpo },
      data: {
        uid: envio.uid,
        ruta: envio.destino,
        evento: event.params.evento,
      },
      android: { notification: { tag: event.params.evento } },
      apns: {
        headers: { "apns-collapse-id": event.params.evento.slice(0, 64) },
      },
    });
    const pendientes = [];
    for (let i = 0; i < resultado.responses.length; i++) {
      const r = resultado.responses[i];
      if (
        !r.success &&
        [
          "messaging/registration-token-not-registered",
          "messaging/invalid-registration-token",
        ].includes(r.error?.code)
      )
        await Promise.all(
          validos
            .filter((d) => d.data().token === tokens[i])
            .map((d) => d.ref.delete()),
        );
      else if (!r.success) pendientes.push(tokens[i]);
    }
    if (pendientes.length) {
      // Guardar solo los destinatarios pendientes evita reenviar a quienes ya recibieron el evento.
      await ref.update({
        estado: "reintento",
        tokensPendientes: pendientes,
        procesado: FieldValue.serverTimestamp(),
      });
      throw new Error("entrega_push_pendiente");
    }
    await ref.update({
      estado: "enviado",
      tokensPendientes: FieldValue.delete(),
      procesado: FieldValue.serverTimestamp(),
    });
  },
);
