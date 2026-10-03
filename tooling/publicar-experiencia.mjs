import { escribir } from './datos.mjs';
const modo = process.argv[2] ?? 'viajes';
if (!['viajes','ahorro','invalida'].includes(modo)) throw new Error('Usa viajes, ahorro o invalida.');
await escribir('experiencias/actual', modo === 'invalida' ? { schemaVersion: 99, revision: Date.now(), tarjetas: [] } : {
  schemaVersion: 1, revision: Date.now(), actualizado: new Date(), tarjetas: [
    { id: 'remota', tipo: modo === 'viajes' ? 'divisas' : 'recomendacion', titulo: modo === 'viajes' ? 'Tu siguiente destino te espera' : 'Haz crecer tus buenos hábitos', texto: 'Este contenido se publicó desde el servicio y llegó sin instalar una nueva versión.', segmento: 'todos', destino: modo === 'viajes' ? '/divisas' : '/cuentas', orden: 1 },
  ],
});
console.log(`Configuración ${modo} publicada; observa el cambio en la misma instalación.`);
