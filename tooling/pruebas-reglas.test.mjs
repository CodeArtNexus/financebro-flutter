import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp, updateDoc, collectionGroup, getDocs } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';
let entorno;
before(async()=>{entorno=await initializeTestEnvironment({projectId:'demo-financebro-reglas',firestore:{host:'127.0.0.1',port:Number(process.env.REGLAS_FIRESTORE_PORT??8080),rules:await readFile(new URL('../firestore.rules',import.meta.url),'utf8')},storage:{host:'127.0.0.1',port:Number(process.env.REGLAS_STORAGE_PORT??9199),rules:await readFile(new URL('../storage.rules',import.meta.url),'utf8')}});});
after(async()=>entorno?.cleanup());
beforeEach(async()=>{await entorno.clearFirestore();await entorno.withSecurityRulesDisabled(async c=>{
 const db=c.firestore();await setDoc(doc(db,'usuarios/ana'),{nombre:'Ana Demo',segmento:'ahorro',mostrarSaldo:true});
 await setDoc(doc(db,'usuarios/ana/cuentas/ahorros'),{nombre:'Ahorros',saldoCentavos:10000,numeroCuenta:'10000000000001',estado:'activa'});
 for(const col of ['movimientosGlobales','contactos','tarjetas','autopagos','datosPersonales','operaciones','notificaciones'])await setDoc(doc(db,`usuarios/ana/${col}/uno`),{dato:'privado'});
 await setDoc(doc(db,'usuarios/ana/cuentas/ahorros/movimientos/uno'),{centavos:10000});
 await setDoc(doc(db,'usuarios/ana/solicitudes/corriente'),{estado:'borrador',uid:'ana'});
 await setDoc(doc(db,'directorioCuentas/10000000000001'),{uid:'ana',cuenta:'ahorros'});
 await setDoc(doc(db,'servicios/luz'),{nombre:'Luz',activo:true});await setDoc(doc(db,'experiencias/actual'),{schemaVersion:1});
});});
const cliente=uid=>entorno.authenticatedContext(uid),admin=()=>entorno.authenticatedContext('asesor',{financebroAdmin:true});
const base=()=>({nombre:'Ana Demo',segmento:'ahorro',mostrarSaldo:true,actualizado:serverTimestamp()});
test('El propietario consulta sus cuentas y todo su histórico',async()=>{for(const r of ['cuentas/ahorros','cuentas/ahorros/movimientos/uno','movimientosGlobales/uno'])await assertSucceeds(getDoc(doc(cliente('ana').firestore(),`usuarios/ana/${r}`)));});
test('Otra identidad y un visitante no consultan finanzas',async()=>{for(const c of [cliente('bruno'),entorno.unauthenticatedContext()])for(const r of ['cuentas/ahorros','movimientosGlobales/uno','tarjetas/uno','operaciones/uno'])await assertFails(getDoc(doc(c.firestore(),`usuarios/ana/${r}`)));});
test('Nadie escribe saldos desde el cliente, incluso con rol de administrador',async()=>{for(const c of [cliente('ana'),admin()])await assertFails(updateDoc(doc(c.firestore(),'usuarios/ana/cuentas/ahorros'),{saldoCentavos:999999}));});
test('El histórico y los recibos son inmutables desde ambos clientes',async()=>{for(const c of [cliente('ana'),admin()])for(const r of ['cuentas/ahorros/movimientos/uno','movimientosGlobales/uno','operaciones/uno']){await assertFails(setDoc(doc(c.firestore(),`usuarios/ana/${r}`),{centavos:999}));await assertFails(deleteDoc(doc(c.firestore(),`usuarios/ana/${r}`)));}});
test('El directorio del receptor no expone su UID ni su saldo',async()=>{for(const c of [cliente('ana'),admin()])await assertFails(getDoc(doc(c.firestore(),'directorioCuentas/10000000000001')));});
test('El propietario actualiza un perfil válido sin crear roles',async()=>{await assertSucceeds(setDoc(doc(cliente('ana').firestore(),'usuarios/ana'),base()));for(const extra of [{rol:'admin'},{segmento:'admin'},{nombre:'A'},{mostrarSaldo:'si'},{actualizado:new Date(0)}])await assertFails(setDoc(doc(cliente('ana').firestore(),'usuarios/ana'),{...base(),...extra}));});
test('Los datos de identidad son privados incluso para el panel',async()=>{await assertSucceeds(getDoc(doc(cliente('ana').firestore(),'usuarios/ana/datosPersonales/uno')));for(const c of [cliente('bruno'),admin()])await assertFails(getDoc(doc(c.firestore(),'usuarios/ana/datosPersonales/uno')));});
test('La persona no aprueba solicitudes ni programa cobros escribiendo documentos',async()=>{for(const r of ['solicitudes/corriente','autopagos/uno','contactos/uno','tarjetas/uno'])await assertFails(setDoc(doc(cliente('ana').firestore(),`usuarios/ana/${r}`),{estado:'activa'}));});
test('El catálogo se consulta autenticado y se administra únicamente en el servidor',async()=>{await assertSucceeds(getDoc(doc(cliente('ana').firestore(),'servicios/luz')));await assertFails(getDoc(doc(entorno.unauthenticatedContext().firestore(),'servicios/luz')));for(const c of [cliente('ana'),admin()])await assertFails(setDoc(doc(c.firestore(),'servicios/luz'),{activo:true}));});
test('El rol especial consulta cuentas y solicitudes globales; otro usuario no',async()=>{for(const col of ['cuentas','solicitudes','movimientosGlobales','tarjetas']){await assertSucceeds(getDocs(collectionGroup(admin().firestore(),col)));await assertFails(getDocs(collectionGroup(cliente('ana').firestore(),col)));}});
test('El dispositivo y sus tokens solo pertenecen a su sesión',async()=>{const r='usuarios/ana/dispositivos/android';await assertSucceeds(setDoc(doc(cliente('ana').firestore(),r),{token:'token-de-prueba',actualizado:serverTimestamp()}));await assertFails(getDoc(doc(admin().firestore(),r)));await assertFails(deleteDoc(doc(cliente('bruno').firestore(),r)));await assertSucceeds(deleteDoc(doc(cliente('ana').firestore(),r)));});
test('El cliente no fabrica notificaciones ni solicitudes de push',async()=>{await assertFails(setDoc(doc(cliente('ana').firestore(),'usuarios/ana/notificaciones/nuevo'),{titulo:'Falso'}));await assertFails(setDoc(doc(cliente('ana').firestore(),'enviosPush/nuevo'),{uid:'ana'}));});
test('Se permite guardar una meta propia con cuenta y valores válidos',async()=>{const m={nombre:'Viaje',cuenta:'ahorros',objetivoCentavos:100000,aporteMensualCentavos:5000,fechaObjetivo:new Date(Date.now()+86400000),actualizado:serverTimestamp()};await assertSucceeds(setDoc(doc(cliente('ana').firestore(),'usuarios/ana/metas/viaje'),m));await assertFails(setDoc(doc(cliente('bruno').firestore(),'usuarios/ana/metas/viaje'),m));await assertFails(setDoc(doc(cliente('ana').firestore(),'usuarios/ana/metas/otra'),{...m,cuenta:'ajena'}));});
let version=0;
const archivo=c=>ref(c.storage(),`expedientes/ana/corriente/constitucion/archivo_${Date.now()}_${version++}.pdf`);
const pdf=()=>new TextEncoder().encode('%PDF-1.7\nDocumento sintético');
test('El propietario sube un documento privado del borrador',async()=>{await assertSucceeds(uploadBytes(archivo(cliente('ana')),pdf(),{contentType:'application/pdf'}));});
test('Otra persona no sube ni descarga documentos de la solicitud',async()=>{const f=archivo(cliente('ana'));await assertSucceeds(uploadBytes(f,pdf(),{contentType:'application/pdf'}));await assertFails(getBytes(ref(cliente('bruno').storage(),f.fullPath)));await assertFails(uploadBytes(archivo(cliente('bruno')),pdf(),{contentType:'application/pdf'}));});
test('El asesor puede leer un documento para revisarlo',async()=>{const f=archivo(cliente('ana'));await assertSucceeds(uploadBytes(f,pdf(),{contentType:'application/pdf'}));await assertSucceeds(getBytes(ref(admin().storage(),f.fullPath)));});
test('Se rechazan formatos y tamaños no permitidos',async()=>{await assertFails(uploadBytes(archivo(cliente('ana')),pdf(),{contentType:'text/html'}));await assertFails(uploadBytes(archivo(cliente('ana')),new Uint8Array(5*1024*1024+1),{contentType:'application/pdf'}));});
test('Los documentos enviados a revisión ya no admiten cambios',async()=>{await entorno.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'usuarios/ana/solicitudes/corriente'),{estado:'revision'}));await assertFails(uploadBytes(archivo(cliente('ana')),pdf(),{contentType:'application/pdf'}));});

