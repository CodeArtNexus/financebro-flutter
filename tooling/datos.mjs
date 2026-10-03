import { nube, proyecto } from './nube.mjs';
export const local = process.env.USE_EMULATORS === 'true';
export const proyectoDatos = local ? 'demo-financebro' : proyecto;
const origen = local ? 'http://127.0.0.1:8080' : 'https://firestore.googleapis.com';
export const raiz = `${origen}/v1/projects/${proyectoDatos}/databases/(default)/documents`;
export function codificar(valor) {
  if (valor === null) return { nullValue: null };
  if (valor instanceof Date) return { timestampValue: valor.toISOString() };
  if (typeof valor === 'string') return { stringValue: valor };
  if (typeof valor === 'boolean') return { booleanValue: valor };
  if (typeof valor === 'number') return Number.isInteger(valor) ? { integerValue: String(valor) } : { doubleValue: valor };
  if (Array.isArray(valor)) return { arrayValue: { values: valor.map(codificar) } };
  return { mapValue: { fields: campos(valor) } };
}
export const campos = objeto => Object.fromEntries(Object.entries(objeto).map(([k, v]) => [k, codificar(v)]));
export async function datos(url, opciones = {}) {
  if (!local) return nube(url, opciones);
  const respuesta = await fetch(url, { method: opciones.method ?? 'GET', headers: { authorization: 'Bearer owner', 'content-type': 'application/json' }, ...(opciones.body ? { body: JSON.stringify(opciones.body) } : {}) });
  const resultado = await respuesta.json();
  if (!respuesta.ok) throw new Error(`Emulador (${respuesta.status}): ${resultado.error?.message ?? 'error'}`);
  return resultado;
}
export async function escribir(ruta, objeto) {
  return datos(`${raiz}/${ruta}`, { method: 'PATCH', body: { fields: campos(objeto) } });
}
