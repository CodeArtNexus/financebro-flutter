import { readFile } from 'node:fs/promises';
import { local, datos, raiz, campos } from './datos.mjs';
let uid;
if (local) {
  const respuesta = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo', {method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:'demo@financebro.test',password:'FinanceBro-local-2026!',returnSecureToken:true})});
  uid = (await respuesta.json()).localId;
} else uid = JSON.parse(await readFile('.secrets/demostracion.json', 'utf8')).uid;
if (!uid) throw new Error('Primero prepara los datos de demostración.');
for (const [cuenta, ultimos4] of [['principal','2048'],['ahorro','7712']]) {
  await datos(`${raiz}/usuarios/${uid}/cuentas/${cuenta}?updateMask.fieldPaths=tarjetaUltimos4&updateMask.fieldPaths=tarjetaRed`, {method:'PATCH',body:{fields:campos({tarjetaUltimos4:ultimos4,tarjetaRed:'BRO'})}});
}
console.log('Tarjetas de demostración asociadas. Los saldos e históricos se conservan.');
