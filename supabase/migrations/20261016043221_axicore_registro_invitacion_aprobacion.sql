-- Registro únicamente por invitación para Inquilinos, Propietarios y Administradores.
-- El rol y el alcance se obtienen del perfil existente; no se aceptan desde el navegador.
CREATE TABLE private.solicitudes_registro (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  perfil_tipo text NOT NULL CHECK (perfil_tipo IN ('Inquilino','Propietario','Administrador')),
  perfil_id bigint NOT NULL,
  correo text NOT NULL,
  estado text NOT NULL DEFAULT 'Invitado' CHECK (estado IN ('Invitado','Pendiente','Aprobado')),
  datos_registro jsonb,
  unidades_ids bigint[] NOT NULL DEFAULT '{}',
  invitado_por uuid REFERENCES auth.users(id),
  invitado_at timestamptz NOT NULL DEFAULT now(),
  completado_at timestamptz,
  aprobado_por uuid REFERENCES auth.users(id),
  aprobado_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX solicitudes_registro_unica_pendiente
  ON private.solicitudes_registro(perfil_tipo,perfil_id) WHERE estado IN ('Invitado','Pendiente');
ALTER TABLE private.solicitudes_registro ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.solicitudes_registro FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.axi_registro_perfil(p_tipo text, p_perfil_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v jsonb; v_email text; v_total integer; v_units bigint[]; v_condo bigint; v_nombre text; v_unit_codes jsonb; v_documento text; v_telefono text; v_whatsapp text; v_pendiente boolean;
BEGIN
  IF p_tipo NOT IN ('Inquilino','Propietario','Administrador') THEN RAISE EXCEPTION 'Perfil no admitido'; END IF;
  IF p_tipo = 'Inquilino' THEN
    SELECT lower(btrim(i.email)), i.condominio_id, i.nombre,i.documento,i.telefono,i.whatsapp,
      coalesce(array_agg(DISTINCT u.id ORDER BY u.id) FILTER (WHERE u.id IS NOT NULL), '{}')
      INTO v_email,v_condo,v_nombre,v_documento,v_telefono,v_whatsapp,v_units
      FROM public.inquilinos i LEFT JOIN public.unidades u ON u.id=i.unidad_id
      WHERE i.id=p_perfil_id AND i.estado='Activo' GROUP BY i.id;
  ELSIF p_tipo = 'Propietario' THEN
    SELECT lower(btrim(p.email)), p.condominio_id, p.nombre,p.documento,p.telefono,p.whatsapp,
      coalesce(array_agg(DISTINCT u.id ORDER BY u.id) FILTER (WHERE u.id IS NOT NULL), '{}')
      INTO v_email,v_condo,v_nombre,v_documento,v_telefono,v_whatsapp,v_units
      FROM public.propietarios p LEFT JOIN public.unidades u ON u.condominio_id=p.condominio_id
        AND (u.propietario_id=p.id OR EXISTS (SELECT 1 FROM public.unidad_propietarios up
          WHERE up.unidad_id=u.id AND up.propietario_id=p.id AND up.fecha_fin IS NULL
          AND (up.fecha_inicio IS NULL OR up.fecha_inicio <= now())))
      WHERE p.id=p_perfil_id AND p.estado='Activo' GROUP BY p.id;
  ELSE
    SELECT lower(btrim(a.email)), a.condominio_id, a.nombre,a.documento,a.telefono,a.whatsapp,
      coalesce(array_agg(DISTINCT u.id ORDER BY u.id) FILTER (WHERE u.id IS NOT NULL), '{}')
      INTO v_email,v_condo,v_nombre,v_documento,v_telefono,v_whatsapp,v_units
      FROM public.administradores a LEFT JOIN public.unidad_administradores ua
        ON ua.administrador_id=a.id AND ua.fecha_fin IS NULL
        AND ua.fecha_inicio <= (now() AT TIME ZONE 'America/Santo_Domingo')::date
      LEFT JOIN public.unidades u ON u.id=ua.unidad_id
      WHERE a.id=p_perfil_id AND a.estado='Activo' GROUP BY a.id;
  END IF;
  IF NOT FOUND OR coalesce(v_email,'')='' OR v_condo IS NULL THEN RAISE EXCEPTION 'Perfil activo sin correo o condominio'; END IF;
  SELECT count(*) INTO v_total FROM (
    SELECT 1 FROM public.inquilinos WHERE lower(btrim(email))=v_email
    UNION ALL SELECT 1 FROM public.propietarios WHERE lower(btrim(email))=v_email
    UNION ALL SELECT 1 FROM public.administradores WHERE lower(btrim(email))=v_email
  ) q;
  IF v_total <> 1 THEN RAISE EXCEPTION 'El correo debe identificar un solo perfil. Corrija los registros antes de invitar.'; END IF;
  IF cardinality(v_units)=0 THEN RAISE EXCEPTION 'El perfil no tiene unidades asignadas'; END IF;
  SELECT coalesce(jsonb_agg(u.codigo ORDER BY u.codigo),'[]'::jsonb) INTO v_unit_codes
    FROM public.unidades u WHERE u.id=ANY(v_units);
  IF EXISTS (SELECT 1 FROM public.accesos x WHERE x.activo AND
      ((p_tipo='Inquilino' AND x.inquilino_id=p_perfil_id) OR
       (p_tipo='Propietario' AND x.propietario_id=p_perfil_id) OR
       (p_tipo='Administrador' AND x.administrador_id=p_perfil_id))) THEN
    RAISE EXCEPTION 'Este perfil ya tiene acceso activo';
  END IF;
  SELECT EXISTS (SELECT 1 FROM private.solicitudes_registro r WHERE r.perfil_tipo=p_tipo AND r.perfil_id=p_perfil_id
      AND r.estado IN ('Invitado','Pendiente')) INTO v_pendiente;
  RETURN jsonb_build_object('tipo',p_tipo,'perfil_id',p_perfil_id,'correo',v_email,
    'condominio_id',v_condo,'nombre',v_nombre,'documento',v_documento,'telefono',v_telefono,'whatsapp',v_whatsapp,
    'unidades_ids',to_jsonb(v_units),'unidades_codigos',v_unit_codes,'solicitud_pendiente',v_pendiente);
END $function$;
REVOKE ALL ON FUNCTION public.axi_registro_perfil(text,bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.axi_registro_perfil(text,bigint) TO service_role;

CREATE OR REPLACE FUNCTION public.axi_registro_invitacion_crear(p_tipo text,p_perfil_id bigint,p_auth_user_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_perfil jsonb; v_email text; v_id uuid;
BEGIN
  IF p_auth_user_id IS NULL THEN RAISE EXCEPTION 'Falta la cuenta invitada'; END IF;
  v_perfil := public.axi_registro_perfil(p_tipo,p_perfil_id);
  v_email := v_perfil->>'correo';
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=p_auth_user_id AND lower(btrim(u.email))=v_email) THEN
    RAISE EXCEPTION 'La cuenta invitada no coincide con el correo del perfil';
  END IF;
  INSERT INTO private.solicitudes_registro(auth_user_id,perfil_tipo,perfil_id,correo,unidades_ids,invitado_por)
  VALUES(p_auth_user_id,p_tipo,p_perfil_id,v_email,
    ARRAY(SELECT jsonb_array_elements_text(v_perfil->'unidades_ids')::bigint),auth.uid()) RETURNING id INTO v_id;
  RETURN v_id;
END $function$;
REVOKE ALL ON FUNCTION public.axi_registro_invitacion_crear(text,bigint,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.axi_registro_invitacion_crear(text,bigint,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.axi_registro_contexto()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE r private.solicitudes_registro; p jsonb;
BEGIN
  SELECT * INTO r FROM private.solicitudes_registro WHERE auth_user_id=(SELECT auth.uid());
  IF NOT FOUND THEN RAISE EXCEPTION 'No existe una invitación de registro para esta cuenta'; END IF;
  IF r.estado = 'Aprobado' THEN RAISE EXCEPTION 'La solicitud ya fue aprobada'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=r.auth_user_id AND lower(btrim(u.email))=r.correo AND u.email_confirmed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Confirme el correo abriendo la invitación enviada antes de continuar';
  END IF;
  p := public.axi_registro_perfil(r.perfil_tipo,r.perfil_id);
  IF p->>'correo' <> r.correo OR (p->'unidades_ids') IS DISTINCT FROM to_jsonb(r.unidades_ids) THEN
    RAISE EXCEPTION 'El perfil o sus unidades cambiaron; contacte a la administración para revisar la invitación';
  END IF;
  RETURN jsonb_build_object('id',r.id,'tipo',r.perfil_tipo,'rol',r.perfil_tipo,'correo',r.correo,
    'nombre',p->>'nombre','documento',p->>'documento','telefono',p->>'telefono','whatsapp',p->>'whatsapp',
    'unidades',p->'unidades_ids','unidades_codigos',p->'unidades_codigos','estado',r.estado);
END $function$;
REVOKE ALL ON FUNCTION public.axi_registro_contexto() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.axi_registro_contexto() TO authenticated;

CREATE OR REPLACE FUNCTION public.axi_registro_completar(
  p_nombre text,p_documento text,p_telefono text,p_whatsapp text,p_usuario_login text,p_unidades_ids bigint[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE r private.solicitudes_registro; p jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Inicie sesión mediante la invitación recibida'; END IF;
  IF nullif(btrim(p_nombre),'') IS NULL OR nullif(btrim(p_documento),'') IS NULL OR
     nullif(btrim(p_telefono),'') IS NULL OR nullif(btrim(p_whatsapp),'') IS NULL OR
     nullif(btrim(p_usuario_login),'') IS NULL THEN RAISE EXCEPTION 'Complete todos los campos obligatorios'; END IF;
  SELECT * INTO r FROM private.solicitudes_registro WHERE auth_user_id=(SELECT auth.uid()) FOR UPDATE;
  IF NOT FOUND OR r.estado <> 'Invitado' THEN RAISE EXCEPTION 'No hay una invitación vigente para completar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=r.auth_user_id AND lower(btrim(u.email))=r.correo AND u.email_confirmed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'El correo debe coincidir con la invitación y estar confirmado';
  END IF;
  p := public.axi_registro_perfil(r.perfil_tipo,r.perfil_id);
  IF p->>'correo' <> r.correo OR (p->'unidades_ids') IS DISTINCT FROM to_jsonb(r.unidades_ids) OR
     coalesce(p_unidades_ids,'{}'::bigint[]) IS DISTINCT FROM r.unidades_ids THEN
    RAISE EXCEPTION 'El perfil o sus unidades no coinciden con la invitación';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('registro-login:'||lower(btrim(p_usuario_login)),0));
  IF EXISTS (SELECT 1 FROM public.usuarios u WHERE lower(btrim(u.usuario_login))=lower(btrim(p_usuario_login)) AND u.auth_user_id IS DISTINCT FROM auth.uid()) THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está en uso';
  END IF;
  UPDATE private.solicitudes_registro SET estado='Pendiente',completado_at=now(),
    datos_registro=jsonb_build_object('nombre',btrim(p_nombre),'documento',btrim(p_documento),
      'telefono',btrim(p_telefono),'whatsapp',btrim(p_whatsapp),'usuario_login',btrim(p_usuario_login))
    WHERE id=r.id;
END $function$;
REVOKE ALL ON FUNCTION public.axi_registro_completar(text,text,text,text,text,bigint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.axi_registro_completar(text,text,text,text,text,bigint[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.axi_registro_aprobaciones()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN
  IF NOT private.es_ceo() OR NOT private.aal2_ok() THEN RAISE EXCEPTION 'Solo el CEO con verificación en dos pasos puede aprobar registros' USING ERRCODE='42501'; END IF;
  RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'tipo',r.perfil_tipo,'correo',r.correo,
      'nombre',r.datos_registro->>'nombre','documento',r.datos_registro->>'documento',
      'telefono',r.datos_registro->>'telefono','whatsapp',r.datos_registro->>'whatsapp',
      'usuario_login',r.datos_registro->>'usuario_login','unidades',to_jsonb(r.unidades_ids),'completado_at',r.completado_at)
      ORDER BY r.completado_at) FROM private.solicitudes_registro r WHERE r.estado='Pendiente'), '[]'::jsonb);
END $function$;
REVOKE ALL ON FUNCTION public.axi_registro_aprobaciones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.axi_registro_aprobaciones() TO authenticated;

CREATE OR REPLACE FUNCTION public.axi_registro_aprobar(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE r private.solicitudes_registro; p jsonb; d jsonb; v_usuario_id bigint; v_condo bigint; v_nombre text;
BEGIN
  IF NOT private.es_ceo() OR NOT private.aal2_ok() THEN RAISE EXCEPTION 'Solo el CEO con verificación en dos pasos puede aprobar registros' USING ERRCODE='42501'; END IF;
  SELECT * INTO r FROM private.solicitudes_registro WHERE id=p_id FOR UPDATE;
  IF NOT FOUND OR r.estado <> 'Pendiente' THEN RAISE EXCEPTION 'La solicitud ya no está pendiente'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=r.auth_user_id AND lower(btrim(u.email))=r.correo AND u.email_confirmed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'El correo de la invitación aún no ha sido confirmado';
  END IF;
  p := public.axi_registro_perfil(r.perfil_tipo,r.perfil_id); d := r.datos_registro;
  IF p->>'correo' <> r.correo OR (p->'unidades_ids') IS DISTINCT FROM to_jsonb(r.unidades_ids) THEN
    RAISE EXCEPTION 'El perfil o sus unidades cambiaron desde la solicitud; revise el registro antes de aprobar';
  END IF;
  IF EXISTS (SELECT 1 FROM public.accesos x WHERE x.activo AND
      ((r.perfil_tipo='Inquilino' AND x.inquilino_id=r.perfil_id) OR
       (r.perfil_tipo='Propietario' AND x.propietario_id=r.perfil_id) OR
       (r.perfil_tipo='Administrador' AND x.administrador_id=r.perfil_id))) THEN
    RAISE EXCEPTION 'Este perfil ya tiene un acceso activo';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('registro-login:'||lower(btrim(d->>'usuario_login')),0));
  IF EXISTS (SELECT 1 FROM public.usuarios u WHERE lower(btrim(u.usuario_login))=lower(btrim(d->>'usuario_login'))) THEN
    RAISE EXCEPTION 'El nombre de usuario ya fue tomado; solicite al usuario que presente otro';
  END IF;
  v_condo := (p->>'condominio_id')::bigint; v_nombre := d->>'nombre';
  IF r.perfil_tipo='Inquilino' THEN
    UPDATE public.inquilinos SET nombre=v_nombre,documento=d->>'documento',telefono=d->>'telefono',whatsapp=d->>'whatsapp'
      WHERE id=r.perfil_id AND estado='Activo';
  ELSIF r.perfil_tipo='Propietario' THEN
    UPDATE public.propietarios SET nombre=v_nombre,documento=d->>'documento',telefono=d->>'telefono',whatsapp=d->>'whatsapp'
      WHERE id=r.perfil_id AND estado='Activo';
  ELSE
    UPDATE public.administradores SET nombre=v_nombre,documento=d->>'documento',telefono=d->>'telefono',whatsapp=d->>'whatsapp'
      WHERE id=r.perfil_id AND estado='Activo';
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'El perfil no existe o está inactivo'; END IF;
  INSERT INTO public.usuarios(nombre_completo,usuario_login,rol,email,whatsapp,activo,debe_cambiar_clave,
      fecha_creacion,created_at,updated_at,auth_user_id)
    VALUES(v_nombre,btrim(d->>'usuario_login'),r.perfil_tipo,r.correo,d->>'whatsapp',true,false,now(),now(),now(),r.auth_user_id)
    RETURNING id INTO v_usuario_id;
  INSERT INTO public.accesos(auth_user_id,rol,condominio_id,usuario_id,propietario_id,inquilino_id,administrador_id,activo,created_by)
    VALUES(r.auth_user_id,r.perfil_tipo,v_condo,v_usuario_id,
      CASE WHEN r.perfil_tipo='Propietario' THEN r.perfil_id END,
      CASE WHEN r.perfil_tipo='Inquilino' THEN r.perfil_id END,
      CASE WHEN r.perfil_tipo='Administrador' THEN r.perfil_id END,true,auth.uid());
  INSERT INTO public.correos_salida(para,asunto,texto,referencia)
    VALUES(ARRAY[r.correo],'AXICORE | Solicitud de acceso aprobada',
      'Su solicitud de registro en AXICORE fue aprobada. Ya puede iniciar sesión con el correo y la contraseña que registró.',
      'registro-aprobado:'||r.id::text);
  UPDATE private.solicitudes_registro SET estado='Aprobado',aprobado_por=auth.uid(),aprobado_at=now() WHERE id=r.id;
  RETURN jsonb_build_object('ok',true,'rol',r.perfil_tipo,'correo',r.correo,'usuario_id',v_usuario_id);
END $function$;
REVOKE ALL ON FUNCTION public.axi_registro_aprobar(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.axi_registro_aprobar(uuid) TO authenticated;

