// Solo procesa trabajos construidos y autorizados en PostgreSQL; no acepta destinatarios del cliente.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json"}});
Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return json({error:"Método no permitido"},405);
 const key=Deno.env.get("RESEND_API_KEY");
 if(!key)return json({error:"Falta RESEND_API_KEY"},503);
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await sb.rpc("axi_circular_cola_tomar");
 if(error)return json({error:"No se pudo tomar la cola"},500);
 let enviados=0,fallidos=0;
 for(const job of data||[]){
  let proveedor:string|null=null, fallo:string|null=null, reintentar=false, espera=300;
  try{
   const response=await fetch("https://api.resend.com/emails",{
    method:"POST",headers:{Authorization:"Bearer "+key,"Content-Type":"application/json","Idempotency-Key":"axi-circular-"+job.id},
    body:JSON.stringify({from:"AXICORE <invitaciones@axicorepard.com>",to:[job.para],...(job.cc?.length?{cc:job.cc}:{}),subject:job.asunto,text:job.texto}),
    signal:AbortSignal.timeout(8000),
   });
   const body=await response.json().catch(()=>({}));
   if(response.ok&&body.id){proveedor=body.id;enviados++;}
   else{
    // No se guardan credenciales, cabeceras ni respuestas que puedan contener secretos.
    fallo="Resend HTTP "+response.status+": "+String(body.name||"rechazado");
    reintentar=response.status===429||response.status>=500;
    espera=response.status===429?Math.max(3600,Number(response.headers.get("retry-after"))||0):Math.min(7200,300*2**job.intentos);
    fallidos++;
   }
  }catch(_){fallo="No se obtuvo confirmación del proveedor; se reintentará con la misma clave para evitar duplicados.";reintentar=true;espera=600;fallidos++;}
  const done=await sb.rpc("axi_circular_cola_finalizar",{p_id:job.id,p_lote:job.lote,p_proveedor:proveedor,p_error:fallo,p_reintentar:reintentar,p_espera:espera});
  if(done.error)return json({error:"El estado de envío requiere revisión"},500);
  await new Promise(resolve=>setTimeout(resolve,650));
 }
 return json({ok:true,enviados,fallidos});
});
