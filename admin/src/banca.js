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
    const estados = {
      revision: "En revisión",
      preaprobada: "Preaprobada",
      rechazada: "No aprobada",
      revision_diseno: "Diseño en revisión",
      preparacion: "En preparación",
      enviada: "Envío registrado",
      entregada: "Entrega registrada",
      deposito: "Depósito pendiente",
      activa: "Activa",
      correcciones: "Requiere correcciones",
    };

    const accion = (s, valor, nombre) =>
      `<button class="${valor === "rechazar" ? "secundario" : "primario"}" data-tarjeta-revision="${valor}" data-id="${escapar(s.id)}" data-uid="${escapar(s.uid)}">${nombre}</button>`;
    const tarjeta = (s) =>
      `<article class="solicitud"><div class="cabecera"><div><h2>${s.tipo === "credito" ? "Solicitud de crédito" : "Tarjeta física"} · ${escapar(s.nombre)}</h2><p>${escapar(estados[s.estado] ?? s.estado)}</p></div></div>${s.tipo === "credito" ? `<p>${escapar(s.ocupacion)} · Ingresos mensuales ${dinero(s.ingresosCentavos)}</p><p>Preaprobar registra la evaluación inicial. La emisión y el cupo requieren completar las condiciones con el cliente.</p>` : `<div class="vista-tarjeta tono-${escapar(s.diseno.color)}"><strong>fb.</strong><p>${escapar(s.diseno.nombre)}</p><span>•••• ${escapar(s.diseno.ultimos4)}</span></div><p>${s.personalizada ? "Diseño personalizado · revisión en 3 días" : "Diseño predeterminado"}<br>Envío solicitado: ${escapar(s.fechaEnvio)}<br>${escapar(s.domicilio.direccion)} · ${escapar(s.domicilio.ciudad)}<br>Contacto: ${escapar(s.domicilio.telefono)}</p>`}${s.nota ? `<p>${escapar(s.nota)}</p>` : ""}<div class="acciones">${s.tipo === "credito" && s.estado === "revision" ? accion(s, "rechazar", "No aprobar") + accion(s, "preaprobar", "Preaprobar") : s.estado === "revision_diseno" ? accion(s, "rechazar", "No aprobar diseño") + accion(s, "aprobar_diseno", "Aprobar diseño") : s.estado === "preparacion" ? accion(s, "enviar", "Registrar envío") : s.estado === "enviada" ? accion(s, "entregar", "Registrar entrega") : ""}</div></article>`;
    const corporativa = (s) =>
      `<article class="solicitud"><div class="cabecera"><div><h2>${escapar(s.empresa)}</h2><p>${escapar(s.representante)} · RUC ${escapar(s.ruc)}<br>${escapar(estados[s.estado] ?? s.estado)} · ${s.depositoCentavos ? dinero(s.depositoCentavos) : s.escala === "pyme" ? "Depósito USD 1.000" : "Depósito USD 2.000"}</p></div></div><div class="documentos">${Object.entries(
        s.documentos ?? {},
      )
        .map(
          ([k, d]) =>
            `<button class="secundario" data-documento="${escapar(d.ruta)}">${escapar(k)} · ${escapar(d.nombre)}</button>`,
        )
        .join(
          "",
        )}</div>${s.nota ? `<p>${escapar(s.nota)}</p>` : ""}<div class="acciones">${s.estado === "revision" ? `<button class="secundario" data-revision="corregir" data-uid="${escapar(s.uid)}">Solicitar correcciones</button><button class="primario" data-revision="aprobar" data-uid="${escapar(s.uid)}">Aprobar cuenta temporal</button>` : ""}${s.estado === "deposito" ? `<button class="primario" data-revision="activar" data-uid="${escapar(s.uid)}">Validar depósito y activar</button>` : ""}</div></article>`;
    $("solicitudes-lista").innerHTML = solicitudes.length
      ? solicitudes
          .map((s) =>
            ["credito", "fisica"].includes(s.tipo)
              ? tarjeta(s)
              : corporativa(s),
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
    const boton = e.target.closest("[data-revision], [data-tarjeta-revision]");
    if (!boton) return;
    const dialog = document.createElement("dialog"),
      form = document.createElement("form");
    form.innerHTML = `<h2>Revisar solicitud</h2><p>${boton.dataset.revision === "activar" ? "Se comprobará el depósito antes de habilitar la cuenta." : "La decisión quedará registrada con tu identidad de asesor."}</p><label>Observación<textarea name="nota" minlength="5" maxlength="160" required></textarea></label><div class="acciones"><button type="button" class="secundario">Volver</button><button class="primario" type="submit">Confirmar revisión</button></div>`;
    dialog.append(form);
    document.body.append(dialog);
    form.querySelector("[type=button]").onclick = () => dialog.close();
    form.onsubmit = async (evento) => {
      evento.preventDefault();
      evento.submitter.disabled = true;
      try {
        await ejecutar(
          boton.dataset.tarjetaRevision ? "revisarTarjeta" : "revisarSolicitud",
          {
            ...(boton.dataset.tarjetaRevision ? { id: boton.dataset.id } : {}),
            uid: boton.dataset.uid,
            accion: boton.dataset.tarjetaRevision ?? boton.dataset.revision,
            nota: new FormData(form).get("nota"),
          },
        );
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
        solicitudes = items.filter(
          (s) =>
            ["credito", "fisica"].includes(s.tipo) ||
            ["revision", "deposito", "activa", "correcciones"].includes(
              s.estado,
            ),
        );
        solicitudes.sort(
          (a, b) =>
            (b.actualizado?.toMillis() ?? 0) - (a.actualizado?.toMillis() ?? 0),
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
