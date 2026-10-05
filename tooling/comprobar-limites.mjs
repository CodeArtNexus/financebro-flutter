import { readFile } from 'node:fs/promises';
import { Banco } from '../functions/src/banca.js';
import { OPERACIONES } from '../functions/src/contratos.js';
for (const metodo of Object.values(OPERACIONES)) {
  if (typeof Banco.prototype[metodo] !== 'function') throw Error(`Contrato sin implementación: ${metodo}`);
}
for (const archivo of ['historial_pantalla.dart', 'contacto_detalle_pantalla.dart']) {
  const fuente = await readFile(new URL(`../lib/features/banking/${archivo}`, import.meta.url), 'utf8');
  if (/cloud_firestore|firebase_historial|\.collection\(|datosProvider/.test(fuente)) throw Error(`La pantalla consulta almacenamiento directamente: ${archivo}`);
}
for (const dominio of ['onboarding','transferencias','tarjetas','expedientes','servicios','experiencia']) {
  const fuente=await readFile(new URL(`../functions/src/dominios/${dominio}.js`,import.meta.url),'utf8');
  if (/from\s+["'][^"']*banca\.js["']/.test(fuente)) throw Error(`Dependencia circular del dominio ${dominio}`);
}
console.log('Contratos bancarios y límites de históricos comprobados.');
