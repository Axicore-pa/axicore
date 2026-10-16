const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const {babelTransform}=require(path.join(path.dirname(require.resolve('playwright/package.json',{paths:[process.env.AXICORE_NODE_MODULES||__dirname]})),'lib/transform/babelBundle.js'));
const source=fs.readFileSync(path.join(__dirname,'../supabase/functions/webapp-upload/index.ts'),'utf8').replace(/^import .*;\n/gm,'');
const code=babelTransform(source,'upload.ts',false,[],[]).code;
(async()=>{
 for(const c of [
  {name:'GET anónimo',method:'GET',expected:405},
  {name:'POST anónimo',method:'POST',expected:401},
  {name:'token inválido',method:'POST',token:true,badIdentity:true,expected:401},
  {name:'perfil inválido',method:'POST',token:true,badProfile:true,expected:401},
  {name:'residente',method:'POST',token:true,rol:'Propietario',aal2:true,expected:403},
  {name:'CEO sin MFA',method:'POST',token:true,rol:'CEO',aal2:false,expected:403},
  {name:'CEO con MFA',method:'POST',token:true,rol:'CEO',aal2:true,expected:200},
 ]){
  let handler,privileged=0,uploads=0;
  const ctx={Response,TextEncoder,Deno:{env:{get:k=>k},serve:f=>handler=f},createClient:(url,key)=>{
   if(key==='SUPABASE_SERVICE_ROLE_KEY'){
    privileged++;
    return {from:()=>({select:()=>({eq:()=>({single:async()=>({data:{html:'<!DOCTYPE html><title>AXICORE</title>'}})})})}),storage:{from:()=>({upload:async()=>{uploads++;return {error:null}}})}};
   }
   return {auth:{getUser:async()=>({data:{user:c.badIdentity?null:{id:'synthetic'}},error:c.badIdentity?{}:null})},rpc:async()=>({data:c.badProfile?null:{aal2:c.aal2,accesos:[{rol:c.rol}]},error:null})};
  }};
  vm.runInNewContext(code,ctx);
  const response=await handler(new Request('https://example.test',{method:c.method,headers:c.token?{Authorization:'Bearer synthetic'}:{}}));
  assert.equal(response.status,c.expected,c.name);
  assert.equal(privileged,c.expected===200?1:0,c.name+' no debe crear cliente privilegiado');
  assert.equal(uploads,c.expected===200?1:0,c.name+' no debe escribir');
  console.log('OK',c.name,response.status);
 }
})();
