import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,signInWithEmailAndPassword,signOut} from 'firebase/auth';
import {getFirestore,doc,getDoc,getDocs,collectionGroup,query,orderBy,limit} from 'firebase/firestore';
import {firebaseConfig} from './src/firebase-config.js';
import {ajustarFondos} from './src/operaciones.js';
const admin=JSON.parse(await readFile('.secrets/administracion.json','utf8'));
const normal=JSON.parse(await readFile('.secrets/demostracion.json','utf8'));
const app=initializeApp(firebaseConfig,'verificacion-admin');
const auth=getAuth(app),db=getFirestore(app);
try {
 await signInWithEmailAndPassword(auth,normal.correo,normal.clave);
 let denegado=false;
 try{await getDocs(collectionGroup(db,'cuentas'));}catch(e){denegado=e.code==='permission-denied';}
 if(!denegado)throw new Error('Una identidad común pudo consultar cuentas globales.');
 await signOut(auth);
 const sesion=await signInWithEmailAndPassword(auth,admin.correo,admin.clave);
 if((await sesion.user.getIdTokenResult(true)).claims.financebroAdmin!==true)throw new Error('Falta el rol administrativo.');
 const cuentas=await getDocs(collectionGroup(db,'cuentas'));
 const movimientos=await getDocs(query(collectionGroup(db,'movimientos'),orderBy('fecha','desc'),limit(200)));
 if(cuentas.empty||movimientos.empty)throw new Error('Las consultas globales no devolvieron los datos esperados.');
 const cuenta=doc(db,`usuarios/${normal.uid}/cuentas/principal`),saldo=(await getDoc(cuenta)).data().saldoCentavos;
 const id=randomUUID(),motivo='Verificación remota de administración';
 await ajustarFondos(db,admin.uid,normal.uid,'principal',1000,motivo,id);
 await ajustarFondos(db,admin.uid,normal.uid,'principal',1000,motivo,id);
 if((await getDoc(cuenta)).data().saldoCentavos!==saldo+1000)throw new Error('El reintento duplicó o perdió el ajuste.');
 await ajustarFondos(db,admin.uid,normal.uid,'principal',-1000,'Restituir fondos tras verificación remota');
 if((await getDoc(cuenta)).data().saldoCentavos!==saldo)throw new Error('No se conservaron los fondos tras verificar.');
 console.log('Firebase remoto: acceso común rechazado; rol administrativo, consultas globales, ajustes e idempotencia verificados. Los dos movimientos de verificación se conservan.');
} finally {await signOut(auth);await deleteApp(app);}
