import { beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { Banco } from '../../src/banca.js';
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST)
  throw Error('Solo ejecutar en Emulator Suite.');
const db = getFirestore(initializeApp({ projectId: 'demo-financebro' }));
let ahora, b, a, z, admin, numero, prefijo;
const saldo = async (uid, cuenta = 'ahorros') => (await b.cuenta(uid, cuenta).get()).data().saldoCentavos;
const conteo = async (uid, coleccion) => (await b.usuario(uid).collection(coleccion).get()).size;
const datos = (id, centavos = 100) => ({ cuenta: 'ahorros', numero, centavos, nota: 'Integridad de fondos', referencia: `${prefijo}_${id}` });
beforeEach(async () => {
  prefijo = randomUUID().replaceAll('-', ''); ahora = new Date('2026-10-04T14:00:00Z');
  b = new Banco(db, { reloj: () => ahora }); a = { uid: `a_${prefijo}` }; z = { uid: `z_${prefijo}` };
  admin = { uid: `admin_${prefijo}`, token: { financebroAdmin: true } };
  for (const [auth, nombre] of [[a, 'Ana Integridad'], [z, 'Zoe Integridad']]) {
    await b.usuario(auth.uid).set({ nombre });
    for (const tipo of ['ahorro', 'corriente']) {
      const cuenta = tipo === 'ahorro' ? 'ahorros' : 'corriente', c = b.nuevaCuenta(tipo, b.ahora());
      await b.cuenta(auth.uid, cuenta).set(c);
      await db.doc(`directorioCuentas/${c.numeroCuenta}`).set({ uid: auth.uid, cuenta, titular: nombre });
      if (auth === z && tipo === 'ahorro') numero = c.numeroCuenta;
    }
  }
});
test('Diez transferencias distintas compiten por fondos: nunca hay sobregiro y todos los registros coinciden', async () => {
  await b.ajustar(admin, { uid: a.uid, cuenta: 'ahorros', centavos: 300, motivo: 'Saldo de concurrencia', referencia: `${prefijo}_fondos` });
  const resultados = await Promise.allSettled(Array.from({ length: 10 }, (_, i) => b.transferir(a, datos(`paralelo_${i}`))));
  assert.equal(resultados.filter(r => r.status === 'fulfilled').length, 3);
  assert.equal(await saldo(a.uid), 0); assert.equal(await saldo(z.uid), 300);
  for (const [uid, cantidad, total] of [[a.uid, 4, 0], [z.uid, 3, 300]]) {
    const movimientos = await b.cuenta(uid, 'ahorros').collection('movimientos').get();
    assert.equal(movimientos.size, cantidad);
    assert.equal(movimientos.docs.reduce((sum, d) => sum + d.data().centavos, 0), total);
    assert.equal(await conteo(uid, 'movimientosGlobales'), cantidad);
    assert.equal(await conteo(uid, 'notificaciones'), cantidad);
    for (const m of movimientos.docs) {
      assert.equal((await b.privado(uid, 'movimientosGlobales', `ahorros_${m.id}`).get()).data().centavos, m.data().centavos);
      assert.equal((await db.doc(`enviosPush/${uid}_ahorros_${m.id}`).get()).exists, true);
    }
  }
  assert.equal(await conteo(a.uid, 'operaciones'), 3);
});
test('Un ajuste y una transferencia concurrentes no gastan dos veces el mismo saldo', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 100 });
  const r = await Promise.allSettled([
    b.transferir(a, datos('con_ajuste')),
    b.ajustar(admin, { uid: a.uid, cuenta: 'ahorros', centavos: -100, motivo: 'Retiro concurrente', referencia: `${prefijo}_retiro` }),
  ]);
  assert.equal(r.filter(x => x.status === 'fulfilled').length, 1);
  assert.equal(await saldo(a.uid), 0);
  assert.ok([0, 100].includes(await saldo(z.uid)));
});
test('Una respuesta perdida se recupera después de 24 horas con el mismo comprobante y un único descuento', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 100 });
  const d = { ...datos('respuesta_perdida'), colaCreada: ahora.toISOString() }, recibo = await b.transferir(a, d);
  ahora = new Date('2026-10-06T14:00:00Z');
  assert.deepEqual(await b.transferir(a, d), recibo);
  assert.equal(await saldo(a.uid), 0); assert.equal(await saldo(z.uid), 100);
  assert.equal(await conteo(a.uid, 'operaciones'), 1);
  await assert.rejects(b.transferir(a, { ...d, referencia: `${prefijo}_vencida` }), e => e.codigo === 'failed-precondition');
});
test('Si falla la creación de un registro, la transacción completa revierte ambos saldos y el comprobante', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 100 });
  const d = datos('colision');
  await b.privado(a.uid, 'movimientosGlobales', `ahorros_${d.referencia}`).set({ centavos: -999 });
  await assert.rejects(b.transferir(a, d));
  assert.equal(await saldo(a.uid), 100); assert.equal(await saldo(z.uid), 0);
  assert.equal(await conteo(a.uid, 'operaciones'), 0); assert.equal(await conteo(a.uid, 'notificaciones'), 0);
  assert.equal((await b.cuenta(a.uid, 'ahorros').collection('movimientos').get()).size, 0);
});
test('El directorio debe coincidir con la cuenta receptora; una referencia corrupta no mueve dinero', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 100 });
  await b.cuenta(z.uid, 'ahorros').update({ numeroCuenta: '10000000000000' });
  await assert.rejects(b.transferir(a, datos('directorio')), e => e.codigo === 'failed-precondition');
  await assert.rejects(b.destinatario(a, { numero }), e => e.codigo === 'failed-precondition');
  assert.equal(await saldo(a.uid), 100); assert.equal(await saldo(z.uid), 0);
});
test('Cuentas corruptas, suspendidas o en el límite no aceptan abonos ni débitos parciales', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 100 });
  for (const cambios of [{ saldoCentavos: 100000000 }, { saldoCentavos: '100' }, { saldoCentavos: Number.NaN }, { saldoCentavos: -1 }, { saldoCentavos: 0, estado: 'suspendida' }]) {
    await b.cuenta(z.uid, 'ahorros').update(cambios);
    await assert.rejects(b.transferir(a, datos('cuenta_invalida')));
    assert.equal(await saldo(a.uid), 100); assert.equal(await conteo(a.uid, 'operaciones'), 0);
  }
});
test('Transferir entre cuentas propias conserva el total y una cuenta no puede enviarse a sí misma', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 100 });
  const destino = (await b.cuenta(a.uid, 'corriente').get()).data().numeroCuenta;
  await b.transferir(a, { ...datos('propias'), numero: destino });
  assert.equal(await saldo(a.uid), 0); assert.equal(await saldo(a.uid, 'corriente'), 100);
  await assert.rejects(b.transferir(a, { ...datos('mismo_destino'), cuenta: 'corriente', numero: destino }), e => e.codigo === 'invalid-argument');
});
test('No se puede retirar fondos de otra identidad ni atribuirse permisos administrativos', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 100 });
  await assert.rejects(b.transferir({ uid: 'intruso' }, datos('ajena')));
  await assert.rejects(b.ajustar({ uid: a.uid, financebroAdmin: true }, { uid: a.uid, cuenta: 'ahorros', centavos: 100, motivo: 'Intento de alteración', referencia: `${prefijo}_falso` }), e => e.codigo === 'permission-denied');
  await assert.rejects(b.transferir(null, datos('anonimo')), e => e.codigo === 'unauthenticated');
  assert.equal(await saldo(a.uid), 100);
});
test('Dos cobros del mismo cheque y una transferencia compiten sin perder fondos', async () => {
  await b.cuenta(a.uid, 'corriente').update({ saldoCentavos: 100 });
  const n = (await b.cuenta(z.uid, 'corriente').get()).data().numeroCuenta;
  const { ids } = await b.emitirCheques(a, { cuenta: 'corriente', numero: n, concepto: 'Pago a proveedor', aceptaEmision: true, referencia: `${prefijo}_emision`, cheques: [{ centavos: 100, fecha: '2026-10-04' }] });
  const r = await Promise.allSettled([b.cobrarCheque(a, { id: ids[0] }), b.cobrarCheque(z, { id: ids[0] }), b.transferir(a, { ...datos('junto_cheque'), cuenta: 'corriente', numero: n })]);
  assert.ok(r.some(x => x.status === 'fulfilled'));
  assert.equal(await saldo(a.uid, 'corriente'), 0); assert.equal(await saldo(z.uid, 'corriente'), 100);
  assert.equal((await b.cuenta(z.uid, 'corriente').collection('movimientos').get()).size, 1);
});
test('Un cheque con importe o saldo corrupto no crea dinero ni genera movimientos', async () => {
  await b.cuenta(a.uid, 'corriente').update({ saldoCentavos: 500 });
  const n = (await b.cuenta(z.uid, 'corriente').get()).data().numeroCuenta;
  const { ids } = await b.emitirCheques(a, { numero: n, concepto: 'Cheque íntegro', aceptaEmision: true, referencia: `${prefijo}_cheque`, cheques: [{ centavos: 100, fecha: '2026-10-04' }] });
  const ref = db.doc(`cheques/${ids[0]}`);
  await ref.update({ centavos: -100 }); await assert.rejects(b.cobrarCheque(a, { id: ids[0] }));
  await ref.update({ centavos: 100 }); await b.cuenta(z.uid, 'corriente').update({ saldoCentavos: '0' });
  await assert.rejects(b.cobrarCheque(a, { id: ids[0] }));
  assert.equal(await saldo(a.uid, 'corriente'), 500);
  assert.equal((await b.cuenta(a.uid, 'corriente').collection('movimientos').get()).size, 0);
});

test('Una deuda, cupo o total facturado incoherente impide el abono sin tocar la cuenta', async () => {
  await b.cuenta(a.uid, 'ahorros').update({ saldoCentavos: 500 });
  const ref = b.privado(a.uid, 'tarjetas', 'bro_credito');
  const tarjeta = { tipo: 'propia', clase: 'credito', estado: 'activa', cupoCentavos: 10000, deudaCentavos: 1000, totalPagarCentavos: 800, minimoPagarCentavos: 100, proximoCorte: '2026-11-01' };
  for (const cambio of [{ deudaCentavos: '1000' }, { deudaCentavos: -1 }, { cupoCentavos: 500 }, { totalPagarCentavos: 1100 }, { minimoPagarCentavos: 900 }]) {
    await ref.set({ ...tarjeta, ...cambio });
    await assert.rejects(b.pagarTarjetaCredito(a, { cuenta: 'ahorros', centavos: 100, referencia: `${prefijo}_abono` }));
    assert.equal(await saldo(a.uid), 500); assert.equal(await conteo(a.uid, 'operaciones'), 0);
  }
});
