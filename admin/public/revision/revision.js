const $ = (id) => document.getElementById(id),
  controles = ["plataforma", "tema", "categoria", "buscar"].map($);
let capturas = [],
  visibles = [],
  indice = 0,
  botonOrigen;
const normalizar = (s) =>
  s
    .toLocaleLowerCase("es")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
function aplicar() {
  const [plataforma, tema, categoria, busqueda] = controles.map((c) => c.value);
  visibles = capturas.filter(
    (c) =>
      (!plataforma || c.plataforma === plataforma) &&
      (!tema || c.tema === tema) &&
      (!categoria || c.categoria === categoria) &&
      normalizar(`${c.titulo} ${c.categoria}`).includes(normalizar(busqueda)),
  );
  $("contador").textContent =
    `${visibles.length} de ${capturas.length} capturas`;
  $("sin-resultados").hidden = visibles.length !== 0;
  $("galeria").replaceChildren(
    ...visibles.map((c, i) => {
      const figura = document.createElement("figure"),
        boton = document.createElement("button"),
        foto = document.createElement("img"),
        pie = document.createElement("figcaption"),
        detalle = document.createElement("small"),
        titulo = document.createElement("strong");
      boton.className = "captura";
      boton.setAttribute(
        "aria-label",
        `Ampliar ${c.titulo} · ${c.plataforma} · ${c.tema}`,
      );
      foto.src = c.imagen;
      foto.alt = c.titulo;
      foto.loading = "lazy";
      foto.width = c.ancho;
      foto.height = c.alto;
      if (c.plataforma === "Panel web") foto.dataset.web = "true";
      detalle.textContent = `${c.plataforma} · ${c.tema} · ${c.categoria}`;
      titulo.textContent = c.titulo;
      boton.append(foto);
      pie.append(detalle, titulo);
      figura.append(boton, pie);
      boton.addEventListener("click", () => {
        botonOrigen = boton;
        abrir(i);
      });
      return figura;
    }),
  );
}
function mostrar() {
  const c = visibles[indice];
  $("titulo-visor").textContent = c.titulo;
  $("detalle-visor").textContent =
    `${c.plataforma} · ${c.tema} · ${c.escenario}`;
  $("imagen-ampliada").src = c.imagen;
  $("original").href = c.imagen;
  document
    .querySelector(".imagen-visor")
    .classList.toggle("web", c.plataforma === "Panel web");
  $("imagen-ampliada").alt = c.titulo;
  $("posicion").textContent = `${indice + 1} / ${visibles.length}`;
  $("anterior").disabled = indice === 0;
  $("siguiente").disabled = indice === visibles.length - 1;
}
function abrir(i) {
  indice = i;
  mostrar();
  $("visor").showModal();
  document.body.classList.add("visor-abierto");
}
function mover(n) {
  if (indice + n >= 0 && indice + n < visibles.length) {
    indice += n;
    mostrar();
  }
}
controles.forEach((c) => c.addEventListener("input", aplicar));
$("restablecer").addEventListener("click", () => {
  controles.forEach((c) => (c.value = ""));
  aplicar();
});
document.querySelectorAll("[data-ruta]").forEach((b) =>
  b.addEventListener("click", () => {
    controles.forEach((c) => (c.value = ""));
    $("categoria").value = b.dataset.ruta;
    aplicar();
    $("pantallas").scrollIntoView({
      behavior: matchMedia("(prefers-reduced-motion: reduce)").matches
        ? "instant"
        : "smooth",
    });
  }),
);
$("cerrar").addEventListener("click", () => $("visor").close());
$("visor").addEventListener("close", () => {
  document.body.classList.remove("visor-abierto");
  botonOrigen?.focus();
});
$("anterior").addEventListener("click", () => mover(-1));
$("siguiente").addEventListener("click", () => mover(1));
$("visor").addEventListener("keydown", (e) => {
  if (e.key === "ArrowLeft") mover(-1);
  if (e.key === "ArrowRight") mover(1);
});
function apariencia(v) {
  document.body.classList.toggle("oscuro", v);
  $("apariencia").setAttribute("aria-pressed", String(v));
}
let preferencia;
try {
  preferencia = localStorage.getItem("revision_apariencia");
} catch {}
apariencia(
  preferencia
    ? preferencia === "oscuro"
    : matchMedia("(prefers-color-scheme: dark)").matches,
);
$("apariencia").addEventListener("click", () => {
  const v = !document.body.classList.contains("oscuro");
  apariencia(v);
  try {
    localStorage.setItem("revision_apariencia", v ? "oscuro" : "claro");
  } catch {}
});
(async () => {
  try {
    const r = await fetch("capturas.json");
    if (!r.ok) throw Error();
    capturas = await r.json();
    $("total").textContent = capturas.length;
    [...new Set(capturas.map((c) => c.categoria))].sort().forEach((v) => {
      const o = document.createElement("option");
      o.value = v;
      o.textContent = v;
      $("categoria").append(o);
    });
    aplicar();
  } catch {
    $("contador").textContent =
      "No pudimos cargar las capturas. Actualiza esta página para reintentar.";
  }
})();
(async () => {
  try {
    const r = await fetch("integridad.json");
    if (!r.ok) return;
    const v = await r.json();
    $("integridad").textContent = v.diferencias.length
      ? "Consulta los resultados de revisión en el repositorio."
      : `${v.perfiles.length} perfiles · ${v.cuentas} cuentas · sin descuadres en saldos, movimientos y deuda. Verificado el ${new Date(v.fecha).toLocaleDateString("es-EC")}.`;
  } catch {}
})();
