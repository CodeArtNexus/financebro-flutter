import { randomBytes } from 'node:crypto';
import { mkdir, readFile, writeFile, chmod } from 'node:fs/promises';
import { nube, proyecto } from './nube.mjs';
import { local, datos, raiz, campos } from './datos.mjs';
const archivo=local?'.secrets/administracion-local.json':'.secrets/administracion.json';
await mkdir('.secrets',{recursive:true});
let acceso;
try { acceso=JSON.parse(await readFile(archivo,'utf8')); }
catch { acceso={correo:'admin@financebro.test',clave:local?'FinanceBro-admin-local-2026!':randomBytes(24).toString('base64url')}; }
let usuario;
if (local) {
  const respuesta=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:acceso.correo,password:acceso.clave,displayName:'Administración FinanceBro',returnSecureToken:true})});
  usuario=await respuesta.json();
  if (!usuario.localId) {
    const login=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:acceso.correo,password:acceso.clave,returnSecureToken:true})});
    usuario=await login.json();
  }
  if (!usuario.localId) throw new Error('No se pudo preparar la identidad administrativa local.');
  const respuestaRol=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/demo-financebro/accounts:update',{method:'POST',headers:{authorization:'Bearer owner','content-type':'application/json'},body:JSON.stringify({localId:usuario.localId,customAttributes:JSON.stringify({financebroAdmin:true})})});
  if(!respuestaRol.ok) throw new Error('El emulador rechazó la asignación del rol administrativo.');
} else {
  const existentes=await nube(`https://identitytoolkit.googleapis.com/v1/projects/${proyecto}/accounts:lookup`,{method:'POST',body:{email:[acceso.correo]}});
  usuario=existentes.users?.[0];
  if(!usuario) usuario=await nube(`https://identitytoolkit.googleapis.com/v1/projects/${proyecto}/accounts`,{method:'POST',body:{email:acceso.correo,password:acceso.clave,displayName:'Administración FinanceBro',emailVerified:true}});
  const atributos=JSON.parse(usuario.customAttributes ?? '{}');
  await nube(`https://identitytoolkit.googleapis.com/v1/projects/${proyecto}/accounts:update`,{method:'POST',body:{localId:usuario.localId,customAttributes:JSON.stringify({...atributos,financebroAdmin:true})}});
}
acceso.uid=usuario.localId;
// Las credenciales remotas y locales usan archivos distintos, evitando sobrescribirlas.
const destino=local?'.secrets/administracion-local.json':archivo;
await writeFile(destino,JSON.stringify(acceso,null,2),{mode:0o600}); await chmod(destino,0o600);
await datos(`${raiz}/comercios/cafe-bro`,{method:'PATCH',body:{fields:campos({nombre:'Café Bro',activo:true})}});
if (!local) {
  const origen=`https://firebase.googleapis.com/v1beta1/projects/${proyecto}`;
  const apps=await nube(`${origen}/webApps`);
  let app=apps.apps?.find(a=>a.displayName==='FinanceBro Administración');
  if(!app) {
    let operacion=await nube(`${origen}/webApps`,{method:'POST',body:{displayName:'FinanceBro Administración'}});
    for(let intento=0;!operacion.done && intento<30;intento++) {
      await new Promise(r=>setTimeout(r,2000)); operacion=await nube(`https://firebase.googleapis.com/v1beta1/${operacion.name}`);
    }
    if(operacion.error || !operacion.done) throw new Error('La app web de Firebase sigue pendiente o tuvo un error.');
    app=operacion.response;
  }
  const configuracion=await nube(`${origen}/webApps/${app.appId}/config`);
  const publico=Object.fromEntries(['apiKey','authDomain','projectId','storageBucket','messagingSenderId','appId'].map(k=>[k,configuracion[k]]));
  await writeFile('admin/src/firebase-config.js',`// Configuración pública del cliente. Las reglas y el rol protegen el acceso.\nexport const firebaseConfig = ${JSON.stringify(publico,null,2)};\n`);
}
console.log(`Administración ${local?'local':'remota'} preparada. El acceso se guardó exclusivamente en ${destino}. Los fondos y movimientos existentes se conservan.`);
