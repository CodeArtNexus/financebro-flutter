import {doc,runTransaction,serverTimestamp,setDoc} from 'firebase/firestore';
export async function ajustarFondos(db,actor,uid,cuenta,delta,motivo,id=crypto.randomUUID()) {
  if(!Number.isInteger(delta) || !delta || Math.abs(delta)>100000000 || motivo.trim().length<5 || motivo.trim().length>120) throw new Error('Revisa el importe y escribe un motivo de 5 a 120 caracteres.');
  const cuentaRef=doc(db,`usuarios/${uid}/cuentas/${cuenta}`);
  const movimiento=doc(db,`usuarios/${uid}/cuentas/${cuenta}/movimientos/${id}`);
  await runTransaction(db,async tx=>{
    const previo=await tx.get(movimiento);
    if(previo.exists()) {
      const m=previo.data();
      if(m.actor!==actor || m.centavos!==delta || m.motivo!==motivo.trim()) throw new Error('La referencia ya corresponde a otro ajuste.');
      return;
    }
    const snapshot=await tx.get(cuentaRef);
    if(!snapshot.exists()) throw new Error('La cuenta ya no está disponible.');
    const saldo=snapshot.data().saldoCentavos+delta;
    if(saldo<0 || saldo>100000000) throw new Error('El saldo resultante debe estar entre USD 0 y USD 1.000.000.');
    tx.update(cuentaRef,{saldoCentavos:saldo,actualizado:serverTimestamp(),ultimoMovimiento:id});
    tx.set(movimiento,{descripcion:`Ajuste de fondos · ${motivo.trim()}`,centavos:delta,categoria:'Ajuste de fondos',tipo:'ajuste',actor,motivo:motivo.trim(),fecha:serverTimestamp()});
  });
  return id;
}
export async function asignarCuenta(db,uid,nombre,ultimos4,id=crypto.randomUUID()) {
  if(nombre.trim().length<2 || nombre.trim().length>60 || !/^[0-9]{4}$/.test(ultimos4)) throw new Error('Escribe un nombre de 2 a 60 caracteres y los cuatro dígitos de una tarjeta de prueba.');
  await setDoc(doc(db,`usuarios/${uid}/cuentas/${id}`),{nombre:nombre.trim(),numero:`•••• ${ultimos4}`,saldoCentavos:0,tarjetaUltimos4:ultimos4,tarjetaRed:'BRO',actualizado:serverTimestamp()});
  return id;
}