test('El registro de identidad no es consultable y el domicilio de una solicitud solo se comparte con propietario y asesor',async()=>{
 await entorno.withSecurityRulesDisabled(async c=>{
   await setDoc(doc(c.firestore(),'identidadesRegistradas/huella'),{uid:'ana'});
   await setDoc(doc(c.firestore(),'usuarios/ana/solicitudes/fisica_bro_ahorros'),{tipo:'fisica',domicilio:{direccion:'Calle ficticia 100'}});
 });
 for(const c of [cliente('ana'),cliente('bruno'),admin()])await assertFails(getDoc(doc(c.firestore(),'identidadesRegistradas/huella')));
 for(const c of [cliente('ana'),admin()])await assertSucceeds(getDoc(doc(c.firestore(),'usuarios/ana/solicitudes/fisica_bro_ahorros')));
 await assertFails(getDoc(doc(cliente('bruno').firestore(),'usuarios/ana/solicitudes/fisica_bro_ahorros')));
 for(const c of [cliente('ana'),admin()])await assertFails(setDoc(doc(c.firestore(),'usuarios/ana/solicitudes/fisica_bro_ahorros'),{estado:'enviada'}));
});

test('El cupo, los consumos y los estados de cuenta de una tarjeta propia solo los escribe el servidor',async()=>{
 await entorno.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'usuarios/ana/tarjetas/bro_credito'),{clase:'credito',cupoCentavos:150000,deudaCentavos:20000});
  await setDoc(doc(c.firestore(),'usuarios/ana/tarjetas/bro_credito/estadosCuenta/2026-10-15'),{totalCentavos:20000});
 });
 for(const r of ['usuarios/ana/tarjetas/bro_credito','usuarios/ana/tarjetas/bro_credito/estadosCuenta/2026-10-15']){
  for(const c of [cliente('ana'),admin()])await assertSucceeds(getDoc(doc(c.firestore(),r)));
  await assertFails(getDoc(doc(cliente('bruno').firestore(),r)));
  for(const c of [cliente('ana'),admin()])await assertFails(setDoc(doc(c.firestore(),r),{cupoCentavos:999999}));
 }
});

