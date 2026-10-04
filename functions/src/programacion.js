// Módulo futuro, deliberadamente fuera de la entrada publicada.
import { onSchedule } from "firebase-functions/v2/scheduler";
import { procesarCheques } from "./chequera.js";
export function crearProgramacion(banco) {
const pagosMensuales = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "America/Guayaquil",
    maxInstances: 1,
    timeoutSeconds: 300,
  },
  async () => banco.procesarAutopagos(),
);

const cortesTarjetas = onSchedule(
  {
    schedule: "every day 09:05",
    timeZone: "America/Guayaquil",
    maxInstances: 1,
    timeoutSeconds: 300,
  },
  async () => banco.procesarCortesTarjetas(),
);



const cobrosCheques = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "America/Guayaquil",
    maxInstances: 1,
    timeoutSeconds: 300,
  },
  async () => {
    let cursor;
    for (let pagina = 0; pagina < 20; pagina++) {
      const r = await procesarCheques(
        banco,
        null,
        { cursor },
        { programado: true },
      );
      if (!r.hayMas) break;
      cursor = r.cursor;
    }
  },
);

return {pagosMensuales, cortesTarjetas, cobrosCheques};
}
