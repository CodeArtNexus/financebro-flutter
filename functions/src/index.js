import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getMessaging } from "firebase-admin/messaging";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { Banco, FalloBanco } from "./banca.js";
import { logger } from "firebase-functions";
import { OPERACIONES } from "./contratos.js";
import { observarOperacion } from "./observacion.js";
import { procesarAviso, FirebaseBandejaAvisos } from "./avisos.js";

initializeApp();
setGlobalOptions({
  region: "us-central1",
  minInstances: 0,
  maxInstances: 1,
  memory: "256MiB",
  timeoutSeconds: 60,
});
const db = getFirestore();
const banco = new Banco(db, { bucket: getStorage().bucket() });
export const banca = onCall({ cors: true }, async (request) =>
  observarOperacion(
    {
      operacion: request.data?.operacion,
      referencia: request.data?.datos?.referencia,
    },
    async () => {
      try {
        if (request.data?.operacion === "procesarAutopagos") {
          if (!request.auth)
            throw new FalloBanco("unauthenticated", "Ingresa para continuar.");
          if (request.auth.token.financebroAdmin !== true)
            throw new FalloBanco(
              "permission-denied",
              "Esta acción requiere acceso administrativo.",
            );
          throw new FalloBanco(
            "failed-precondition",
            "Cada pago mensual requiere confirmación del titular. No hay débitos programados activos.",
          );
        }
        return await banco.ejecutar(
          request.auth,
          request.data?.operacion,
          request.data?.datos,
        );
      } catch (error) {
        if (error instanceof FalloBanco)
          throw new HttpsError(error.codigo, error.message);
        // No registrar documentos, identificaciones, saldos ni tokens en los logs.

        throw new HttpsError(
          "unavailable",
          "No pudimos completar la operación. Reintenta con la misma referencia.",
        );
      }
    },
    {
      permitidas: OPERACIONES,
      registrar: (evento, datos) =>
        datos.categoria === "tecnico"
          ? logger.error(evento, datos)
          : logger.info(evento, datos),
    },
  ),
);
// La evaluación no despliega cobros ni pagos programados.
export const enviarAviso = onDocumentCreated(
  { document: "enviosPush/{evento}", retry: true },
  async (event) =>
    procesarAviso(event.params.evento, {
      repositorio: new FirebaseBandejaAvisos(db),
      mensajeria: getMessaging(),
      emulado: process.env.FUNCTIONS_EMULATOR === "true",
    }),
);
