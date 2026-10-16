const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[process.env.AXICORE_NODE_MODULES||'C:/Users/HP/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.AXICORE_BROWSER||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  const response=await page.goto('https://axicore-pa.github.io/axicore/?seguridad='+Date.now(),{waitUntil:'networkidle'});
  assert(response.ok());
  const actual=await response.text(),expected=fs.readFileSync(path.join(__dirname,'../index.html'),'utf8');
  assert.equal(actual.replace(/\r\n/g,'\n').trim(),expected.replace(/\r\n/g,'\n').trim());
  const state=await page.evaluate(()=>({escape:typeof axiEscapeHTML,js:typeof axiJSString,csp:document.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content,session:sesion}));
  assert.equal(state.escape,'function');assert.equal(state.js,'function');assert(state.csp.includes("object-src 'none'"));assert.equal(state.session,null);assert.deepEqual(errors,[]);
  console.log('OK publicación idéntica, funciones y protección de navegador cargadas, sin sesión ni errores JS.');
 }finally{await browser.close()}
})().catch(e=>{console.error(e.message);process.exit(1)});
