import "./estilo.css";
import { initializeApp } from "firebase/app";
import {
  getAuth,
  setPersistence,
  browserSessionPersistence,
  signInWithEmailAndPassword,
  onAuthStateChanged,
  signOut,
  connectAuthEmulator,
} from "firebase/auth";
import {
  getFirestore,
  connectFirestoreEmulator,
  collection,
  collectionGroup,
  onSnapshot,
} from "firebase/firestore";
import QRCode from "qrcode";
import { firebaseConfig } from "./firebase-config.js";
import { centavos, dinero } from "./dinero.js";
import {
  getFunctions,
  connectFunctionsEmulator,
  httpsCallable,
} from "firebase/functions";
import { iniciarBanca } from "./banca.js";
import { observarHistorial } from "./historial.js";
const local = import.meta.env.VITE_USE_EMULATORS === "true";
const app = initializeApp(
  local
    ? {
        apiKey: "demo-key",
        projectId: "demo-financebro",
        appId: "demo-admin",
        authDomain: "localhost",
        storageBucket: "demo-financebro.appspot.com",
      }
    : firebaseConfig,
);
const auth = getAuth(app),
  db = getFirestore(app),
  functions = getFunctions(app, "us-central1");
const ejecutar = async (operacion, datos = {}) =>
  (await httpsCallable(functions, "banca")({ operacion, datos })).data;
if (local) {
  connectAuthEmulator(
    auth,
    `http://127.0.0.1:${import.meta.env.VITE_AUTH_PORT ?? 9099}`,
    { disableWarnings: true },
  );
  connectFirestoreEmulator(
    db,
    "127.0.0.1",
    Number(import.meta.env.VITE_FIRESTORE_PORT ?? 8080),
  );
}
if (local)
  connectFunctionsEmulator(
    functions,
    "127.0.0.1",
    Number(import.meta.env.VITE_FUNCTIONS_PORT ?? 5001),
  );
