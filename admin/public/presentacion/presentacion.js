const video = document.querySelector("#recorrido");
const lista = document.querySelector("#capitulos");
fetch("capitulos.json?v=1.7.0")
  .then((r) => {
    if (!r.ok) throw new Error("Capítulos no disponibles");
    return r.json();
  })
  .then((items) => {
    for (const c of items) {
      const b = document.createElement("button");
      b.type = "button";
      const t = document.createElement("span");
      t.textContent = `${String(Math.floor(c.segundos / 60)).padStart(2, "0")}:${String(c.segundos % 60).padStart(2, "0")}`;
      b.append(t, document.createTextNode(c.titulo));
      b.addEventListener("click", () => {
        video.currentTime = c.segundos;
        video.play().catch(() => {});
        video.scrollIntoView({
          behavior: matchMedia("(prefers-reduced-motion: reduce)").matches
            ? "auto"
            : "smooth",
          block: "center",
        });
      });
      lista.append(b);
    }
  })
  .catch(() => {
    lista.textContent =
      "El recorrido puede reproducirse con los controles del video.";
  });
