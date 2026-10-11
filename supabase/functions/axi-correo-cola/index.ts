// AXICORE | axi-correo-cola
// Envia los correos en cola (tabla correos_salida) por Gmail. Lo llama pg_cron cada minuto.
// No recibe datos: solo procesa lo que la base de datos ya dejo en cola (reservas, avisos, recordatorios).
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import nodemailer from "npm:nodemailer@6.9.14";

Deno.serve(async () => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const user = Deno.env.get("GMAIL_USER"), pass = Deno.env.get("GMAIL_APP_PASSWORD");
  if (!user || !pass) return new Response(JSON.stringify({ error: "Faltan GMAIL_USER / GMAIL_APP_PASSWORD" }), { status: 500 });

  const { data: cola, error } = await sb.from("correos_salida").select("*")
    .eq("estado", "Pendiente").lt("intentos", 3).order("id").limit(20);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  if (!cola?.length) return new Response(JSON.stringify({ ok: true, enviados: 0 }));

  const tx = nodemailer.createTransport({ host: "smtp.gmail.com", port: 465, secure: true, auth: { user, pass } });
  let enviados = 0, fallidos = 0;
  for (const c of cola) {
    try {
      await tx.sendMail({
        from: `"AXICORE - Reservaciones y Avisos" <${user}>`,
        to: (c.para || []).join(", ") || undefined,
        cc: (c.cc || []).join(", ") || undefined,
        subject: c.asunto, html: c.html || undefined, text: c.texto || undefined,
        attachments: (c.adjuntos || []).map((a: { nombre: string; mime: string; base64: string }) => ({
          filename: a.nombre, contentType: a.mime, content: String(a.base64).replace(/\s+/g, ""), encoding: "base64",
        })),
      });
      await sb.from("correos_salida").update({ estado: "Enviado", enviado_at: new Date().toISOString(), intentos: c.intentos + 1, error: null }).eq("id", c.id);
      enviados++;
    } catch (e) {
      const intentos = c.intentos + 1;
      await sb.from("correos_salida").update({
        estado: intentos >= 3 ? "Error" : "Pendiente", intentos, error: e instanceof Error ? e.message : String(e),
      }).eq("id", c.id);
      fallidos++;
    }
  }
  return new Response(JSON.stringify({ ok: true, enviados, fallidos }), { headers: { "Content-Type": "application/json" } });
});
