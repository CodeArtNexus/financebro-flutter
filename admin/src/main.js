import './estilo.css';
import {initializeApp} from 'firebase/app';
import {getAuth,setPersistence,browserSessionPersistence,signInWithEmailAndPassword,onAuthStateChanged,signOut,connectAuthEmulator} from 'firebase/auth';
import {getFirestore,connectFirestoreEmulator,collection,collectionGroup,query,orderBy,limit,onSnapshot} from 'firebase/firestore';
import QRCode from 'qrcode';
import {firebaseConfig} from './firebase-config.js';
import {centavos,dinero,solicitudQr} from './dinero.js';
import {ajustarFondos,asignarCuenta} from './operaciones.js';
const local=import.meta.env.VITE_USE_EMULATORS==='true';
const app=initializeApp(local?{apiKey:'demo-key',projectId:'demo-financebro',appId:'demo-admin',authDomain:'localhost'}:firebaseConfig);
const auth=getAuth(app),db=getFirestore(app);
if(local){connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});connectFirestoreEmulator(db,'127.0.0.1',8080);}
await setPersistence(auth,browserSessionPersistence);
const $=id=>document.getElementById(id);
const escapar=valor=>String(valor??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let usuarios=[],cuentas=[],movimientos=[],detalles=[],seleccion=null,desuscribir=[],detalleListener=null,mensajeTimer=null,ajustePendiente=null;
function avisar(texto,error=false){clearTimeout(mensajeTimer);$('mensaje').textContent=texto;$('mensaje').classList.remove('oculto');$('mensaje').classList.toggle('error',error);mensajeTimer=setTimeout(()=>$('mensaje').classList.add('oculto'),error?12000:7000);}
function fallo(error){const codigo=error?.code??'';if(codigo.includes('permission-denied'))return 'Tu cuenta no tiene permiso para realizar esta operación.';if(codigo.includes('unavailable')||codigo.includes('network'))return 'No hay conexión con el servicio. Revisa tu red y vuelve a intentar.';if(codigo.startsWith('auth/'))return 'No se pudo ingresar. Revisa tus credenciales y la conexión.';return error?.message??'No se pudo completar la operación.';}
function detener(){for(const cancelar of desuscribir)cancelar();desuscribir=[];detalleListener?.();detalleListener=null;usuarios=[];cuentas=[];movimientos=[];detalles=[];seleccion=null;ajustePendiente=null;}
function persona(uid){return usuarios.find(u=>u.id===uid)?.nombre??'Persona registrada';}
function cuentaSeleccionada(){return cuentas.find(c=>c.ruta===seleccion);}
function fechas(fecha){return fecha?.toDate?new Intl.DateTimeFormat('es-EC',{dateStyle:'short',timeStyle:'short'}).format(fecha.toDate()):'Sincronizando…';}
function tabla(items,global=false){if(!items.length)return '<p class="vacio">Todavía no hay movimientos en esta vista.</p>';return `<div class="tabla-scroll"><table><thead><tr>${global?'<th>Persona / Cuenta</th>':''}<th>Movimiento</th><th>Fecha</th><th>Importe</th><th>Referencia</th></tr></thead><tbody>${items.map(m=>`<tr>${global?`<td>${escapar(persona(m.uid))}<small>${escapar(cuentas.find(c=>c.uid===m.uid&&c.id===m.cuenta)?.nombre??m.cuenta)}</small></td>`:''}<td>${escapar(m.descripcion)}<small>${escapar(m.categoria)}${m.actor?` · ${escapar(m.actor)}`:''}</small></td><td>${escapar(fechas(m.fecha))}</td><td class="importe ${m.centavos>=0?'ingreso':'gasto'}">${m.centavos>0?'+':''}${escapar(dinero(m.centavos))}</td><td><small>${escapar(m.id)}</small></td></tr>`).join('')}</tbody></table></div>`;}
function render(){
 $('metricas').innerHTML=[['Personas registradas',usuarios.length],['Cuentas asociadas',cuentas.length],['Fondos de prueba',dinero(cuentas.reduce((s,c)=>s+c.saldoCentavos,0))]].map(([label,valor])=>`<div class="cristal metrica"><span>${escapar(label)}</span><strong>${escapar(valor)}</strong></div>`).join('');
 const filtro=$('buscar').value.toLocaleLowerCase('es');
 const visibles=cuentas.filter(c=>`${persona(c.uid)} ${c.uid} ${c.nombre}`.toLocaleLowerCase('es').includes(filtro));
 $('cuentas').innerHTML=visibles.length?visibles.map(c=>`<button class="cuenta" data-cuenta="${escapar(c.ruta)}" aria-pressed="${c.ruta===seleccion}"><span><strong>${escapar(persona(c.uid))}</strong><small>${escapar(c.nombre)} · ${escapar(c.numero)}</small></span><span>${escapar(dinero(c.saldoCentavos))} →</span></button>`).join(''):'<p class="vacio">No hay cuentas para esta búsqueda. Puedes asignar una a una persona registrada.</p>';
 const seleccionada=cuentaSeleccionada();
 $('cuenta-titulo').textContent=seleccionada?.nombre??'Elige una cuenta';
 $('cuenta-subtitulo').textContent=seleccionada?`${persona(seleccionada.uid)} · ${dinero(seleccionada.saldoCentavos)}`:'Sus fondos y movimientos aparecerán aquí.';
 $('ajuste').querySelector('button').disabled=!seleccionada||!auth.currentUser;
 $('global-movimientos').innerHTML=tabla(movimientos,true);
 $('detalle-movimientos').innerHTML=seleccion?tabla(detalles):'<p class="vacio">Selecciona una cuenta para consultar su histórico.</p>';
 const actual=$('persona-cuenta').value;
 $('persona-cuenta').innerHTML=usuarios.map(u=>`<option value="${escapar(u.id)}">${escapar(u.nombre)} · ${escapar(u.id.slice(0,8))}</option>`).join('');
 if(usuarios.some(u=>u.id===actual))$('persona-cuenta').value=actual;
 $('asignar').disabled=!usuarios.length;
}
function escuchar(origen,guardar){return onSnapshot(origen,{includeMetadataChanges:true},snapshot=>{
 guardar(snapshot.docs.map(d=>({id:d.id,ruta:d.ref.path,...d.data()})));
 const cache=snapshot.metadata.fromCache;$('panel').querySelector('.estado').innerHTML=cache?'Datos guardados · reconectando':'<i></i> Datos en vivo';render();
},error=>avisar(fallo(error),true));}
function seleccionar(ruta){seleccion=ruta;detalles=[];detalleListener?.();detalleListener=escuchar(query(collection(db,`${ruta}/movimientos`),orderBy('fecha','desc'),limit(100)),items=>detalles=items);render();}
onAuthStateChanged(auth,async usuario=>{
 detener();$('panel').classList.add('oculto');$('acceso').classList.remove('oculto');$('salir').classList.add('oculto');
 if(!usuario)return;
 try{
  const token=await usuario.getIdTokenResult(true);
  if(auth.currentUser?.uid!==usuario.uid)return;
  if(token.claims.financebroAdmin!==true){await signOut(auth);avisar('Esta cuenta no está habilitada para administrar FinanceBro.',true);return;}
  $('clave').value='';$('panel').classList.remove('oculto');$('acceso').classList.add('oculto');$('salir').classList.remove('oculto');$('identidad').textContent=`${usuario.email} · ${local?'Emuladores locales':'Demostración conectada a Firebase'}`;
  desuscribir.push(escuchar(collection(db,'usuarios'),items=>usuarios=items));
  desuscribir.push(escuchar(collectionGroup(db,'cuentas'),items=>cuentas=items.map(c=>({...c,uid:c.ruta.split('/')[1]}))));
  desuscribir.push(escuchar(query(collectionGroup(db,'movimientos'),orderBy('fecha','desc'),limit(200)),items=>movimientos=items.map(m=>({...m,uid:m.ruta.split('/')[1],cuenta:m.ruta.split('/')[3]}))));
 }catch(error){await signOut(auth);avisar(fallo(error),true);}
});
$('login').addEventListener('submit',async e=>{e.preventDefault();const boton=e.submitter;boton.disabled=true;try{await signInWithEmailAndPassword(auth,$('correo').value.trim(),$('clave').value);}catch(error){avisar(fallo(error),true);}finally{boton.disabled=false;}});
$('salir').addEventListener('click',async()=>{try{await signOut(auth);$('importe').value='';$('motivo').value='';}catch(error){avisar(fallo(error),true);}});
$('buscar').addEventListener('input',render);
$('cuentas').addEventListener('click',e=>{const boton=e.target.closest('[data-cuenta]');if(boton)seleccionar(boton.dataset.cuenta);});
document.querySelector('.pestanas').addEventListener('click',e=>{const boton=e.target.closest('[data-vista]');if(!boton)return;for(const b of document.querySelectorAll('[data-vista]'))b.removeAttribute('aria-current');boton.setAttribute('aria-current','page');for(const id of ['cuentas','movimientos','qr'])$(`vista-${id}`).classList.toggle('oculto',id!==boton.dataset.vista);});
$('ajuste').addEventListener('submit',e=>{e.preventDefault();try{
 const cuenta=cuentaSeleccionada();if(!cuenta)throw new Error('Selecciona una cuenta.');
 const delta=centavos($('importe').value,{negativo:true}),motivo=$('motivo').value.trim();
 if(motivo.length<5||motivo.length>120)throw new Error('Escribe un motivo de 5 a 120 caracteres.');
 if(cuenta.saldoCentavos+delta<0||cuenta.saldoCentavos+delta>100000000)throw new Error('Revisa el saldo que resultaría del ajuste.');
 // Mantiene la referencia si se reintenta el mismo ajuste tras una respuesta incierta.
 if(!ajustePendiente||ajustePendiente.ruta!==seleccion||ajustePendiente.delta!==delta||ajustePendiente.motivo!==motivo)ajustePendiente={ruta:seleccion,uid:cuenta.uid,cuenta:cuenta.id,delta,motivo,id:crypto.randomUUID()};
 $('confirmacion-texto').textContent=`${delta>0?'Agregar':'Retirar'} ${dinero(Math.abs(delta))} a ${cuenta.nombre} de ${persona(cuenta.uid)}. Saldo previsto: ${dinero(cuenta.saldoCentavos+delta)}.`;
 $('confirmacion-motivo').textContent=motivo;$('confirmacion').showModal();
}catch(error){avisar(fallo(error),true);}});
$('confirmacion').addEventListener('close',async()=>{if($('confirmacion').returnValue!=='confirmar'||!ajustePendiente)return;const boton=$('ajuste').querySelector('button');boton.disabled=true;const p=ajustePendiente;try{
 await ajustarFondos(db,auth.currentUser.uid,p.uid,p.cuenta,p.delta,p.motivo,p.id);ajustePendiente=null;$('importe').value='';$('motivo').value='';avisar('Fondos actualizados. El ajuste quedó en el histórico.');
}catch(error){avisar(fallo(error),true);}finally{boton.disabled=!cuentaSeleccionada();}});
$('asignar').addEventListener('click',()=>{$('nueva-cuenta').showModal();});$('cancelar-cuenta').addEventListener('click',()=>{$('nueva-cuenta').close();});
$('form-cuenta').addEventListener('submit',async e=>{e.preventDefault();e.submitter.disabled=true;try{const id=await asignarCuenta(db,$('persona-cuenta').value,$('nombre-cuenta').value,$('tarjeta-cuenta').value);const ruta=`usuarios/${$('persona-cuenta').value}/cuentas/${id}`;$('nueva-cuenta').close();seleccionar(ruta);avisar('Cuenta y tarjeta de prueba asociadas. Ya puedes asignar fondos.');}catch(error){avisar(fallo(error),true);}finally{e.submitter.disabled=false;}});
$('crear-qr').addEventListener('submit',async e=>{e.preventDefault();try{const importe=centavos($('importe-qr').value),referencia=crypto.randomUUID(),codigo=solicitudQr('cafe-bro',importe,referencia);const url=await QRCode.toDataURL(codigo,{width:480,margin:2,errorCorrectionLevel:'M',color:{dark:'#242735',light:'#ffffff'}});const imagen=new Image();imagen.src=url;imagen.alt='QR de pago de demostración a Café Bro';$('imagen-qr').replaceChildren(imagen);$('total-qr').textContent=`${dinero(importe)} · Café Bro`;$('referencia-qr').textContent=`Referencia: ${referencia}`;$('contenido-qr').value=codigo;$('contenido-qr').classList.remove('oculto');$('copiar-qr').classList.remove('oculto');}catch(error){avisar(fallo(error),true);}});
$('copiar-qr').addEventListener('click',async()=>{try{await navigator.clipboard.writeText($('contenido-qr').value);avisar('Código copiado. Puedes pegarlo en la app.');}catch{$('contenido-qr').select();avisar('Selecciona y copia el código mostrado.');}});
