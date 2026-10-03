import { createRequire } from 'node:module';
import { join } from 'node:path';
import { homedir } from 'node:os';

const require = createRequire(import.meta.url);
export const proyecto = process.env.FINANCEBRO_PROJECT_ID ?? 'financebro-sb-20261003';
export async function tokenAdministrativo() {
  let auth;
  try { auth = require('firebase-tools/lib/auth'); }
  catch { auth = require(join(process.env.POSTULACION_TOOLCHAINS_DIR ?? join(homedir(), 'Documents/Codex/toolchains'), 'firebase-cli/node_modules/firebase-tools/lib/auth.js')); }
  const cuenta = auth.getGlobalDefaultAccount();
  if (!cuenta) throw new Error('Primero ejecuta firebase login con la cuenta propietaria del proyecto.');
  return (await auth.getAccessToken(cuenta.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase'])).access_token;
}
export async function nube(url, { method = 'GET', body } = {}) {
  const respuesta = await fetch(url, {
    method, headers: { authorization: `Bearer ${await tokenAdministrativo()}`, 'content-type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const resultado = await respuesta.json();
  if (!respuesta.ok) {
    const error = new Error(`Servicio remoto (${respuesta.status}): ${resultado.error?.message ?? 'solicitud rechazada'}`);
    error.estado = respuesta.status;
    error.codigo = resultado.error?.details?.find(d => d.errorCode)?.errorCode;
    throw error;
  }
  return resultado;
}
