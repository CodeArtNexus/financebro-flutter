import {
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
} from "firebase/firestore";
import { dinero } from "./dinero.js";
export function iniciarChequera({ db, ejecutar, avisar, fallo, escapar }) {
  const $ = (id) => document.getElementById(id);
  let detener = null,
    items = [],
    tamano = 200;
  function render() {
    const buscar = $("cheques-buscar").value.toLocaleLowerCase("es"),
      estado = $("cheques-estado").value;
    const lista = items.filter(
      (c) =>
        (!estado || c.estado === estado) &&
        [
          c.emisor,
          c.receptor,
          c.concepto,
          c.numeroOrigen,
          c.numeroDestino,
        ].some((v) =>
          String(v ?? "")
            .toLocaleLowerCase("es")
            .includes(buscar),
        ),
    );
    $("cheques-lista").innerHTML =
      lista
        .map(
          (c) =>
            `<article class="solicitud"><div class="cabecera"><div><h2>${escapar(c.emisor)} → ${escapar(c.receptor)}</h2><p>${escapar(c.concepto)}<br>${escapar(c.numeroOrigen)} → ${escapar(c.numeroDestino)}</p></div><strong>${dinero(c.centavos)}</strong></div><p>📅 ${escapar(c.fechaCobro)} · ${escapar(c.estado.replaceAll("_", " "))}<br>Fecha original ${escapar(c.fechaOriginal)} · Referencia ${escapar(c.id)}</p></article>`,
        )
        .join("") || '<p class="vacio">No hay cheques en esta selección.</p>';
    $("cheques-resumen").textContent =
      `${lista.length} cheques visibles · ${dinero(lista.filter((c) => !["cancelado", "cobrado"].includes(c.estado)).reduce((s, c) => s + c.centavos, 0))} pendientes de cobro`;
    $("cheques-mas").hidden = items.length < tamano;
  }
  function escuchar() {
    detener?.();
    detener = onSnapshot(
      query(
        collection(db, "cheques"),
        orderBy("creado", "desc"),
        limit(tamano),
      ),
      (s) => {
        items = s.docs.map((d) => ({ id: d.id, ...d.data() }));
        render();
      },
      (e) => avisar(fallo(e), true),
    );
  }
  $("cheques-buscar").addEventListener("input", render);
  $("cheques-estado").addEventListener("change", render);
  $("cheques-mas").addEventListener("click", () => {
    tamano += 200;
    escuchar();
  });
  $("cheques-procesar").addEventListener("click", async (e) => {
    e.currentTarget.disabled = true;
    try {
      let cursor,
        cobrados = 0,
        recordados = 0;
      for (let p = 0; p < 20; p++) {
        const r = await ejecutar("procesarCheques", { cursor });
        cobrados += r.cobrados;
        recordados += r.recordados;
        if (!r.hayMas) break;
        cursor = r.cursor;
      }
      avisar(
        `${cobrados} cobros confirmados · ${recordados} recordatorios enviados.`,
      );
    } catch (error) {
      avisar(fallo(error), true);
    } finally {
      $("cheques-procesar").disabled = false;
    }
  });
  return {
    escuchar,
    detener() {
      detener?.();
      detener = null;
      items = [];
      tamano = 200;
      $("cheques-lista").replaceChildren();
    },
  };
}