test('El fondo de una tarjeta propia es privado, inmutable y tiene un tamaño máximo',async()=>{
 await entorno.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'usuarios/ana/tarjetas/bro_ahorros'),{tipo:'propia'}));
 const ruta=`tarjetas/ana/bro_ahorros/fondos/imagen_${Date.now()}.png`,foto=new Uint8Array([137,80,78,71,13,10,26,10]);
 await assertSucceeds(uploadBytes(ref(cliente('ana').storage(),ruta),foto,{contentType:'image/png'}));
 await assertSucceeds(getBytes(ref(cliente('ana').storage(),ruta)));
 await assertSucceeds(getBytes(ref(admin().storage(),ruta)));
 await assertFails(getBytes(ref(cliente('bruno').storage(),ruta)));
 await assertFails(uploadBytes(ref(cliente('bruno').storage(),ruta),foto,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(cliente('ana').storage(),ruta),foto,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(cliente('ana').storage(),ruta.replace('.png','_grande.png')),new Uint8Array(2*1024*1024+1),{contentType:'image/png'}));
});
test('Una tarjeta externa no permite subir un fondo FinanceBro',async()=>{
 await entorno.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'usuarios/ana/tarjetas/externa'),{tipo:'externa'}));
 await assertFails(uploadBytes(ref(cliente('ana').storage(),`tarjetas/ana/externa/fondos/imagen_${Date.now()}.png`),new Uint8Array([137,80,78,71]),{contentType:'image/png'}));
});
