import {
  doc,
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
    servicios = [],
    tarjetasCredito = [];
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
      aprobada: "Tarjeta aprobada",
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
      `<article class="solicitud"><div class="cabecera"><div><h2>${s.tipo === "credito" ? "Solicitud de tarjeta de crédito" : "Tarjeta física"} · ${escapar(s.nombre)}</h2><p>${escapar(estados[s.estado] ?? s.estado)}</p></div></div>${s.tipo === "credito" ? `<p>${escapar(s.ocupacion)} · Ingresos mensuales ${dinero(s.ingresosCentavos)}</p>${s.cupoCentavos ? `<p><strong>Cupo aprobado ${dinero(s.cupoCentavos)}</strong> · El titular elige su corte en la app.</p>` : `<p>Aprueba la tarjeta asignando un cupo. La app solicitará al titular elegir su corte mensual.</p>`}` : `<div class="vista-tarjeta tono-${escapar(s.diseno.color)}"><strong>fb.</strong><p>${escapar(s.diseno.nombre)}</p><span>•••• ${escapar(s.diseno.ultimos4)}</span></div><p>${s.diseno.fondoRuta ? `<button class="secundario" data-documento="${escapar(s.diseno.fondoRuta)}">Ver fondo personalizado</button>` : ""}${s.personalizada ? "Diseño personalizado · revisión en 3 días" : "Diseño predeterminado"}<br>Envío solicitado: ${escapar(s.fechaEnvio)}<br>${escapar(s.domicilio.direccion)} · ${escapar(s.domicilio.ciudad)}<br>Contacto: ${escapar(s.domicilio.telefono)}</p>`}${s.nota ? `<p>${escapar(s.nota)}</p>` : ""}<div class="acciones">${s.tipo === "credito" && ["revision", "preaprobada"].includes(s.estado) ? accion(s, "rechazar", "No aprobar") + accion(s, "aprobar", "Aprobar tarjeta y cupo") : s.estado === "revision_diseno" ? accion(s, "rechazar", "No aprobar diseño") + accion(s, "aprobar_diseno", "Aprobar diseño") : s.estado === "preparacion" ? accion(s, "enviar", "Registrar envío") : s.estado === "enviada" ? accion(s, "entregar", "Registrar entrega") : ""}</div></article>`;
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
    const buscar = $("buscar-solicitud").value.trim().toLocaleLowerCase("es");
    const visibles = solicitudes.filter((s) =>
      [s.nombre, s.empresa, s.uid].some((v) =>
        String(v ?? "")
          .toLocaleLowerCase("es")
          .includes(buscar),
      ),
    );
    $("solicitudes-lista").innerHTML = visibles.length
      ? visibles
          .map((s) =>
            ["credito", "fisica"].includes(s.tipo)
              ? tarjeta(s)
              : corporativa(s),
          )
          .join("")
      : '<p class="vacio">Las solicitudes enviadas aparecerán aquí.</p>';
  }
  $("buscar-solicitud").addEventListener("input", renderSolicitudes);
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
    const aprobacion = boton.dataset.tarjetaRevision === "aprobar";
    form.innerHTML = `<h2>${aprobacion ? "Aprobar tarjeta de crédito" : "Revisar solicitud"}</h2><p>${boton.dataset.revision === "activar" ? "Se comprobará el depósito antes de habilitar la cuenta." : "La decisión quedará registrada con tu identidad de asesor."}</p>${aprobacion ? `<label>Cupo aprobado en USD<input name="cupo" type="number" min="1" max="50000" step="0.01" required placeholder="1500.00" /></label><p>La aprobación emite una tarjeta. El titular recibirá el cupo y elegirá su corte mensual para activarla.</p>` : ""}<label>Observación<textarea name="nota" minlength="5" maxlength="160" required></textarea></label><div class="acciones"><button type="button" class="secundario">Volver</button><button class="primario" type="submit">Confirmar revisión</button></div>`;
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
            ...(aprobacion
              ? { cupoCentavos: centavos(new FormData(form).get("cupo")) }
              : {}),
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
        visibleEnApp: $("servicio-visible").value === "true",
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
    $("servicio-visible").value = String(s.visibleEnApp !== false);
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
  $("tarjetas-credito-lista").addEventListener("click", (e) => {
    const boton = e.target.closest("[data-consumo]");
    if (!boton) return;
    const dialog = document.createElement("dialog"),
      form = document.createElement("form"),
      referencia = crypto.randomUUID();
    form.innerHTML =
      '<h2>Registrar consumo de tarjeta</h2><p>El consumo reduce el cupo disponible y conserva el comercio, la referencia y tu identidad en el histórico.</p><label>Comercio<input name="comercio" minlength="2" maxlength="80" required /></label><label>Importe en USD<input name="importe" type="number" min="0.10" max="50000" step="0.01" required /></label><div class="acciones"><button type="button" class="secundario">Volver</button><button class="primario" type="submit">Confirmar consumo</button></div>';
    form.querySelector("[type=button]").onclick = () => dialog.close();
    form.onsubmit = async (e) => {
      e.preventDefault();
      e.submitter.disabled = true;
      try {
        const d = new FormData(form);
        await ejecutar("registrarConsumoTarjeta", {
          uid: boton.dataset.consumo,
          centavos: centavos(d.get("importe")),
          comercio: d.get("comercio"),
          referencia,
        });
        dialog.close();
        avisar("Consumo registrado. El titular recibirá un aviso.");
      } catch (error) {
        avisar(fallo(error), true);
      } finally {
        e.submitter.disabled = false;
      }
    };
    dialog.append(form);
    document.body.append(dialog);
    dialog.addEventListener("close", () => dialog.remove());
    dialog.showModal();
  });
  $("procesar-cortes").onclick = async (e) => {
    e.target.disabled = true;
    try {
      const r = await ejecutar("procesarCortesTarjetas");
      avisar(
        `${r.procesados} cortes procesados. Los estados de cuenta están actualizados.`,
      );
    } catch (error) {
      avisar(fallo(error), true);
    } finally {
      e.target.disabled = false;
    }
  };
  let decoracionEditada=false;
  const hoy=new Date(Date.now()-5*3600000).toISOString().slice(0,10);
  $("decoracion-desde").value=hoy;$("decoracion-hasta").value=hoy;
  $("decoracion-form").addEventListener("input",()=>{decoracionEditada=true;});
  $("decoracion-form").addEventListener("submit",async(e)=>{
    e.preventDefault();e.submitter.disabled=true;
    try {
      await ejecutar("guardarDecoracion",{activa:$("decoracion-activa").value==="true",tema:$("decoracion-tema").value,desde:$("decoracion-desde").value,hasta:$("decoracion-hasta").value,titulo:$("decoracion-titulo").value,mensaje:$("decoracion-mensaje").value});
      decoracionEditada=false;avisar("Temporada guardada. La app recibirá el cambio.");
    } catch(error) {avisar(fallo(error),true);} finally {e.submitter.disabled=false;}
  });
  return {
    escuchar() {
      suscripciones.push(onSnapshot(doc(db,"experiencias/decoracion"),(s)=>{
        const d=s.data();if(!d || decoracionEditada)return;
        for(const campo of ["tema","desde","hasta","titulo","mensaje","activa"])$("decoracion-"+campo).value=String(d[campo]);
        const activa=d.activa && d.desde<=hoy && d.hasta>=hoy;
        document.body.dataset.temporada=activa?d.tema:"habitual";
      },e=>avisar(fallo(e),true)));

      observar(collectionGroup(db, "tarjetas"), (items) => {
        tarjetasCredito = items.filter(
          (t) => t.clase === "credito" && t.tipo === "propia",
        );
        $("tarjetas-credito-lista").innerHTML =
          tarjetasCredito
            .map(
              (t) =>
                `<article class="solicitud"><div class="cabecera"><div><h2>${escapar(t.titular)} · •••• ${escapar(t.ultimos4)}</h2><p>${t.estado === "activa" ? `Corte día ${t.diaCorte} · próximo ${escapar(t.proximoCorte)}` : "Esperando elección del corte mensual"}</p></div><span class="estado">${dinero(t.cupoCentavos - t.deudaCentavos)} disponibles</span></div><div class="metricas"><div class="cristal metrica"><span>Cupo aprobado</span><strong>${dinero(t.cupoCentavos)}</strong></div><div class="cristal metrica"><span>Saldo pendiente</span><strong>${dinero(t.deudaCentavos)}</strong></div><div class="cristal metrica"><span>Total facturado pendiente</span><strong>${dinero(t.totalPagarCentavos)}</strong></div><div class="cristal metrica"><span>Mínimo pendiente</span><strong>${dinero(t.minimoPagarCentavos)}</strong></div></div>${t.pagoHasta ? `<p>Pago hasta ${escapar(t.pagoHasta)}</p>` : ""}<button class="secundario" data-consumo="${escapar(t.uid)}" ${t.estado !== "activa" ? "disabled" : ""}>Registrar consumo</button></article>`,
            )
            .join("") ||
          '<p class="vacio">Las tarjetas aprobadas aparecerán aquí.</p>';
      });
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
      $("tarjetas-credito-lista").replaceChildren();
      tarjetasCredito = [];
      decoracionEditada=false;document.body.dataset.temporada="habitual";
    },
  };
}
