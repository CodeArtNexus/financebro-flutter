// Preferencia local: no añade lecturas al servidor ni depende de la sesión.
const boton = document.getElementById('apariencia');
const sistema = matchMedia('(prefers-color-scheme: dark)');
let eleccion = localStorage.getItem('apariencia-bro') ?? 'sistema';
function aplicar() {
  const oscuro = eleccion === 'oscuro' || (eleccion === 'sistema' && sistema.matches);
  document.documentElement.dataset.apariencia = oscuro ? 'oscuro' : 'claro';
  boton.textContent = oscuro ? 'Modo claro' : 'Modo oscuro';
  boton.setAttribute('aria-label', oscuro ? 'Activar modo claro' : 'Activar modo oscuro');
  boton.setAttribute('aria-pressed', String(oscuro));
}
boton.addEventListener('click', () => {
  eleccion = document.documentElement.dataset.apariencia === 'oscuro' ? 'claro' : 'oscuro';
  localStorage.setItem('apariencia-bro', eleccion); aplicar();
});
sistema.addEventListener('change', () => {if (eleccion === 'sistema') aplicar();});
aplicar();
const trazos = {
  sol: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1 1m12 12 1 1M5 19l1-1M18 6l1-1"/>',
  luna: '<path d="M20.5 14A9 9 0 0 1 10 3.5a9 9 0 1 0 10.5 10.5Z"/>',
  tarjeta: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 10h18M7 15h3"/>',
  historial: '<path d="M3 11a9 9 0 1 1 2 7M3 5v6h6M12 7v5l3 2"/>',
  cuenta: '<path d="m3 8 9-5 9 5M4 9h16M6 10v8m6-8v8m6-8v8M3 21h18"/>',
  qr: '<path d="M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h3v3h4v4h-7z"/>',
  buscar: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
  guardar: '<path d="M5 3h12l4 4v14H3V3h2Zm2 0v6h10V3M7 21v-7h10v7"/>',
  documento: '<path d="M5 3h9l5 5v13H5zM14 3v5h5M8 12h8m-8 4h6"/>',
  cerrar: '<path d="m6 6 12 12M6 18 18 6"/>',
  confirmar: '<path d="m5 12 4 4L19 6"/>',
  agregar: '<path d="M12 4v16M4 12h16"/>',
  enviar: '<path d="m3 3 18 9-18 9 4-9-4-9Zm4 9h14"/>',
  flecha: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
  calendario: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M3 11h18m-13 4h2m4 0h2"/>',
  personas: '<circle cx="9" cy="8" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3m1-16a3 3 0 0 1 0 6m2 4a4 4 0 0 1 3 4v2"/>',
};
function elegir(texto) {
  const reglas = [[/modo claro/, 'sol'],[/modo oscuro/, 'luna'],[/cancel|cerrar|no aprobar/, 'cerrar'],[/guardar/, 'guardar'],[/aprobar|confirm|validar/, 'confirmar'],[/tarjeta|cupo/, 'tarjeta'],[/hist|movim|actividad|anteriores/, 'historial'],[/qr|código/, 'qr'],[/cuenta|fondos|ajuste/, 'cuenta'],[/documen|solicitud|chequera|cheque/, 'documento'],[/servicio|pago|corte|vencim/, 'calendario'],[/experiencia|temporada|diseño/, 'sol'],[/envi|respuesta|asesor/, 'enviar'],[/agregar|nuevo|crear/, 'agregar'],[/buscar|revisar/, 'buscar'],[/persona|cliente/, 'personas']];
  return reglas.find(([patron]) => patron.test(texto.toLocaleLowerCase('es')))?.[1] ?? 'flecha';
}
function decorar() {
  for (const b of document.querySelectorAll('button')) {
    if (b.querySelector(':scope > .icono-boton')) continue;
    const tipo = elegir(b.textContent);
    const svg = document.createElementNS('http://www.w3.org/2000/svg','svg');
    svg.classList.add('icono-boton'); svg.setAttribute('viewBox','0 0 24 24'); svg.setAttribute('aria-hidden','true');
    svg.innerHTML = trazos[tipo]; b.prepend(svg);
  }
}
const observador = new MutationObserver(decorar);
observador.observe(document.body, {subtree:true, childList:true});
decorar();
