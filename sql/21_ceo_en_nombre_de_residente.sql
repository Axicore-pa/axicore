-- AXICORE | 21 - El CEO reserva y reporta en nombre de un residente (decisiones de Misael 11/10/2026)
--  * Reserva: solo CEO; elige unidad y Propietario/Inquilino; queda Aprobada directo; confirmacion con .ics al residente.
--  * Reporte de situacion: solo CEO; mismos campos del Google Form; serie aparte AXI-RPT-AAAA-W0001.
--    El PDF con marca y los correos (con .ics a la administracion) los arma la web.

-- ---------------------------------------------------------------- Reserva en nombre de un residente
CREATE OR REPLACE FUNCTION public.fn_reserva_crear_admin(p jsonb)
RETURNS public.reservas LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_unidad public.unidades; f record; v_r public.reservas; v_cargo text; v_inq public.inquilinos; v_codigo text; v_para text[];
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO puede reservar en nombre de un residente'; END IF;
  SELECT * INTO v_unidad FROM public.unidades u WHERE u.id = (p->>'unidad_id')::bigint;
  IF NOT FOUND THEN RAISE EXCEPTION 'Seleccione la unidad'; END IF;
  v_cargo := coalesce(p->>'cargo_a', '');
  IF v_cargo NOT IN ('Propietario', 'Inquilino') THEN RAISE EXCEPTION 'Indique si reserva a nombre del Propietario o del Inquilino'; END IF;
  IF v_cargo = 'Propietario' AND v_unidad.propietario_id IS NULL THEN RAISE EXCEPTION 'La unidad no tiene propietario registrado'; END IF;
  IF v_cargo = 'Inquilino' THEN
    SELECT * INTO v_inq FROM public.inquilinos i WHERE i.id = (p->>'inquilino_id')::bigint AND i.unidad_id = v_unidad.id
       AND coalesce(i.estado, 'Activo') ILIKE 'activo%';
    IF NOT FOUND THEN RAISE EXCEPTION 'El inquilino elegido no está activo en la unidad'; END IF;
  END IF;
  SELECT * INTO f FROM private.res_franjas() x WHERE x.franja = p->>'franja';
  IF NOT FOUND THEN RAISE EXCEPTION 'Seleccione un horario válido'; END IF;
  IF (p->>'fecha') IS NULL THEN RAISE EXCEPTION 'Seleccione la fecha'; END IF;
  IF ((p->>'fecha')::date + f.inicio) <= private.res_ahora() THEN RAISE EXCEPTION 'Ese horario ya pasó. Seleccione otro.'; END IF;
  IF coalesce(btrim(p->>'responsable'), '') = '' THEN RAISE EXCEPTION 'Debe completar el campo: Nombre y Apellido'; END IF;
  IF coalesce(btrim(p->>'telefono'), '') = '' THEN RAISE EXCEPTION 'Debe completar el campo: Teléfono'; END IF;
  IF coalesce(btrim(p->>'email'), '') <> '' AND btrim(p->>'email') !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' THEN RAISE EXCEPTION 'Correo electrónico no válido'; END IF;
  IF coalesce(btrim(p->>'motivo'), '') = '' THEN RAISE EXCEPTION 'Debe completar el campo: Motivo'; END IF;
  IF coalesce((p->>'cantidad_personas')::int, 0) < 1 THEN RAISE EXCEPTION 'La cantidad de personas debe ser mayor que cero.'; END IF;

  v_codigo := 'RES-' || to_char(private.res_ahora(), 'YYYYMMDD') || '-' || lpad(nextval('public.reservas_num_seq')::text, 4, '0');
  BEGIN
    INSERT INTO public.reservas (condominio_id, codigo, unidad_id, propietario_id, inquilino_id, solicitado_por, responsable, unidad_texto,
      email, telefono, nombre_quien_reserva, motivo, cantidad_personas, incluye_picuzzi, incluye_bbq, fecha, franja, hora_inicio, hora_fin,
      estado, decidido_por, decidido_at, origen)
    VALUES (v_unidad.condominio_id, v_codigo, v_unidad.id, v_unidad.propietario_id, v_inq.id, NULL, btrim(p->>'responsable'), v_unidad.codigo,
      coalesce(nullif(btrim(p->>'email'), ''), private.res_admin_email()), btrim(p->>'telefono'),
      coalesce(nullif(btrim(p->>'nombre_quien_reserva'), ''), btrim(p->>'responsable')), btrim(p->>'motivo'), (p->>'cantidad_personas')::int,
      coalesce((p->>'incluye_picuzzi')::boolean, false), coalesce((p->>'incluye_bbq')::boolean, false),
      (p->>'fecha')::date, f.franja, f.inicio, f.fin, 'Aprobada', private.nombre_actor(), now(), 'Administración (' || v_cargo || ')')
    RETURNING * INTO v_r;
  EXCEPTION WHEN exclusion_violation THEN
    RAISE EXCEPTION 'Ese horario ya está reservado. Seleccione otro horario.';
  END;

  v_para := CASE WHEN coalesce(btrim(p->>'email'), '') <> '' THEN ARRAY[btrim(p->>'email')] ELSE ARRAY[private.res_admin_email()] END;
  PERFORM private.res_correo(v_para, CASE WHEN coalesce(btrim(p->>'email'), '') <> '' THEN ARRAY[private.res_admin_email()] ELSE '{}' END,
    'Reservación ' || v_r.codigo || ' | Aprobada',
    private.res_html('Reservación de Área Común',
      '<p>La Administración registró y <strong style="color:#2e7d32">APROBÓ</strong> esta reservación a su nombre.</p>' || private.res_tabla(v_r)
      || '<div style="text-align:center;margin:25px 0;"><a href="' || private.res_calendar_url(v_r) || '" target="_blank" style="display:inline-block;background:#14233F;color:#FFFFFF;text-decoration:none;padding:13px 20px;border-radius:5px;font-weight:bold;">AGREGAR A GOOGLE CALENDAR</a></div>'
      || '<p style="font-size:13px;color:#455a64;">También se adjunta un archivo de calendario (.ics) compatible con Google Calendar, Outlook, Apple Calendar y otros calendarios. El archivo incluye alertas de 48 horas, 24 horas y 4 horas antes.</p>'
      || '<p><strong>AXICORE enviará además recordatorios por correo 48 horas, 24 horas y 4 horas antes de la reservación.</strong></p>'
      || '<p>Las normas de uso, seguridad, higiene y convivencia indicadas en el formulario permanecen aplicables durante toda la reservación.</p>'),
    v_r.codigo, jsonb_build_array(private.res_ics(v_r)));
  PERFORM private.log_portal('Reservas', 'reservas', v_r.id, NULL, NULL, v_r.codigo, 'Creación',
    'Reserva registrada por el CEO a nombre del ' || v_cargo || ' de ' || v_unidad.codigo);
  RETURN v_r;
