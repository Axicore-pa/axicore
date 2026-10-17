// Ejecutar con Node >= 24. Solo fixtures locales; ninguna respuesta real.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createServer } = require('node:http');
const root = path.resolve(__dirname, '..');
const endpoint = 'https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-despacho-responder';
const token = '00000000-0000-4000-8000-000000000000';
const options = ['De inmediato','Dentro de 2 horas','Dentro de 4 horas','En algún momento del día de hoy','Mañana en la mañana','Mañana en la tarde','No puedo atender'];
let checks = 0;
function pass(label) { checks++; console.log('OK ' + label); }
(async () => {
  let calls = [], mock = {data:{ok:true,mensaje:'Respuesta registrada'},error:null};
  const source = stripTypeScriptTypes(fs.readFileSync(path.join(root,'supabase/functions/axi-despacho-responder/index.ts'),'utf8'))
    .replace(/^import .*;\s*$/m,'').replace('export async function','async function');
  const context = {Request,Response,URL,Set,JSON, Deno:{env:{get:()=> 'fixture'},serve:fn=>context.handle=fn},
    createClient:()=>({rpc:async(name,args)=>{calls.push({name,args});return mock;}})};
  vm.runInNewContext(source,context);
  const handle = context.handle;
  async function post(body,origin='https://axicorepard.com',type='application/json') {
    return handle(new Request(endpoint,{method:'POST',headers:{'content-type':type,...(origin?{origin}:{})},body:typeof body==='string'?body:JSON.stringify(body)}));
  }
  for (const method of ['GET','HEAD']) {
    const r=await handle(new Request(endpoint+'?token='+token,{method}));
    assert.equal(r.status,302); assert.equal(r.headers.get('location'),'https://axicorepard.com/despacho.html#token='+token);
    assert.equal(r.headers.get('cache-control'),'no-store'); assert.equal(await r.text(),'');
  }
  pass('enlaces antiguos GET/HEAD redirigen sin servir HTML');
  for (const bad of ['',"'><script>alert(1)</script>",'https://evil.test',token+'x']) {
    const r=await handle(new Request(endpoint+'?token='+encodeURIComponent(bad)));
    assert.equal(r.headers.get('location'),'https://axicorepard.com/despacho.html');
  }
  assert.equal(calls.length,0); pass('token inválido no se interpola ni consulta datos');
  const pre=await handle(new Request(endpoint,{method:'OPTIONS',headers:{origin:'https://axicorepard.com'}}));
  assert.equal(pre.status,204); assert.equal(pre.headers.get('access-control-allow-origin'),'https://axicorepard.com');
  assert.equal((await handle(new Request(endpoint,{method:'OPTIONS',headers:{origin:'https://evil.test'}}))).status,403);
  pass('preflight del portal y rechazo de origen ajeno');
  assert.equal((await handle(new Request(endpoint,{method:'DELETE'}))).status,405); pass('métodos no admitidos');
  for(const body of [null,[],{token:1,respuesta:options[0]},{token,respuesta:'otra'},{token:'bad',respuesta:options[0]},'{bad']) {
    assert.equal((await post(body)).status,400);
  }
  assert.equal((await post({token,respuesta:options[0]},'https://evil.test')).status,403);
  assert.equal((await post('token=bad','https://axicorepard.com','text/plain')).status,415);
  assert.equal((await post(JSON.stringify({padding:'x'.repeat(5000)}))).status,413);
  assert.equal(calls.length,0); pass('datos/tipo/origen/tamaño inválidos no invocan RPC');
  for (const respuesta of options) {
    const r=await post({token,respuesta}); assert.equal(r.status,200); assert.equal((await r.json()).ok,true);
    assert.equal(calls.at(-1).name,'despacho_responder'); assert.equal(calls.at(-1).args.p_token,token); assert.equal(calls.at(-1).args.p_respuesta,respuesta);
  }
  pass('siete respuestas conservadas exactamente en RPC');
  for(const error of ['Token inválido','Ya respondiste a este despacho','Este despacho ya fue cerrado']) {
    mock={data:{ok:false,error},error:null}; const r=await post({token,respuesta:options[0]}); assert.deepEqual(await r.json(),{ok:false,error});
  }
  pass('errores de negocio vigentes se conservan');
  mock={data:null,error:{message:'internal secret fixture'}};
  const failed=await post({token,respuesta:options[0]}); assert.equal(failed.status,500); assert(!JSON.stringify(await failed.json()).includes('secret'));
  pass('fallo interno sin exponer detalles');

  const {chromium}=require(require.resolve('playwright',{paths:[process.env.AXICORE_NODE_MODULES||'C:/Users/HP/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
  const server=createServer((req,res)=>{
    const p=new URL(req.url,'http://localhost').pathname;
    const files={'/despacho.html':'despacho.html','/assets/despacho.js':'assets/despacho.js','/assets/despacho.css':'assets/despacho.css'};
    if(!files[p]){res.writeHead(404);return res.end();}
    res.setHeader('content-type',p.endsWith('.html')?'text/html; charset=utf-8':p.endsWith('.js')?'text/javascript; charset=utf-8':'text/css; charset=utf-8');
    res.end(fs.readFileSync(path.join(root,files[p])));
  });
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const base='http://127.0.0.1:'+server.address().port;
  const browser=await chromium.launch({headless:true,executablePath:process.env.AXICORE_BROWSER||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  try {
    const page=await browser.newPage({viewport:{width:1000,height:900}}), errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    // Cada enlace de correo abre un documento nuevo; un cambio solo de hash no lo recarga.
    async function visit(url) { await page.goto('about:blank'); await page.goto(url); }
    let payloads=[],mode='success';
    await page.route(endpoint,async route=>{
      const req=route.request(); if(req.method()==='OPTIONS')return route.fulfill({status:204,headers:{'Access-Control-Allow-Origin':base,'Access-Control-Allow-Headers':'content-type'}});
      payloads.push(req.postDataJSON());
      if(mode==='network') return route.abort();
      const body=mode==='success'?{ok:true,mensaje:'Respuesta registrada. Le notificaremos si es seleccionado.'}:mode==='expired'?{ok:false,error:'Este despacho ya fue cerrado'}:{ok:false,error:'<img src=x onerror=alert(1)>'};
      await new Promise(r=>setTimeout(r,150));
      return route.fulfill({status:200,headers:{'Access-Control-Allow-Origin':base,'Content-Type':'application/json; charset=utf-8'},body:JSON.stringify(body)});
    });
    await visit(base+'/despacho.html'); assert(await page.getByText('Enlace inválido',{exact:true}).isVisible()); assert.equal(payloads.length,0); pass('enlace ausente muestra mensaje sin consultar backend');
    await visit(base+'/despacho.html#token='+token);
    assert.equal(await page.locator('.opt').count(),7); assert(await page.getByRole('heading',{name:'¿Cuándo puede asistir?'}).isVisible());
    assert(await page.getByRole('button',{name:'Confirmar respuesta'}).isDisabled());
    assert.equal(await page.locator('.opt').nth(4).getAttribute('data-val'),'Mañana en la mañana');
    pass('formulario renderizado con siete opciones, acentos y botón inicial deshabilitado');
    for(let i=0;i<7;i++){await page.locator('.opt').nth(i).click(); assert.equal(await page.locator('.selected').count(),1);assert.equal(await page.locator('[aria-pressed=true]').count(),1);}
    pass('selección única de las siete opciones');
    await page.locator('#btnEnviar').evaluate(b=>{b.click();b.click();});
    await page.getByText('Puede cerrar esta página.',{exact:true}).waitFor();
    assert.equal(payloads.length,1); assert.equal(payloads[0].respuesta,'No puedo atender');assert.equal(payloads[0].token,token);assert.equal(new URL(page.url()).hash,'');
    pass('confirmación guarda una vez y retira token de URL');
    mode='expired';await visit(base+'/despacho.html#token='+token);await page.locator('.opt').first().click();await page.locator('#btnEnviar').click();await page.getByText('⚠️ Este despacho ya fue cerrado',{exact:true}).waitFor();pass('ventana cerrada informa sin éxito falso');
    mode='xss';await visit(base+'/despacho.html#token='+token);await page.locator('.opt').first().click();await page.locator('#btnEnviar').click();await page.getByText('⚠️ <img src=x onerror=alert(1)>',{exact:true}).waitFor();assert.equal(await page.locator('img').count(),0);pass('respuestas se dibujan como texto, sin HTML ejecutable');
    mode='network';await visit(base+'/despacho.html#token='+token);await page.locator('.opt').first().click();await page.locator('#btnEnviar').click();await page.getByText('No se pudo confirmar el envío. Revise su conexión e intente nuevamente.',{exact:true}).waitFor();assert(await page.locator('#btnEnviar').isEnabled());pass('error de conexión permite reintentar');
    await visit(base+'/despacho.html?token='+token);assert.equal(new URL(page.url()).search,'');assert.equal(new URL(page.url()).hash,'#token='+token);pass('consulta antigua se mueve a fragmento');
    await page.setViewportSize({width:390,height:844});
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    fs.mkdirSync(path.join(root,'output'),{recursive:true});await page.screenshot({path:path.join(root,'output/despacho-mobile.png'),fullPage:true});pass('móvil sin desborde');
    await page.setViewportSize({width:1000,height:900});await page.screenshot({path:path.join(root,'output/despacho-desktop.png'),fullPage:true});
    assert.equal(errors.length,0,errors.join('\n'));pass('cero errores JavaScript');
  } finally {await browser.close();await new Promise(r=>server.close(r));}
  console.log(checks+' comprobaciones aprobadas. Sin cuentas, correos ni cambios reales.');
})().catch(e=>{console.error(e);process.exit(1);});

