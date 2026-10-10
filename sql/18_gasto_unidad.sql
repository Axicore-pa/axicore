-- AXICORE | 18 - Gasto tipo "Unidad" cobrado al Propietario o Inquilino (decisiones de Misael 10/10/2026)
--  * Al registrar un gasto tipo Unidad se genera una factura (tipo_factura 'Gasto de unidad')
--    contra el Propietario o el Inquilino elegido, vence el mismo dia del gasto.
--  * Ni el gasto ni el pago del residente afectan el fondo comun (solo el estado de cuenta de la unidad).

CREATE OR REPLACE FUNCTION public.axi_gasto_registrar(p jsonb)
 RETURNS gastos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_gasto public.gastos; v_codigo text; v_condos bigint[]; v_condominio_id bigint; v_afecta_fc boolean; v_fg_id bigint;
  v_es_unidad boolean; v_unidad public.unidades; v_cargo text; v_inq public.inquilinos; v_fac_id bigint; v_no text;
BEGIN
  v_condos := private.staff_condos('Gastos', 'crear');
  IF array_length(v_condos, 1) IS NULL OR v_condos = '{}' THEN RAISE EXCEPTION 'No tiene permiso para registrar gastos'; END IF;
  IF coalesce((p->>'proveedor_id')::bigint, 0) = 0 THEN RAISE EXCEPTION 'Proveedor ID obligatorio'; END IF;
  IF coalesce(p->>'tipo_aplicacion', '') = '' THEN RAISE EXCEPTION 'Tipo Aplicación obligatorio'; END IF;
  IF coalesce(p->>'area_aplicacion', '') = '' THEN RAISE EXCEPTION 'Área de aplicación obligatoria'; END IF;
  IF lower(coalesce(p->>'area_aplicacion', '')) = 'otro' AND coalesce(p->>'area_aplicacion_otro', '') = '' THEN RAISE EXCEPTION 'Otro - detalle obligatorio cuando el área es Otro'; END IF;
  IF coalesce(p->>'categoria', '') = '' THEN RAISE EXCEPTION 'Categoría obligatoria'; END IF;
  IF (p->>'fecha') IS NULL THEN RAISE EXCEPTION 'Fecha obligatoria'; END IF;
  IF coalesce((p->>'monto')::numeric, 0) <= 0 THEN RAISE EXCEPTION 'Monto debe ser mayor que cero'; END IF;
  IF coalesce(p->>'factura_proveedor', '') = '' THEN RAISE EXCEPTION 'Factura Proveedor obligatoria'; END IF;
  IF coalesce(p->>'metodo_pago', '') = '' THEN RAISE EXCEPTION 'Método obligatorio'; END IF;
  IF coalesce(p->>'descripcion', '') = '' THEN RAISE EXCEPTION 'Descripción obligatoria'; END IF;
  v_condominio_id := coalesce((p->>'condominio_id')::bigint, 5);
  IF NOT (v_condominio_id = ANY(v_condos)) THEN RAISE EXCEPTION 'No tiene permiso en este condominio'; END IF;

  -- Tipo Unidad: unidad + a cargo de (Propietario | Inquilino)
  v_es_unidad := lower(coalesce(p->>'tipo_aplicacion', '')) = 'unidad';
  IF v_es_unidad THEN
    SELECT * INTO v_unidad FROM public.unidades u WHERE u.id = (p->>'unidad_id')::bigint AND u.condominio_id = v_condominio_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Seleccione la unidad a la que se aplica el gasto'; END IF;
    v_cargo := coalesce(p->>'cargo_a', '');
    IF v_cargo NOT IN ('Propietario', 'Inquilino') THEN RAISE EXCEPTION 'Indique si el gasto se cobra al Propietario o al Inquilino'; END IF;
    IF v_cargo = 'Propietario' AND v_unidad.propietario_id IS NULL THEN RAISE EXCEPTION 'La unidad % no tiene propietario registrado', v_unidad.codigo; END IF;
    IF v_cargo = 'Inquilino' THEN
      SELECT * INTO v_inq FROM public.inquilinos i
       WHERE i.id = (p->>'inquilino_id')::bigint AND i.unidad_id = v_unidad.id AND coalesce(i.estado, 'Activo') ILIKE 'activo%';
      IF NOT FOUND THEN RAISE EXCEPTION 'El inquilino elegido no está activo en la unidad %', v_unidad.codigo; END IF;
    END IF;
  END IF;

  v_afecta_fc := lower(coalesce(p->>'tipo_aplicacion', '')) ILIKE 'com_n';
  v_codigo := coalesce(nullif(trim(p->>'codigo'), ''), public.axi_gasto_generar_codigo());
  INSERT INTO public.gastos (
    condominio_id, proveedor_id, unidad_id, propietario_id, codigo, fecha, categoria, tipo_servicio,
    area_aplicacion, area_aplicacion_otro, tipo_aplicacion, descripcion, monto, factura_proveedor,
    metodo_pago, estado, afecta_fondo_comun, foto_factura_url, created_at, updated_at, created_by, updated_by
  ) VALUES (
    v_condominio_id, (p->>'proveedor_id')::bigint,
    CASE WHEN v_es_unidad THEN v_unidad.id ELSE (p->>'unidad_id')::bigint END,
    CASE WHEN v_es_unidad THEN v_unidad.propietario_id ELSE (p->>'propietario_id')::bigint END,
    v_codigo, (p->>'fecha')::date, p->>'categoria', p->>'tipo_servicio', p->>'area_aplicacion',
    CASE WHEN lower(coalesce(p->>'area_aplicacion', '')) = 'otro' THEN p->>'area_aplicacion_otro' ELSE NULL END,
    p->>'tipo_aplicacion', p->>'descripcion', (p->>'monto')::numeric, p->>'factura_proveedor',
    p->>'metodo_pago', 'Registrado', v_afecta_fc, p->>'foto_factura_url', now(), now(),
    (SELECT auth.uid())::text, (SELECT auth.uid())::text
  ) RETURNING * INTO v_gasto;
  IF lower(coalesce(v_gasto.tipo_aplicacion, '')) <> 'no aplicable a cuota' THEN
    INSERT INTO public.facturas_gastos (
      condominio_id, gasto_id, proveedor_id, no_factura, periodo, fecha, categoria, concepto,
      monto, estado, area_aplicacion, tipo_aplicacion, deducir_de_cuota_mensual, deducir_acumulativo,
      reflejar_estado_condominio, observaciones, created_at
    ) VALUES (
      v_condominio_id, v_gasto.id, v_gasto.proveedor_id, public.axi_factura_gasto_generar_no(),
      to_char(v_gasto.fecha, 'YYYY-MM'), v_gasto.fecha, v_gasto.categoria, v_gasto.descripcion,
      v_gasto.monto, 'Registrada', v_gasto.area_aplicacion, v_gasto.tipo_aplicacion,
      true, true, true, 'Generada automáticamente', now()
    ) RETURNING id INTO v_fg_id;
  END IF;
  PERFORM public.axi_libro_registrar_gasto(v_gasto.id);

  -- Factura al residente por el gasto de su unidad (vence el mismo dia)
  IF v_es_unidad THEN
    v_no := public.fn_factura_siguiente_numero(v_condominio_id);
    INSERT INTO public.facturas (
      condominio_id, no_factura, unidad_id, propietario_id, inquilino_id, tipo_facturacion, tipo_factura,
      periodo, fecha_factura, fecha_vencimiento, concepto, observaciones, monto, monto_pagado, balance_pendiente,
      estado, afecta_cuota_mantenimiento, created_at, updated_at
    ) VALUES (
      v_condominio_id, v_no, v_unidad.id, v_unidad.propietario_id,
      CASE WHEN v_cargo = 'Inquilino' THEN v_inq.id END, v_cargo, 'Gasto de unidad',
      to_char(v_gasto.fecha, 'YYYY-MM'), v_gasto.fecha, v_gasto.fecha,
      'Gasto de unidad ' || v_codigo || ' - ' || v_gasto.descripcion,
      'Generada desde el gasto ' || v_codigo, v_gasto.monto, 0, v_gasto.monto,
      'Pendiente', false, now(), now()
    ) RETURNING id INTO v_fac_id;
    PERFORM private.log_portal('Facturación', 'facturas', v_fac_id, NULL, NULL, v_no, 'Creación',
      'Factura por gasto de unidad ' || v_codigo || ' a ' || v_cargo || ' | Monto: ' || v_gasto.monto);
  END IF;

  PERFORM private.log_portal('Gastos', 'gastos', v_gasto.id, NULL, NULL, v_codigo, 'Creación',
    'Gasto registrado: ' || v_codigo || ' | Monto: ' || v_gasto.monto);
  RETURN v_gasto;
END $function$;

-- fn_pago_registrar: el pago de una factura 'Gasto de unidad' no entra al fondo comun
DO $do$
DECLARE d text;
BEGIN
  d := pg_get_functiondef('public.fn_pago_registrar(jsonb)'::regprocedure);
  IF position('Gasto de unidad' in d) = 0 THEN
    d := replace(d, '     OR v_tipo_apl ILIKE ''%GLP%'' THEN v_fc := false; END IF;',
                    '     OR v_tipo_apl ILIKE ''%GLP%'' THEN v_fc := false; END IF;' || chr(10) ||
                    '  IF coalesce(v_factura.tipo_factura, '''') = ''Gasto de unidad'' THEN v_fc := false; END IF;');
    IF position('Gasto de unidad' in d) = 0 THEN RAISE EXCEPTION 'No se encontro el punto de insercion en fn_pago_registrar'; END IF;
    EXECUTE d;
  END IF;
END $do$;

NOTIFY pgrst, 'reload schema';
