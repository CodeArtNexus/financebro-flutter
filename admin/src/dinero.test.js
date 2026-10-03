import {test} from 'node:test';
import assert from 'node:assert/strict';
import {centavos,solicitudQr} from './dinero.js';
test('Conserva centavos sin redondear números binarios y rechaza valores ambiguos',()=>{
  assert.equal(centavos('0,29'),29); assert.equal(centavos('-450.05',{negativo:true}),-45005);
  for(const texto of ['1e4','1,000.23','1.001','-2','Infinity','0','1000001']) assert.throws(()=>centavos(texto));
});
test('El QR no acepta importes fuera del límite ni referencias usadas como rutas',()=>{
  assert.match(solicitudQr('cafe-bro',450,'ref-12345678'),/^financebro:\/\/pagar\?/);
  for(const [importe,ref] of [[1000001,'ref-12345678'],[-1,'ref-12345678'],[1.5,'ref-12345678'],[450,'../../cuenta']]) assert.throws(()=>solicitudQr('cafe-bro',importe,ref));
});
