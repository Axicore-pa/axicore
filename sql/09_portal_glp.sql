-- AXICORE | P1 Mi gas (GLP) del residente (10/10/2026)
-- Saldo = depositos ACTIVOS - consumos ACTIVOS (convencion: positivo = a favor, negativo = pendiente)
-- Lecturas: excluye anuladas y las de monto negativo (depositos guardados como lectura en Access)
CREATE OR REPLACE FUNCTION public.portal_mi_glp(p_unidad_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_condo bigint;
BEGIN
  SELECT u.condominio_id INTO v_condo FROM public.unidades u WHERE u.id = p_unidad_id;
  IF v_condo IS NULL THEN RAISE EXCEPTION 'Unidad no encontrada' USING ERRCODE = '22023'; END IF;
  IF NOT (private.es_ceo()
          OR v_condo = ANY (private.staff_condos('GLP','ver'))
          OR p_unidad_id = ANY (private.unidades_propias())
          OR p_unidad_id = ANY (private.unidades_inquilino())) THEN
    RAISE EXCEPTION 'Sin acceso a esta unidad' USING ERRCODE = '42501'; END IF;
  RETURN jsonb_build_object(
    'unidad', (SELECT u.codigo FROM public.unidades u WHERE u.id = p_unidad_id),
    'medidor', (SELECT jsonb_build_object('serie', m.numero_serie, 'marca', m.marca_modelo, 'ubicacion', m.ubicacion_fisica,
                       'unidad_medida', m.unidad_medida, 'lectura_inicial', m.lectura_inicial, 'estado', m.estado_equipo)
                  FROM public.glp_medidores m WHERE m.unidad_id = p_unidad_id ORDER BY m.id DESC LIMIT 1),
    'precio_vigente', (SELECT pr.precio_galon FROM public.glp_precios pr WHERE pr.condominio_id = v_condo
                        AND pr.fecha_vigencia <= now() ORDER BY pr.fecha_vigencia DESC LIMIT 1),
    'total_depositos', (SELECT coalesce(sum(x.monto), 0) FROM public.glp_movimientos x
                         WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO' AND upper(x.tipo_movimiento) = 'DEPOSITO'),
    'total_consumos', (SELECT coalesce(sum(x.monto), 0) FROM public.glp_movimientos x
                        WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO' AND upper(x.tipo_movimiento) = 'CONSUMO'),
    'saldo', (SELECT coalesce(sum(CASE WHEN upper(x.tipo_movimiento) = 'DEPOSITO' THEN x.monto ELSE -x.monto END), 0)
                FROM public.glp_movimientos x WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO'),
    'movimientos', (SELECT coalesce(jsonb_agg(jsonb_build_object('fecha', x.fecha_movimiento::date, 'tipo', x.tipo_movimiento,
                       'periodo', x.periodo, 'concepto', x.concepto, 'monto', x.monto, 'saldo', x.saldo_posterior)
                       ORDER BY x.fecha_movimiento DESC, x.id DESC), '[]'::jsonb)
                      FROM public.glp_movimientos x WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO'),
    'lecturas', (SELECT coalesce(jsonb_agg(jsonb_build_object('fecha', l.fecha_lectura::date, 'periodo', l.periodo,
                       'anterior', l.lectura_anterior, 'actual', l.lectura_actual, 'consumo', l.consumo,
                       'precio', l.precio_unitario, 'monto', l.monto_consumo)
                       ORDER BY l.fecha_lectura DESC, l.id DESC), '[]'::jsonb)
                   FROM public.glp_lecturas l WHERE l.unidad_id = p_unidad_id
                    AND upper(coalesce(l.estado, 'ACTIVO')) <> 'ANULADO' AND coalesce(l.monto_consumo, 0) >= 0));
END $$;
REVOKE EXECUTE ON FUNCTION public.portal_mi_glp(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.portal_mi_glp(bigint) TO authenticated;
NOTIFY pgrst, 'reload schema';
