// Casos de uso del dominio; BancoBase conserva las escrituras monetarias compartidas.
import { falla, texto } from "../compartido.js";

export async function guardarDecoracion(banco, auth, d) {
  const actor = banco.actor(auth, true);
  if (
    typeof d.activa !== "boolean" ||
    !["habitual", "navidad", "aniversario"].includes(d.tema)
  )
    falla("invalid-argument", "Revisa el tema y su disponibilidad.");
  function fecha(v) {
    if (
      typeof v !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(v) ||
      !Number.isFinite(Date.parse(`${v}T05:00:00Z`)) ||
      new Date(`${v}T05:00:00Z`).toISOString().slice(0, 10) !== v
    )
      falla("invalid-argument", "Revisa las fechas de la temporada.");
    return v;
  }
  const desde = fecha(d.desde),
    hasta = fecha(d.hasta);
  if (hasta < desde || Date.parse(hasta) - Date.parse(desde) > 90 * 86400000)
    falla("invalid-argument", "La temporada admite hasta 90 días.");
  const configuracion = {
    activa: d.activa,
    tema: d.tema,
    desde,
    hasta,
    titulo: texto(d.titulo, "el saludo de temporada", 2, 60),
    mensaje: texto(d.mensaje, "el mensaje de temporada", 2, 140),
    actor,
    actualizado: banco.ahora(),
  };
  await banco.db.doc("experiencias/decoracion").set(configuracion);
  return { guardada: true };
}
