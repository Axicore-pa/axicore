import { createClient } from "npm:@supabase/supabase-js@2.45.4";
const PORTAL="https://axicorepard.com";
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const headers={"Access-Control-Allow-Origin":PORTAL,"Access-Control-Allow-Methods":"GET,POST,OPTIONS","Access-Control-Allow-Headers":"content-type","Vary":"Origin","Cache-Control":"no-store","Referrer-Policy":"no-referrer","X-Content-Type-Options":"nosniff"};
function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:{...headers,"Content-Type":"application/json; charset=utf-8"}});}
export async function handleRequest(req:Request):Promise<Response>{
 const origin=req.headers.get("origin");
 if(req.method==="OPTIONS")return origin===PORTAL?new Response(null,{status:204,headers}):json({ok:false,error:"Origen no permitido"},403);
 if(req.method==="GET"){
  const token=new URL(req.url).searchParams.get("token")||"";
  return new Response(null,{status:302,headers:{...headers,Location:PORTAL+"/despacho-seguimiento.html"+(UUID.test(token)?"#token="+encodeURIComponent(token):"")}});
 }
 if(req.method!=="POST")return json({ok:false,error:"Método no permitido"},405);
 if(origin&&origin!==PORTAL)return json({ok:false,error:"Origen no permitido"},403);
 if(!req.headers.get("content-type")?.toLowerCase().startsWith("application/json"))return json({ok:false,error:"Se requiere JSON"},415);
 let b:Record<string,unknown>;
 try{const text=await req.text();if(text.length>2048)return json({ok:false,error:"Datos demasiado extensos"},413);b=JSON.parse(text);if(!b||typeof b!=="object"||Array.isArray(b))throw Error();}catch{return json({ok:false,error:"Datos inválidos"},400);}
 if(typeof b.token!=="string"||!UUID.test(b.token)||!['consultar','fecha','llegada'].includes(String(b.accion)))return json({ok:false,error:"Enlace o acción inválidos"},400);
 let fecha:string|null=null;
 if(b.accion==='fecha'){
  if(typeof b.fecha!=="string"||!/^\d{4}-\d\d-\d\dT\d\d:\d\d(:\d\d(\.\d{1,3})?)?(Z|[+-]\d\d:\d\d)$/.test(b.fecha)||!Number.isFinite(Date.parse(b.fecha)))return json({ok:false,error:"Hora inválida"},400);
  fecha=new Date(b.fecha).toISOString();
 }
 try{
  const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error}=await sb.rpc("axi_despacho_seguimiento_proveedor",{p_token:b.token,p_accion:b.accion,p_fecha:fecha});
  if(error||!data||typeof data.ok!=="boolean")return json({ok:false,error:"No se pudo procesar. Intente nuevamente."},500);
  return json(data);
 }catch{return json({ok:false,error:"No se pudo procesar. Intente nuevamente."},500);}
}
Deno.serve(handleRequest);
