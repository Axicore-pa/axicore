-- AXICORE: inicio de asignaciones y consumo GLP sujeto a aprobación del CEO.
-- Autorización: Misael, conversación del 14/10/2026, propuesta aceptada con "ok".
-- Requiere SQL 25-27 y funciones de aprobación existentes.
-- No reclasifica registros históricos ni altera importes de producción.
-- La comprobación previa aborta si aparecen consumos pendientes históricos.
DO $preflight$
BEGIN
 IF EXISTS (SELECT 1 FROM public.glp_facturas WHERE estado_aprobacion IN ('Sometido','En proceso','Rechazado')) THEN
  RAISE EXCEPTION 'Revisar consumos GLP no aprobados existentes antes de aplicar esta migración';
 END IF;
END $preflight$;
CREATE OR REPLACE FUNCTION private.unidades_propias()
 RETURNS bigint[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT coalesce(array_agg(DISTINCT x.id), '{}'::bigint[]) FROM (
    SELECT u.id FROM public.accesos a
    JOIN public.unidades u ON u.condominio_id = a.condominio_id
     AND (u.propietario_id = a.propietario_id
          OR EXISTS (SELECT 1 FROM public.unidad_propietarios up
                     WHERE up.unidad_id = u.id AND up.propietario_id = a.propietario_id AND up.fecha_fin IS NULL
                       AND (up.fecha_inicio IS NULL OR up.fecha_inicio <= now())))
    WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Propietario'
    UNION
    SELECT ua.unidad_id FROM public.accesos a
    JOIN public.administradores ad ON ad.id = a.administrador_id AND ad.estado = 'Activo'
    JOIN public.unidad_administradores ua ON ua.administrador_id = a.administrador_id AND ua.fecha_fin IS NULL
      AND ua.fecha_inicio <= (now() AT TIME ZONE 'America/Santo_Domingo')::date
    WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Administrador' AND private.aal2_ok()) x $function$;

CREATE OR REPLACE FUNCTION public.fn_glp_registrar_consumo(p_unidad_id bigint, p_periodo text, p_fecha date, p_lectura_actual numeric, p_foto text DEFAULT NULL::text, p_precio numeric DEFAULT NULL::numeric, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u record; v_med bigint; v_antl numeric; v_m3 numeric; v_gal numeric; v_precio numeric; v_monto numeric;
        v_ant numeric; v_lid bigint; v_mid bigint; v_fid bigint; v_num text; v_anio text; n int; v_factor numeric; v_estado text; v_aprobacion text;
BEGIN
  SELECT x.id, x.codigo, x.condominio_id, c.glp_factor_m3_galon AS factor INTO u
    FROM public.unidades x JOIN public.condominios c ON c.id = x.condominio_id WHERE x.id = p_unidad_id;
  IF u.id IS NULL THEN RAISE EXCEPTION 'Unidad no encontrada'; END IF;
  IF NOT private.glp_puede(u.condominio_id, 'crear') THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  IF p_periodo IS NULL OR p_periodo !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' THEN RAISE EXCEPTION 'Periodo no valido (AAAA-MM)'; END IF;
  IF p_fecha IS NULL OR p_fecha > (now() AT TIME ZONE 'America/Santo_Domingo')::date + 1 THEN RAISE EXCEPTION 'Fecha de lectura no valida'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || p_unidad_id));
  IF EXISTS (SELECT 1 FROM public.glp_facturas f
              WHERE f.unidad_id = p_unidad_id AND f.estado_aprobacion IN ('Sometido','En proceso')
                AND upper(coalesce(f.estado, 'ACTIVO')) <> 'ANULADO') THEN
    RAISE EXCEPTION 'Primero apruebe o rechace el consumo pendiente de esta unidad'; END IF;
  v_estado := CASE WHEN private.es_ceo() THEN 'ACTIVO' ELSE 'PENDIENTE' END;
  SELECT m.id INTO v_med FROM public.glp_medidores m WHERE m.unidad_id = p_unidad_id ORDER BY m.id DESC LIMIT 1;
  IF v_med IS NULL THEN RAISE EXCEPTION 'La unidad no tiene medidor registrado'; END IF;
  IF EXISTS (SELECT 1 FROM public.glp_lecturas l WHERE l.unidad_id = p_unidad_id AND l.periodo = p_periodo
               AND upper(coalesce(l.estado,'ACTIVO')) = 'ACTIVO' AND coalesce(l.monto_consumo,0) >= 0) THEN
    RAISE EXCEPTION 'Ya existe un consumo activo para el periodo % de esta unidad (anulelo primero si debe corregirlo)', p_periodo; END IF;
  v_antl := private.glp_lectura_anterior(p_unidad_id);
  IF p_lectura_actual IS NULL OR p_lectura_actual < v_antl THEN
    RAISE EXCEPTION 'La lectura actual (%) no puede ser menor que la anterior (%)', p_lectura_actual, v_antl; END IF;
  v_precio := coalesce(p_precio, private.glp_precio_vigente(u.condominio_id, p_fecha));
  IF v_precio IS NULL OR v_precio <= 0 THEN RAISE EXCEPTION 'No hay precio de GLP vigente; registre el precio primero'; END IF;
  v_factor := coalesce(u.factor, 1.22);
  v_m3 := round(p_lectura_actual - v_antl, 4);
  v_gal := round(v_m3 * v_factor, 3);
  v_monto := round(v_m3 * v_factor * v_precio, 2);   -- igual que Access: galones sin redondear x precio
  v_ant := private.glp_saldo(p_unidad_id);
  INSERT INTO public.glp_lecturas (condominio_id, medidor_id, unidad_id, periodo, fecha_lectura, lectura_anterior, lectura_actual,
         consumo, precio_unitario, fecha_revision_precio, monto_consumo, foto_ruta, observaciones, fecha_registro, consumo_m3, estado, created_at, updated_at)
  VALUES (u.condominio_id, v_med, u.id, p_periodo, p_fecha::timestamptz, v_antl, p_lectura_actual, v_gal, v_precio, now(), v_monto,
         nullif(p_foto,''), nullif(btrim(p_observaciones),''), now(), v_m3, v_estado, now(), now())
  RETURNING id INTO v_lid;
  INSERT INTO public.glp_movimientos (condominio_id, unidad_id, medidor_id, lectura_id, periodo, fecha_movimiento, tipo_movimiento, concepto,
         monto, saldo_anterior, saldo_posterior, foto_ruta, estado, fecha_registro, usuario_registro, created_at, updated_at)
  VALUES (u.condominio_id, u.id, v_med, v_lid, p_periodo, p_fecha::timestamptz, 'CONSUMO',
         'Consumo GLP ' || p_periodo || ' (' || v_gal || ' gal)', v_monto, v_ant, v_ant - CASE WHEN v_estado = 'ACTIVO' THEN v_monto ELSE 0 END, nullif(p_foto,''), v_estado,
         now(), private.nombre_actor(), now(), now())
  RETURNING id INTO v_mid;
  v_anio := to_char(p_fecha, 'YYYY');
  PERFORM pg_advisory_xact_lock(hashtext('glp_factura_' || v_anio));
  SELECT coalesce(max(substring(f.numero_factura FROM '^GLP-FAC-' || v_anio || '-([0-9]+)$')::int), 0) + 1 INTO n FROM public.glp_facturas f;
  v_num := 'GLP-FAC-' || v_anio || '-' || lpad(n::text, 4, '0');
  INSERT INTO public.glp_facturas (condominio_id, numero_factura, unidad_id, movimiento_id, lectura_id, periodo, fecha_factura, monto_factura,
         estado, fecha_registro, usuario_registro, created_at, updated_at)
  VALUES (u.condominio_id, v_num, u.id, v_mid, v_lid, p_periodo, now(), v_monto, v_estado, now(), private.nombre_actor(), now(), now())
  RETURNING id, estado_aprobacion INTO v_fid, v_aprobacion;
  PERFORM private.log_portal('GLP', 'glp_lecturas', v_lid, NULL, NULL, v_num, 'Creación', 'Consumo GLP ' || u.codigo || ' ' || p_periodo || ' RD$' || v_monto);
  RETURN jsonb_build_object('lectura_id', v_lid, 'movimiento_id', v_mid, 'factura', v_num, 'm3', v_m3, 'galones', v_gal,
         'precio', v_precio, 'monto', v_monto, 'saldo', private.glp_saldo(p_unidad_id),
         'estado_aprobacion', v_aprobacion);
END $function$;

CREATE OR REPLACE FUNCTION public.fn_aprobaciones_bandeja(p_condominio_id bigint)
 RETURNS TABLE(modulo text, registro_id bigint, referencia text, descripcion text, monto numeric, estado text, sometido_por text, sometido_at timestamp with time zone, motivo_rechazo text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_ceo boolean := private.es_ceo(); v_uid uuid := (SELECT auth.uid());
BEGIN
  IF NOT private.es_staff() THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT * FROM (
    SELECT 'Facturas'::text, f.id, f.no_factura, coalesce(f.tipo_factura, '') || ' | ' || coalesce(f.concepto, ''), f.monto,
           f.estado_aprobacion, private.nombre_auth(f.sometido_por), f.sometido_at, f.motivo_rechazo
      FROM public.facturas f WHERE f.condominio_id = p_condominio_id
       AND ((v_ceo AND f.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND f.sometido_por = v_uid))
    UNION ALL
    SELECT 'Pagos', x.id, x.codigo, x.tipo_movimiento || ' | ' || coalesce(x.recibido_de, '') || ' | ' || coalesce(x.metodo, ''), x.monto,
           x.estado_aprobacion, private.nombre_auth(x.sometido_por), x.sometido_at, x.motivo_rechazo
      FROM public.pagos x WHERE x.condominio_id = p_condominio_id
       AND ((v_ceo AND x.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND x.sometido_por = v_uid))
    UNION ALL
    SELECT 'Gastos', g.id, g.codigo, coalesce(g.categoria, '') || ' | ' || coalesce(g.descripcion, ''), g.monto,
           g.estado_aprobacion, private.nombre_auth(g.sometido_por), g.sometido_at, g.motivo_rechazo
      FROM public.gastos g WHERE g.condominio_id = p_condominio_id
       AND ((v_ceo AND g.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND g.sometido_por = v_uid))
    UNION ALL
    SELECT 'PagosProveedor', pg.id, coalesce(g.codigo, '') || ' / ' || coalesce(pg.referencia, ''), coalesce(pg.metodo_pago, '') || ' | ' || coalesce(pg.nota, ''), pg.monto,
           pg.estado_aprobacion, private.nombre_auth(pg.sometido_por), pg.sometido_at, pg.motivo_rechazo
      FROM public.pagos_gastos pg LEFT JOIN public.gastos g ON g.id = pg.gasto_id WHERE pg.condominio_id = p_condominio_id
       AND ((v_ceo AND pg.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND pg.sometido_por = v_uid))
    UNION ALL
    SELECT 'Proveedores', pr.id, pr.codigo, coalesce(pr.nombre_comercial, pr.nombre), NULL::numeric,
           pr.estado_aprobacion, private.nombre_auth(pr.sometido_por), pr.sometido_at, pr.motivo_rechazo
      FROM public.proveedores pr
     WHERE ((v_ceo AND pr.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND pr.sometido_por = v_uid))
    UNION ALL
    SELECT 'GLP', f.id, f.numero_factura, 'Consumo GLP ' || coalesce(f.periodo, ''), f.monto_factura,
           f.estado_aprobacion, private.nombre_auth(f.sometido_por), f.sometido_at, f.motivo_rechazo
      FROM public.glp_facturas f WHERE f.condominio_id = p_condominio_id
       AND upper(coalesce(f.estado, 'ACTIVO')) <> 'ANULADO'
       AND ((v_ceo AND f.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND f.sometido_por = v_uid))
    UNION ALL
    SELECT 'Solicitud', s.id, s.tipo_accion || ' ' || s.tabla || ' #' || s.registro_id,
           coalesce(s.campo, '') || ': ' || coalesce(s.valor_anterior, 'NULL') || ' -> ' || coalesce(s.valor_nuevo, 'NULL') || coalesce(' | ' || s.motivo_solicitud, ''),
           NULL::numeric, s.estado_solicitud, coalesce(s.usuario_solicitante, private.nombre_auth(s.solicitante_auth)),
           coalesce(s.fecha_solicitud, s.created_at), s.comentario_ceo
      FROM public.solicitudes_autorizacion s
     WHERE s.modulo <> 'Residentes' AND (s.condominio_id IS NULL OR s.condominio_id = p_condominio_id)
       AND ((v_ceo AND s.estado_solicitud IN ('Pendiente','Sometido','En proceso'))
         OR (NOT v_ceo AND s.solicitante_auth = v_uid))
  ) b
  ORDER BY 8 DESC NULLS LAST;
END $function$;

CREATE OR REPLACE FUNCTION public.fn_aprobacion_revisar(p_modulo text, p_id bigint, p_estado text, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tabla text; v_actual text; v_uid uuid := (SELECT auth.uid()); s public.solicitudes_autorizacion;
  v_dep text; v_fid bigint; v_valor_hoy text;
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO aprueba o rechaza' USING ERRCODE = '42501'; END IF;
  IF p_estado NOT IN ('En proceso','Aprobado','Rechazado') THEN RAISE EXCEPTION 'Estado no valido'; END IF;
  IF p_estado = 'Rechazado' AND nullif(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo del rechazo'; END IF;

  IF p_modulo = 'Solicitud' THEN
    SELECT * INTO s FROM public.solicitudes_autorizacion x WHERE x.id = p_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud no encontrada'; END IF;
    IF s.estado_solicitud NOT IN ('Pendiente','Sometido','En proceso') THEN RAISE EXCEPTION 'La solicitud ya fue procesada'; END IF;
    IF p_estado = 'Aprobado' THEN
      IF s.tipo_accion = 'Anulación' THEN
        CASE s.tabla
          WHEN 'facturas' THEN PERFORM public.fn_factura_anular(s.registro_id, s.motivo_solicitud);
          WHEN 'pagos'    THEN PERFORM public.fn_pago_anular(s.registro_id, s.motivo_solicitud);
          WHEN 'gastos'   THEN PERFORM public.axi_gasto_eliminar(s.registro_id);
          ELSE RAISE EXCEPTION 'Anulacion no soportada para %', s.tabla;
        END CASE;
      ELSE
        IF s.tabla NOT IN ('proveedores','gastos','pagos','pagos_gastos','propietarios','inquilinos') THEN RAISE EXCEPTION 'Tabla no soportada'; END IF;
        EXECUTE format('SELECT (%I)::text FROM public.%I WHERE id = $1', s.campo, s.tabla) INTO v_valor_hoy USING s.registro_id;
        IF v_valor_hoy IS DISTINCT FROM s.valor_anterior THEN
          RAISE EXCEPTION 'El valor actual (%) ya no coincide con el anterior (%)', v_valor_hoy, s.valor_anterior; END IF;
        EXECUTE format('UPDATE public.%I SET %I = %L, updated_at = now() WHERE id = $1', s.tabla, s.campo, s.valor_nuevo) USING s.registro_id;
        IF s.tabla = 'gastos' THEN PERFORM public.axi_libro_registrar_gasto(s.registro_id); END IF;
        IF s.tabla = 'pagos' THEN
          PERFORM public.fn_pago_postear_libro(s.registro_id);
          SELECT factura_id INTO v_fid FROM public.pagos WHERE id = s.registro_id;
          PERFORM public.fn_factura_recalcular(v_fid);
        END IF;
      END IF;
    END IF;
    UPDATE public.solicitudes_autorizacion SET estado_solicitud = p_estado, revisado_por = v_uid,
      autorizado_por_usuario_id = private.mi_usuario_id(), autorizado_por_nombre = private.nombre_auth(v_uid),
      comentario_ceo = nullif(btrim(p_motivo), ''), fecha_autorizacion = now(),
      aplicado = (p_estado = 'Aprobado'), fecha_aplicacion = CASE WHEN p_estado = 'Aprobado' THEN now() END, updated_at = now()
     WHERE id = s.id;
    PERFORM private.log_portal(s.modulo, s.tabla, s.registro_id, s.campo, s.valor_anterior, s.valor_nuevo,
      CASE p_estado WHEN 'Aprobado' THEN 'Autorización' WHEN 'Rechazado' THEN 'Rechazo' ELSE 'Modificación' END,
      'Solicitud ' || lower(p_estado) || ': ' || s.tipo_accion || ' ' || s.tabla || ' #' || s.registro_id || coalesce(' | ' || p_motivo, ''));
    RETURN jsonb_build_object('modulo', p_modulo, 'id', p_id, 'estado', p_estado);
  END IF;

  v_tabla := CASE p_modulo WHEN 'Facturas' THEN 'facturas' WHEN 'Pagos' THEN 'pagos' WHEN 'Gastos' THEN 'gastos'
                           WHEN 'PagosProveedor' THEN 'pagos_gastos' WHEN 'Proveedores' THEN 'proveedores'
                           WHEN 'GLP' THEN 'glp_facturas' END;
  IF v_tabla IS NULL THEN RAISE EXCEPTION 'Modulo no valido'; END IF;
  IF v_tabla = 'glp_facturas' THEN
    SELECT f.unidad_id INTO v_fid FROM public.glp_facturas f WHERE f.id = p_id;
    IF v_fid IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || v_fid));
    END IF;
  END IF;
  EXECUTE format('SELECT estado_aprobacion FROM public.%I WHERE id = $1 FOR UPDATE', v_tabla) INTO v_actual USING p_id;
  IF v_actual IS NULL THEN RAISE EXCEPTION 'Registro no encontrado'; END IF;
  IF v_actual NOT IN ('Sometido','En proceso') THEN RAISE EXCEPTION 'El registro ya fue revisado (estado: %)', v_actual; END IF;

  IF p_estado = 'Aprobado' THEN
    IF v_tabla = 'pagos' THEN
      SELECT f.estado_aprobacion INTO v_dep FROM public.pagos x JOIN public.facturas f ON f.id = x.factura_id WHERE x.id = p_id;
      IF v_dep <> 'Aprobado' THEN RAISE EXCEPTION 'Primero apruebe la factura del pago'; END IF;
    ELSIF v_tabla = 'gastos' THEN
      SELECT pr.estado_aprobacion INTO v_dep FROM public.gastos g JOIN public.proveedores pr ON pr.id = g.proveedor_id WHERE g.id = p_id;
      IF v_dep <> 'Aprobado' THEN RAISE EXCEPTION 'Primero apruebe el proveedor del gasto'; END IF;
    ELSIF v_tabla = 'pagos_gastos' THEN
      SELECT g.estado_aprobacion INTO v_dep FROM public.pagos_gastos x JOIN public.gastos g ON g.id = x.gasto_id WHERE x.id = p_id;
      IF v_dep <> 'Aprobado' THEN RAISE EXCEPTION 'Primero apruebe el gasto de este pago'; END IF;
    END IF;
  END IF;

  EXECUTE format('UPDATE public.%I SET estado_aprobacion = $1, revisado_por = $2, revisado_at = now(),
                  motivo_rechazo = $3, updated_at = now() WHERE id = $4', v_tabla)
    USING p_estado, v_uid, CASE WHEN p_estado = 'Rechazado' THEN btrim(p_motivo) END, p_id;

  IF p_estado = 'Aprobado' THEN
    IF v_tabla = 'pagos' THEN
      UPDATE public.pagos SET validado = true, fecha_validacion = private.hoy() WHERE id = p_id;
      PERFORM public.fn_pago_postear_libro(p_id);
      SELECT factura_id INTO v_fid FROM public.pagos WHERE id = p_id;
      PERFORM public.fn_factura_recalcular(v_fid);
      UPDATE public.pagos x SET estado = f.estado FROM public.facturas f
       WHERE x.id = p_id AND f.id = x.factura_id AND coalesce(x.tipo_movimiento, 'Ingreso recibido') = 'Ingreso recibido';
    ELSIF v_tabla = 'gastos' THEN
      PERFORM public.axi_libro_registrar_gasto(p_id);
    ELSIF v_tabla = 'facturas' THEN
      PERFORM public.fn_factura_recalcular(p_id);
    END IF;
  END IF;

  PERFORM private.log_portal(p_modulo, v_tabla, p_id, 'estado_aprobacion', v_actual, p_estado,
    CASE p_estado WHEN 'Aprobado' THEN 'Autorización' WHEN 'Rechazado' THEN 'Rechazo' ELSE 'Modificación' END,
    p_modulo || ' #' || p_id || ' ' || lower(p_estado) || coalesce(' | ' || p_motivo, ''));
  RETURN jsonb_build_object('modulo', p_modulo, 'id', p_id, 'estado', p_estado);
END $function$;

CREATE OR REPLACE FUNCTION public.portal_mi_glp(p_unidad_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
                    AND upper(coalesce(l.estado, 'ACTIVO')) = 'ACTIVO' AND coalesce(l.monto_consumo, 0) >= 0));
END $function$;

CREATE OR REPLACE FUNCTION public.fn_glp_anular(p_movimiento_id bigint, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE x public.glp_movimientos; v_unidad bigint;
BEGIN
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO anula movimientos de GLP' USING ERRCODE = '42501'; END IF;
  SELECT m.unidad_id INTO v_unidad FROM public.glp_movimientos m WHERE m.id = p_movimiento_id;
  IF v_unidad IS NULL THEN RAISE EXCEPTION 'Movimiento no encontrado'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || v_unidad));
  SELECT * INTO x FROM public.glp_movimientos m WHERE m.id = p_movimiento_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Movimiento no encontrado'; END IF;
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO anula movimientos de GLP' USING ERRCODE = '42501'; END IF;
  IF upper(x.estado) = 'ANULADO' THEN RAISE EXCEPTION 'El movimiento ya esta anulado'; END IF;
  IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique el motivo'; END IF;
  UPDATE public.glp_movimientos SET estado = 'ANULADO', fecha_anulacion = now(), usuario_anulacion = private.nombre_actor(),
         motivo_anulacion = btrim(p_motivo), updated_at = now() WHERE id = x.id;
  IF x.lectura_id IS NOT NULL THEN
    UPDATE public.glp_lecturas SET estado = 'ANULADO', fecha_anulacion = now(), usuario_anulacion = private.nombre_actor(),
           motivo_anulacion = btrim(p_motivo), updated_at = now() WHERE id = x.lectura_id;
  END IF;
  UPDATE public.glp_facturas SET estado = 'ANULADO', updated_at = now() WHERE movimiento_id = x.id AND upper(estado) <> 'ANULADO';
  UPDATE public.libro_financiero SET entrada = 0, balance_movimiento = 0, concepto = '[ANULADO] ' || concepto, updated_at = now()
   WHERE codigo_pago = 'GLP-DEP-' || x.id AND concepto NOT LIKE '[ANULADO]%';
  PERFORM private.log_portal('GLP', 'glp_movimientos', x.id, 'estado', x.estado, 'ANULADO', 'Anulación', 'Movimiento GLP anulado: ' || btrim(p_motivo));
  RETURN jsonb_build_object('id', x.id, 'saldo', private.glp_saldo(x.unidad_id));
END $function$;

CREATE OR REPLACE FUNCTION private.trg_glp_aprobacion_efectos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_mov public.glp_movimientos; v_estado text;
BEGIN
  IF NEW.estado_aprobacion IS NOT DISTINCT FROM OLD.estado_aprobacion
     OR NEW.estado_aprobacion NOT IN ('Aprobado','Rechazado') THEN RETURN NEW; END IF;
  IF NOT private.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO revisa consumos de GLP' USING ERRCODE = '42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || NEW.unidad_id));
  SELECT * INTO v_mov FROM public.glp_movimientos WHERE id = NEW.movimiento_id FOR UPDATE;
  IF NOT FOUND OR v_mov.unidad_id IS DISTINCT FROM NEW.unidad_id
     OR v_mov.lectura_id IS DISTINCT FROM NEW.lectura_id
     OR upper(v_mov.tipo_movimiento) <> 'CONSUMO' THEN
    RAISE EXCEPTION 'Factura GLP sin consumo y lectura vinculados correctamente'; END IF;
  IF upper(v_mov.estado) = 'ANULADO' THEN RAISE EXCEPTION 'No se puede revisar un consumo anulado'; END IF;
  v_estado := CASE WHEN NEW.estado_aprobacion = 'Aprobado' THEN 'ACTIVO' ELSE 'RECHAZADO' END;
  UPDATE public.glp_movimientos SET estado = v_estado, updated_at = now() WHERE id = v_mov.id;
  UPDATE public.glp_lecturas SET estado = v_estado, updated_at = now() WHERE id = v_mov.lectura_id;
  UPDATE public.glp_facturas SET estado = v_estado, updated_at = now() WHERE id = NEW.id;
  -- Mantener el orden de registro usado por los saldos anteriores/posteriores.
  -- Solo se actualizan los saldos del movimiento revisado y los posteriores.
  WITH saldos AS (
    SELECT id, sum(CASE WHEN upper(tipo_movimiento) = 'DEPOSITO' THEN monto ELSE -monto END)
      OVER (ORDER BY id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS posterior,
      CASE WHEN upper(tipo_movimiento) = 'DEPOSITO' THEN monto ELSE -monto END AS delta
    FROM public.glp_movimientos WHERE unidad_id = NEW.unidad_id AND upper(estado) = 'ACTIVO'
  )
  UPDATE public.glp_movimientos m SET saldo_anterior = s.posterior - s.delta,
         saldo_posterior = s.posterior, updated_at = now()
  FROM saldos s WHERE m.id = s.id AND m.id >= v_mov.id
    AND (m.saldo_anterior IS DISTINCT FROM s.posterior - s.delta OR m.saldo_posterior IS DISTINCT FROM s.posterior);
  RETURN NEW;
END $function$;
REVOKE ALL ON FUNCTION private.trg_glp_aprobacion_efectos() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_glp_aprobacion_efectos AFTER UPDATE OF estado_aprobacion ON public.glp_facturas
FOR EACH ROW EXECUTE FUNCTION private.trg_glp_aprobacion_efectos();
