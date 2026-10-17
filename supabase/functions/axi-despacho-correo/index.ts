// AXICORE | axi-despacho-correo v3
// Cron: envia correo a proveedores con link para responder despacho.
// Usa Resend API con remitente Admin@axicorepard.com
// verify_jwt=true, llamado por cron via pg_net con anon key.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });


async function enviarSeguimientos(sb: ReturnType<typeof createClient>, resendKey: string) {
  const {data: items, error} = await sb.rpc("axi_despacho_seguimiento_cola");
  if(error) throw new Error("Cola de seguimiento no disponible");
  let enviados=0, fallidos=0;
  const esc=(v: unknown)=>String(v??"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;");
  for(const item of Array.isArray(items)?items:[]) {
    let ok=false;
    try {
      const safeLink=typeof item.link==="string" && /^https:\/\/axicorepard\.com\/despacho-seguimiento\.html#token=[0-9a-f-]{36}$/i.test(item.link)?item.link:null;
      const text=String(item.texto||"")+(safeLink?"\n\nConfirmar hora o avisar llegada: "+safeLink:"")+"\n\nAPA | AxiCore Property Administration\nTel. 809-282-7776\naxispard@gmail.com";
      const html='<div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;color:#1B2A4A"><h2>AXICORE</h2><p><strong>'+esc(item.reporte)+'</strong> · '+esc(item.proveedor)+'</p><p>'+esc(item.texto)+'</p>'+(safeLink?'<p><a href="'+esc(safeLink)+'">Confirmar hora / Avisar llegada</a></p>':'')+'<hr><p>APA | AxiCore Property Administration<br>Tel. 809-282-7776<br>axispard@gmail.com</p></div>';
      const res=await fetch("https://api.resend.com/emails",{method:"POST",headers:{Authorization:"Bearer "+resendKey,"Content-Type":"application/json","Idempotency-Key":"axi-despacho-seg-"+item.id},body:JSON.stringify({from:"AXICORE <Admin@axicorepard.com>",to:[item.email],...(item.cc?{cc:[item.cc]}:{}),subject:item.asunto,text,html}),signal:AbortSignal.timeout(8000)});
      const body=await res.json().catch(()=>({}));
      ok=res.ok&&!!body.id;
    } catch { ok=false; }
    const {error: markError}=await sb.rpc("axi_despacho_seguimiento_correo_resultado",{p_id:item.id,p_reserva:item.reserva,p_ok:ok});
    if(ok&&!markError) enviados++; else fallidos++;
    await new Promise(r=>setTimeout(r,650));
  }
  return {enviados,fallidos};
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) return json({ error: "Falta RESEND_API_KEY" }, 503);

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } }
  );

  // Obtener cola de correos pendientes
  const { data: cola, error: errCola } = await sb.rpc("despacho_cola_correo");
  if (errCola) return json({ error: "Error obteniendo cola: " + errCola.message }, 500);
  const pendientes = Array.isArray(cola) ? cola : [];

  const baseUrl = Deno.env.get("SUPABASE_URL")!;
  let enviados = 0, fallidos = 0;

  for (const item of pendientes) {
    const linkResponder = `${baseUrl}/functions/v1/axi-despacho-responder?token=${item.token}`;

    const htmlBody = `
<div style="font-family:Segoe UI,Arial,sans-serif;max-width:600px;margin:0 auto;background:#F7F5F0;padding:0">
  <div style="background:#1B2A4A;padding:20px 24px;text-align:center">
    <h1 style="color:#C08A3E;margin:0;font-size:22px">AXICORE</h1>
    <p style="color:#F7F5F0;margin:4px 0 0;font-size:13px">Solicitud de Servicio</p>
  </div>
  <div style="padding:24px">
    <p style="color:#1B2A4A;margin:0 0 16px">Estimado/a <strong>${item.proveedor_nombre}</strong>,</p>
    <p style="color:#1B2A4A;margin:0 0 16px">Se ha registrado un reporte que requiere atención en su categoría de servicio:</p>
    <table style="width:100%;border-collapse:collapse;margin:0 0 20px">
      <tr><td style="padding:8px 12px;background:#1B2A4A;color:#C08A3E;font-weight:bold;width:120px">Reporte</td><td style="padding:8px 12px;background:#fff;color:#1B2A4A">${item.reporte_codigo || 'Sin código'}</td></tr>
      <tr><td style="padding:8px 12px;background:#1B2A4A;color:#C08A3E;font-weight:bold">Categoría</td><td style="padding:8px 12px;background:#fff;color:#1B2A4A">${item.categoria}</td></tr>
      <tr><td style="padding:8px 12px;background:#1B2A4A;color:#C08A3E;font-weight:bold">Prioridad</td><td style="padding:8px 12px;background:#fff;color:#1B2A4A">${item.prioridad || 'Normal'}</td></tr>
      <tr><td style="padding:8px 12px;background:#1B2A4A;color:#C08A3E;font-weight:bold">Ubicación</td><td style="padding:8px 12px;background:#fff;color:#1B2A4A">${item.ubicacion || 'No especificada'}</td></tr>
      <tr><td style="padding:8px 12px;background:#1B2A4A;color:#C08A3E;font-weight:bold">Descripción</td><td style="padding:8px 12px;background:#fff;color:#1B2A4A">${(item.descripcion || 'Sin descripción').substring(0, 200)}</td></tr>
    </table>
    <p style="color:#1B2A4A;margin:0 0 16px">Tiene <strong>${item.ventana_minutos} minutos</strong> para confirmar su disponibilidad:</p>
    <div style="text-align:center;margin:20px 0">
      <a href="${linkResponder}" style="display:inline-block;background:#C08A3E;color:#fff;text-decoration:none;padding:14px 32px;border-radius:6px;font-size:16px;font-weight:bold">Responder disponibilidad</a>
    </div>
    <p style="color:#8A8578;font-size:12px;margin:20px 0 0;text-align:center">Si no responde dentro de la ventana, otro proveedor podría ser asignado.</p>
  </div>
  <div style="background:#1B2A4A;padding:12px 24px;text-align:center">
    <p style="color:#8A8578;font-size:11px;margin:0">AXICORE Property Administration &bull; 809-282-7776</p>
  </div>
</div>`;

    const textoPlano = `AXICORE - Solicitud de Servicio\n\nEstimado/a ${item.proveedor_nombre},\n\nReporte: ${item.reporte_codigo || 'N/A'}\nCategoría: ${item.categoria}\nPrioridad: ${item.prioridad || 'Normal'}\nUbicación: ${item.ubicacion || 'N/A'}\nDescripción: ${(item.descripcion || '').substring(0, 200)}\n\nTiene ${item.ventana_minutos} minutos para responder.\nResponda aquí: ${linkResponder}\n\nAXICORE Property Administration | 809-282-7776`;

    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: "Bearer " + resendKey,
          "Content-Type": "application/json",
          "Idempotency-Key": "axi-despacho-" + item.respuesta_id,
        },
        body: JSON.stringify({
          from: "AXICORE <Admin@axicorepard.com>",
          to: [item.proveedor_email],
          subject: `Solicitud de servicio: ${item.categoria} - ${item.reporte_codigo || 'Nuevo reporte'}`,
          html: htmlBody,
          text: textoPlano,
        }),
        signal: AbortSignal.timeout(8000),
      });

      const body = await res.json().catch(() => ({}));
      if (res.ok && body.id) {
        await sb.rpc("despacho_marcar_notificado", { p_respuesta_id: item.respuesta_id });
        enviados++;
      } else {
        fallidos++;
      }
    } catch {
      fallidos++;
    }

    await new Promise(r => setTimeout(r, 650));
  }

  let seguimiento;
  try { seguimiento = await enviarSeguimientos(sb, resendKey); }
  catch { return json({ ok: false, error: "No se pudo procesar la cola de seguimiento", enviados, fallidos }, 503); }
  return json({ ok: true, enviados, fallidos, seguimiento });
});
