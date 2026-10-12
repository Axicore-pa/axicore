-- AXICORE | 25 - Tanque de GLP (nivel al corte)
-- Llenados del tanque del condominio. Consumo = lecturas ACTIVAS desde el ultimo llenado hasta el corte.
-- Corte = fecha de la ultima lectura activa anterior al mes en curso (ej. en octubre: 30-sep-2026).
-- Visible para CEO, staff con GLP/ver, y propietarios/inquilinos de ese condominio (solo el tanque).
CREATE TABLE IF NOT EXISTS public.glp_llenados (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  condominio_id bigint NOT NULL REFERENCES public.condominios(id),
  fecha date NOT NULL,
  galones numeric(10,2) NOT NULL CHECK (galones > 0),
  capacidad_tanque numeric(10,2) NOT NULL CHECK (capacidad_tanque > 0),
  observaciones text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.glp_llenados ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.glp_llenados FROM anon, authenticated;

INSERT INTO public.glp_llenados (condominio_id, fecha, galones, capacidad_tanque, observaciones)
SELECT 5, DATE '2026-07-17', 191.66, 191.66, 'Llenado inicial (dato de Misael, 11/10/2026)'
WHERE NOT EXISTS (SELECT 1 FROM public.glp_llenados WHERE condominio_id = 5 AND fecha = DATE '2026-07-17');

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
    'corte', v_corte, 'consumo', round(v_cons, 2),
    'balance', round(v_ll.galones - v_cons, 2),
    'pct', round(100 * (v_ll.galones - v_cons) / v_ll.capacidad_tanque, 1));
END $function$;
REVOKE ALL ON FUNCTION public.fn_glp_tanque(bigint) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.fn_glp_tanque(bigint) TO authenticated;
