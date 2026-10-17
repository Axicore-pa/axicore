// AXICORE | axi-despacho-responder v3
// El gateway estándar de Supabase reescribe HTML a text/plain.
// GET mantiene enlaces existentes mediante redirección al portal.
// POST conserva el RPC de respuesta y la autorización por token.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const PORTAL = "https://axicorepard.com";
const FORM_URL = PORTAL + "/despacho.html";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const OPCIONES = new Set([
  "De inmediato",
  "Dentro de 2 horas",
  "Dentro de 4 horas",
  "En algún momento del día de hoy",
  "Mañana en la mañana",
  "Mañana en la tarde",
  "No puedo atender"
]);
const CORS = {
  "Access-Control-Allow-Origin": PORTAL,
  "Access-Control-Allow-Methods": "GET, HEAD, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
  "Vary": "Origin",
};
const HEADERS = {
  ...CORS,
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};
function jsonRes(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...HEADERS, "Content-Type": "application/json; charset=utf-8" },
  });
}
export async function handleRequest(req: Request): Promise<Response> {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") {
    if (origin !== PORTAL) return jsonRes({ ok: false, error: "Origen no permitido" }, 403);
    return new Response(null, { status: 204, headers: HEADERS });
  }
  if (req.method === "GET" || req.method === "HEAD") {
    const token = new URL(req.url).searchParams.get("token") || "";
    const location = UUID.test(token) ? FORM_URL + "#token=" + encodeURIComponent(token) : FORM_URL;
    return new Response(null, { status: 302, headers: { ...HEADERS, Location: location } });
  }
  if (req.method !== "POST") return jsonRes({ ok: false, error: "Método no permitido" }, 405);
  if (origin && origin !== PORTAL) return jsonRes({ ok: false, error: "Origen no permitido" }, 403);
  if (!req.headers.get("content-type")?.toLowerCase().startsWith("application/json")) {
    return jsonRes({ ok: false, error: "Se requiere JSON" }, 415);
  }
  let body: unknown;
  try {
    const text = await req.text();
    if (text.length > 4096) return jsonRes({ ok: false, error: "Datos demasiado extensos" }, 413);
    body = JSON.parse(text);
  } catch {
    return jsonRes({ ok: false, error: "Datos inválidos" }, 400);
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return jsonRes({ ok: false, error: "Datos inválidos" }, 400);
  }
  const { token, respuesta } = body as Record<string, unknown>;
  if (typeof token !== "string" || !UUID.test(token) ||
      typeof respuesta !== "string" || !OPCIONES.has(respuesta)) {
    return jsonRes({ ok: false, error: "Enlace o respuesta inválidos" }, 400);
  }
  try {
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const { data, error } = await sb.rpc("despacho_responder", {
      p_token: token, p_respuesta: respuesta,
    });
    if (error) return jsonRes({ ok: false, error: "No se pudo procesar la respuesta. Intente nuevamente." }, 500);
    if (!data || typeof data !== "object" || typeof data.ok !== "boolean") {
      return jsonRes({ ok: false, error: "Respuesta no disponible" }, 502);
    }
    return jsonRes(data);
  } catch {
    return jsonRes({ ok: false, error: "No se pudo procesar la respuesta. Intente nuevamente." }, 500);
  }
}
Deno.serve(handleRequest);