await setPersistence(auth, browserSessionPersistence);
const $ = (id) => document.getElementById(id);
const escapar = (valor) =>
  String(valor ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
let usuarios = [],
  cuentas = [],
  movimientos = [],
  detalles = [],
  seleccion = null,
  desuscribir = [],
  detalleHistorial = null,
  globalHistorial = null,
  mensajeTimer = null,
  ajustePendiente = null;
function avisar(texto, error = false) {
  clearTimeout(mensajeTimer);
  $("mensaje").textContent = texto;
  $("mensaje").classList.remove("oculto");
  $("mensaje").classList.toggle("error", error);
  mensajeTimer = setTimeout(
    () => $("mensaje").classList.add("oculto"),
    error ? 12000 : 7000,
  );
}
function fallo(error) {
  const codigo = error?.code ?? "";
  if (codigo.includes("permission-denied"))
    return "Tu cuenta no tiene permiso para realizar esta operación.";
  if (codigo.includes("unavailable") || codigo.includes("network"))
    return "No hay conexión con el servicio. Revisa tu red y vuelve a intentar.";
  if (codigo.startsWith("auth/"))
    return "No se pudo ingresar. Revisa tus credenciales y la conexión.";
  return error?.message ?? "No se pudo completar la operación.";
}
const bancoPanel = iniciarBanca({
  app,
  db,
  ejecutar,
  avisar,
  fallo,
  escapar,
  local,
});
function detener() {
  bancoPanel.detener();
  for (const cancelar of desuscribir) cancelar();
  desuscribir = [];
  detalleHistorial?.detener();
  globalHistorial?.detener();
  detalleHistorial = globalHistorial = null;
  $("mas-detalle").classList.add("oculto");
  $("mas-movimientos").classList.add("oculto");
  usuarios = [];
  cuentas = [];
  movimientos = [];
  detalles = [];
  seleccion = null;
  ajustePendiente = null;
}
function persona(uid) {
  return usuarios.find((u) => u.id === uid)?.nombre ?? "Persona registrada";
}
function cuentaSeleccionada() {
  return cuentas.find((c) => c.ruta === seleccion);
}
function fechas(fecha) {
  return fecha?.toDate
    ? new Intl.DateTimeFormat("es-EC", {
        dateStyle: "short",
        timeStyle: "short",
      }).format(fecha.toDate())
    : "Sincronizando…";
}
function tabla(items, global = false) {
  if (!items.length)
    return '<p class="vacio">Todavía no hay movimientos en esta vista.</p>';
  return `<div class="tabla-scroll"><table><thead><tr>${global ? "<th>Persona / Cuenta</th>" : ""}<th>Movimiento</th><th>Fecha</th><th>Importe</th><th>Referencia</th></tr></thead><tbody>${items.map((m) => `<tr>${global ? `<td>${escapar(persona(m.uid))}<small>${escapar(cuentas.find((c) => c.uid === m.uid && c.id === m.cuenta)?.nombre ?? (m.cuenta === "tarjeta_bro_credito" ? "Tarjeta de crédito" : m.cuenta))}</small></td>` : ""}<td>${escapar(m.descripcion)}<small>${escapar(m.categoria)}${m.actor ? ` · ${escapar(m.actor)}` : ""}</small></td><td>${escapar(fechas(m.fecha))}</td><td class="importe ${m.centavos >= 0 ? "ingreso" : "gasto"}">${m.centavos > 0 ? "+" : ""}${escapar(dinero(m.centavos))}</td><td><small>${escapar(m.referencia ?? m.id)}</small></td></tr>`).join("")}</tbody></table></div>`;
}
function render() {
  $("metricas").innerHTML = [
    ["Personas registradas", usuarios.length],
    ["Cuentas asociadas", cuentas.length],
    [
      "Fondos registrados",
      dinero(cuentas.reduce((s, c) => s + c.saldoCentavos, 0)),
    ],
  ]
    .map(
      ([label, valor]) =>
        `<div class="cristal metrica"><span>${escapar(label)}</span><strong>${escapar(valor)}</strong></div>`,
    )
    .join("");
  const filtro = $("buscar").value.toLocaleLowerCase("es");
  const visibles = cuentas.filter((c) =>
    `${persona(c.uid)} ${c.uid} ${c.nombre}`
      .toLocaleLowerCase("es")
      .includes(filtro),
  );
  $("cuentas").innerHTML = visibles.length
    ? visibles
        .map(
          (c) =>
            `<button class="cuenta" data-cuenta="${escapar(c.ruta)}" aria-pressed="${c.ruta === seleccion}"><span><strong>${escapar(persona(c.uid))}</strong><small>${escapar(c.nombre)} · ${escapar(c.numeroCuenta ?? c.numero)} · ${escapar(c.tipo ?? "Ahorros")} · ${escapar(c.estado ?? "Preparación")}</small></span><span>${escapar(dinero(c.saldoCentavos))} →</span></button>`,
        )
        .join("")
    : '<p class="vacio">No hay cuentas para esta búsqueda. Puedes asignar una a una persona registrada.</p>';
  const seleccionada = cuentaSeleccionada();
  $("cuenta-titulo").textContent = seleccionada?.nombre ?? "Elige una cuenta";
  $("cuenta-subtitulo").textContent = seleccionada
    ? `${persona(seleccionada.uid)} · ${dinero(seleccionada.saldoCentavos)}`
    : "Sus fondos y movimientos aparecerán aquí.";
  $("ajuste").querySelector("button").disabled =
    !seleccionada || !auth.currentUser;
  $("global-movimientos").innerHTML = tabla(movimientos, true);
  $("detalle-movimientos").innerHTML = seleccion
    ? tabla(detalles)
    : '<p class="vacio">Selecciona una cuenta para consultar su histórico.</p>';
  const qrActual = $("cuenta-qr").value;
  $("cuenta-qr").innerHTML = cuentas
    .filter((c) => c.numeroCuenta)
    .map(
      (c) =>
        `<option value="${escapar(c.ruta)}">${escapar(persona(c.uid))} · ${escapar(c.tipo)} · ${escapar(c.numeroCuenta)}</option>`,
    )
    .join("");
  if (cuentas.some((c) => c.ruta === qrActual)) $("cuenta-qr").value = qrActual;
  const actual = $("persona-cuenta").value;
  $("persona-cuenta").innerHTML = usuarios
    .map(
      (u) =>
        `<option value="${escapar(u.id)}">${escapar(u.nombre)} · ${escapar(u.id.slice(0, 8))}</option>`,
    )
    .join("");
  if (usuarios.some((u) => u.id === actual)) $("persona-cuenta").value = actual;
  $("asignar").disabled = !usuarios.length;
}
function escuchar(origen, guardar) {
  return onSnapshot(
    origen,
    { includeMetadataChanges: true },
    (snapshot) => {
      guardar(
        snapshot.docs.map((d) => ({ id: d.id, ruta: d.ref.path, ...d.data() })),
      );
      const cache = snapshot.metadata.fromCache;
      $("panel").querySelector(".estado").innerHTML = cache
        ? "Datos guardados · reconectando"
        : "<i></i> Datos en vivo";
      render();
    },
    (error) => avisar(fallo(error), true),
  );
}
function historial(origen, boton, guardar) {
  return observarHistorial({
    origen,
    cambiar: (items) => {
      guardar(items);
      render();
    },
    estado: ({ mas, ocupado }) => {
      $(boton).classList.toggle("oculto", !mas);
      $(boton).disabled = ocupado;
    },
    fallo: (e) => avisar(fallo(e), true),
  });
}
$("mas-movimientos").addEventListener("click", () => globalHistorial?.mas());
$("mas-detalle").addEventListener("click", () => detalleHistorial?.mas());
function seleccionar(ruta) {
  seleccion = ruta;
  detalles = [];
  detalleHistorial?.detener();
  detalleHistorial = historial(
    collection(db, `${ruta}/movimientos`),
    "mas-detalle",
    (items) => {
      detalles = items;
    },
  );
  render();
}
onAuthStateChanged(auth, async (usuario) => {
  detener();
  $("panel").classList.add("oculto");
  $("acceso").classList.remove("oculto");
  $("salir").classList.add("oculto");
  if (!usuario) return;
  try {
    const token = await usuario.getIdTokenResult(true);
    if (auth.currentUser?.uid !== usuario.uid) return;
    if (token.claims.financebroAdmin !== true) {
      await signOut(auth);
      avisar(
        "Esta cuenta no está habilitada para administrar FinanceBro.",
        true,
      );
      return;
    }
    $("clave").value = "";
    $("panel").classList.remove("oculto");
    $("acceso").classList.add("oculto");
    $("salir").classList.remove("oculto");
    $("identidad").textContent =
      `${usuario.email} · ${local ? "Emuladores locales" : "Conectado a Firebase"}`;
    bancoPanel.escuchar();
    desuscribir.push(
      escuchar(collection(db, "usuarios"), (items) => (usuarios = items)),
    );
    desuscribir.push(
      escuchar(
        collectionGroup(db, "cuentas"),
        (items) =>
          (cuentas = items.map((c) => ({ ...c, uid: c.ruta.split("/")[1] }))),
      ),
    );
    globalHistorial = historial(
      collectionGroup(db, "movimientosGlobales"),
      "mas-movimientos",
      (items) => {
        movimientos = items.map((m) => ({
          ...m,
          uid: m.ruta.split("/")[1],
          cuenta: m.cuenta,
        }));
      },
    );
  } catch (error) {
    await signOut(auth);
    avisar(fallo(error), true);
  }
});
$("login").addEventListener("submit", async (e) => {
  e.preventDefault();
  const boton = e.submitter;
  boton.disabled = true;
  try {
    await signInWithEmailAndPassword(
      auth,
      $("correo").value.trim(),
      $("clave").value,
    );
  } catch (error) {
    avisar(fallo(error), true);
  } finally {
    boton.disabled = false;
  }
});
$("salir").addEventListener("click", async () => {
  try {
    await signOut(auth);
    $("importe").value = "";
    $("motivo").value = "";
  } catch (error) {
    avisar(fallo(error), true);
  }
});
$("buscar").addEventListener("input", render);
$("cuentas").addEventListener("click", (e) => {
  const boton = e.target.closest("[data-cuenta]");
  if (boton) seleccionar(boton.dataset.cuenta);
});
document.querySelector(".pestanas").addEventListener("click", (e) => {
  const boton = e.target.closest("[data-vista]");
  if (!boton) return;
  for (const b of document.querySelectorAll("[data-vista]"))
    b.removeAttribute("aria-current");
  boton.setAttribute("aria-current", "page");
  for (const id of ["cuentas", "movimientos", "qr", "solicitudes", "tarjetas", "servicios", "experiencia", "chequera"])
    $(`vista-${id}`).classList.toggle("oculto", id !== boton.dataset.vista);
});
$("ajuste").addEventListener("submit", (e) => {
  e.preventDefault();
  try {
    const cuenta = cuentaSeleccionada();
    if (!cuenta) throw new Error("Selecciona una cuenta.");
    const delta = centavos($("importe").value, { negativo: true }),
      motivo = $("motivo").value.trim();
    if (motivo.length < 5 || motivo.length > 120)
      throw new Error("Escribe un motivo de 5 a 120 caracteres.");
    if (
      cuenta.saldoCentavos + delta < 0 ||
      cuenta.saldoCentavos + delta > 100000000
    )
      throw new Error("Revisa el saldo que resultaría del ajuste.");
    // Mantiene la referencia si se reintenta el mismo ajuste tras una respuesta incierta.
    if (
      !ajustePendiente ||
      ajustePendiente.ruta !== seleccion ||
      ajustePendiente.delta !== delta ||
      ajustePendiente.motivo !== motivo
    )
      ajustePendiente = {
        ruta: seleccion,
        uid: cuenta.uid,
        cuenta: cuenta.id,
        delta,
        motivo,
        id: crypto.randomUUID(),
      };
    $("confirmacion-texto").textContent =
      `${delta > 0 ? "Agregar" : "Retirar"} ${dinero(Math.abs(delta))} a ${cuenta.nombre} de ${persona(cuenta.uid)}. Saldo previsto: ${dinero(cuenta.saldoCentavos + delta)}.`;
    $("confirmacion-motivo").textContent = motivo;
    $("confirmacion").showModal();
  } catch (error) {
    avisar(fallo(error), true);
  }
});
$("confirmacion").addEventListener("close", async () => {
  if ($("confirmacion").returnValue !== "confirmar" || !ajustePendiente) return;
  const boton = $("ajuste").querySelector("button");
  boton.disabled = true;
  const p = ajustePendiente;
  try {
    await ejecutar("ajustar", {
      uid: p.uid,
      cuenta: p.cuenta,
      centavos: p.delta,
      motivo: p.motivo,
      referencia: p.id,
    });
    ajustePendiente = null;
    $("importe").value = "";
    $("motivo").value = "";
    avisar("Fondos actualizados. El ajuste quedó en el histórico.");
  } catch (error) {
    avisar(fallo(error), true);
  } finally {
    boton.disabled = !cuentaSeleccionada();
  }
});
$("asignar").addEventListener("click", () => {
  $("nueva-cuenta").showModal();
});
$("cancelar-cuenta").addEventListener("click", () => {
  $("nueva-cuenta").close();
});
$("form-cuenta").addEventListener("submit", async (e) => {
  e.preventDefault();
  e.submitter.disabled = true;
  try {
    await ejecutar("migrarCuentas", { uid: $("persona-cuenta").value });
    $("nueva-cuenta").close();
    avisar("Cuentas preparadas sin cambiar fondos ni movimientos.");
  } catch (error) {
    avisar(fallo(error), true);
  } finally {
    e.submitter.disabled = false;
  }
});
$("crear-qr").addEventListener("submit", async (e) => {
  e.preventDefault();
  try {
    const c = cuentas.find((c) => c.ruta === $("cuenta-qr").value);
    if (!c?.numeroCuenta)
      throw new Error("Prepara el número de esa cuenta primero.");
    const codigo = `financebro://transferir?cuenta=${c.numeroCuenta}&v=1`;
    const url = await QRCode.toDataURL(codigo, {
      width: 480,
      margin: 2,
      errorCorrectionLevel: "M",
      color: { dark: "#242735", light: "#ffffff" },
    });
    const imagen = new Image();
    imagen.src = url;
    imagen.alt = "QR de la cuenta receptora FinanceBro";
    $("imagen-qr").replaceChildren(imagen);
    $("total-qr").textContent = persona(c.uid);
    $("referencia-qr").textContent = `Cuenta: ${c.numeroCuenta}`;
    $("contenido-qr").value = codigo;
    $("contenido-qr").classList.remove("oculto");
    $("copiar-qr").classList.remove("oculto");
  } catch (error) {
    avisar(fallo(error), true);
  }
});
$("copiar-qr").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText($("contenido-qr").value);
    avisar("Código copiado. Puedes pegarlo en la app.");
  } catch {
    $("contenido-qr").select();
    avisar("Selecciona y copia el código mostrado.");
  }
});
