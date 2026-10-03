import { readFile } from 'node:fs/promises';
import { nube, proyecto } from './nube.mjs';
import { raiz, datos, escribir, local } from './datos.mjs';
if (local) throw new Error('FCM requiere Firebase real; los emuladores no envían push.');
const { uid } = JSON.parse(await readFile('.secrets/demostracion.json','utf8'));
const lista = await datos(`${raiz}/usuarios/${uid}/dispositivos`);
const dispositivos = lista.documents ?? [];
if (!dispositivos.length) throw new Error('Abre FinanceBro e ingresa con el usuario demo; activa sus notificaciones primero.');
const ruta = '/cuentas';
const titulo = 'FinanceBro';
const texto = 'Tu espacio está actualizado. Revisa tus cuentas.';
await escribir(`usuarios/${uid}/notificaciones/${Date.now()}`,{titulo,texto,fecha:new Date(),ruta});
let enviados=0;
for(const d of dispositivos) {
  await nube(`https://fcm.googleapis.com/v1/projects/${proyecto}/messages:send`, {method:'POST',body:{message:{token:d.fields.token.stringValue,notification:{title:titulo,body:texto},data:{ruta,uid},android:{priority:'HIGH',notification:{channel_id:'financebro_clientes',icon:'ic_notification'}}}}});
  enviados++;
}
console.log(`FCM aceptó ${enviados} mensaje(s). Verifica su recepción y apertura en el dispositivo; la aceptación no confirma entrega.`);
