import {
  collection,
  collectionGroup,
  query,
  limit,
  onSnapshot,
  orderBy,
} from "firebase/firestore";
import {
  getStorage,
  connectStorageEmulator,
  ref,
  getBytes,
} from "firebase/storage";
import { dinero, centavos } from "./dinero.js";
export function iniciarBanca({
  app,
  db,
  ejecutar,
  avisar,
  fallo,
  escapar,
  local,
}) {
  const $ = (id) => document.getElementById(id),
    storage = getStorage(app);
  let suscripciones = [],
    solicitudes = [],
    servicios = [];
  if (local)
    connectStorageEmulator(
      storage,
      "127.0.0.1",
      Number(import.meta.env.VITE_STORAGE_PORT ?? 9199),
    );
  const observar = (consulta, guardar) =>
    suscripciones.push(
      onSnapshot(
        consulta,
        (s) =>
          guardar(
            s.docs.map((d) => ({ id: d.id, ruta: d.ref.path, ...d.data() })),
          ),
        (e) => avisar(fallo(e), true),
      ),
    );
  function renderSolicitudes() {
    $("solicitudes-lista").innerHTML = solicitudes.length
      ? solicitudes
          .map(
            (s) =>
              `<article class="solicitud"><div class="cabecera"><div><h2>${escapar(s.empresa)}</h2><p>${escapar(s.representante)} · RUC ${escapar(s.ruc)}<br>${escapar(s.estado)} · ${s.depositoCentavos ? dinero(s.depositoCentavos) : s.escala === "pyme" ? "Depósito USD 1.000" : "Depósito USD 2.000"}</p></div></div><div class="documentos">${Object.entries(
                s.documentos ?? {},
              )
                .map(
                  ([k, d]) =>
                    `<button class="secundario" data-documento="${escapar(d.ruta)}">${escapar(k)} · ${escapar(d.nombre)}</button>`,
                )
                .join(
                  "",
                )}</div>${s.nota ? `<p>${escapar(s.nota)}</p>` : ""}<div class="acciones">${s.estado === "revision" ? `<button class="secundario" data-revision="corregir" data-uid="${escapar(s.uid)}">Solicitar correcciones</button><button class="primario" data-revision="aprobar" data-uid="${escapar(s.uid)}">Aprobar cuenta temporal</button>` : ""}${s.estado === "deposito" ? `<button class="primario" data-revision="activar" data-uid="${escapar(s.uid)}">Validar depósito y activar</button>` : ""}</div></article>`,
          )
          .join("")
      : '<p class="vacio">Las solicitudes enviadas aparecerán aquí.</p>';
  }
  $("solicitudes-lista").addEventListener("click", async (e) => {
    const doc = e.target.closest("[data-documento]");
    if (doc) {
      doc.disabled = true;
      try {
        const datos = await getBytes(
          ref(storage, doc.dataset.documento),
          5 * 1024 * 1024,
        );
        const extension = doc.dataset.documento.split(".").pop();
        const url = URL.createObjectURL(
          new Blob([datos], {
            type:
              extension === "pdf"
                ? "application/pdf"
                : extension === "png"
                  ? "image/png"
                  : "image/jpeg",
          }),
        );
        const a = document.createElement("a");
        a.href = url;
        a.download = doc.dataset.documento.split("/").pop();
        a.click();
        setTimeout(() => URL.revokeObjectURL(url), 30000);
      } catch (error) {
        avisar(fallo(error), true);
      } finally {
        doc.disabled = false;
      }
      return;
    }
    const boton = e.target.closest("[data-revision]");
    if (!boton) return;
    const dialog = document.createElement("dialog"),
      form = document.createElement("form");
    form.innerHTML = `<h2>Revisar solicitud</h2><p>${boton.dataset.revision === "activar" ? "Se comprobará el depósito antes de habilitar la cuenta." : "La decisión quedará registrada con tu identidad de asesor."}</p><label>Observación<textarea name="nota" minlength="5" maxlength="200" required></textarea></label><div class="acciones"><button type="button" class="secundario">Volver</button><button class="primario" type="submit">Confirmar revisión</button></div>`;
    dialog.append(form);
    document.body.append(dialog);
    form.querySelector("[type=button]").onclick = () => dialog.close();
    form.onsubmit = async (evento) => {
      evento.preventDefault();
      evento.submitter.disabled = true;
      try {
        await ejecutar("revisarSolicitud", {
          uid: boton.dataset.uid,
          accion: boton.dataset.revision,
          nota: new FormData(form).get("nota"),
        });
        dialog.close();
        avisar("Revisión guardada. La persona verá el nuevo estado en la app.");
      } catch (error) {
        avisar(fallo(error), true);
      } finally {
        evento.submitter.disabled = false;
      }
    };
    dialog.addEventListener("close", () => dialog.remove());
    dialog.showModal();
  });
  $("servicio-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    e.submitter.disabled = true;
    try {
      await ejecutar("guardarServicio", {
        id: $("servicio-id").value.trim(),
        nombre: $("servicio-nombre").value,
        icono: $("servicio-icono").value,
        baseCentavos: centavos($("servicio-base").value),
        activo: $("servicio-activo").value === "true",
      });
      avisar("Servicio actualizado en el catálogo de la app.");
    } catch (error) {
      avisar(fallo(error), true);
    } finally {
      e.submitter.disabled = false;
    }
  });
  $("servicios-lista").addEventListener("click", (e) => {
    const boton = e.target.closest("[data-servicio]");
    if (!boton) return;
    const s = servicios.find((s) => s.id === boton.dataset.servicio);
    $("servicio-id").value = s.id;
    $("servicio-nombre").value = s.nombre;
    $("servicio-icono").value = s.icono;
    $("servicio-base").value = (s.baseCentavos / 100).toFixed(2);
    $("servicio-activo").value = String(s.activo);
  });
  $("procesar-autopagos").addEventListener("click", async (e) => {
    e.target.disabled = true;
    try {
      const r = await ejecutar("procesarAutopagos");
      avisar(
        `${r.procesados} pagos vencidos procesados. Revisa los estados y movimientos.`,
      );
    } catch (error) {
      avisar(fallo(error), true);
    } finally {
      e.target.disabled = false;
    }
  });
  return {
    escuchar() {
      observar(collectionGroup(db, "solicitudes"), (items) => {
        solicitudes = items.filter((s) =>
          ["revision", "deposito", "activa", "correcciones"].includes(s.estado),
        );
        renderSolicitudes();
      });
      observar(collection(db, "servicios"), (items) => {
        servicios = items;
        $("servicios-lista").innerHTML =
          items
            .map(
              (s) =>
                `<button class="cuenta" data-servicio="${escapar(s.id)}"><span><strong>${escapar(s.nombre)}</strong><small>${escapar(s.id)} · ${s.activo ? "Habilitado" : "Deshabilitado"}</small></span><span>${dinero(s.baseCentavos)}</span></button>`,
            )
            .join("") || "<p>Agrega tu primer servicio.</p>";
      });
      observar(query(collectionGroup(db, "autopagos"), limit(100)), (items) => {
        $("autopagos-lista").innerHTML =
          items
            .map(
              (a) =>
                `<div class="cuenta"><span><strong>${escapar(a.nombre)} · ${escapar(a.contrato)}</strong><small>${escapar(a.uid)} · ${a.activo ? "Activo" : "Pausado"} · ${escapar(a.siguiente)} · ${escapar(a.ultimoEstado ?? "Preparado")}</small></span><span>${dinero(a.maximoCentavos)}</span></div>`,
            )
            .join("") || "<p>Aún no hay pagos mensuales.</p>";
      });
    },
    detener() {
      for (const s of suscripciones) s();
      suscripciones = [];
      solicitudes = [];
      servicios = [];
      $("solicitudes-lista").replaceChildren();
      $("servicios-lista").replaceChildren();
      $("autopagos-lista").replaceChildren();
    },
  };
}
