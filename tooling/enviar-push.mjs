import { readFile } from 'node:fs/promises';
import { nube, proyecto } from './nube.mjs';
import { raiz, datos, escribir, local } from './datos.mjs';
if (local) throw new Error('FCM requiere Firebase real; los emuladores no envían push.');
const perfil = JSON.parse(await readFile(process.env.FINANCEBRO_PRUEBA_DEFINES ?? '.secrets/prueba-real.json','utf8'));
const uid = perfil.DEMO_UID ?? perfil.uid;
if (typeof uid !== 'string' || !uid.trim()) throw new Error('Falta DEMO_UID en el archivo privado de la prueba.');
const lista = await datos(`${raiz}/usuarios/${uid}/dispositivos`);
const dispositivos = lista.documents ?? [];
if (!dispositivos.length) throw new Error('Abre FinanceBro e ingresa con la identidad de evaluación; activa sus notificaciones primero.');
const segundoPlano = process.argv[2] === 'segundo-plano';
const ruta = segundoPlano ? '/perfil' : '/cuentas';
const titulo = 'FinanceBro';
const texto = segundoPlano ? 'Tu prioridad importa. Revisa tus preferencias.' : 'Tu espacio está actualizado. Revisa tus cuentas.';
await escribir(`usuarios/${uid}/notificaciones/${Date.now()}`,{titulo,texto,fecha:new Date(),ruta});
let enviados=0;
for(const d of dispositivos) {
  try {
  await nube(`https://fcm.googleapis.com/v1/projects/${proyecto}/messages:send`, {method:'POST',body:{message:{token:d.fields.token.stringValue,notification:{title:titulo,body:texto},data:{ruta,uid},android:{priority:'HIGH',notification:{channel_id:'financebro_clientes',icon:'ic_notification'}}}}});
  enviados++;
  } catch (error) {
    if (error.codigo !== 'UNREGISTERED') throw error;
    await datos(`https://firestore.googleapis.com/v1/${d.name}`, {method: 'DELETE'});
    console.log('Se retiró un dispositivo cuyo token había vencido.');
  }
}
if(!enviados) throw new Error('No hay dispositivos vigentes. Abre la app y activa sus notificaciones.');
console.log(`FCM aceptó ${enviados} mensaje(s). Verifica su recepción y apertura en el dispositivo; la aceptación no confirma entrega.`);
