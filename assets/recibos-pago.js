// Recibos de pagos: plantilla del PDF de Access aprobado por Misael.
// Las tres salidas usan el mismo documento; nunca registran ni modifican pagos.
let reciboPagoActual = null;
let reciboPagoDocumento = null;
let reciboPagoCargando = false;

function pagoTieneRecibo(p) {
  return p.estado_aprobacion === 'Aprobado' &&
    !['anulado','anulada','eliminado'].includes(String(p.estado || '').toLowerCase()) &&
    (!p.tipo_movimiento || p.tipo_movimiento === 'Ingreso recibido');
}
function reciboPagoNombre(r) {
  const limpio = x => String(x || '').replace(/[<>:"/\\|?*\u0000-\u001f]/g, '').trim();
  return 'AXICORE_Recibo_' + limpio(r.codigo) + '_' + limpio(r.recibido_de || 'Pago') + '.pdf';
}
function reciboPagoTexto(c, text, x, top, size, color, bold, width, align) {
  c.fillStyle = color; c.textAlign = align || 'left'; c.textBaseline = 'alphabetic';
  let fontSize = size;
  const set = () => { c.font = (bold ? '700 ' : '400 ') + fontSize + 'px "Segoe UI", Arial, sans-serif'; };
  set();
  while (width && c.measureText(String(text)).width > width && fontSize > 7) { fontSize -= .15; set(); }
  if (width && c.measureText(String(text)).width > width) throw new Error('Un dato es demasiado largo para el formato del recibo. Revísalo antes de emitirlo.');
  c.fillText(String(text == null ? '' : text), x, top + fontSize * .80);
}
function reciboPagoLineas(c, text, width, size) {
  c.font = '400 ' + size + 'px "Segoe UI", Arial, sans-serif';
  const out = [];
  String(text || '').split(/\r?\n/).forEach(parrafo => {
    let line = '';
    parrafo.split(/\s+/).filter(Boolean).forEach(word => {
      if (c.measureText(word).width > width) throw new Error('Una observación contiene un texto sin espacios demasiado largo.');
      const next = line ? line + ' ' + word : word;
      if (line && c.measureText(next).width > width) { out.push(line); line = word; } else line = next;
    });
    out.push(line);
  });
  return out;
}
async function reciboPagoCanvas(r) {
  const a = r.empresa || {};
  for (const k of ['nombre','direccion','telefono','email','banco','tipo_cuenta','numero_cuenta','beneficiario']) {
    if (!String(a[k] || '').trim()) throw new Error('Falta ' + k + ' en la configuración de AXICORE. No se copiarán datos antiguos del ejemplo.');
  }
  if (!r.codigo || !r.fecha_pago || !r.factura || !r.recibido_de) throw new Error('El pago no tiene todos los datos necesarios para emitir el recibo.');
  for (const k of ['monto_factura','abonado_antes','este_pago','balance']) if (!Number.isFinite(Number(r[k]))) throw new Error('Importe inválido en el recibo.');
  await document.fonts.load('400 10px "Segoe UI"');
  await document.fonts.load('700 10px "Segoe UI"');
  const canvas = document.createElement('canvas'), scale = 300 / 72;
  canvas.width = Math.round(612.16 * scale); canvas.height = Math.round(792.06 * scale);
  const c = canvas.getContext('2d'); c.scale(scale, scale);
  c.fillStyle = '#fff'; c.fillRect(0,0,612.16,792.06);
  const navy='#1b2a4a',gold='#c08a3e',gray='#8b887b',text='#222';
  const t=(s,x,y,size=9,color=text,bold=false,w,align)=>reciboPagoTexto(c,s,x,y,size,color,bold,w,align);
  c.fillStyle=navy; c.fillRect(17.96,35.847,540.75,64.923);
  t(a.nombre,39.546,59.5,12.99,'#fff',true,280);
  t('RECIBO DE PAGO',536.02,56.9,17.984,'#fff',true,205,'right');
  c.fillStyle='#fff'; c.fillRect(361.03,73.877,174.99,14.763);
  t(r.codigo,535.02,77.6,9.989,gold,true,173,'right');
  t(a.direccion,41.035,116.6,9.004,text,false,365);
  t('Tel. '+a.telefono+'  |  '+a.email,41.035,130.5,9.004,text,false,495);
  t('Fecha de pago',416.2,116.6,9.004,navy,true,75);
  t(r.fecha_pago.split('T')[0].split('-').reverse().join('/'),536.02,116.7,9.004,text,false,65,'right');
  c.fillStyle=gold; c.fillRect(40.579,152.031,495.61,1.989);
  t('RECIBIDO DE',41.035,172,10.997,navy,true);
  t('DETALLE DEL PAGO',318.96,172,10.997,navy,true);
  t(r.recibido_de,41.131,189.2,9.989,text,true,260);
  t('Factura aplicada: '+r.factura,41.131,203.9,9.004,gray,false,260);
  const concepto=reciboPagoLineas(c,'Concepto: '+r.concepto,217,9.004);
  if (concepto.length>3) throw new Error('El concepto supera el espacio del recibo de referencia. Abrevia el concepto antes de emitir.');
  concepto.forEach((s,i)=>t(s,318.96,189+i*12,9.004,gray));
  const extra=Math.max(0,concepto.length-1)*12;
  t('Metodo: '+(r.metodo||''),318.96,203.9+extra,9.004,gray,false,217);
  t('Banco: '+(r.banco||''),318.96,218.9+extra,9.004,gray,false,217);
  const delta=Math.max(0,extra-12);
  c.fillStyle=navy;c.fillRect(40.483,255.232+delta,495.71,24.038);
  c.fillStyle='#f7f5f0';c.fillRect(40.483,279.17+delta,495.71,34.99);
  const xs=[49.559,163.69,277.93,392.06];
  ['MONTO FACTURA','ABONADO ANTES','ESTE PAGO','BALANCE'].forEach((s,i)=>t(s,xs[i],265.2+delta,9.004,'#fff',true,111));
  const money=n=>Number(n).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
  [r.monto_factura,r.abonado_antes,r.este_pago,r.balance].forEach((v,i)=>{
    c.fillStyle='#fff';c.fillRect(xs[i]-.4,289.284+delta,104.93,13.756);
    t('$'+money(v),xs[i],293+delta,i>1?10.997:9.989,i===3?gold:i===1?gray:text,i>1,108);
  });
  t('Balance = Monto factura - Abonado antes - Este pago',41.035,319.2+delta,7.996,gray);
  t('DATOS PARA TRANSFERENCIA',41.035,348.4+delta,9.004,navy,true);
  t('Banco: '+a.banco,41.035,364.4+delta,9.004,gray,false,495);
  t('Cuenta: '+a.tipo_cuenta+' '+a.numero_cuenta,41.035,376.9+delta,9.004,gray,false,495);
  t('Beneficiario: '+a.beneficiario,41.035,389.3+delta,9.004,gray,false,495);
  t('Observaciones:',41.035,418.2+delta,9.004,navy,true);
  const obs=[r.referencia?'Ref. '+r.referencia:'',r.observaciones||''].filter(Boolean).join('\n');
  const notas=reciboPagoLineas(c,obs,495,9.004);
  const footer=Math.max(476.221+delta,435.8+delta+notas.length*12+20);
  if (footer>710) throw new Error('Las observaciones superan una página. No se ha recortado información; reduce su longitud antes de emitir.');
  notas.forEach((s,i)=>t(s,41.131,435.8+delta+i*12,9.004,gray));
  c.fillStyle=gold;c.fillRect(40.579,footer,495.61,1.989);
  t('Gracias por confiar en '+a.nombre+'.',288.38,footer+17.08,9.989,navy,true,495,'center');
  t(a.direccion+'  |  Tel. '+a.telefono+'  |  '+a.email,288.38,footer+32.18,6.987,gray,false,495,'center');
  return canvas;
}
async function reciboPagoCrearDocumento(r) {
  await cargarLibsExport();
  const canvas=await reciboPagoCanvas(r);
  const {jsPDF}=window.jspdf;
  const doc=new jsPDF({unit:'pt',format:[612.16,792.06],compress:true});
  doc.setProperties({title:'Recibo de pago '+r.codigo,subject:'Pago aplicado a '+r.factura,author:r.empresa.nombre,creator:'AXICORE'});
  doc.addImage(canvas.toDataURL('image/png'),'PNG',0,0,612.16,792.06,undefined,'FAST');
  return {doc,canvas,nombre:reciboPagoNombre(r)};
}
async function reciboPagoConsultar(id) {
  const {data,error}=await sb.rpc('fn_pago_recibo',{p_pago_id:Number(id)});
  if(error) throw new Error(error.message);
  if(!data) throw new Error('No se pudo consultar el recibo.');
  return data;
}
function reciboPagoModal() {
  if($('modal-recibo-pago')) return;
  const el=document.createElement('div');el.id='modal-recibo-pago';el.className='modal-overlay';
  el.innerHTML='<div class="modal" style="max-width:760px"><h3>Recibo de pago</h3><div id="recibo-pago-nota" role="status"></div><div id="recibo-pago-vista" style="max-height:65vh;overflow:auto"></div><div class="modal-actions"><button class="btn btn-outline" type="button" onclick="imprimirReciboPago()">Imprimir</button><button class="btn btn-outline" type="button" onclick="enviarReciboPago()">Enviar recibo</button><button class="btn btn-outline" type="button" onclick="descargarReciboPagoActual()">↓ PDF</button><button class="btn btn-outline" type="button" onclick="cerrarModal(\'modal-recibo-pago\')">Cerrar</button></div></div>';
  document.body.appendChild(el);
}
async function abrirReciboPago(id,descargar=false) {
  if(reciboPagoCargando) return;
  reciboPagoCargando=true;
  try {
    const r=await reciboPagoConsultar(id), d=await reciboPagoCrearDocumento(r);
    reciboPagoActual=r;reciboPagoDocumento=d;reciboPagoModal();
    $('recibo-pago-nota').textContent='Recibo '+r.codigo+' · Factura '+r.factura;
    const img=document.createElement('img');img.alt='Vista previa del recibo '+r.codigo;img.src=d.canvas.toDataURL('image/png');img.style.width='100%';
    $('recibo-pago-vista').replaceChildren(img);$('modal-recibo-pago').classList.add('show');
    if(descargar) d.doc.save(d.nombre);
  } catch(e) {alert('No se pudo generar el recibo: '+e.message);return false;}
  finally {reciboPagoCargando=false;}
}
function reciboPagoDestinatarios(r) {
  // Regla expresa de Misael: nunca enviar este recibo al inquilino ni añadir copias.
  const titular=r.tipo_facturacion==='Inquilino'?(r.administrador || r.propietario):r.propietario;
  const emails=x=>String(x||'').split(/[,;\s]+/).map(s=>s.trim()).filter(s=>/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s));
  const to=emails(titular && titular.email);
  return {to,cc:[]};
}
async function reciboPagoActualizar() {
  if(!reciboPagoActual) throw new Error('Abre primero un recibo.');
  // Volver a validar aprobación y estado; no emitir un documento anulado después de abrir la vista.
  const r=await reciboPagoConsultar(reciboPagoActual.id);
  const d=await reciboPagoCrearDocumento(r);
  reciboPagoActual=r;reciboPagoDocumento=d;
  const vista=$('recibo-pago-vista');if(vista && vista.firstElementChild) vista.firstElementChild.src=d.canvas.toDataURL('image/png');
  return d;
}
async function descargarReciboPagoActual() {
  try {const d=await reciboPagoActualizar();d.doc.save(d.nombre);}catch(e){alert(e.message);}
}
async function imprimirReciboPago() {
  const w=window.open('about:blank','_blank');
  if(!w){alert('Permite abrir la ventana de impresión para este sitio.');return;}
  w.opener=null;
  try {
    const d=await reciboPagoActualizar();
    w.document.write('<!doctype html><html><head><title>Recibo AXICORE</title><style>@page{size:letter;margin:0}html,body{margin:0}img{display:block;width:612pt;height:792pt}</style></head><body><img alt="Recibo" src="'+d.canvas.toDataURL('image/png')+'"></body></html>');
    w.document.close();
    const im=w.document.querySelector('img');if(!im.complete)await new Promise(ok=>im.onload=ok);
    w.focus();w.print();
  }catch(e){w.close();alert(e.message);}
}
async function enviarReciboPago() {
  try {
    const d=await reciboPagoActualizar(),r=reciboPagoActual;
    const destinos=reciboPagoDestinatarios(r);
    const texto='Saludos,\n\nAdjunto el recibo '+r.codigo+' correspondiente al pago recibido el '+r.fecha_pago.split('-').reverse().join('/')+
      ', aplicado a la factura '+r.factura+(r.periodo?' del período '+r.periodo:'')+
      (r.unidad?', unidad '+r.unidad:'')+'.\n\nMonto recibido: RD$ '+fmt(r.este_pago)+'.\n\nGracias por confiar en '+r.empresa.nombre+
      '.\nTel. '+r.empresa.telefono+' | '+r.empresa.email;
    cerrarModal('modal-recibo-pago');
    await abrirCorreo({to:destinos.to,cc:destinos.cc,subject:'Recibo de pago '+r.codigo+' | Factura '+r.factura,texto,
      adjuntos:[{nombre:d.nombre,mime:'application/pdf',base64:d.doc.output('datauristring').split(',')[1]}]},'AXICORE_Correo_'+r.codigo+'.eml');
    $('modal-recibo-pago').classList.add('show');
  }catch(e){alert('No se pudo preparar el correo: '+e.message);}
}
