// AXICORE | invitación de registro vinculada a un perfil existente.
// Solo CEO autenticado y con AAL2. Nunca acepta rol, correo o permisos desde el navegador.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const CORS = {
  "Access-Control-Allow-Origin": "https://axicore-pa.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-axicore-tab",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);
  try {
    const authHeader = req.headers.get("Authorization") || "";
    const caller = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader, "x-axicore-tab": req.headers.get("x-axicore-tab") || "" } },
    });
    const { data: perfil, error: perfilError } = await caller.rpc("mi_perfil");
    if (perfilError || !perfil) return json({ error: "Sesión no válida" }, 401);
    if (!(perfil.accesos || []).some((a: { rol: string }) => a.rol === "CEO") || perfil.aal2 !== true) {
      return json({ error: "Solo el CEO con verificación en dos pasos puede enviar invitaciones" }, 403);
    }

    const body = await req.json();
    const tipo = String(body.tipo || "");
    const perfilId = Number(body.perfil_id);
    if (!["Inquilino", "Propietario", "Administrador"].includes(tipo) || !Number.isSafeInteger(perfilId) || perfilId < 1) {
      return json({ error: "Seleccione un perfil válido" }, 400);
    }

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    // Esta función resuelve el correo y el rol a partir del registro almacenado y sus unidades.
    const { data: destino, error: destinoError } = await admin.rpc("axi_registro_perfil", {
      p_tipo: tipo, p_perfil_id: perfilId,
    });
    if (destinoError || !destino?.correo) return json({ error: destinoError?.message || "No se pudo validar el perfil" }, 400);
    if (destino.solicitud_pendiente) return json({ error: "Ya existe una invitación o solicitud pendiente para este perfil" }, 409);

    const { data: invitado, error: inviteError } = await admin.auth.admin.inviteUserByEmail(destino.correo, {
      redirectTo: "https://axicore-pa.github.io/axicore/",
    });
    if (inviteError || !invitado?.user?.id) {
      return json({ error: inviteError?.message || "Supabase no devolvió la cuenta invitada" }, 400);
    }

    const { data: solicitudId, error: registroError } = await admin.rpc("axi_registro_invitacion_crear", {
      p_tipo: tipo, p_perfil_id: perfilId, p_auth_user_id: invitado.user.id,
    });
    if (registroError || !solicitudId) {
      // Evita dejar una identidad utilizable si la invitación no quedó vinculada al perfil.
      await admin.auth.admin.deleteUser(invitado.user.id);
      return json({ error: "No se pudo vincular la invitación al perfil. No se habilitó acceso: " + (registroError?.message || "error interno") }, 500);
    }
    return json({ ok: true, solicitud_id: solicitudId, rol: destino.tipo, correo: destino.correo });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});

