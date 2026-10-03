import { randomBytes } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { nube, proyecto } from './nube.mjs';
import { local, escribir } from './datos.mjs';

const correo = 'demo@financebro.test';
let usuario;
if (local) {
  const respuesta = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: correo, password: 'FinanceBro-local-2026!', displayName: 'Sebastian Demo', returnSecureToken: true }),
  });
  usuario = await respuesta.json();
  if (!respuesta.ok && usuario.error?.message === 'EMAIL_EXISTS') {
    usuario = await (await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: correo, password: 'FinanceBro-local-2026!', returnSecureToken: true }) })).json();
  }
  if (!usuario.localId) throw new Error('No se pudo preparar el usuario local.');
} else {
  await mkdir('.secrets', { recursive: true });
  const archivo = '.secrets/demostracion.json';
  let acceso;
  try { acceso = JSON.parse(await readFile(archivo, 'utf8')); }
  catch { acceso = { correo, clave: randomBytes(18).toString('base64url') }; }
  const existentes = await nube(`https://identitytoolkit.googleapis.com/v1/projects/${proyecto}/accounts:lookup`, { method: 'POST', body: { email: [correo] } });
  usuario = existentes.users?.[0];
  if (!usuario) usuario = await nube(`https://identitytoolkit.googleapis.com/v1/projects/${proyecto}/accounts`, { method: 'POST', body: { email: correo, password: acceso.clave, displayName: 'Sebastian Demo', emailVerified: true } });
  acceso.uid = usuario.localId;
  await writeFile(archivo, JSON.stringify(acceso, null, 2), { mode: 0o600 });
}
const uid = usuario.localId;
await escribir(`usuarios/${uid}`, { nombre: 'Sebastian Demo', segmento: 'equilibrio', mostrarSaldo: true, actualizado: new Date() });
const operaciones = [
  { id: 'ingreso', descripcion: 'Ingreso de prueba', centavos: 280000, categoria: 'Ingresos', dias: 0 },
  { id: 'compras', descripcion: 'Supermercado de prueba', centavos: -8250, categoria: 'Compras', dias: 1 },
  { id: 'cafe', descripcion: 'Café de prueba', centavos: -450, categoria: 'Alimentación', dias: 2 },
  { id: 'servicio', descripcion: 'Servicio de prueba', centavos: -3980, categoria: 'Servicios', dias: 3 },
];
await escribir(`usuarios/${uid}/cuentas/principal`, { nombre: 'Cuenta del día a día', numero: '•••• 2048', saldoCentavos: operaciones.reduce((s, m) => s + m.centavos, 0), actualizado: new Date() });
for (const movimiento of operaciones) await escribir(`usuarios/${uid}/cuentas/principal/movimientos/${movimiento.id}`, {
  descripcion: movimiento.descripcion, centavos: movimiento.centavos, categoria: movimiento.categoria, fecha: new Date(Date.now() - movimiento.dias * 86400000),
});
await escribir(`usuarios/${uid}/cuentas/ahorro`, { nombre: 'Mi ahorro', numero: '•••• 7712', saldoCentavos: 150000, actualizado: new Date() });
await escribir(`usuarios/${uid}/cuentas/ahorro/movimientos/inicial`, { descripcion: 'Ahorro inicial de prueba', centavos: 150000, categoria: 'Ahorro', fecha: new Date() });
await escribir('experiencias/actual', { schemaVersion: 1, revision: 1, actualizado: new Date(), tarjetas: [
  { id: 'bienestar', tipo: 'aviso', titulo: 'Pequeños pasos, grandes cambios', texto: 'Revisa tus movimientos y encuentra espacio para ahorrar.', segmento: 'todos', destino: '/cuentas', orden: 1 },
  { id: 'ahorro', tipo: 'recomendacion', titulo: 'Dale intención a tu ahorro', texto: 'Tu perfil de ahorro prioriza contenido para tus metas.', segmento: 'ahorro', destino: '/cuentas', orden: 2 },
  { id: 'viajes', tipo: 'divisas', titulo: 'Tu próximo viaje empieza aquí', texto: 'Calcula tu presupuesto con tasas de referencia actuales.', segmento: 'viajes', destino: '/divisas', orden: 2 },
] });
console.log(`Datos de prueba persistentes preparados en ${local ? 'emuladores locales' : 'Firebase remoto'}. Credenciales remotas guardadas únicamente en .secrets.`);
