import { OPERACIONES } from "./contratos.js";
import { BancoBase } from "./base-banco.js";
import { falla } from "./compartido.js";
import * as chequera from "./chequera.js";
export {
  FalloBanco,
  texto,
  entero,
  identificador,
  referencia,
  numeroCuenta,
  qrCuenta,
  DOCUMENTOS,
  COLORES,
  periodo,
} from "./compartido.js";
import * as onboarding from "./dominios/onboarding.js";
import * as tarjetas from "./dominios/tarjetas.js";
import * as transferencias from "./dominios/transferencias.js";
import * as expedientes from "./dominios/expedientes.js";
import * as servicios from "./dominios/servicios.js";
import * as experiencia from "./dominios/experiencia.js";

// Fachada compatible: compone dominios sin cambiar los contratos ni dividir transacciones.
export class Banco extends BancoBase {
  registrarCliente(...args) {
    return onboarding.registrarCliente(this, ...args);
  }
  abrirAhorros(...args) {
    return onboarding.abrirAhorros(this, ...args);
  }
  migrarCuentas(...args) {
    return onboarding.migrarCuentas(this, ...args);
  }
  solicitarCredito(...args) {
    return tarjetas.solicitarCredito(this, ...args);
  }
  solicitarFisica(...args) {
    return tarjetas.solicitarFisica(this, ...args);
  }
  revisarTarjeta(...args) {
    return tarjetas.revisarTarjeta(this, ...args);
  }
  tarjetaCredito(...args) {
    return tarjetas.tarjetaCredito(this, ...args);
  }
  elegirCorteTarjeta(...args) {
    return tarjetas.elegirCorteTarjeta(this, ...args);
  }
  sincronizarCorte(...args) {
    return tarjetas.sincronizarCorte(this, ...args);
  }
  consultarTarjetaCredito(...args) {
    return tarjetas.consultarTarjetaCredito(this, ...args);
  }
  procesarCortesTarjetas(...args) {
    return tarjetas.procesarCortesTarjetas(this, ...args);
  }
  registrarConsumoTarjeta(...args) {
    return tarjetas.registrarConsumoTarjeta(this, ...args);
  }
  pagarTarjetaCredito(...args) {
    return tarjetas.pagarTarjetaCredito(this, ...args);
  }
  guardarTarjeta(...args) {
    return tarjetas.guardarTarjeta(this, ...args);
  }
  destinatario(...args) {
    return transferencias.destinatario(this, ...args);
  }
  transferir(...args) {
    return transferencias.transferir(this, ...args);
  }
  ajustar(...args) {
    return transferencias.ajustar(this, ...args);
  }
  guardarContacto(...args) {
    return transferencias.guardarContacto(this, ...args);
  }
  pagarExterno(...args) {
    return transferencias.pagarExterno(this, ...args);
  }
  guardarSolicitud(...args) {
    return expedientes.guardarSolicitud(this, ...args);
  }
  registrarDocumento(...args) {
    return expedientes.registrarDocumento(this, ...args);
  }
  enviarSolicitud(...args) {
    return expedientes.enviarSolicitud(this, ...args);
  }
  revisarSolicitud(...args) {
    return expedientes.revisarSolicitud(this, ...args);
  }
  guardarServicio(...args) {
    return servicios.guardarServicio(this, ...args);
  }
  consultarFactura(...args) {
    return servicios.consultarFactura(this, ...args);
  }
  obtenerFactura(...args) {
    return servicios.obtenerFactura(this, ...args);
  }
  pagarServicio(...args) {
    return servicios.pagarServicio(this, ...args);
  }
  configurarAutopago(...args) {
    return servicios.configurarAutopago(this, ...args);
  }
  pausarAutopago(...args) {
    return servicios.pausarAutopago(this, ...args);
  }
  procesarAutopagos(...args) {
    return servicios.procesarAutopagos(this, ...args);
  }
  guardarDecoracion(...args) {
    return experiencia.guardarDecoracion(this, ...args);
  }
  async emitirCheques(auth, d) {
    return chequera.emitirCheques(this, auth, d);
  }
  async gestionarCheque(auth, d) {
    return chequera.gestionarCheque(this, auth, d);
  }
  async cobrarCheque(auth, d) {
    return chequera.cobrarCheque(this, auth, d);
  }
  async procesarCheques(auth, d) {
    return chequera.procesarCheques(this, auth, d);
  }
  async solicitarAsesor(auth, d) {
    return chequera.solicitarAsesor(this, auth, d);
  }
  async responderAsesoria(auth, d) {
    return chequera.responderAsesoria(this, auth, d);
  }
  async ejecutar(auth, operacion, datos = {}) {
    const metodos = OPERACIONES;
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
