// Lectura del portal público, sin cuentas ni envío de correos.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[process.env.AXICORE_NODE_MODULES||'C:/Users/HP/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.AXICORE_BROWSER||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('https://axicore-pa.github.io/axicore/?circulares='+Date.now(),{waitUntil:'networkidle'});
  const result=await page.evaluate(async()=>{
   const src=document.querySelector('script[src*="assets/circulares.js"]').src;
   return {src,asset:await (await fetch(src,{cache:'no-store'})).text(),module:typeof window.AXICirculares?.iniciar==='function',auth:!!(await sb.auth.getSession()).data.session};
  });
  assert(result.src.endsWith('v=20261016-2'));
  assert.equal(result.asset.replace(/\r\n/g,'\n').trim(),fs.readFileSync(path.join(__dirname,'../assets/circulares.js'),'utf8').replace(/\r\n/g,'\n').trim());
  assert.equal(result.module,true);assert.equal(result.auth,false);assert.equal(errors.length,0,errors.join('\n'));
  console.log('OK portal publicado: versión nueva, código idéntico al probado, módulo cargado y cero errores JS; sin sesión ni envíos.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
