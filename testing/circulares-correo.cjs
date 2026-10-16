const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),{stripTypeScriptTypes}=require('node:module');
const source=stripTypeScriptTypes(fs.readFileSync(path.join(__dirname,'../supabase/functions/axi-circulares-correo/index.ts'),'utf8')).replace(/^import .*;\s*$/m,'');
(async()=>{
 let handler,key='clave-sintetica',calls=[],posts=[],finish=[],responseStatus=200;
 const jobs=[{id:'job1',lote:'lote1',para:'residente@example.test',cc:['ceo@example.test'],asunto:'Aviso',texto:'Prueba',intentos:1}];
 const sb={rpc:async(name,args)=>{calls.push(name);if(name==='axi_circular_cola_tomar')return {data:jobs};finish.push(args);return {};}};
 vm.runInNewContext(source,{Deno:{serve:fn=>handler=fn,env:{get:k=>k==='RESEND_API_KEY'?key:'valor-sintetico'}},createClient:()=>sb,Response,JSON,AbortSignal,fetch:async(url,options)=>{posts.push({url,options});return new Response(JSON.stringify(responseStatus===200?{id:'resend-simulado'}:{name:'rate_limit_exceeded'}),{status:responseStatus});},setTimeout:fn=>{fn();return 0;},Promise});
 assert.equal((await handler({method:'GET'})).status,405);key=null;assert.equal((await handler({method:'POST'})).status,503);assert.equal(posts.length,0);key='clave-sintetica';
 assert.equal((await handler({method:'POST'})).status,200);assert.equal(finish[0].p_error,null);const body=JSON.parse(posts[0].options.body);assert.equal(body.to.length,1);assert.deepEqual(body.cc,['ceo@example.test']);assert.equal(body.from,'AXICORE <invitaciones@axicorepard.com>');assert.equal(posts[0].options.headers['Idempotency-Key'],'axi-circular-job1');
 responseStatus=429;await handler({method:'POST'});assert.equal(finish[1].p_reintentar,true);assert(finish[1].p_espera>=3600);assert.equal(posts[1].options.headers['Idempotency-Key'],posts[0].options.headers['Idempotency-Key']);
 responseStatus=401;await handler({method:'POST'});assert.equal(finish[2].p_reintentar,false);assert(!finish[2].p_error.includes(key));
 console.log('OK correo: un TO, CC separado, remitente Resend, credencial privada, idempotencia y manejo de límites/errores; sin red real.');
})().catch(e=>{console.error(e);process.exit(1)});
