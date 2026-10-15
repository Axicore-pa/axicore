-- AXICORE | 27 - Perfil "Administrador de propiedades" (aprobado por Misael 11/10/2026)
-- * Perfil propio (como propietarios) y asignacion POR UNIDAD con historial (fecha_inicio/fecha_fin).
-- * Rol de acceso 'Administrador' en accesos (administrador_id). Ve sus unidades como un propietario,
--   SIN fondo comun, gastos/comprobantes del condominio ni morosidad global (esas usan condos_propietario).
-- * 2FA obligatorio: sin sesion verificada (aal2) no ve ninguna unidad.

-- 27a ------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.administradores (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  condominio_id bigint NOT NULL REFERENCES public.condominios(id),
  codigo text,
  nombre text NOT NULL,
  documento text, telefono text, whatsapp text, email text,
  estado text NOT NULL DEFAULT 'Activo' CHECK (estado IN ('Activo','Inactivo')),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz
);
CREATE TABLE IF NOT EXISTS public.unidad_administradores (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  unidad_id bigint NOT NULL REFERENCES public.unidades(id),
  administrador_id bigint NOT NULL REFERENCES public.administradores(id),
  fecha_inicio date NOT NULL DEFAULT current_date,
  fecha_fin date,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS unidad_administradores_una_activa ON public.unidad_administradores(unidad_id) WHERE fecha_fin IS NULL;
ALTER TABLE public.administradores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unidad_administradores ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.administradores, public.unidad_administradores FROM anon, authenticated;
ALTER TABLE public.accesos ADD COLUMN IF NOT EXISTS administrador_id bigint REFERENCES public.administradores(id);

-- 27b (sentencias DROP aparte) -----------------------------------------------------------------
ALTER TABLE public.accesos DROP CONSTRAINT accesos_rol_check;
ALTER TABLE public.accesos DROP CONSTRAINT accesos_datos_por_rol;

-- 27c ------------------------------------------------------------------------------------------
ALTER TABLE public.accesos ADD CONSTRAINT accesos_rol_check CHECK (rol IN ('CEO','Asistente','Propietario','Inquilino','Administrador'));
ALTER TABLE public.accesos ADD CONSTRAINT accesos_datos_por_rol CHECK (
  (rol IN ('CEO','Asistente') AND propietario_id IS NULL AND inquilino_id IS NULL AND administrador_id IS NULL)
  OR (rol = 'Propietario' AND propietario_id IS NOT NULL AND inquilino_id IS NULL AND administrador_id IS NULL AND condominio_id IS NOT NULL)
  OR (rol = 'Inquilino' AND inquilino_id IS NOT NULL AND propietario_id IS NULL AND administrador_id IS NULL AND condominio_id IS NOT NULL)
  OR (rol = 'Administrador' AND administrador_id IS NOT NULL AND propietario_id IS NULL AND inquilino_id IS NULL AND condominio_id IS NOT NULL));

CREATE OR REPLACE FUNCTION private.accesos_completar()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NEW.rol = 'Propietario' THEN
    SELECT p.condominio_id INTO NEW.condominio_id FROM public.propietarios p WHERE p.id = NEW.propietario_id;
  ELSIF NEW.rol = 'Inquilino' THEN
    SELECT i.condominio_id INTO NEW.condominio_id FROM public.inquilinos i WHERE i.id = NEW.inquilino_id;
  ELSIF NEW.rol = 'Administrador' THEN
    SELECT a.condominio_id INTO NEW.condominio_id FROM public.administradores a WHERE a.id = NEW.administrador_id;
  END IF;
  IF TG_OP = 'UPDATE' THEN NEW.updated_at := now(); END IF;
  RETURN NEW;
END $function$;

-- Unidades del usuario: propias + (solo con 2FA verificado) las que administra
CREATE OR REPLACE FUNCTION private.unidades_propias()
RETURNS bigint[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce(array_agg(DISTINCT x.id), '{}'::bigint[]) FROM (
    SELECT u.id FROM public.accesos a
    JOIN public.unidades u ON u.condominio_id = a.condominio_id
     AND (u.propietario_id = a.propietario_id
          OR EXISTS (SELECT 1 FROM public.unidad_propietarios up
                     WHERE up.unidad_id = u.id AND up.propietario_id = a.propietario_id AND up.fecha_fin IS NULL))
    WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Propietario'
    UNION
    SELECT ua.unidad_id FROM public.accesos a
    JOIN public.administradores ad ON ad.id = a.administrador_id AND ad.estado = 'Activo'
    JOIN public.unidad_administradores ua ON ua.administrador_id = a.administrador_id AND ua.fecha_fin IS NULL
    WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Administrador' AND private.aal2_ok()) x $function$;

CREATE OR REPLACE FUNCTION private.es_residente()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.accesos a WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo
                  AND (a.rol IN ('Propietario','Inquilino') OR (a.rol = 'Administrador' AND private.aal2_ok()))) $function$;

CREATE OR REPLACE FUNCTION private.condos_residente()
RETURNS bigint[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce(array_agg(DISTINCT a.condominio_id), '{}'::bigint[]) FROM public.accesos a
  WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo
    AND (a.rol IN ('Propietario','Inquilino') OR (a.rol = 'Administrador' AND private.aal2_ok())) $function$;

-- Sesion: Administrador exige 2FA y muestra el nombre de su perfil
CREATE OR REPLACE FUNCTION public.axi_sesion_iniciar()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_acceso public.accesos;
  v_usuario public.usuarios;
  v_nombre text;
BEGIN
  SELECT * INTO v_acceso FROM public.accesos a
   WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo
   ORDER BY CASE a.rol WHEN 'CEO' THEN 1 WHEN 'Asistente' THEN 2 WHEN 'Administrador' THEN 3 ELSE 4 END
   LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no tiene acceso al sistema';
  END IF;
  SELECT * INTO v_usuario FROM public.usuarios u WHERE u.id = v_acceso.usuario_id;
  v_nombre := coalesce(v_usuario.nombre_completo,
                       (SELECT ad.nombre FROM public.administradores ad WHERE ad.id = v_acceso.administrador_id), '');
  IF v_acceso.rol IN ('CEO','Asistente','Administrador') AND NOT private.aal2_ok() THEN
    RETURN jsonb_build_object('requiere_2fa', true, 'rol', v_acceso.rol, 'nombre', v_nombre);
  END IF;
  INSERT INTO public.historial_sesiones (
    usuario_id, usuario_login, nombre_usuario, rol, nivel_acceso, fecha_hora_inicio, activa
  ) VALUES (
    v_acceso.usuario_id, v_usuario.usuario_login, v_nombre, v_acceso.rol, v_usuario.nivel_acceso, now(), true
  );
  RETURN jsonb_build_object('rol', v_acceso.rol, 'usuario_id', v_acceso.usuario_id,
    'nombre', v_nombre, 'condominio_id', v_acceso.condominio_id);
END $function$;

-- Catalogo (solo CEO) ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_admin_listar(p_condominio_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  RETURN (SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', a.id, 'codigo', a.codigo, 'nombre', a.nombre, 'documento', a.documento, 'telefono', a.telefono,
      'whatsapp', a.whatsapp, 'email', a.email, 'estado', a.estado,
      'unidades', (SELECT coalesce(jsonb_agg(jsonb_build_object('unidad_id', u.id, 'codigo', u.codigo, 'desde', ua.fecha_inicio) ORDER BY u.codigo), '[]'::jsonb)
                     FROM public.unidad_administradores ua JOIN public.unidades u ON u.id = ua.unidad_id
                    WHERE ua.administrador_id = a.id AND ua.fecha_fin IS NULL),
      'con_acceso', EXISTS (SELECT 1 FROM public.accesos x WHERE x.administrador_id = a.id AND x.activo))
    ORDER BY a.nombre), '[]'::jsonb)
    FROM public.administradores a WHERE a.condominio_id = p_condominio_id);
END $function$;

CREATE OR REPLACE FUNCTION public.fn_admin_guardar(p_condominio_id bigint, p jsonb)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_id bigint := nullif(p->>'id','')::bigint; v_nombre text := nullif(btrim(p->>'nombre'),'');
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO gestiona administradores' USING ERRCODE = '42501'; END IF;
  IF v_nombre IS NULL THEN RAISE EXCEPTION 'Indique el nombre'; END IF;
  IF v_id IS NULL THEN
    INSERT INTO public.administradores (condominio_id, codigo, nombre, documento, telefono, whatsapp, email, estado)
    VALUES (p_condominio_id,
            'ADM-' || lpad(((SELECT count(*) FROM public.administradores x WHERE x.condominio_id = p_condominio_id) + 1)::text, 3, '0'),
            v_nombre, nullif(btrim(p->>'documento'),''), nullif(btrim(p->>'telefono'),''), nullif(btrim(p->>'whatsapp'),''),
            lower(nullif(btrim(p->>'email'),'')), coalesce(nullif(p->>'estado',''), 'Activo'))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.administradores SET nombre = v_nombre, documento = nullif(btrim(p->>'documento'),''),
           telefono = nullif(btrim(p->>'telefono'),''), whatsapp = nullif(btrim(p->>'whatsapp'),''),
           email = lower(nullif(btrim(p->>'email'),'')), estado = coalesce(nullif(p->>'estado',''), 'Activo'), updated_at = now()
     WHERE id = v_id AND condominio_id = p_condominio_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Administrador no encontrado'; END IF;
  END IF;
  PERFORM private.log_portal('Residentes', 'administradores', v_id, 'nombre', NULL, v_nombre, 'Guardar', 'Administrador de propiedades guardado');
  RETURN v_id;
END $function$;

CREATE OR REPLACE FUNCTION public.fn_admin_unidad(p_administrador_id bigint, p_unidad_id bigint, p_asignar boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_otro text;
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO gestiona administradores' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.administradores a JOIN public.unidades u ON u.condominio_id = a.condominio_id
                  WHERE a.id = p_administrador_id AND u.id = p_unidad_id) THEN
    RAISE EXCEPTION 'La unidad no pertenece al condominio del administrador'; END IF;
  IF p_asignar THEN
    SELECT ad.nombre INTO v_otro FROM public.unidad_administradores ua JOIN public.administradores ad ON ad.id = ua.administrador_id
     WHERE ua.unidad_id = p_unidad_id AND ua.fecha_fin IS NULL AND ua.administrador_id <> p_administrador_id;
    IF v_otro IS NOT NULL THEN RAISE EXCEPTION 'Esa unidad ya la administra %. Quítela primero de ese perfil.', v_otro; END IF;
    INSERT INTO public.unidad_administradores (unidad_id, administrador_id)
    SELECT p_unidad_id, p_administrador_id
     WHERE NOT EXISTS (SELECT 1 FROM public.unidad_administradores ua WHERE ua.unidad_id = p_unidad_id AND ua.fecha_fin IS NULL);
  ELSE
    UPDATE public.unidad_administradores SET fecha_fin = current_date
     WHERE unidad_id = p_unidad_id AND administrador_id = p_administrador_id AND fecha_fin IS NULL;
  END IF;
  PERFORM private.log_portal('Residentes', 'unidad_administradores', p_unidad_id, 'administrador_id', NULL, p_administrador_id::text,
                             CASE WHEN p_asignar THEN 'Asignar' ELSE 'Quitar' END, 'Unidad ' || CASE WHEN p_asignar THEN 'asignada a' ELSE 'quitada de' END || ' administrador');
  RETURN jsonb_build_object('ok', true);
END $function$;

REVOKE ALL ON FUNCTION public.fn_admin_listar(bigint), public.fn_admin_guardar(bigint, jsonb), public.fn_admin_unidad(bigint, bigint, boolean) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_listar(bigint), public.fn_admin_guardar(bigint, jsonb), public.fn_admin_unidad(bigint, bigint, boolean) TO authenticated;
