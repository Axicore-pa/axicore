CREATE OR REPLACE FUNCTION public.despacho_cerrar_ventana(p_despacho_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_despacho record;
  v_ganador record;
BEGIN
  SELECT * INTO v_despacho
  FROM public.mant_despachos
  WHERE id = p_despacho_id AND estado = 'En espera';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Despacho no encontrado o no está en espera');
  END IF;

  -- Buscar la mejor respuesta (menor peso, excluir 99=No puede)
  SELECT dr.id, dr.proveedor_id, dr.respuesta, dr.prioridad_peso,
         p.nombre AS proveedor_nombre
  INTO v_ganador
  FROM public.mant_despacho_respuestas dr
  JOIN public.proveedores p ON p.id = dr.proveedor_id
  WHERE dr.despacho_id = p_despacho_id
    AND dr.prioridad_peso IS NOT NULL
    AND dr.prioridad_peso < 99
  ORDER BY dr.prioridad_peso ASC, dr.fecha_respuesta ASC
  LIMIT 1;

  IF FOUND THEN
    -- Marcar ganador
    UPDATE public.mant_despacho_respuestas
    SET es_ganador = true
    WHERE id = v_ganador.id;

    -- Actualizar despacho
    UPDATE public.mant_despachos
    SET estado = 'Asignado',
        proveedor_asignado_id = v_ganador.proveedor_id,
        respuesta_asignada = v_ganador.respuesta,
        fecha_cierre = now(),
        updated_at = now()
    WHERE id = p_despacho_id;

    -- Actualizar proveedor en el mantenimiento
    UPDATE public.mantenimientos
    SET proveedor_id = v_ganador.proveedor_id,
        updated_at = now()
    WHERE id = v_despacho.mantenimiento_id;

    RETURN jsonb_build_object(
      'ok', true,
      'estado', 'Asignado',
      'proveedor', v_ganador.proveedor_nombre,
      'respuesta', v_ganador.respuesta
    );
  ELSE
    -- Nadie respondió o todos dijeron "No puedo"
    UPDATE public.mant_despachos
    SET estado = 'Sin respuesta',
        fecha_cierre = now(),
        updated_at = now()
    WHERE id = p_despacho_id;

    RETURN jsonb_build_object(
      'ok', true,
      'estado', 'Sin respuesta'
    );
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION private.axi_despacho_tick()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_rec RECORD;
BEGIN
  -- PASO 1: Cerrar ventanas vencidas
  FOR v_rec IN SELECT despacho_id FROM public.despachos_vencidos()
  LOOP
    PERFORM public.despacho_cerrar_ventana(v_rec.despacho_id);
  END LOOP;

  -- PASO 2: Enviar correos pendientes via Edge Function
  IF EXISTS(
    SELECT 1
    FROM mant_despacho_respuestas r
    JOIN mant_despachos d ON d.id = r.despacho_id
    WHERE r.notificado = false
      AND d.estado IN ('Abierto','En espera')
  ) THEN
    PERFORM net.http_post(
      url:='https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-despacho-correo',
      headers:=jsonb_build_object(
        'Content-Type','application/json',
        'Authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmZ3lmdHNud3puc3FpenJpZ2dyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0MDgxODgsImV4cCI6MjEwNjk4NDE4OH0.i-icCG4lJ7Vjkp6c_j_a4Mrwt2w5Ig2GYUcfgWoIugQ'
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=55000
    );
  END IF;
END
$function$;

DROP TRIGGER IF EXISTS axi_despacho_nueva_asignacion ON public.mant_despachos;
-- Conservar tablas de seguimiento e historial. No ejecutar sin decisión de reversión.
