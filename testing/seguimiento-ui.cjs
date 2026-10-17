const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const {createServer}=require('node:http');
const {chromium}=require(require.resolve('playwright',{paths:['C:/Users/HP/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
const root=path.resolve(__dirname,'..'),token='00000000-0000-4000-8000-000000000000';
(async()=>{let n=0;const ok=(v,label)=>{assert(v,label);n++;console.log('OK '+label);};
 // API nueva, sin acceso remoto.
 let rpcCalls=[];const ctx={Request,Response,URL,JSON,Date,Number,Error,Deno:{env:{get:()=> 'fixture'},serve:fn=>ctx.handler=fn},createClient:()=>({rpc:async(name,args)=>{rpcCalls.push({name,args});return {data:{ok:true,estado:'Programado'},error:null};}})};
 const src=stripTypeScriptTypes(fs.readFileSync(path.join(root,'supabase/functions/axi-despacho-seguimiento/index.ts'),'utf8')).replace(/^import .*;\s*$/m,'').replace('export async function','async function');vm.runInNewContext(src,ctx);
 const api='https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-despacho-seguimiento';
 const request=async(body,origin='https://axicorepard.com')=>ctx.handler(new Request(api,{method:'POST',headers:{origin,'content-type':'application/json'},body:JSON.stringify(body)}));
 ok((await ctx.handler(new Request(api+'?token='+token))).headers.get('location')==='https://axicorepard.com/despacho-seguimiento.html#token='+token,'GET mantiene token en fragmento');
 for(const b of [null,[],{token,accion:'hack'},{token:'mal',accion:'llegada'},{token,accion:'fecha',fecha:'mañana'}])ok((await request(b)).status===400,'API rechaza entrada inválida');
 ok(rpcCalls.length===0,'entradas inválidas no llaman RPC');
 ok((await request({token,accion:'llegada'},'https://evil.test')).status===403,'API rechaza origen ajeno');
 for(const accion of ['consultar','llegada','fecha']){ok((await request({token,accion,fecha:accion==='fecha'?'2026-10-18T14:00:00-04:00':null})).status===200,'API admite '+accion);}
 ok(rpcCalls.at(-1).args.p_fecha==='2026-10-18T18:00:00.000Z','API convierte hora RD a UTC');
 // Navegador con RPC y correo simulados.
 const server=createServer((req,res)=>{const url=new URL(req.url,'http://localhost');let file=url.pathname.slice(1);if(file==='admin.html'){
   res.setHeader('content-type','text/html; charset=utf-8');return res.end('<!doctype html><html lang="es"><head><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/assets/despacho-seguimiento.css"></head><body><div id="mm-despacho"></div><script src="/assets/despacho-seguimiento-admin.js"></script></body></html>');}
   const files=new Set(['despacho-seguimiento.html','assets/despacho-seguimiento.js','assets/despacho-seguimiento.css','assets/despacho-seguimiento-admin.js','assets/despacho.css']);
   if(!files.has(file)){res.writeHead(404);return res.end();}if(file==='assets/despacho.css')file=fs.existsSync(path.join(root,'assets/despacho.css'))?'assets/despacho.css':'../despacho-fix/assets/despacho.css';
   res.setHeader('content-type',file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.js')?'application/javascript; charset=utf-8':'text/css');res.end(fs.readFileSync(path.join(root,file)));
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{const page=await browser.newPage({viewport:{width:1000,height:900}}),errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
  let state={ok:true,codigo:'RPT-DEMO-001',estado:'Pendiente de hora',estimada:null,llegada:null},requests=[];
  await page.route(api,async route=>{const req=route.request();if(req.method()==='OPTIONS')return route.fulfill({status:204,headers:{'Access-Control-Allow-Origin':base,'Access-Control-Allow-Headers':'content-type'}});const b=req.postDataJSON();requests.push(b);let result=state;if(b.accion==='fecha'){state={...state,estado:'Programado',estimada:b.fecha,desde:'2026-10-18T17:00:00Z',hasta:'2026-10-18T19:00:00Z'};result={ok:true,mensaje:'Hora registrada con tolerancia de ±60 minutos'};}if(b.accion==='llegada'){state={...state,estado:'Llegó',llegada:'2026-10-18T18:15:00Z'};result={ok:true,mensaje:'Llegada registrada'};}await route.fulfill({headers:{'Access-Control-Allow-Origin':base,'Content-Type':'application/json'},body:JSON.stringify(result)});});
  await page.goto(base+'/despacho-seguimiento.html#token='+token);await page.getByText('RPT-DEMO-001 · Pendiente de hora',{exact:true}).waitFor();
  ok(await page.locator('#llegue').isVisible(),'proveedor avisa llegada aun sin hora confirmada');
  await page.locator('#fecha').fill('2026-10-18T14:00');await page.locator('#confirmar').click();await page.getByText('RPT-DEMO-001 · Programado',{exact:true}).waitFor();
  ok(requests.some(x=>x.accion==='fecha'&&x.fecha==='2026-10-18T14:00:00-04:00'),'formulario envía hora RD explícita');
  ok((await page.locator('#detalle').textContent()).includes('Ventana:'),'proveedor ve ventana estimada');
  await page.locator('#llegue').click();await page.getByText('RPT-DEMO-001 · Llegó',{exact:true}).waitFor();ok(await page.locator('#llegue').isHidden(),'llegada confirmada oculta acción');
  state={ok:true,estado:'Cancelado',codigo:'RPT-DEMO-001'};await page.locator('#actualizar').click();await page.getByText('RPT-DEMO-001 · Cancelado',{exact:true}).waitFor();ok(await page.locator('#llegue').isHidden(),'cancelación bloquea aviso de llegada en UI');
  // Pantalla de administración en un DOM aislado, sin iniciar sesión real.
  const data={puede_editar:true,despachos:[{id:1,estado:'Asignado'}],seguimientos:[{id:1,proveedor:'Servicios Demo',turno:1,estado:'Programado',estimada:'2026-10-18T18:00:00Z',desde:'2026-10-18T17:00:00Z',hasta:'2026-10-18T19:00:00Z',canal:null,llegada:null,historial:[],correos:[{tipo:'Asignacion',estado:'Enviado'}]}],candidatos:[{proveedor:'Servicios Demo',disponibilidad:'Dentro de 2 horas',respondio:'2026-10-18T12:00:00Z',seleccionado:true},{proveedor:'Alternativa Demo',disponibilidad:'Dentro de 4 horas',respondio:'2026-10-18T12:01:00Z',seleccionado:false}]};
  await page.addInitScript(d=>{window.fixture=d;window.saved=[];window.sb={rpc:async(name,args)=>{if(name==='axi_despacho_seguimiento_registrar'){window.saved.push(args);window.fixture.seguimientos[0].estado='Llegó';window.fixture.seguimientos[0].llegada='2026-10-18T18:10:00Z';window.fixture.seguimientos[0].canal=args.p_canal;window.fixture.seguimientos[0].nota=args.p_nota;return {data:{ok:true},error:null};}return {data:window.fixture,error:null};}};},data);
  await page.goto(base+'/admin.html');await page.evaluate(()=>window.AXIDespachoSeguimiento.cargar(1));
  ok(await page.getByRole('button',{name:'Registrar llegada',exact:true}).isVisible(),'administración tiene registro manual');
  await page.getByLabel('Canal de confirmación').selectOption('Llamada');await page.getByLabel('Confirmación recibida / nota').fill('Proveedor llamó indicando que ya está en recepción.');
  await page.getByRole('button',{name:'Registrar llegada',exact:true}).click();await page.getByText('Turno 1 · Servicios Demo · Llegó',{exact:true}).waitFor();
  const saved=await page.evaluate(()=>window.saved);ok(saved.length===1&&saved[0].p_canal==='Llamada'&&saved[0].p_accion==='llegada','registro manual por llamada no exige acción del proveedor');
  await page.evaluate(()=>{window.fixture.seguimientos[0].estado='Programado';window.fixture.seguimientos[0].llegada=null;});await page.evaluate(()=>window.AXIDespachoSeguimiento.cargar(1));
  fs.mkdirSync(path.join(root,'output'),{recursive:true});await page.screenshot({path:path.join(root,'output/seguimiento-admin.png'),fullPage:true});
  await page.setViewportSize({width:390,height:844});ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'administración móvil sin desborde');await page.screenshot({path:path.join(root,'output/seguimiento-admin-mobile.png'),fullPage:true});
  await page.goto('about:blank');state={ok:true,codigo:'RPT-DEMO-001',estado:'Pendiente de hora'};await page.goto(base+'/despacho-seguimiento.html#token='+token);await page.getByText('RPT-DEMO-001 · Pendiente de hora',{exact:true}).waitFor();ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'proveedor móvil sin desborde');await page.screenshot({path:path.join(root,'output/seguimiento-proveedor-mobile.png'),fullPage:true});
  ok(errors.length===0,'cero errores JavaScript');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
 console.log(JSON.stringify({checks:n,synthetic:true,remoteWrites:0}));
})().catch(e=>{console.error(e);process.exit(1);});
