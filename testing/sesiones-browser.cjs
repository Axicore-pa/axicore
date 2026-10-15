// Navegador real + Supabase JS 2.45.4; servidor simulado, ninguna cuenta real.
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[process.env.AXICORE_NODE_MODULES]}));
const root=path.resolve(__dirname,'..');
const user={id:'00000000-0000-0000-0000-000000000001',aud:'authenticated',role:'authenticated',email:'usuario@example.test',app_metadata:{provider:'email'},user_metadata:{},identities:[],created_at:'2026-01-01T00:00:00Z'};
let active=null,n=0,history=0,blocks=0,signouts=0;
const jwt=sid=>[Buffer.from('{"alg":"HS256","typ":"JWT"}').toString('base64url'),Buffer.from(JSON.stringify({sub:user.id,role:'authenticated',aal:'aal1',session_id:sid,exp:Math.floor(Date.now()/1000)+3600,iat:Math.floor(Date.now()/1000),aud:'authenticated'})).toString('base64url'),'synthetic'].join('.');
const sid=token=>{try{return JSON.parse(Buffer.from(token.split('.')[1],'base64url')).session_id}catch{return null}};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.AXICORE_BROWSER});
 const context=await browser.newContext();
 const errors=[];
 context.on('page',p=>p.on('pageerror',e=>errors.push(e.message)));
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url()),respond=(data,status=200)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
  if(u.hostname==='axi.test'){
    const rel=u.pathname.replace(/^\//,'')||'index.html';
    let body=fs.readFileSync(path.join(root,rel));
    if(rel==='index.html') body=body.toString().replace('</body>',`<script>entrarAlApp=function(){document.getElementById('app-shell').style.display='flex';document.getElementById('login-screen').style.display='none'};</script></body>`);
    return route.fulfill({contentType:rel.endsWith('.js')?'application/javascript':'text/html',body});
  }
  if(u.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'application/javascript',body:fs.readFileSync(path.join(__dirname,'supabase-2.45.4.js'))});
  if(u.pathname==='/auth/v1/token'){
    const session_id='synthetic-session-'+(++n);
    return respond({access_token:jwt(session_id),token_type:'bearer',expires_in:3600,refresh_token:'refresh-'+n,user});
  }
  if(u.pathname==='/auth/v1/logout'){signouts++;return respond({});}
  if(u.pathname==='/auth/v1/user')return respond(user);
  const current={sid:sid((req.headers().authorization||'').replace(/^Bearer /i,'')),tab:req.headers()['x-axicore-tab']};
  const valid=active && active.sid===current.sid && active.tab===current.tab;
  if(u.pathname.endsWith('/rpc/axi_sesion_iniciar')){
    if(active&&!valid){blocks++;return respond({sesion_bloqueada:true,rol:'Propietario',mensaje:'Ya existe una sesión en curso con este correo. Cierra la otra sesión para acceder.'});}
    if(!active){active=current;history++;}
    return respond({rol:'Propietario',usuario_id:1,nombre:'Usuario Prueba',condominio_id:1});
  }
  if(u.pathname.endsWith('/rpc/axi_sesion_cerrar')){if(valid)active=null;return respond(null);}
  if(u.pathname.endsWith('/rpc/axi_sesion_estado'))return respond({valida:!!valid});
  if(!valid)return respond({code:'42501',message:'AXI_SESSION_INVALID: Sesión no vigente'},403);
  return respond([]);
 });
 try{
  const first=await context.newPage();await first.goto('https://axi.test/');
  const login=async p=>{
    await p.locator('#login-email').fill(user.email);await p.locator('#login-pass').fill('clave-sintetica');await p.locator('#login-form').evaluate(f=>f.requestSubmit());
  };
  await login(first);await first.waitForFunction(()=>sesion?.rol==='Propietario');
  const original={...active};assert.equal(history,1);console.log('OK entrada inicial con SDK real');
  const second=await context.newPage();await second.goto('https://axi.test/');
  assert.equal(await second.evaluate(()=>sesion),null);console.log('OK pestaña nueva sin autenticación heredada');
  await login(second);await second.waitForFunction(()=>document.getElementById('login-alert').textContent.includes('sesión en curso'));
  assert.deepEqual(active,original);assert.equal(await first.evaluate(()=>sb.auth.getSession().then(x=>x.data.session.user.email)),user.email);
  console.log('OK segundo ingreso bloqueado sin alterar tokens de primera');
  const popupPromise=first.waitForEvent('popup');await first.evaluate(()=>window.open('https://axi.test/','_blank'));const copy=await popupPromise;
  await copy.waitForFunction(()=>document.getElementById('login-alert')?.textContent.includes('sesión en curso'));
  assert.notEqual(await copy.evaluate(()=>sessionStorage.getItem('axi-tab-v1')),await first.evaluate(()=>sessionStorage.getItem('axi-tab-v1')));
  assert.deepEqual(active,original);assert.equal(signouts,0);console.log('OK pestaña duplicada cambia prueba y no revoca primera');
  await first.reload();await first.waitForFunction(()=>sesion?.rol==='Propietario');assert.equal(history,1);assert.deepEqual(active,original);console.log('OK recarga conserva sesión e historial');
  await first.evaluate(()=>cerrarSesion());assert.equal(active,null);assert.equal(signouts,1);console.log('OK cerrar sólo sesión local');
  await login(second);await second.waitForFunction(()=>sesion?.rol==='Propietario');assert.equal(history,2);console.log('OK ingreso posterior al cierre');
  active=null;await second.evaluate(()=>sb.rpc('cualquier_rpc'));await second.waitForFunction(()=>sesion===null && document.getElementById('app-shell').style.display==='none');console.log('OK rechazo del servidor oculta aplicación');
  assert.equal(errors.length,0,errors.join('\n'));assert(blocks>=2);console.log('PRUEBAS NAVEGADOR COMPLETADAS');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});

