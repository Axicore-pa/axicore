-- AXICORE | 19 - Decisiones de Misael 10/10/2026
--  1) Gasto de unidad: ni el gasto ni el pago del residente aparecen en el ECG / flujo (solo en el estado de cuenta de la unidad).
--  2) Numeracion de facturas: DH2-FAC-00117, continuando la secuencia existente (FAC-000116).

CREATE OR REPLACE FUNCTION private.lf_es_gasto_unidad(p_pago_id bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p_pago_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.pagos pg JOIN public.facturas f ON f.id = pg.factura_id
     WHERE pg.id = p_pago_id AND f.tipo_factura = 'Gasto de unidad');
$$;
REVOKE ALL ON FUNCTION private.lf_es_gasto_unidad(bigint) FROM PUBLIC, anon, authenticated;

DO $do$
DECLARE fn text; d text; n int;
BEGIN
  FOREACH fn IN ARRAY ARRAY['public.axi_ecg_totales(bigint,date,date)','public.axi_ecg_movimientos(bigint,date,date)','public.axi_flujo_mensual(bigint)'] LOOP
    d := pg_get_functiondef(fn::regprocedure);
    IF position('lf_es_gasto_unidad' in d) = 0 THEN
      n := (length(d) - length(replace(d, 'AND coalesce(lf.tipo_movimiento, '''') NOT ILIKE ''%GLP%''', ''))) / length('AND coalesce(lf.tipo_movimiento, '''') NOT ILIKE ''%GLP%''');
      IF n = 0 THEN RAISE EXCEPTION 'Sin punto de insercion en %', fn; END IF;
      d := replace(d, 'AND coalesce(lf.tipo_movimiento, '''') NOT ILIKE ''%GLP%''',
                      'AND coalesce(lf.tipo_movimiento, '''') NOT ILIKE ''%GLP%'' AND NOT private.lf_es_gasto_unidad(lf.pago_id)');
      EXECUTE d;
    END IF;
  END LOOP;
END $do$;

CREATE OR REPLACE FUNCTION public.fn_factura_siguiente_numero(p_condominio_id bigint)
 RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_prefijo text; v_max_seq int; v_numero text;
BEGIN
  SELECT split_part(coalesce(nullif(c.codigo, ''), 'COND' || c.id), '-', 1) INTO v_prefijo
    FROM public.condominios c WHERE c.id = p_condominio_id;
  IF v_prefijo IS NULL THEN RAISE EXCEPTION 'Condominio % no existe', p_condominio_id; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('factura_num_' || p_condominio_id::text));
  -- Continua la secuencia de TODAS las facturas del condominio (FAC-000116, DH2-FAC-00117, ...)
  SELECT coalesce(max(substring(f.no_factura from 'FAC-0*([0-9]+)$')::int), 0) INTO v_max_seq
    FROM public.facturas f WHERE f.condominio_id = p_condominio_id AND f.no_factura ~ 'FAC-[0-9]+$';
  v_numero := v_prefijo || '-FAC-' || lpad((v_max_seq + 1)::text, 5, '0');
  WHILE EXISTS (SELECT 1 FROM public.facturas WHERE condominio_id = p_condominio_id AND no_factura = v_numero) LOOP
    v_max_seq := v_max_seq + 1;
    v_numero := v_prefijo || '-FAC-' || lpad((v_max_seq + 1)::text, 5, '0');
  END LOOP;
  RETURN v_numero;
END $function$;

NOTIFY pgrst, 'reload schema';
