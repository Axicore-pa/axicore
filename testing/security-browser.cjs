const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const playwrightDir=path.dirname(require.resolve('playwright/package.json',{paths:[process.env.AXICORE_NODE_MODULES||__dirname]}));
const {chromium}=require(playwrightDir);
const {babelParse}=require(path.join(playwrightDir,'lib/transform/babelBundle.js'));
const root=path.resolve(__dirname,'..'),assets=root;
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
for(const m of html.matchAll(/<script\b(?:"[^"]*"|'[^']*'|[^'">])*>([\s\S]*?)<\/script>/g))if(m[1].trim())babelParse(m[1],'inline.js',false);
(async()=>{
const browser=await chromium.launch({headless:true,...(process.env.AXICORE_BROWSER?{executablePath:process.env.AXICORE_BROWSER}:{})});
const page=await browser.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.route('**/*',route=>{
 const u=new URL(route.request().url());
 if(u.hostname==='axi.test'){
  const rel=u.pathname==='/'?'index.html':u.pathname.slice(1),file=path.join(rel==='index.html'?root:assets,rel);
  if(!fs.existsSync(file))return route.abort();
  return route.fulfill({body:fs.readFileSync(file),contentType:rel.endsWith('.js')?'application/javascript':rel.endsWith('.css')?'text/css':rel.endsWith('.html')?'text/html':'image/webp'});
 }
 if(u.pathname.endsWith('/supabase.js'))return route.fulfill({contentType:'application/javascript',body:'window.supabase={createClient:()=>({auth:{onAuthStateChange:()=>{}},rpc:async()=>({data:[],error:null})})}'});
 return route.abort();
});
try{
 await page.goto('https://axi.test/');
 const result=await page.evaluate(async()=>{
  const attack=`\"'><img src=x onerror=\"window.injected=true\">&`,fixture={id:7,codigo:attack,nombre:attack,nombre_completo:attack,documento:attack,telefono:attack,email:attack,estado:'Activo',activo:true,unidades:{codigo:attack},propietarios:{nombre:attack},rnc_cedula:attack,servicio:attack,usuario_login:attack,rol:attack,whatsapp:attack,ultimo_login:attack};
  window.injected=false;sesion={rol:'CEO',condominio_id:1};
  const chain=(data)=>new Proxy({}, {get:(_,k)=>k==='then'?resolve=>Promise.resolve({data,error:null}).then(resolve):()=>chain(data)});
  sb={from:t=>chain(t==='accesos'?[]:[fixture]),rpc:async()=>({data:[{...fixture,unidades:[{codigo:attack}],emergencia_nombre:attack,emergencia_relacion:attack,desde:attack}],error:null})};
  const checked=[];
  for(const [fn,id] of [[cargarCapPropietarios,'cap-propietarios-lista'],[cargarCapInquilinos,'cap-inquilinos-lista'],[cargarCapProveedores,'cap-proveedores-lista'],[cargarCapUsuarios,'cap-usuarios-lista'],[cargarCapUnidades,'cap-unidades-lista'],[cargarMiInquilino,'mi-inq-lista']]){
   await fn();const el=document.getElementById(id);
   if(el.querySelector('img,script,iframe'))throw Error('Contenido activo en '+id);
   if(!el.textContent.includes(attack))throw Error('Texto modificado en '+id);
   checked.push(id);
  }
  const samples=[attack,"quote'\"\\path\nnext\rline",'áéíóú & < >',String.fromCharCode(8232,8233)];
  const box=document.createElement('div');document.body.append(box);
  for(const value of samples){
   box.innerHTML=btnComprobante(value);verComprobante=v=>{window.captured=v};box.querySelector('button').click();
   if(window.captured!==value)throw Error('El argumento no conserva su valor');
   if(box.querySelector('img,script'))throw Error('Inyección en controlador');
  }
  if(axiWebURL('javascript:alert(1)')!=='#'||axiWebURL('data:text/html,test')!=='#')throw Error('URL peligrosa');
  if(axiWebURL('https://example.com/a')!=='https://example.com/a')throw Error('URL válida');
  box.remove();return {checked,roundtrips:samples.length,injected:window.injected};
 });
 assert.equal(result.injected,false);assert.deepEqual(errors,[]);console.log('OK',JSON.stringify(result));
 await page.screenshot({path:path.join(root,'../output/seguridad-login-verificado.png')});
}finally{await browser.close()}
})();
