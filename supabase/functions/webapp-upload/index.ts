import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

// Publicar requiere identidad verificada y autorización del servidor antes de
// crear el cliente privilegiado. Nunca acepta HTML ni rutas desde el cliente.
const cors = {
  "Access-Control-Allow-Origin": "https://axicore-pa.github.io",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-axicore-tab",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);
  const authorization = req.headers.get("Authorization") || "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) return json({ error: "Sesión requerida" }, 401);
  try {
    const caller = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authorization, "x-axicore-tab": req.headers.get("x-axicore-tab") || "" } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: identity, error: identityError } = await caller.auth.getUser();
    if (identityError || !identity?.user) return json({ error: "Sesión no válida" }, 401);
    const { data: profile, error: profileError } = await caller.rpc("mi_perfil");
    if (profileError || !profile) return json({ error: "Sesión no válida" }, 401);
    if (profile.aal2 !== true || !(profile.accesos || []).some((a: { rol: string }) => a.rol === "CEO")) {
      return json({ error: "Solo el CEO con doble factor puede publicar" }, 403);
    }
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await admin.from("webapp_pages").select("html").eq("id", "index").single();
    if (error || !data?.html) return json({ error: "No hay una versión disponible para publicar" }, 409);
    const bytes = new TextEncoder().encode(data.html);
    const { error: uploadError } = await admin.storage.from("webapp").upload("index.html", bytes, {
      contentType: "text/html", upsert: true,
    });
    if (uploadError) return json({ error: "No se pudo publicar" }, 500);
    return json({ success: true, size: bytes.length });
  } catch (_) {
    return json({ error: "No se pudo publicar" }, 500);
  }
});
