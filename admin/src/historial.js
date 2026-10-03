import {
  query,
  orderBy,
  limit,
  onSnapshot,
  getDocs,
  startAfter,
} from "firebase/firestore";

export function ordenarMovimientos(items) {
  return [...items].sort((a, b) => {
    const fecha = (b.fecha?.toMillis?.() ?? 0) - (a.fecha?.toMillis?.() ?? 0);
    return fecha || (a.ruta < b.ruta ? 1 : a.ruta > b.ruta ? -1 : 0);
  });
}

// El registro es inmutable. Conservamos los elementos que salen de la ventana
// en vivo para no dejar huecos cuando llega una operación durante la paginación.
export function observarHistorial({
  origen,
  tamano = 100,
  cambiar,
  estado,
  fallo,
}) {
  const cargados = new Map();
  let cursor,
    inicial = false,
    mas = true,
    ocupado = false,
    vigente = true;
  const consulta = query(origen, orderBy("fecha", "desc"), limit(tamano));
  function agregar(snapshot) {
    for (const d of snapshot.docs)
      cargados.set(d.ref.path, { id: d.id, ruta: d.ref.path, ...d.data() });
    cambiar(ordenarMovimientos(cargados.values()));
  }
  function actualizar() {
    estado({ mas: inicial && mas, ocupado });
  }
  const cancelar = onSnapshot(
    consulta,
    { includeMetadataChanges: true },
    (s) => {
      if (!vigente) return;
      if (!inicial && !s.metadata.fromCache) {
        inicial = true;
        cursor = s.docs.at(-1);
        mas = s.size === tamano;
      }
      agregar(s);
      actualizar();
    },
    (e) => {
      if (vigente) fallo(e);
    },
  );
  actualizar();
  return {
    async mas() {
      if (!vigente || ocupado || !inicial || !mas || !cursor) return;
      ocupado = true;
      actualizar();
      try {
        const s = await getDocs(query(consulta, startAfter(cursor)));
        if (!vigente) return;
        cursor = s.docs.at(-1) ?? cursor;
        mas = s.size === tamano;
        agregar(s);
      } catch (e) {
        if (vigente) fallo(e);
      } finally {
        ocupado = false;
        if (vigente) actualizar();
      }
    },
    detener() {
      vigente = false;
      cancelar();
      cargados.clear();
    },
  };
}
