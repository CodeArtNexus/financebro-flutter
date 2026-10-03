import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

let entorno;
before(async () => {
  entorno = await initializeTestEnvironment({projectId: 'demo-financebro-reglas', firestore: {host: '127.0.0.1', port: 8080, rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8')}});
});
after(async () => entorno?.cleanup());
beforeEach(async () => {
  await entorno.clearFirestore();
  await entorno.withSecurityRulesDisabled(async contexto => {
    await setDoc(doc(contexto.firestore(), 'usuarios/ana/cuentas/principal'), {saldoCentavos: 10000});
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
test('El cliente no modifica saldos ni crea movimientos', async () => {
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
