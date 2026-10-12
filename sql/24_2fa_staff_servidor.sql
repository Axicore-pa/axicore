-- AXICORE | 24 - 2FA obligatorio en el SERVIDOR para CEO y Asistente (fase 2)
-- Aplicar SOLO despues de que el CEO active su 2FA desde la web (fase 1, commit 1941937).
-- Efecto: sin sesion verificada con codigo (aal2), CEO/Asistente no tienen permisos de staff.
-- Reversion: quitar "AND private.aal2_ok()" de es_ceo / es_staff / staff_condos.

CREATE OR REPLACE FUNCTION private.aal2_ok()
RETURNS boolean LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT coalesce((SELECT auth.jwt() ->> 'aal'), '') = 'aal2' $$;

CREATE OR REPLACE FUNCTION private.es_ceo()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.accesos a WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'CEO')
         AND private.aal2_ok() $function$;

CREATE OR REPLACE FUNCTION private.es_staff()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.accesos a WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol IN ('CEO','Asistente'))
         AND private.aal2_ok() $function$;

CREATE OR REPLACE FUNCTION private.staff_condos(p_modulo text, p_accion text)
RETURNS bigint[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce(array_agg(DISTINCT c.id), '{}'::bigint[])
  FROM public.accesos a
  JOIN public.permisos p ON p.rol = a.rol AND p.modulo = p_modulo AND p.activo
  JOIN public.condominios c ON (a.condominio_id IS NULL OR c.id = a.condominio_id)
  WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol IN ('CEO','Asistente')
    AND private.aal2_ok()
    AND CASE p_accion
          WHEN 'ver'      THEN p.puede_ver
          WHEN 'exportar' THEN p.puede_exportar
          WHEN 'crear'    THEN p.puede_crear AND (a.rol = 'CEO' OR NOT p.requiere_autorizacion
                                                  OR p_modulo IN ('Facturacion','Pagos','Gastos','GLP'))
          WHEN 'editar'   THEN p.puede_editar   AND (a.rol = 'CEO' OR NOT p.requiere_autorizacion)
          WHEN 'eliminar' THEN p.puede_eliminar AND (a.rol = 'CEO' OR NOT p.requiere_autorizacion)
          ELSE false END
$function$;

-- Inicio de sesion: CEO/Asistente sin codigo verificado -> no se registra la sesion, se pide 2FA
CREATE OR REPLACE FUNCTION public.axi_sesion_iniciar()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_acceso public.accesos;
  v_usuario public.usuarios;
BEGIN
  SELECT * INTO v_acceso FROM public.accesos a
   WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo
   ORDER BY CASE a.rol WHEN 'CEO' THEN 1 WHEN 'Asistente' THEN 2 ELSE 3 END
   LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no tiene acceso al sistema';
  END IF;
  SELECT * INTO v_usuario FROM public.usuarios u WHERE u.id = v_acceso.usuario_id;

  IF v_acceso.rol IN ('CEO','Asistente') AND NOT private.aal2_ok() THEN
    RETURN jsonb_build_object('requiere_2fa', true, 'rol', v_acceso.rol, 'nombre', coalesce(v_usuario.nombre_completo, ''));
  END IF;

  INSERT INTO public.historial_sesiones (
    usuario_id, usuario_login, nombre_usuario, rol, nivel_acceso, fecha_hora_inicio, activa
  ) VALUES (
    v_acceso.usuario_id, v_usuario.usuario_login, v_usuario.nombre_completo, v_acceso.rol, v_usuario.nivel_acceso, now(), true
  );
  RETURN jsonb_build_object('rol', v_acceso.rol, 'usuario_id', v_acceso.usuario_id,
    'nombre', coalesce(v_usuario.nombre_completo, ''), 'condominio_id', v_acceso.condominio_id);
END $function$;

-- El CEO puede reiniciar el 2FA de un Asistente (telefono perdido). No aplica al propio CEO.
CREATE OR REPLACE FUNCTION public.fn_mfa_reiniciar(p_auth_user_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE n integer;
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.accesos a WHERE a.auth_user_id = p_auth_user_id AND a.rol = 'Asistente') THEN
    RAISE EXCEPTION 'Solo se puede reiniciar el 2FA de un Asistente'; END IF;
  WITH d AS (DELETE FROM auth.mfa_factors f WHERE f.user_id = p_auth_user_id RETURNING 1) SELECT count(*) INTO n FROM d;
  RETURN n;
END $function$;
REVOKE ALL ON FUNCTION public.fn_mfa_reiniciar(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.fn_mfa_reiniciar(uuid) TO authenticated;

-- mi_perfil: informa si la sesion esta verificada con codigo (lo usa la Edge Function axi-enviar-correo)
CREATE OR REPLACE FUNCTION public.mi_perfil()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT CASE WHEN (SELECT auth.uid()) IS NULL THEN NULL ELSE jsonb_build_object(
    'usuario', (SELECT auth.uid()),
    'aal2', private.aal2_ok(),
    'accesos', (SELECT coalesce(jsonb_agg(jsonb_build_object('rol', a.rol, 'condominio_id', a.condominio_id,
                 'propietario_id', a.propietario_id, 'inquilino_id', a.inquilino_id) ORDER BY a.rol), '[]'::jsonb)
                FROM public.accesos a WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo),
    'unidades_propias', to_jsonb(private.unidades_propias()),
    'unidades_inquilino', to_jsonb(private.unidades_inquilino()),
    'permisos', (SELECT coalesce(jsonb_object_agg(p.modulo, jsonb_build_object('ver', p.puede_ver, 'crear', p.puede_crear,
                  'editar', p.puede_editar, 'eliminar', p.puede_eliminar, 'exportar', p.puede_exportar,
                  'requiere_autorizacion', p.requiere_autorizacion)), '{}'::jsonb)
                 FROM public.permisos p WHERE p.activo AND p.rol = (
                   SELECT a.rol FROM public.accesos a WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo
                   AND a.rol IN ('CEO','Asistente') ORDER BY a.rol LIMIT 1))) END $function$;
