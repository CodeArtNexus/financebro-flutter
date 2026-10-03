import { nube, proyecto } from './nube.mjs';

const operacion = await nube(`https://serviceusage.googleapis.com/v1/projects/${proyecto}/services:batchEnable`, {
  method: 'POST', body: { serviceIds: ['firestore.googleapis.com', 'identitytoolkit.googleapis.com', 'fcm.googleapis.com'] },
});
if (operacion.name && !operacion.done) {
  for (let intento = 0; intento < 30; intento++) {
    await new Promise(r => setTimeout(r, 2000));
    const estado = await nube(`https://serviceusage.googleapis.com/v1/${operacion.name}`);
    if (estado.error) throw new Error(estado.error.message);
    if (estado.done) break;
    if (intento === 29) throw new Error('Las APIs siguen activándose. Vuelve a ejecutar la configuración.');
  }
}
try {
  await nube(`https://identitytoolkit.googleapis.com/admin/v2/projects/${proyecto}/config`);
} catch (error) {
  if (!error.message.includes('CONFIGURATION_NOT_FOUND')) throw error;
  throw new Error(`Inicia Authentication con «Comenzar» en https://console.firebase.google.com/project/${proyecto}/authentication y activa Correo electrónico/contraseña. No se habilita facturación automáticamente.`);
}
await nube(`https://identitytoolkit.googleapis.com/admin/v2/projects/${proyecto}/config?updateMask=signIn.email`, {
  method: 'PATCH', body: { signIn: { email: { enabled: true, passwordRequired: true } } },
});
console.log('APIs y autenticación por correo habilitadas en el proyecto de prueba.');
