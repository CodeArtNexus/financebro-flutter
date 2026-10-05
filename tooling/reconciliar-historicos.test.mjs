import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planificarCuenta, escriturasSeguras, documentosPlan, validarLecturas } from './reconciliar-historicos.mjs';
const base = 'projects/evaluacion/databases/(default)/documents/usuarios/persona/cuentas/principal';
const cuenta = { name: base, updateTime: '2026-10-04T10:00:00Z', fields: { saldoCentavos: { integerValue: '300' } } };
const movimiento = (id, importe) => ({ name: `${base}/movimientos/${id}`, updateTime: '2026-10-04T09:00:00Z', fields: { centavos: { integerValue: String(importe) }, fecha: { timestampValue: '2026-10-03T12:00:00Z' }, descripcion: { stringValue: 'Ingreso original' } } });
const ms = [movimiento('ingreso',500),movimiento('pago',-200)];
test('La reconstrucción conserva importes y fechas y no escribe cuentas ni originales', () => {
  const p = planificarCuenta(cuenta, ms, []), w = escriturasSeguras([p]);
  assert.equal(p.faltantes.length, 2);
  for (const f of p.faltantes) { assert.deepEqual(f.copia.fields.fecha,f.original.fields.fecha); assert.deepEqual(f.copia.fields.centavos,f.original.fields.centavos); }
  assert.ok(w.filter(x=>x.update).every(x=>x.update.name.includes('/movimientosGlobales/') && x.currentDocument.exists===false));
  assert.equal(w.length, 2);
  assert.equal(documentosPlan([p]).length, 5);
});
test('Repetir la reconstrucción no crea copias nuevas', () => {
  const p = planificarCuenta(cuenta,ms,[]), g = p.faltantes.map(f=>f.copia);
  assert.deepEqual(escriturasSeguras([planificarCuenta(cuenta,ms,g)]),[]);
});
test('Un descuadre de saldo o un importe inválido detiene la reconstrucción', () => {
  assert.throws(()=>planificarCuenta(cuenta,[movimiento('error',1)],[]),/difieren/);
  assert.throws(()=>planificarCuenta(cuenta,[{...ms[0],fields:{...ms[0].fields,centavos:{doubleValue:300}}}],[]),/enteros/);
});
test('Una copia global diferente y un movimiento ajeno no se sobrescriben', () => {
  const p=planificarCuenta(cuenta,ms,[]), g={...p.faltantes[0].copia,fields:{centavos:{integerValue:'1'}}};
  assert.throws(()=>planificarCuenta(cuenta,ms,[g]),/no se sobrescribirá/);
  const conFechaDistinta={...p.faltantes[0].copia,fields:{...p.faltantes[0].copia.fields,fecha:{timestampValue:'2026-10-04T12:00:00Z'}}};
  assert.throws(()=>planificarCuenta(cuenta,ms,[conFechaDistinta]),/no se sobrescribirá/);
  assert.throws(()=>planificarCuenta(cuenta,[{...ms[0],name:base.replace('persona','otra')+'/movimientos/ingreso'},ms[1]],[]),/ajeno/);
});
test('Las lecturas en la transacción abortan si cambia una cuenta o aparece una copia', () => {
  const p=planificarCuenta(cuenta,ms,[]);
  const lecturas=[...[cuenta,...ms].map(found=>({found})),...p.faltantes.map(f=>({missing:f.copia.name}))];
  assert.doesNotThrow(()=>validarLecturas([p],lecturas));
  assert.throws(()=>validarLecturas([p],[{found:{...cuenta,updateTime:'otra'}},...lecturas.slice(1)]),/Cambió/);
  assert.throws(()=>validarLecturas([p],lecturas.map(l=>l.missing===p.faltantes[0].copia.name?{found:p.faltantes[0].copia}:l)),/concurrente/);
});
