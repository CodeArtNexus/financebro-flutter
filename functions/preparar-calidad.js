import './sembrar-local.js';
import { getApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { Banco } from './src/banca.js';
// La semilla anterior exige los emuladores antes de modificar datos.
const app = getApp(), db = getFirestore(app), banco = new Banco(db);
const persona = await getAuth(app).getUserByEmail('demo@financebro.test');
const contraparte = await getAuth(app).getUserByEmail('valeria@financebro.test');
const numero = (await db.doc(`usuarios/${contraparte.uid}/cuentas/ahorros`).get()).data().numeroCuenta;
for (let i = 0; i < 45; i++) {
  await banco.ajustar({uid: 'asesor_demo', token: {financebroAdmin: true}}, {
    uid: persona.uid, cuenta: 'ahorros', centavos: i % 2 ? -10 : 10,
    motivo: `Medición de histórico ${i + 1}`, referencia: `calidad_ajuste_${i}`,
  });
}
await banco.guardarContacto({uid: persona.uid}, {id: 'calidad', tipo: 'interno', numero});
await banco.transferir({uid: persona.uid}, {cuenta: 'ahorros', numero, centavos: 10,
  referencia: 'calidad_conversacion', nota: 'Servicio acordado con Valeria',
});
console.log('Histórico paginado y contacto sintéticos preparados en Emulator Suite.');
