import {readFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
const archivo = process.argv[2] ?? 'evidencia-local/e2e-remoto.log';
async function esperar(marcador) {
  for(let intento=0;intento<180;intento++) {
    const registro = await readFile(archivo,'utf8').catch(()=> '');
    if(registro.includes(marcador)) return;
    if(registro.includes('Some tests failed.')) throw new Error('La prueba remota falló antes del envío.');
    await new Promise(r=>setTimeout(r,1000));
  }
  throw new Error('La app no alcanzó el paso esperado para enviar el push.');
}
async function enviar(modo) {
  await new Promise((resolve,reject)=> {
    const proceso = spawn(process.execPath,['tooling/enviar-push.mjs',modo],{stdio:'inherit'});
    proceso.on('error',reject);
    proceso.on('exit',codigo=>codigo===0 ? resolve() : reject(new Error('El envío FCM falló.')));
  });
}
async function abrirAviso() {
  await new Promise((resolve,reject)=> {
    const proceso = spawn('adb',[
      '-s',process.env.FINANCEBRO_DEVICE_ID ?? 'emulator-5554',
      'shell','am','instrument','-w',
      'ec.financebro.evaluacion.test/androidx.test.runner.AndroidJUnitRunner',
    ]);
    let salida = '';
    proceso.stdout.on('data',datos=> { salida += datos; process.stdout.write(datos); });
    proceso.stderr.pipe(process.stderr);
    proceso.on('error',reject);
    proceso.on('exit',codigo=>codigo===0 && /OK \(1 test\)/.test(salida)
      ? resolve() : reject(new Error('UI Automator no confirmó la apertura del aviso.')));
  });
}
await esperar('evidencia=dispositivo_iniciado');
// El runner puede reinstalar el APK de pruebas; conceder el permiso a esa instalación.
await new Promise((resolve,reject)=>{
  const permiso=spawn('adb',['-s',process.env.FINANCEBRO_DEVICE_ID ?? 'emulator-5554','shell','pm','grant','ec.financebro.financebro','android.permission.POST_NOTIFICATIONS'],{stdio:'inherit'});
  permiso.on('error',reject);
  permiso.on('exit',codigo=>codigo===0?resolve():reject(new Error('No se concedió el permiso nativo de avisos.')));
});
await esperar('evidencia=esperando_push_primer_plano');
if (process.env.FINANCEBRO_GRABAR === 'true') {
  const grabacion = spawn('adb',[
    '-s',process.env.FINANCEBRO_DEVICE_ID ?? 'emulator-5554',
    'shell','screenrecord','--time-limit','60','/sdcard/financebro-push.mp4',
  ],{stdio:'ignore',detached:true});
  grabacion.unref();
  await new Promise(r=>setTimeout(r,2000));
}
await enviar('primer-plano');
await esperar('evidencia=esperando_push_segundo_plano');
await enviar('segundo-plano');
await esperar('evidencia=aviso_android_publicado');
await abrirAviso();
await esperar('evidencia=push_segundo_plano_abierto');
console.log('La app confirmó recepción y apertura del aviso Android en segundo plano.');
