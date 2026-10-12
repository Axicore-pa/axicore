-- AXICORE | 23 - Resumen de reportes por estado (tarjeta del Dashboard)
-- Cuenta TODOS los reportes del condominio (incluye historicos de Access y Cancelados),
-- independiente del indice de Salud (que solo cuenta desde fecha_arranque).
-- Mismo permiso que fn_salud_residencial. Solo lectura.
CREATE OR REPLACE FUNCTION public.fn_mant_resumen_estados(p_condominio_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT (private.es_ceo() OR p_condominio_id = ANY (private.staff_condos('Mantenimientos','ver'))) THEN
    RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  RETURN (
    SELECT coalesce(jsonb_agg(jsonb_build_object('estado', e.estado, 'n',
             (SELECT count(*) FROM public.mantenimientos m
               WHERE m.condominio_id = p_condominio_id AND m.estatus = e.estado),
             'cuenta', e.cuenta_indice) ORDER BY e.orden), '[]'::jsonb)
      FROM public.mant_estados e);
END $function$;

REVOKE ALL ON FUNCTION public.fn_mant_resumen_estados(bigint) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.fn_mant_resumen_estados(bigint) TO authenticated;