END $$;

-- ---------------------------------------------------------------- Reporte de situacion desde la web (CEO)
CREATE SEQUENCE IF NOT EXISTS public.mant_web_seq;

INSERT INTO storage.buckets (id, name, public) VALUES ('mant-evidencia', 'mant-evidencia', false) ON CONFLICT (id) DO NOTHING;
CREATE POLICY axi_mantev_subir ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'mant-evidencia' AND (SELECT private.es_ceo()));
CREATE POLICY axi_mantev_ver ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'mant-evidencia' AND (SELECT private.es_staff()));

CREATE OR REPLACE FUNCTION public.fn_mant_reporte_web(p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_ref text; v_id bigint; v_uni public.unidades; v_condo bigint; v_pri text; v_cond_txt text;
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO puede registrar reportes en nombre de un residente'; END IF;
  v_condo := coalesce((p->>'condominio_id')::bigint, 5);
  IF NOT (v_condo = ANY (private.staff_condos('Mantenimientos', 'ver'))) THEN RAISE EXCEPTION 'Sin acceso a este condominio'; END IF;
  IF coalesce(btrim(p->>'nombre'), '') = '' THEN RAISE EXCEPTION 'Debe completar: Nombre y Apellido'; END IF;
  IF coalesce(btrim(p->>'telefono'), '') = '' THEN RAISE EXCEPTION 'Debe completar: Teléfono (WhatsApp)'; END IF;
  IF coalesce(btrim(p->>'correo'), '') <> '' AND btrim(p->>'correo') !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' THEN RAISE EXCEPTION 'Correo electrónico no válido'; END IF;
  IF coalesce(btrim(p->>'unidad'), '') = '' AND (p->>'unidad_id') IS NULL THEN RAISE EXCEPTION 'Debe completar: Unidad que Ocupa'; END IF;
  IF coalesce(btrim(p->>'categoria'), '') = '' THEN RAISE EXCEPTION 'Debe completar: Categoría del Problema'; END IF;
  IF length(coalesce(btrim(p->>'descripcion'), '')) < 3 THEN RAISE EXCEPTION 'Debe completar: Descripción del Problema'; END IF;
  IF coalesce(btrim(p->>'area'), '') = '' THEN RAISE EXCEPTION 'Debe completar: Área Afectada'; END IF;
  v_pri := p->>'prioridad';
  IF v_pri NOT IN ('Baja','Media','Alta','Crítica') THEN RAISE EXCEPTION 'Debe completar: Prioridad'; END IF;
  IF (p->>'unidad_id') IS NOT NULL THEN
    SELECT * INTO v_uni FROM public.unidades u WHERE u.id = (p->>'unidad_id')::bigint AND u.condominio_id = v_condo;
  END IF;
  SELECT c.nombre INTO v_cond_txt FROM public.condominios c WHERE c.id = v_condo;

  v_ref := 'AXI-RPT-' || to_char(private.res_ahora(), 'YYYY') || '-W' || lpad(nextval('public.mant_web_seq')::text, 4, '0');
  INSERT INTO public.mantenimientos (condominio_id, unidad_id, codigo, tipo, prioridad, fecha_solicitud, estatus, descripcion,
         area_aplicacion, bloque, afecta_fondo_comun, reportante_nombre, reportante_telefono, reportante_email,
         condominio_texto, unidad_texto, origen, evidencia, estado_registro, created_at)
  VALUES (v_condo, v_uni.id, v_ref, left(btrim(p->>'categoria'), 60), v_pri, now(), 'Recibido', left(btrim(p->>'descripcion'), 4000),
         left(btrim(p->>'area'), 100), left(nullif(btrim(p->>'bloque'), ''), 40), false,
         left(btrim(p->>'nombre'), 150), left(btrim(p->>'telefono'), 40), lower(left(nullif(btrim(p->>'correo'), ''), 254)),
         coalesce(v_cond_txt, ''), left(coalesce(v_uni.codigo, btrim(p->>'unidad')), 60), 'Web (CEO)',
         CASE WHEN jsonb_typeof(p->'evidencia') = 'array' THEN p->'evidencia' END, 'Completado', now())
  RETURNING id INTO v_id;
  INSERT INTO public.mantenimiento_historial (mantenimiento_id, codigo_formulario, unidad_codigo, nombre_reportante, categoria,
         prioridad, estatus, fecha_cambio, accion, usuario_nombre, created_at)
  VALUES (v_id, v_ref, coalesce(v_uni.codigo, p->>'unidad'), p->>'nombre', p->>'categoria', v_pri, 'Recibido', now(),
         'Registrado desde la web en nombre del residente', private.nombre_actor(), now());
  RETURN jsonb_build_object('id', v_id, 'referencia', v_ref, 'condominio', v_cond_txt, 'unidad', coalesce(v_uni.codigo, p->>'unidad'));
END $$;

REVOKE ALL ON FUNCTION public.fn_reserva_crear_admin(jsonb), public.fn_mant_reporte_web(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_reserva_crear_admin(jsonb), public.fn_mant_reporte_web(jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';
