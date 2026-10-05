import { randomBytes } from "node:crypto";
import { Timestamp } from "firebase-admin/firestore";
import {
  identificador,
  texto,
  falla,
  entero,
  MAX_SALDO,
} from "./compartido.js";

// Núcleo transaccional compartido; una operación conserva saldo, comprobante e históricos.
export class BancoBase {
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
}
