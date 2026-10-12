-- AXICORE | 26 - Registrar llenado del tanque de GLP (solo CEO) + nivel tras cada llenado
-- Nivel tras llenado = lo que quedaba en el tanque a esa fecha + galones cargados (tope: capacidad).
-- Lo que quedaba = nivel del llenado anterior - consumo de lecturas ACTIVAS entre ambos llenados.
ALTER TABLE public.glp_llenados ADD COLUMN IF NOT EXISTS nivel_tras_llenado numeric(10,2);
ALTER TABLE public.glp_llenados ADD COLUMN IF NOT EXISTS registrado_por text;
UPDATE public.glp_llenados SET nivel_tras_llenado = least(capacidad_tanque, galones) WHERE nivel_tras_llenado IS NULL;
ALTER TABLE public.glp_llenados ALTER COLUMN nivel_tras_llenado SET NOT NULL;

CREATE OR REPLACE FUNCTION public.fn_glp_llenado_registrar(p_condominio_id bigint, p_fecha date, p_galones numeric,
  p_capacidad numeric, p_observaciones text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_prev public.glp_llenados; v_cons numeric := 0; v_resto numeric := 0; v_nivel numeric; v_id bigint;
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO registra llenados del tanque' USING ERRCODE = '42501'; END IF;
  IF p_fecha IS NULL OR p_fecha > (now() AT TIME ZONE 'America/Santo_Domingo')::date THEN RAISE EXCEPTION 'La fecha no puede ser futura'; END IF;
  IF coalesce(p_galones, 0) <= 0 THEN RAISE EXCEPTION 'Indique los galones cargados'; END IF;
  IF coalesce(p_capacidad, 0) <= 0 THEN RAISE EXCEPTION 'Indique la capacidad del tanque'; END IF;
  SELECT * INTO v_prev FROM public.glp_llenados l WHERE l.condominio_id = p_condominio_id ORDER BY l.fecha DESC, l.id DESC LIMIT 1;
  IF FOUND THEN
    IF p_fecha < v_prev.fecha THEN RAISE EXCEPTION 'La fecha es anterior al último llenado (%)', to_char(v_prev.fecha, 'DD/MM/YYYY'); END IF;
    SELECT coalesce(sum(l.consumo), 0) INTO v_cons FROM public.glp_lecturas l
     WHERE l.condominio_id = p_condominio_id AND upper(coalesce(l.estado, 'ACTIVO')) = 'ACTIVO'
       AND l.fecha_lectura::date >= v_prev.fecha AND l.fecha_lectura::date < p_fecha;
    v_resto := greatest(0, v_prev.nivel_tras_llenado - v_cons);
  END IF;
  v_nivel := least(p_capacidad, v_resto + p_galones);
  INSERT INTO public.glp_llenados (condominio_id, fecha, galones, capacidad_tanque, nivel_tras_llenado, observaciones, registrado_por)
  VALUES (p_condominio_id, p_fecha, round(p_galones, 2), round(p_capacidad, 2), round(v_nivel, 2), nullif(btrim(p_observaciones), ''), private.nombre_actor())
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('id', v_id, 'remanente', round(v_resto, 2), 'nivel_tras_llenado', round(v_nivel, 2),
                            'excedente', round(greatest(0, v_resto + p_galones - p_capacidad), 2));
END $function$;
REVOKE ALL ON FUNCTION public.fn_glp_llenado_registrar(bigint, date, numeric, numeric, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.fn_glp_llenado_registrar(bigint, date, numeric, numeric, text) TO authenticated;

-- Tanque: balance = nivel tras el ultimo llenado - consumo desde ese llenado hasta el corte
CREATE OR REPLACE FUNCTION public.fn_glp_tanque(p_condominio_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_ll public.glp_llenados; v_corte date; v_cons numeric;
BEGIN
  IF NOT (private.es_ceo()
          OR p_condominio_id = ANY (private.staff_condos('GLP','ver'))
          OR EXISTS (SELECT 1 FROM public.unidades u WHERE u.condominio_id = p_condominio_id
                      AND (u.id = ANY (private.unidades_propias()) OR u.id = ANY (private.unidades_inquilino())))) THEN
    RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  SELECT * INTO v_ll FROM public.glp_llenados l WHERE l.condominio_id = p_condominio_id ORDER BY l.fecha DESC, l.id DESC LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT max(l.fecha_lectura::date) INTO v_corte FROM public.glp_lecturas l
   WHERE l.condominio_id = p_condominio_id AND upper(coalesce(l.estado, 'ACTIVO')) = 'ACTIVO'
     AND l.fecha_lectura::date >= v_ll.fecha
     AND l.fecha_lectura::date < date_trunc('month', (now() AT TIME ZONE 'America/Santo_Domingo'))::date;
  SELECT coalesce(sum(l.consumo), 0) INTO v_cons FROM public.glp_lecturas l
   WHERE l.condominio_id = p_condominio_id AND upper(coalesce(l.estado, 'ACTIVO')) = 'ACTIVO'
     AND l.fecha_lectura::date >= v_ll.fecha AND v_corte IS NOT NULL AND l.fecha_lectura::date <= v_corte;
  RETURN jsonb_build_object(
    'capacidad', v_ll.capacidad_tanque, 'fecha_llenado', v_ll.fecha, 'galones_llenado', v_ll.galones,
    'nivel_tras_llenado', v_ll.nivel_tras_llenado, 'corte', v_corte, 'consumo', round(v_cons, 2),
    'balance', round(v_ll.nivel_tras_llenado - v_cons, 2),
    'pct', round(100 * (v_ll.nivel_tras_llenado - v_cons) / v_ll.capacidad_tanque, 1),
    'puede_registrar', private.es_ceo());
END $function$;
