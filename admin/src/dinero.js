export function centavos(texto, {negativo=false}={}) {
  const normalizado=String(texto).trim().replace(',','.');
  if(!(negativo?/^-?\d{1,7}(\.\d{1,2})?$/:/^\d{1,7}(\.\d{1,2})?$/).test(normalizado)) throw new Error('Escribe un importe con hasta dos decimales.');
  const signo=normalizado.startsWith('-')?-1:1;
  const [entero,decimal='']=normalizado.replace('-','').split('.');
  const valor=signo*(Number(entero)*100+Number(decimal.padEnd(2,'0')));
  if(valor===0 || Math.abs(valor)>100000000) throw new Error('Usa un importe distinto de cero, de hasta USD 1.000.000.');
  return valor;
}
export const dinero=valor=>new Intl.NumberFormat('es-EC',{style:'currency',currency:'USD'}).format(valor/100);
export function solicitudQr(comercio, importe, referencia) {
  if(!/^[a-z0-9-]{2,60}$/.test(comercio) || !Number.isInteger(importe) || importe<1 || importe>1000000 || !/^[a-zA-Z0-9_-]{8,80}$/.test(referencia)) throw new Error('El importe del QR debe estar entre USD 0,01 y USD 10.000.');
  return `financebro://pagar?${new URLSearchParams({comercio,centavos:String(importe),referencia})}`;
}
