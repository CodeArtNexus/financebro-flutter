import { randomUUID } from "node:crypto";
import { FieldValue } from "firebase-admin/firestore";

const TERMINALES = new Set([
  "enviado",
  "sin_dispositivo",
  "demostracion",
  "fallido",
]);
const INVALIDOS = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);
export class EntregaPendiente extends Error {
  constructor() {
    super("entrega_push_pendiente");
  }
}

// El transporte es sustituible; la bandeja y el dinero tienen ciclos separados.
export async function procesarAviso(
  evento,
  {
    repositorio,
    mensajeria,
    reloj = Date.now,
    intento = randomUUID(),
    emulado = false,
  },
) {
  const envio = await repositorio.reservar(evento, intento, reloj());
  if (!envio) return;
  const guardar = (estado, tokensPendientes) =>
    repositorio.finalizar(evento, intento, estado, tokensPendientes);
  if (emulado) {
    await guardar("demostracion");
    return;
  }
  let pendientes;
  try {
    const dispositivos = await repositorio.dispositivos(envio.uid);
    const activos = [
      ...new Set(
        dispositivos
          .map((d) => d.token)
          .filter((t) => typeof t === "string" && t.length > 0),
      ),
    ];
    const tokens = envio.tokensPendientes
      ? activos.filter((t) => envio.tokensPendientes.includes(t))
      : activos;
    if (!tokens.length) {
      await guardar("sin_dispositivo");
      return;
    }
    const resultado = await mensajeria.sendEachForMulticast({
      tokens,
      notification: { title: envio.titulo, body: envio.cuerpo },
      data: { uid: envio.uid, ruta: envio.destino, evento },
      android: { notification: { tag: evento } },
      apns: { headers: { "apns-collapse-id": evento.slice(0, 64) } },
    });
    if (resultado.responses.length !== tokens.length)
      throw new EntregaPendiente();
    pendientes = [];
    let entregados = 0;
    for (let i = 0; i < tokens.length; i++) {
      const respuesta = resultado.responses[i];
      if (respuesta.success) entregados++;
      else if (INVALIDOS.has(respuesta.error?.code)) {
        await Promise.all(
          dispositivos
            .filter((d) => d.token === tokens[i])
            .map((d) => repositorio.descartar(envio.uid, d)),
        );
      } else pendientes.push(tokens[i]);
    }
    if (pendientes.length) throw new EntregaPendiente();
    if (!(await guardar(entregados ? "enviado" : "sin_dispositivo")))
      throw new EntregaPendiente();
  } catch (error) {
    await guardar(envio.intentos >= 3 ? "fallido" : "reintento", pendientes);
    if (envio.intentos < 3) throw error;
  }
}

export class FirebaseBandejaAvisos {
  constructor(db, { coleccion = "enviosPush" } = {}) {
    this.db = db;
    this.coleccion = coleccion;
  }
  referencia(evento) {
    return this.db.doc(`${this.coleccion}/${evento}`);
  }
  async reservar(evento, intento, ahora) {
    const ref = this.referencia(evento);
    return this.db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      if (!doc.exists || TERMINALES.has(doc.data().estado)) return null;
      const envio = doc.data();
      if (envio.reservaHasta?.toMillis() > ahora) throw new EntregaPendiente();
      if ((envio.intentos ?? 0) >= 3) {
        tx.update(ref, {
          estado: "fallido",
          procesado: FieldValue.serverTimestamp(),
        });
        return null;
      }
      const intentos = (envio.intentos ?? 0) + 1;
      tx.update(ref, {
        estado: "procesando",
        intentos,
        reserva: intento,
        reservaHasta: new Date(ahora + 90000),
      });
      return { ...envio, intentos };
    });
  }
  async finalizar(evento, intento, estado, pendientes) {
    const ref = this.referencia(evento);
    return this.db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      if (!doc.exists || doc.data().reserva !== intento) return false;
      const datos = {
        estado,
        procesado: FieldValue.serverTimestamp(),
        reserva: FieldValue.delete(),
        reservaHasta: FieldValue.delete(),
      };
      // Si el transporte cae antes de responder, conservar los pendientes previos.
      if (pendientes !== undefined) datos.tokensPendientes = pendientes;
      else if (TERMINALES.has(estado))
        datos.tokensPendientes = FieldValue.delete();
      tx.update(ref, datos);
      return true;
    });
  }
  async dispositivos(uid) {
    const docs = await this.db
      .collection(`usuarios/${uid}/dispositivos`)
      .limit(100)
      .get();
    return docs.docs.map((d) => ({ id: d.id, token: d.data().token }));
  }
  async descartar(uid, dispositivo) {
    const ref = this.db.doc(`usuarios/${uid}/dispositivos/${dispositivo.id}`);
    await this.db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      // Un token renovado mientras FCM respondía sigue siendo válido.
      if (doc.exists && doc.data().token === dispositivo.token) tx.delete(ref);
    });
  }
}
