import { pathToFileURL } from 'node:url';
import { nube, proyecto } from './nube.mjs';
import { raiz } from './datos.mjs';

const centavos = (valor) => {
  if (!valor?.integerValue || !Number.isSafeInteger(Number(valor.integerValue))) {
    throw new Error('El saldo y los movimientos deben contener centavos enteros.');
  }
  return Number(valor.integerValue);
};

// Copias derivadas: conservar los originales y nunca recalcular o escribir saldos.
export function planificarCuenta(cuenta, movimientos, globales, fecha = new Date()) {
  const saldo = centavos(cuenta.fields.saldoCentavos);
  if (saldo < 0 || saldo > 100000000) throw new Error('Saldo fuera de límites.');
  let suma = 0;
  for (const movimiento of movimientos) {
    suma += centavos(movimiento.fields.centavos);
    if (!Number.isSafeInteger(suma)) throw new Error('Histórico fuera de límites.');
  }
  if (suma !== saldo) throw new Error('Saldo e histórico difieren; se requiere revisar el origen antes de copiar.');
  const idCuenta = cuenta.name.split('/').at(-1);
  const usuario = cuenta.name.split('/cuentas/')[0];
  const existentes = new Map(globales.map(g => [g.name, g]));
  const faltantes = [];
  for (const m of movimientos) {
    if (!m.name.startsWith(`${cuenta.name}/movimientos/`)) throw new Error('Movimiento ajeno a la cuenta.');
    if (!m.fields.fecha?.timestampValue || !m.updateTime) throw new Error('Falta fecha o versión del movimiento original.');
    const id = m.name.split('/').at(-1), nombre = `${usuario}/movimientosGlobales/${idCuenta}_${id}`;
    const existente = existentes.get(nombre);
    if (existente) {
      if (centavos(existente.fields.centavos) !== centavos(m.fields.centavos) ||
          existente.fields.fecha?.timestampValue !== m.fields.fecha.timestampValue ||
          existente.fields.cuenta?.stringValue !== idCuenta) {
        throw new Error('La copia global difiere; no se sobrescribirá.');
      }
      continue;
    }
    const titulo = m.fields.titulo ?? m.fields.descripcion ?? { stringValue: 'Movimiento registrado' };
    faltantes.push({ original: m, copia: {
      name: nombre,
      fields: { ...m.fields, titulo, cuenta: { stringValue: idCuenta },
        referencia: m.fields.referencia ?? { stringValue: id },
        reconstruidoDesde: { stringValue: m.name }, reconstruido: { timestampValue: fecha.toISOString() } },
    } });
  }
  return { cuenta, faltantes };
}

export function documentosPlan(planes) {
  return [...new Set(planes.filter(p => p.faltantes.length).flatMap(p => [
    p.cuenta.name, ...p.faltantes.flatMap(f => [f.original.name, f.copia.name]),
  ]))];
}

export function validarLecturas(planes, lecturas) {
  const leidos = new Map(lecturas.map(l => [l.found?.name ?? l.missing, l]));
  for (const p of planes.filter(p => p.faltantes.length)) {
    for (const original of [p.cuenta, ...p.faltantes.map(f => f.original)]) {
      if (!original.updateTime || leidos.get(original.name)?.found?.updateTime !== original.updateTime) {
        throw new Error('Cambió un original o una cuenta; vuelve a revisar antes de aplicar.');
      }
    }
    for (const f of p.faltantes) {
      if (leidos.get(f.copia.name)?.missing !== f.copia.name) {
        throw new Error('Apareció una copia concurrente; vuelve a revisar antes de aplicar.');
      }
    }
  }
}

export function escriturasSeguras(planes) {
  const escrituras = planes.flatMap(p => p.faltantes.map(f => ({
    update: f.copia, currentDocument: { exists: false },
  })));
  if (documentosPlan(planes).length > 450) throw new Error('El plan excede un lote seguro; no se aplicó ningún cambio.');
  return escrituras;
}

async function listar(url) {
  const resultado = [];
  let token;
  do {
    const q = new URL(url); q.searchParams.set('pageSize', '300');
    if (token) q.searchParams.set('pageToken', token);
    const r = await nube(q.toString()); resultado.push(...(r.documents ?? [])); token = r.nextPageToken;
  } while (token);
  return resultado;
}

async function ejecutar() {
  const args = process.argv.slice(2), pos = args.indexOf('--proyecto');
  if (pos < 0 || args[pos + 1] !== proyecto || process.env.USE_EMULATORS === 'true') {
    throw new Error('Indica explícitamente --proyecto con el proyecto remoto configurado.');
  }
  const planes = [], personas = await listar(`${raiz}/usuarios`);
  let movimientos = 0;
  for (const persona of personas) {
    const globales = await listar(`https://firestore.googleapis.com/v1/${persona.name}/movimientosGlobales`);
    for (const cuenta of await listar(`https://firestore.googleapis.com/v1/${persona.name}/cuentas`)) {
      const ms = await listar(`https://firestore.googleapis.com/v1/${cuenta.name}/movimientos`); movimientos += ms.length;
      planes.push(planificarCuenta(cuenta, ms, globales));
    }
  }
  const escrituras = escriturasSeguras(planes), aplicar = args.includes('--aplicar');
  if (aplicar && escrituras.length) {
    const { transaction } = await nube(`${raiz}:beginTransaction`, {
      method: 'POST', body: { options: { readWrite: {} } },
    });
    try {
      // Leer dentro de la transacción protege cuentas, originales y destinos ante concurrencia.
      const lecturas = await nube(`${raiz}:batchGet`, {
        method: 'POST', body: { documents: documentosPlan(planes), transaction },
      });
      validarLecturas(planes, lecturas);
      await nube(`${raiz}:commit`, { method: 'POST', body: { writes: escrituras, transaction } });
    } catch (e) {
      await nube(`${raiz}:rollback`, { method: 'POST', body: { transaction } }).catch(() => {});
      throw e;
    }
  }
  console.log(JSON.stringify({ modo: aplicar ? 'aplicado' : 'solo lectura', perfiles: personas.length,
    cuentas: planes.length, movimientos, copiasFaltantes: planes.reduce((n,p) => n + p.faltantes.length, 0), saldosModificados: 0 }));
}
if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  ejecutar().catch(e => { console.error(e.message); process.exitCode = 1; });
}
