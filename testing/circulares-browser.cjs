const {chromium}=require(require.resolve('playwright',{paths:[process.env.AXICORE_NODE_MODULES||'C:/Users/HP/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.join(__dirname,'..'),out=path.join(root,'../output/circulares');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.AXICORE_BROWSER||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const page=await browser.newPage({viewport:{width:1400,height:950}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>{const u=new URL(route.request().url());if(u.hostname==='axi.test'){
  const rel=u.pathname.slice(1)||(fs.existsSync(path.join(root,'index-circulares.html'))?'index-circulares.html':'index.html');const file=path.join(root,rel);if(!file.startsWith(root)||!fs.existsSync(file))return route.abort();
  return route.fulfill({body:fs.readFileSync(file),contentType:rel.endsWith('.css')?'text/css':rel.endsWith('.js')?'application/javascript':'text/html'});
 }if(u.pathname.endsWith('/supabase.js'))return route.fulfill({contentType:'application/javascript',body:'window.supabase={createClient:()=>({auth:{onAuthStateChange:()=>{}},rpc:async()=>({data:[],error:null})})}'});
 if(u.pathname.endsWith('/pdf.min.mjs')||u.pathname.endsWith('/pdf.worker.min.mjs'))return route.fulfill({contentType:'application/javascript',headers:{'Access-Control-Allow-Origin':'*'},body:fs.readFileSync(path.join(__dirname,u.pathname.split('/').pop()))});return route.abort();});
 try{
 await page.goto('https://axi.test/');
 await page.evaluate(()=>{
  const canvas=document.createElement('canvas');canvas.width=850;canvas.height=1050;const c=canvas.getContext('2d');c.fillStyle='#fff';c.fillRect(0,0,850,1050);c.fillStyle='#1b2a49';c.fillRect(0,0,850,150);c.fillStyle='#fff';c.font='bold 34px Arial';c.fillText('AXICORE · CIRCULAR',65,90);c.fillStyle='#1b2a49';c.font='bold 32px Arial';c.fillText('Asamblea de residentes',65,235);c.font='23px Arial';c.fillText('Condominio de prueba',65,285);c.fillText('Esta circular contiene datos sintéticos.',65,390);c.fillText('No se enviarán correos durante esta prueba.',65,440);
  const bytes=Uint8Array.from(atob(canvas.toDataURL('image/png').split(',')[1]),x=>x.charCodeAt(0));
  window.testState={reads:0,sends:0,failDownload:false,staff:false,upload:0,published:true,circular:{id:'11111111-1111-4111-8111-111111111111',titulo:'Asamblea de residentes',descripcion:'Información para la próxima reunión del condominio.',mime:'image/png',creado_at:'2026-10-16T00:00:00Z',publicado_at:'2026-10-16T00:00:00Z',enviado_at:null,leido_at:null,lecturas:0,envios:{total:0}}};
  sb={auth:{onAuthStateChange:()=>{}},rpc:async(name,args)=>{const s=testState;
   if(name==='axi_circulares_listar')return {data:{staff:s.staff,destinatarios:3,circulares:[{...s.circular}]}};
   if(name==='axi_circular_abrir')return {data:{archivo:'1/test.png',mime:s.circular.mime}};
   if(name==='axi_circular_leida'){s.reads++;s.circular.leido_at=new Date().toISOString();return {data:{comprobante:'comprobante-sintetico',leido_at:s.circular.leido_at}};}
   if(name==='axi_circular_enviar'){s.sends++;s.circular.enviado_at=new Date().toISOString();return {data:3};}
   if(name==='axi_circular_preparar'){s.codigoRecibido=args.p_codigo;return {data:{id:s.circular.id,archivo:'1/test.png'}};}
   if(name==='axi_circular_publicar'){s.published=true;return {data:null};}
   if(name==='axi_circular_comprobantes')return {data:{lecturas:[],correos:[]}};
   return {data:[]};
  },storage:{from:()=>({download:async()=>testState.failDownload?{error:{message:'fallo sintético'}}:{data:new Blob([testState.circular.mime==='application/pdf'?testPdf:bytes],{type:testState.circular.mime})},upload:async()=>{testState.upload++;return {data:{path:'1/test.png'}};}})}};
  window.startTest=async(rol='Propietario')=>{AXICirculares.cerrar();testState.staff=['CEO','Asistente'].includes(rol);sesion={rol,usuario_id:1,nombre:'Residente de prueba',condominio_id:1};condominiosUsuario=[{rol,condominio_id:1,nombre:'Condominio de prueba'}];cargarMiCuenta=async()=>{};cargarDashboard=async()=>{};actualizarBadgeAprobaciones=async()=>{};$('login-screen').style.display='none';entrarAlApp();};
 });
 await page.evaluate(()=>startTest());await page.getByRole('dialog',{name:'Nueva Circular Disponible'}).waitFor();
 assert(await page.getByRole('button',{name:'Abrir circular',exact:true}).isVisible());
 await page.screenshot({path:path.join(out,'aviso-residente.png')});
 await page.getByRole('button',{name:'No leída',exact:true}).click();assert.equal(await page.evaluate(()=>testState.reads),0);
 await page.evaluate(()=>startTest());await page.getByRole('dialog',{name:'Nueva Circular Disponible'}).waitFor();console.log('OK No leída reaparece al próximo inicio');
 await page.getByRole('button',{name:'Abrir circular',exact:true}).click();await page.getByText('Acuse registrado; correo al CEO en cola de envío.',{exact:false}).waitFor();
 assert.equal(await page.evaluate(()=>testState.reads),1);assert(await page.locator('dialog canvas').evaluate(c=>c.width>0));
 assert.equal(await page.locator('dialog a[download],dialog iframe,dialog embed').count(),0);
 await page.screenshot({path:path.join(out,'visor-circular.png')});
 await page.getByRole('button',{name:'Cerrar y volver al inicio'}).click();assert(await page.locator('#page-mi-cuenta').evaluate(e=>e.classList.contains('active')));console.log('OK Abrir confirma y cerrar vuelve al inicio de unidad');
 await page.evaluate(()=>startTest());assert.equal(await page.locator('dialog[open]').count(),0);console.log('OK circular leída no reaparece');
 await page.evaluate(()=>{testState.circular.leido_at=null;return startTest();});await page.getByRole('button',{name:'Leída',exact:true}).click();await page.getByText('Acuse registrado. El correo al CEO está en cola de envío.').waitFor();assert.equal(await page.evaluate(()=>testState.reads),2);
 await page.getByRole('button',{name:'Cerrar',exact:true}).last().click();console.log('OK Leída confirma sin abrir');
 await page.evaluate(()=>{testState.circular.leido_at=null;testState.failDownload=true;return startTest();});await page.getByRole('button',{name:'Abrir circular',exact:true}).click();await page.getByText('No se pudo abrir la circular.',{exact:false}).waitFor();assert.equal(await page.evaluate(()=>testState.reads),2);console.log('OK archivo que falla no registra lectura');
 await page.evaluate(()=>{testState.failDownload=false;return startTest('CEO');});await page.waitForFunction(()=>!document.getElementById('axi-circ-new').hidden);await page.evaluate(()=>navegar('circulares'));
 await page.getByRole('button',{name:'Enviar',exact:true}).click();await page.getByRole('dialog',{name:'Enviar circular'}).waitFor();await page.getByRole('dialog').getByRole('button',{name:'Enviar',exact:true}).click();await page.getByText('3 avisos en cola de envío.').waitFor();assert.equal(await page.evaluate(()=>testState.sends),1);await page.getByRole('dialog').getByRole('button',{name:'Cerrar',exact:true}).last().click();
 await page.screenshot({path:path.join(out,'gestion-ceo.png')});console.log('OK envío individual en cola y botón evita repetición');
 await page.getByRole('button',{name:'Nueva circular',exact:true}).click();await page.locator('#axi-circ-title').fill('Publicación de prueba');
 assert.equal(await page.locator('#axi-circ-code').evaluate(e=>e.checkValidity()),false);
 await page.locator('#axi-circ-code').fill('cir-dh2-007-2026');
 const png=await page.evaluate(()=>{const c=document.createElement('canvas');c.width=c.height=20;return c.toDataURL('image/png').split(',')[1];});
 await page.locator('#axi-circ-file').setInputFiles({name:'circular.png',mimeType:'image/png',buffer:Buffer.from(png,'base64')});await page.getByRole('button',{name:'Subir y publicar',exact:true}).click();await page.waitForFunction(()=>testState.upload===1);await page.getByRole('dialog').waitFor({state:'detached'});assert.equal(await page.evaluate(()=>testState.codigoRecibido),'CIR-DH2-007-2026');console.log('OK carga y publicación desde formulario de staff con código manual');
 const streams=['0.1 0.2 0.4 rg 30 650 535 150 re f','0.6 0.4 0.2 rg 30 500 535 150 re f'];
 const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>',
 '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << >> /Contents 4 0 R >>',`<< /Length ${streams[0].length} >>\nstream\n${streams[0]}\nendstream`,
 '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << >> /Contents 6 0 R >>',`<< /Length ${streams[1].length} >>\nstream\n${streams[1]}\nendstream`];
 let pdfText='%PDF-1.4\n';const offsets=[0];objects.forEach((o,i)=>{offsets.push(Buffer.byteLength(pdfText));pdfText+=`${i+1} 0 obj\n${o}\nendobj\n`;});const xref=Buffer.byteLength(pdfText);pdfText+='xref\n0 7\n0000000000 65535 f \n'+offsets.slice(1).map(o=>String(o).padStart(10,'0')+' 00000 n \n').join('')+'trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n'+xref+'\n%%EOF\n';const pdf=Buffer.from(pdfText).toString('base64');
 await page.evaluate(base64=>{window.testPdf=Uint8Array.from(atob(base64),c=>c.charCodeAt(0));testState.circular.mime='application/pdf';testState.circular.leido_at=null;return startTest();},pdf);
 await page.getByRole('button',{name:'Abrir circular',exact:true}).click();await page.getByText('Página 1 de 2',{exact:true}).waitFor();await page.getByRole('button',{name:'Siguiente',exact:true}).click();await page.getByText('Página 2 de 2',{exact:true}).waitFor();await page.getByRole('button',{name:'Cerrar y volver al inicio'}).click();console.log('OK PDF real de dos páginas en canvas sin visor nativo');
 await page.setViewportSize({width:390,height:844});await page.evaluate(()=>{testState.circular.mime='image/png';testState.circular.leido_at=null;return startTest('Inquilino');});await page.getByRole('button',{name:'No leída',exact:true}).click();await page.evaluate(()=>navegar('circulares'));await page.screenshot({path:path.join(out,'residente-movil.png')});
 assert(await page.locator('#axi-circ-new').isHidden());assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));console.log('OK residente sin carga y vista móvil sin desbordamiento');
 assert.equal(errors.length,0,errors.join('\n'));console.log('Pruebas de navegador completadas; ningún envío real.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});

