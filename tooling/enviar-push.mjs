import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {raiz, datos, escribir, local} from './datos.mjs';

if (local) throw new Error('La recepción FCM se verifica contra el servidor publicado.');
const perfil = JSON.parse(await readFile(process.env.FINANCEBRO_PRUEBA_DEFINES ?? '.secrets/prueba-real.json','utf8'));
const uid = perfil.DEMO_UID ?? perfil.uid;
if (typeof uid !== 'string' || !uid.trim()) throw new Error('Falta la identidad del perfil de evaluación.');
const lista = await datos(`${raiz}/usuarios/${uid}/dispositivos`);
if (!lista.documents?.length) throw new Error('Ingresa y activa las notificaciones antes de comprobar la entrega.');
const segundoPlano = process.argv[2] === 'segundo-plano';
const ruta = segundoPlano ? '/perfil' : '/cuentas';
const titulo = 'FinanceBro';
const texto = segundoPlano ? 'Tu prioridad importa. Revisa tus preferencias.' : 'Tu espacio está actualizado. Revisa tus cuentas.';
const evento = `revision_${randomUUID()}`;
// Usa el consumidor publicado, no un envío FCM directo desde la herramienta.
await escribir(`usuarios/${uid}/notificaciones/${evento}`, {titulo,texto,fecha:new Date(),ruta});
await escribir(`enviosPush/${evento}`, {uid,titulo,cuerpo:texto,destino:ruta,estado:'pendiente',intentos:0,fecha:new Date()});
const reloj = Date.now();
while (Date.now() - reloj < 90000) {
  const envio = await datos(`${raiz}/enviosPush/${evento}`);
  const estado = envio.fields?.estado?.stringValue;
  if (estado === 'enviado') {
    console.log(`Bandeja publicada: transporte aceptado en ${envio.fields.intentos.integerValue} intento(s). La prueba del dispositivo confirma recepción y apertura aparte.`);
    process.exit(0);
  }
  if (['fallido','sin_dispositivo'].includes(estado)) throw new Error(`La bandeja terminó en ${estado}.`);
  await new Promise(r => setTimeout(r,1000));
}
throw new Error('La bandeja no alcanzó un resultado de transporte dentro del plazo de revisión.');
