// Ejecutar con Node y Playwright; jsPDF debe estar disponible en JSPDF_PATH.
// No conecta a Supabase ni envía correos. Usa solo datos sintéticos.
const fs=require('fs'),path=require('path'),assert=require('assert');
const mods=process.env.AXICORE_NODE_MODULES || process.cwd();
const {chromium}=require(require.resolve('playwright',{paths:[mods]}));
const root=path.resolve(__dirname,'..');
const fixture={id:1,codigo:'PG20261014-FAC000123-0001',fecha_pago:'2026-10-14',
 recibido_de:'Residente de prueba',metodo:'Transferencia',banco:'Banco de prueba',referencia:'PRUEBA',
 concepto:'Recibo de aporte a gastos comunes',factura:'FAC-000123',tipo_facturacion:'Propietario',
 periodo:'2026-10',unidad:'2A',monto_factura:4500,abonado_antes:1000,este_pago:2000,balance:1500,
 empresa:{nombre:'Administración de prueba',direccion:'Dirección de prueba',telefono:'000-000-0000',
 email:'administracion@example.test',banco:'Banco de prueba',tipo_cuenta:'Ahorros RD$',numero_cuenta:'000000',beneficiario:'Beneficiario de prueba'},
 propietario:{nombre:'Propietario de prueba',email:'propietario@example.test'},
 inquilino:{email:'inquilino@example.test'},administrador:{nombre:'Administrador de prueba',email:'administrador@example.test'}};
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.AXICORE_BROWSER?{executablePath:process.env.AXICORE_BROWSER}:{})});
 try{
 const page=await browser.newPage();
 await page.setContent('<!doctype html><html><head><meta charset="utf-8"></head><body></body></html>');
 await page.addScriptTag({path:process.env.JSPDF_PATH});
 await page.addScriptTag({content:'async function cargarLibsExport(){}'});
 await page.addScriptTag({path:path.join(root,'assets/recibos-pago.js')});
 const source=fs.readFileSync(path.join(root,'index.html'),'utf8');
 await page.addScriptTag({content:source.slice(source.indexOf('function b64utf8('),source.indexOf('// ==================== CORREO: ventana unica'))});
 const result=await page.evaluate(async r=>{
  const checks=[],check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label)};
  const d=await reciboPagoCrearDocumento(r),pdf=d.doc.output('datauristring').split(',')[1];
  check(pagoTieneRecibo({estado_aprobacion:'Aprobado',estado:'Aplicado'}),'aprobado');
  check(!pagoTieneRecibo({estado_aprobacion:'Sometido'}),'pendiente');
  check(!pagoTieneRecibo({estado_aprobacion:'Aprobado',estado:'Anulado'}),'anulado');
  check(!pagoTieneRecibo({estado_aprobacion:'Aprobado',tipo_movimiento:'Ajuste'}),'ajuste');
  const tenant={...r,tipo_facturacion:'Inquilino'};
  check(reciboPagoDestinatarios(tenant).to.join()==='administrador@example.test','inquilino a administrador');
  check(reciboPagoDestinatarios({...tenant,administrador:null}).to.join()==='propietario@example.test','inquilino a propietario');
  check(reciboPagoDestinatarios(r).to.join()==='propietario@example.test','propietario a propietario');
  check(reciboPagoDestinatarios(tenant).cc.length===0,'sin copias');
  check(reciboPagoDestinatarios({...tenant,administrador:{nombre:'Sin correo'}}).to.length===0,'no cambia destinatario por correo ausente');
  check(reciboPagoNombre(r)===reciboPagoNombre({...r}),'codigo estable');
  let blocked=false;try{await reciboPagoCanvas({...r,empresa:{...r.empresa,telefono:''}})}catch(e){blocked=true}
  check(blocked,'configuración obligatoria');
  check(d.canvas.toDataURL()===(await reciboPagoCrearDocumento(r)).canvas.toDataURL(),'mismo formato en todas las salidas');
  const eml=await construirEml({to:['propietario@example.test'],subject:'Recibo '+r.codigo,texto:'Prueba',
    adjuntos:[{nombre:d.nombre,mime:'application/pdf',base64:pdf}]}).text();
  check(eml.includes('X-Unsent: 1'),'eml borrador');
  check(eml.includes('Subject: Recibo '+r.codigo),'asunto con código');
  check(eml.includes('Content-Type: application/pdf'),'adjunto pdf');
  check(eml.includes(pdf.slice(0,60)),'adjunto corresponde al documento');
  return checks;
 },fixture);
 // Probar el guardado real de la interfaz con servicios simulados.
 await page.setContent('<form id="form-pago"></form><button id="pago-btn-guardar"></button><button id="pago-btn-correo"></button><div id="pago-alert"></div>');
 const ids=['pago-factura','pago-fecha','pago-monto','pago-metodo','pago-banco','pago-referencia','pago-recibido-de','pago-tipo-mov','pago-tipo-apl','pago-obs'];
 await page.evaluate(ids=>ids.forEach(id=>{const e=document.createElement('input');e.id=id;e.value=id==='pago-monto'?'2000':id==='pago-factura'?'123':'PRUEBA';document.body.appendChild(e)}),ids);
 await page.addScriptTag({content:"const $=id=>document.getElementById(id);let pagoEdit=null;const sesion={rol:'CEO'};let llamadas=0,preparaciones=0;const sb={rpc:async()=>{llamadas++;await new Promise(ok=>setTimeout(ok,10));return {data:{id:1,codigo:'TEST',estado_aprobacion:'Aprobado'}}}};function cerrarModal(){}function cargarPagos(){};window.alert=()=>{};abrirReciboPago=async()=>false;enviarReciboPago=async()=>preparaciones++;"});
 const start=source.indexOf('async function guardarPago(e,');
 await page.addScriptTag({content:source.slice(start,source.indexOf('// ==================== GENERAR FACTURACIÓN',start))});
 const saved=await page.evaluate(async()=>{const e={preventDefault(){}};await Promise.all([guardarPago(e,'correo'),guardarPago(e,'correo')]);return {llamadas,preparaciones}});
 assert.equal(saved.llamadas,1,'doble clic no duplica pago');
 assert.equal(saved.preparaciones,0,'error de documento no prepara otro correo ni registra otro pago');
 console.log(JSON.stringify({documentChecks:result,saveChecks:saved}));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
