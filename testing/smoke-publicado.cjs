// Lectura del sitio público, sin login y sin datos personales.
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[process.env.AXICORE_NODE_MODULES]}));
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.AXICORE_BROWSER});
 try{
  const page=await browser.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('https://axicore-pa.github.io/axicore/?seguridad='+Date.now(),{waitUntil:'networkidle'});
  await page.waitForFunction(()=>typeof AXISession!=='undefined' && typeof sb!=='undefined');
  const result=await page.evaluate(async()=>{
    await AXISession.ready;
    const src=document.querySelector('script[src*="assets/sesiones.js"]').src;
    const asset=await (await fetch(src,{cache:'no-store'})).text();
    const {error}=await sb.rpc('axi_sesion_estado');
    return {src,asset,auth:!!(await sb.auth.getSession()).data.session,anonDenied:!!error,anonCode:error?.code};
  });
  assert(result.src.endsWith('v=20261015-2'));
  assert.equal(result.asset.trim(),fs.readFileSync(path.join(__dirname,'../assets/sesiones.js'),'utf8').trim());
  assert.equal(result.auth,false);assert.equal(result.anonDenied,true);assert.equal(errors.length,0,errors.join('\n'));
  delete result.asset;console.log(JSON.stringify({publicado:true,sinErroresJS:true,...result}));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});

