// AXICORE | axi-enviar-correo
// Envia correos desde la web por Gmail (axispard@gmail.com) con contrasena de aplicacion.
// Solo CEO o Asistente con sesion iniciada y verificada en 2 pasos (aal2). La copia queda en "Enviados" de Gmail.
// Secretos requeridos (Supabase > Edge Functions > Secrets): GMAIL_USER, GMAIL_APP_PASSWORD
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import nodemailer from "npm:nodemailer@6.9.14";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const esCorreo = (e: string) => /^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$/.test(e);
const lista = (v: unknown) => (Array.isArray(v) ? v : []).map((x) => String(x).trim()).filter(Boolean);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Metodo no permitido" }, 405);
  try {
    // 1) Quien llama: debe ser CEO o Asistente
    const auth = req.headers.get("Authorization") || "";
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { data: perfil, error: ep } = await sb.rpc("mi_perfil");
    if (ep || !perfil) return json({ error: "Sesion no valida" }, 401);
    const roles = (perfil.accesos || []).map((a: { rol: string }) => a.rol);
    if (!roles.some((r: string) => r === "CEO" || r === "Asistente")) return json({ error: "Su perfil no envia correos" }, 403);
    if (perfil.aal2 !== true) return json({ error: "Verificacion en 2 pasos requerida: inicie sesion de nuevo con su codigo" }, 403);

    // 2) Datos del correo
    const p = await req.json();
    const to = lista(p.to), cc = lista(p.cc), bcc = lista(p.bcc);
    const todos = [...to, ...cc, ...bcc];
    if (!todos.length) return json({ error: "Indique al menos un destinatario" }, 400);
    const malos = todos.filter((e) => !esCorreo(e));
    if (malos.length) return json({ error: "Correo no valido: " + malos.join(", ") }, 400);
    if (todos.length > 100) return json({ error: "Maximo 100 destinatarios por envio" }, 400);
    const subject = String(p.subject || "").trim();
    if (!subject) return json({ error: "Falta el asunto" }, 400);
    const adjuntos = (Array.isArray(p.adjuntos) ? p.adjuntos : []).map((a: { nombre: string; mime: string; base64: string }) => ({
      filename: a.nombre, contentType: a.mime || "application/octet-stream", content: a.base64, encoding: "base64",
    }));

    // 3) Envio por Gmail (puerto 465; Supabase bloquea 25 y 587)
    const user = Deno.env.get("GMAIL_USER"), pass = Deno.env.get("GMAIL_APP_PASSWORD");
    if (!user || !pass) return json({ error: "El proveedor de correo no esta configurado (faltan GMAIL_USER / GMAIL_APP_PASSWORD)" }, 500);
    const tx = nodemailer.createTransport({ host: "smtp.gmail.com", port: 465, secure: true, auth: { user, pass } });
    const info = await tx.sendMail({
      from: `"APA | Axicore Property Administration" <${user}>`,
      to: to.join(", ") || undefined, cc: cc.join(", ") || undefined, bcc: bcc.join(", ") || undefined,
      subject, text: String(p.texto || ""), html: p.html ? String(p.html) : undefined, attachments: adjuntos,
    });
    return json({ ok: true, id: info.messageId, aceptados: info.accepted?.length || 0, rechazados: info.rejected || [] });
  } catch (e) {
    return json({ error: "No se pudo enviar: " + (e instanceof Error ? e.message : String(e)) }, 500);
  }
});
