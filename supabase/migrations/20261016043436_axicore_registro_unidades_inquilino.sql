-- Igualar las unidades del registro a las que private.unidades_inquilino autoriza en AXICORE.
CREATE OR REPLACE FUNCTION public.axi_registro_perfil(p_tipo text, p_perfil_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_email text; v_total integer; v_units bigint[]; v_condo bigint; v_nombre text;
        v_unit_codes jsonb; v_documento text; v_telefono text; v_whatsapp text; v_pendiente boolean;
BEGIN
  IF p_tipo IS NULL OR p_tipo NOT IN ('Inquilino','Propietario','Administrador') THEN RAISE EXCEPTION 'Perfil no admitido'; END IF;
  IF p_tipo = 'Inquilino' THEN
    SELECT lower(btrim(i.email)),i.condominio_id,i.nombre,i.documento,i.telefono,i.whatsapp,
      coalesce(ARRAY(
        SELECT x.unidad_id FROM (
          SELECT i.unidad_id AS unidad_id WHERE i.unidad_id IS NOT NULL
          UNION
          SELECT ui.unidad_id FROM public.unidad_inquilinos ui
            WHERE ui.inquilino_id=i.id AND ui.fecha_fin IS NULL AND ui.unidad_id IS NOT NULL
        ) x JOIN public.unidades u ON u.id=x.unidad_id AND u.condominio_id=i.condominio_id
        ORDER BY x.unidad_id
      ),'{}'::bigint[])
      INTO v_email,v_condo,v_nombre,v_documento,v_telefono,v_whatsapp,v_units
      FROM public.inquilinos i WHERE i.id=p_perfil_id AND i.estado='Activo';
  ELSIF p_tipo = 'Propietario' THEN
    SELECT lower(btrim(p.email)),p.condominio_id,p.nombre,p.documento,p.telefono,p.whatsapp,
      coalesce(array_agg(DISTINCT u.id ORDER BY u.id) FILTER (WHERE u.id IS NOT NULL),'{}')
      INTO v_email,v_condo,v_nombre,v_documento,v_telefono,v_whatsapp,v_units
      FROM public.propietarios p LEFT JOIN public.unidades u ON u.condominio_id=p.condominio_id
        AND (u.propietario_id=p.id OR EXISTS (SELECT 1 FROM public.unidad_propietarios up
          WHERE up.unidad_id=u.id AND up.propietario_id=p.id AND up.fecha_fin IS NULL
          AND (up.fecha_inicio IS NULL OR up.fecha_inicio<=now())))
      WHERE p.id=p_perfil_id AND p.estado='Activo' GROUP BY p.id;
  ELSE
    SELECT lower(btrim(a.email)),a.condominio_id,a.nombre,a.documento,a.telefono,a.whatsapp,
      coalesce(array_agg(DISTINCT u.id ORDER BY u.id) FILTER (WHERE u.id IS NOT NULL),'{}')
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
  IF v_total<>1 THEN RAISE EXCEPTION 'El correo debe identificar un solo perfil. Corrija los registros antes de invitar.'; END IF;
  IF cardinality(v_units)=0 THEN RAISE EXCEPTION 'El perfil no tiene unidades asignadas'; END IF;
  SELECT coalesce(jsonb_agg(u.codigo ORDER BY u.codigo),'[]'::jsonb) INTO v_unit_codes
    FROM public.unidades u WHERE u.id=ANY(v_units);
  IF EXISTS (SELECT 1 FROM public.accesos x WHERE x.activo AND
      ((p_tipo='Inquilino' AND x.inquilino_id=p_perfil_id) OR
       (p_tipo='Propietario' AND x.propietario_id=p_perfil_id) OR
       (p_tipo='Administrador' AND x.administrador_id=p_perfil_id))) THEN RAISE EXCEPTION 'Este perfil ya tiene acceso activo'; END IF;
  SELECT EXISTS (SELECT 1 FROM private.solicitudes_registro r WHERE r.perfil_tipo=p_tipo AND r.perfil_id=p_perfil_id
    AND r.estado IN ('Invitado','Pendiente')) INTO v_pendiente;
  RETURN jsonb_build_object('tipo',p_tipo,'perfil_id',p_perfil_id,'correo',v_email,'condominio_id',v_condo,
    'nombre',v_nombre,'documento',v_documento,'telefono',v_telefono,'whatsapp',v_whatsapp,
    'unidades_ids',to_jsonb(v_units),'unidades_codigos',v_unit_codes,'solicitud_pendiente',v_pendiente);
END $function$;
REVOKE ALL ON FUNCTION public.axi_registro_perfil(text,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.axi_registro_perfil(text,bigint) TO service_role;

