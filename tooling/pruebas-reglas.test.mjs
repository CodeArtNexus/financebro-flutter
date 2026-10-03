import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp, updateDoc, writeBatch, collectionGroup, getDocs } from 'firebase/firestore';

let entorno;
before(async () => {
  entorno = await initializeTestEnvironment({projectId: 'demo-financebro-reglas', firestore: {host: '127.0.0.1', port: 8080, rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8')}});
});
after(async () => entorno?.cleanup());
beforeEach(async () => {
  await entorno.clearFirestore();
  await entorno.withSecurityRulesDisabled(async contexto => {
    const db = contexto.firestore();
    await setDoc(doc(db, 'usuarios/ana'), {nombre:'Ana Demo',segmento:'ahorro',mostrarSaldo:true});
    for (const cuenta of ['principal','ahorro']) await setDoc(doc(db, `usuarios/ana/cuentas/${cuenta}`), {nombre:'Cuenta demo',numero:'•••• 1234',saldoCentavos:10000});
    await setDoc(doc(db, 'comercios/cafe-bro'), {nombre:'Café Bro',activo:true});
    await setDoc(doc(db, 'comercios/cerrado'), {nombre:'Cerrado',activo:false});
    await setDoc(doc(contexto.firestore(), 'usuarios/ana/cuentas/principal/movimientos/uno'), {centavos: 10000});
    await setDoc(doc(contexto.firestore(), 'experiencias/actual'), {schemaVersion: 1});
  });
});
const base = () => ({nombre: 'Ana Demo', segmento: 'ahorro', mostrarSaldo: true, actualizado: serverTimestamp()});
const cliente = uid => entorno.authenticatedContext(uid).firestore();

test('El propietario lee cuentas y movimientos', async () => {
  await assertSucceeds(getDoc(doc(cliente('ana'), 'usuarios/ana/cuentas/principal')));
  await assertSucceeds(getDoc(doc(cliente('ana'), 'usuarios/ana/cuentas/principal/movimientos/uno')));
});
test('Otra identidad y un visitante no leen datos financieros', async () => {
  for (const db of [cliente('bruno'), entorno.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(db, 'usuarios/ana/cuentas/principal')));
    await assertFails(getDoc(doc(db, 'usuarios/ana/cuentas/principal/movimientos/uno')));
  }
});
test('El cliente no modifica saldos ni crea movimientos fuera de una operación validada', async () => {
  await assertFails(setDoc(doc(cliente('ana'), 'usuarios/ana/cuentas/principal'), {saldoCentavos: 999999}));
  await assertFails(setDoc(doc(cliente('ana'), 'usuarios/ana/cuentas/principal/movimientos/dos'), {centavos: 999999}));
});
test('Se permite un perfil válido de su propietario', async () => {
  await assertSucceeds(setDoc(doc(cliente('ana'), 'usuarios/ana'), base()));
  await assertFails(setDoc(doc(cliente('bruno'), 'usuarios/ana'), base()));
});
test('Se rechazan campos extra, segmento, nombre y fecha inválidos', async () => {
  for (const cambio of [{rol: 'admin'}, {segmento: 'administrador'}, {nombre: 'A'}, {mostrarSaldo: 'si'}, {actualizado: new Date(0)}]) {
    await assertFails(setDoc(doc(cliente('ana'), 'usuarios/ana'), {...base(), ...cambio}));
  }
});
test('La configuración solo es de lectura para usuarios autenticados', async () => {
  await assertSucceeds(getDoc(doc(cliente('ana'), 'experiencias/actual')));
  await assertFails(getDoc(doc(entorno.unauthenticatedContext().firestore(), 'experiencias/actual')));
  await assertFails(setDoc(doc(cliente('ana'), 'experiencias/actual'), {schemaVersion: 2}));
});
test('El dispositivo se registra y elimina solo dentro de su sesión', async () => {
  const ruta = 'usuarios/ana/dispositivos/android';
  await assertSucceeds(setDoc(doc(cliente('ana'), ruta), {token: 'token-de-prueba', actualizado: serverTimestamp()}));
  await assertFails(getDoc(doc(cliente('bruno'), ruta)));
  await assertFails(deleteDoc(doc(cliente('bruno'), ruta)));
  await assertSucceeds(deleteDoc(doc(cliente('ana'), ruta)));
});
test('Un cliente no publica notificaciones', async () => {
  await assertFails(setDoc(doc(cliente('ana'), 'usuarios/ana/notificaciones/uno'), {titulo: 'Falso aviso'}));
});

const administrador = () => entorno.authenticatedContext('administracion', {financebroAdmin:true}).firestore();
function pago(db, {uid='ana', cuenta='principal', id='pago-123456', importe=450, saldo=10000, comercio='cafe-bro', nombre='Café Bro', actor='ana', extra={}} = {}) {
  const lote = writeBatch(db);
  lote.update(doc(db, `usuarios/${uid}/cuentas/${cuenta}`), {saldoCentavos:saldo-importe,actualizado:serverTimestamp(),ultimoMovimiento:id});
  lote.set(doc(db, `usuarios/${uid}/cuentas/${cuenta}/movimientos/${id}`), {descripcion:`Pago QR · ${nombre}`,centavos:-importe,categoria:'Pago QR',tipo:'qr',actor,comercio,referencia:id,fecha:serverTimestamp(),...extra});
  lote.set(doc(db, `usuarios/${uid}/pagos/${id}`), {cuenta,comercio,nombre,centavos:importe,fecha:serverTimestamp()});
  return lote.commit();
}
function ajuste(db, delta, {id='ajuste-12345', actor='administracion', motivo='Asignación de prueba'}={}) {
  const lote=writeBatch(db);
  lote.update(doc(db,'usuarios/ana/cuentas/principal'),{saldoCentavos:10000+delta,actualizado:serverTimestamp(),ultimoMovimiento:id});
  lote.set(doc(db,`usuarios/ana/cuentas/principal/movimientos/${id}`),{descripcion:`Ajuste de fondos · ${motivo}`,centavos:delta,categoria:'Ajuste de fondos',tipo:'ajuste',actor,motivo,fecha:serverTimestamp()});
  return lote.commit();
}
test('Un QR válido descuenta y registra un recibo atómicamente', async () => {
  const db=cliente('ana'); await assertSucceeds(pago(db));
  const cuenta=await getDoc(doc(db,'usuarios/ana/cuentas/principal'));
  const recibo=await getDoc(doc(db,'usuarios/ana/pagos/pago-123456'));
  if(cuenta.data().saldoCentavos !== 9550 || recibo.data().centavos !== 450) throw new Error('El saldo y recibo no coinciden.');
});
test('El saldo y el movimiento se rechazan por separado o con delta inconsistente', async () => {
  const db=cliente('ana');
  await assertFails(updateDoc(doc(db,'usuarios/ana/cuentas/principal'),{saldoCentavos:9550,actualizado:serverTimestamp(),ultimoMovimiento:'pago-123456'}));
  await assertFails(setDoc(doc(db,'usuarios/ana/cuentas/principal/movimientos/pago-123456'),{descripcion:'Pago QR · Café Bro',centavos:-450,categoria:'Pago QR',tipo:'qr',actor:'ana',comercio:'cafe-bro',referencia:'pago-123456',fecha:serverTimestamp()}));
  await assertFails(pago(db,{saldo:9999}));
});
test('Un QR no permite fondos insuficientes, importes fraccionarios, créditos ni identidades falsas', async () => {
  const db=cliente('ana');
  for(const cambio of [{importe:10001},{importe:.5},{importe:-500},{actor:'bruno'},{extra:{rol:'admin'}},{uid:'bruno'}]) await assertFails(pago(db,cambio));
});
test('Solo comercios activos y su nombre canónico pueden cobrar', async () => {
  const db=cliente('ana');
  for(const cambio of [{comercio:'inventado'},{comercio:'cerrado',nombre:'Cerrado'},{nombre:'Otra identidad'}]) await assertFails(pago(db,cambio));
});
test('Una referencia usada no se repite en otra cuenta y su histórico es inmutable', async () => {
  const db=cliente('ana'); await assertSucceeds(pago(db));
  await assertFails(pago(db,{cuenta:'ahorro'}));
  for(const contexto of [db,administrador()]) {
    await assertFails(updateDoc(doc(contexto,'usuarios/ana/cuentas/principal/movimientos/pago-123456'),{centavos:-1}));
    await assertFails(deleteDoc(doc(contexto,'usuarios/ana/cuentas/principal/movimientos/pago-123456')));
    await assertFails(deleteDoc(doc(contexto,'usuarios/ana/pagos/pago-123456')));
  }
  const cuenta=await getDoc(doc(db,'usuarios/ana/cuentas/ahorro'));
  if(cuenta.data().saldoCentavos!==10000) throw new Error('El rechazo debe conservar el saldo.');
});
test('El administrador ajusta fondos con motivo; el cliente no obtiene ese rol', async () => {
  await assertSucceeds(ajuste(administrador(),5000));
  await assertFails(ajuste(cliente('ana'),5000,{actor:'ana'}));
  await assertFails(setDoc(doc(cliente('ana'),'usuarios/ana'),{...base(),financebroAdmin:true}));
});
test('Los ajustes administrativos tampoco admiten deuda, motivos vacíos ni actor ajeno', async () => {
  for(const delta of [-10001,100000000,0]) await assertFails(ajuste(administrador(),delta));
  await assertFails(ajuste(administrador(),500,{motivo:''}));
  await assertFails(ajuste(administrador(),500,{actor:'ana'}));
  await assertSucceeds(ajuste(administrador(),-500));
});
test('El panel puede consultar actividad global; una cuenta común no', async () => {
  for(const grupo of ['cuentas','movimientos']) {
    await assertSucceeds(getDocs(collectionGroup(administrador(),grupo)));
    await assertFails(getDocs(collectionGroup(cliente('ana'),grupo)));
  }
});
test('Solo el administrador asigna cuentas inicialmente sin fondos', async () => {
  const nueva={nombre:'Nueva cuenta',numero:'•••• 4321',tarjetaUltimos4:'4321',tarjetaRed:'BRO',saldoCentavos:0,actualizado:serverTimestamp()};
  await assertFails(setDoc(doc(cliente('ana'),'usuarios/ana/cuentas/nueva'),nueva));
  await assertFails(setDoc(doc(administrador(),'usuarios/ana/cuentas/nueva'),{...nueva,saldoCentavos:100}));
  await assertSucceeds(setDoc(doc(administrador(),'usuarios/ana/cuentas/nueva'),nueva));
});
test('Una meta válida pertenece a su usuario y no altera fondos', async () => {
  const meta={nombre:'Mi viaje',cuenta:'ahorro',objetivoCentavos:200000,aporteMensualCentavos:10000,fechaObjetivo:new Date(Date.now()+86400000*365),actualizado:serverTimestamp()};
  const ruta='usuarios/ana/metas/viaje';
  await assertSucceeds(setDoc(doc(cliente('ana'),ruta),meta));
  await assertFails(getDoc(doc(cliente('bruno'),ruta)));
  for(const cambio of [{cuenta:'inventada'},{objetivoCentavos:-1},{aporteMensualCentavos:200001},{fechaObjetivo:new Date(0)},{rol:'admin'}]) await assertFails(setDoc(doc(cliente('ana'),ruta),{...meta,...cambio}));
  await assertFails(deleteDoc(doc(cliente('bruno'),ruta)));
  await assertSucceeds(deleteDoc(doc(cliente('ana'),ruta)));
});
