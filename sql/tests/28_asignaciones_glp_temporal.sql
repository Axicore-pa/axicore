-- Pruebas con tablas temporales y ROLLBACK. No insertar en tablas de producción.
-- Funciones copiadas al espacio temporal; autenticación y log simulados.
BEGIN;
SET LOCAL timezone='America/Santo_Domingo';
CREATE TEMP TABLE libro_financiero (LIKE public.libro_financiero INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE glp_precios (LIKE public.glp_precios INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE accesos (LIKE public.accesos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE unidades (LIKE public.unidades INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE unidad_propietarios (LIKE public.unidad_propietarios INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE administradores (LIKE public.administradores INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE unidad_administradores (LIKE public.unidad_administradores INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE glp_facturas (LIKE public.glp_facturas INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE glp_lecturas (LIKE public.glp_lecturas INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE glp_movimientos (LIKE public.glp_movimientos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE glp_medidores (LIKE public.glp_medidores INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE condominios (LIKE public.condominios INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE propietarios (LIKE public.propietarios INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE inquilinos (LIKE public.inquilinos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE solicitudes_autorizacion (LIKE public.solicitudes_autorizacion INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE facturas (LIKE public.facturas INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE pagos (LIKE public.pagos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE gastos (LIKE public.gastos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE pagos_gastos (LIKE public.pagos_gastos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE proveedores (LIKE public.proveedores INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
DO $$DECLARE r record; BEGIN
 FOR r IN SELECT c.relname, a.attidentity FROM pg_class c JOIN pg_attribute a ON a.attrelid=c.oid AND a.attname='id'
  WHERE c.relnamespace=pg_my_temp_schema() AND c.relkind='r'
 LOOP
  IF r.attidentity='' THEN
   EXECUTE format('CREATE TEMP SEQUENCE %I START 10000',r.relname||'_test_id');
   EXECUTE format('ALTER TABLE pg_temp.%I ALTER COLUMN id SET DEFAULT nextval(%L)',r.relname,'pg_temp.'||r.relname||'_test_id');
  ELSE EXECUTE format('ALTER TABLE pg_temp.%I ALTER COLUMN id RESTART WITH 10000',r.relname);
  END IF;
 END LOOP;
END$$;

CREATE FUNCTION pg_temp.test_uid() RETURNS uuid LANGUAGE sql AS $$SELECT '11111111-1111-4111-8111-111111111111'::uuid$$;
CREATE FUNCTION pg_temp.es_ceo() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('axitest.role',true)='CEO'$$;
CREATE FUNCTION pg_temp.es_staff() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('axitest.role',true) IN ('CEO','Asistente')$$;
CREATE FUNCTION pg_temp.aal2_ok() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('axitest.aal',true)='aal2'$$;
CREATE FUNCTION pg_temp.staff_condos(text,text) RETURNS bigint[] LANGUAGE sql AS $$SELECT ARRAY[900001::bigint]$$;
CREATE FUNCTION pg_temp.glp_puede(bigint,text) RETURNS boolean LANGUAGE sql AS $$SELECT pg_temp.es_staff()$$;
CREATE FUNCTION pg_temp.nombre_actor() RETURNS text LANGUAGE sql AS $$SELECT 'TEST'::text$$;
CREATE FUNCTION pg_temp.nombre_auth(uuid) RETURNS text LANGUAGE sql AS $$SELECT 'TEST'::text$$;
CREATE FUNCTION pg_temp.unidades_inquilino() RETURNS bigint[] LANGUAGE sql AS $$SELECT '{}'::bigint[]$$;
CREATE FUNCTION pg_temp.glp_precio_vigente(bigint,date DEFAULT current_date) RETURNS numeric LANGUAGE sql AS $$SELECT 10::numeric$$;
CREATE FUNCTION pg_temp.check_test(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'TEST FAILED: %',label; END IF; END$$;

CREATE OR REPLACE FUNCTION pg_temp.glp_saldo(p_unidad bigint)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT coalesce(sum(CASE WHEN upper(x.tipo_movimiento) = 'DEPOSITO' THEN x.monto ELSE -x.monto END), 0)
    FROM pg_temp.glp_movimientos x WHERE x.unidad_id = p_unidad AND upper(x.estado) = 'ACTIVO'
$function$;

CREATE OR REPLACE FUNCTION pg_temp.glp_lectura_anterior(p_unidad bigint)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT coalesce(
    (SELECT l.lectura_actual FROM pg_temp.glp_lecturas l WHERE l.unidad_id = p_unidad AND upper(coalesce(l.estado,'ACTIVO')) = 'ACTIVO'
        AND l.lectura_actual IS NOT NULL AND coalesce(l.monto_consumo,0) >= 0 ORDER BY l.fecha_lectura DESC, l.id DESC LIMIT 1),
    (SELECT m.lectura_inicial FROM pg_temp.glp_medidores m WHERE m.unidad_id = p_unidad ORDER BY m.id DESC LIMIT 1), 0)
$function$;

CREATE OR REPLACE FUNCTION pg_temp.trg_aprobacion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_uid uuid := (SELECT pg_temp.test_uid());
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF v_uid IS NULL THEN RETURN NEW; END IF;
    NEW.sometido_por := v_uid;
    NEW.sometido_at  := now();
    NEW.motivo_rechazo := NULL;
    IF pg_temp.es_ceo() THEN
      NEW.estado_aprobacion := 'Aprobado';
      NEW.revisado_por := v_uid;
      NEW.revisado_at  := now();
    ELSE
      NEW.estado_aprobacion := 'Sometido';
      NEW.revisado_por := NULL;
      NEW.revisado_at  := NULL;
    END IF;
  ELSIF v_uid IS NOT NULL AND NOT pg_temp.es_ceo()
        AND (NEW.estado_aprobacion IS DISTINCT FROM OLD.estado_aprobacion
             OR NEW.revisado_por IS DISTINCT FROM OLD.revisado_por) THEN
    RAISE EXCEPTION 'Solo el CEO puede cambiar el estado de aprobacion' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION pg_temp.unidades_propias()
 RETURNS bigint[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT coalesce(array_agg(DISTINCT x.id), '{}'::bigint[]) FROM (
    SELECT u.id FROM pg_temp.accesos a
    JOIN pg_temp.unidades u ON u.condominio_id = a.condominio_id
     AND (u.propietario_id = a.propietario_id
          OR EXISTS (SELECT 1 FROM pg_temp.unidad_propietarios up
                     WHERE up.unidad_id = u.id AND up.propietario_id = a.propietario_id AND up.fecha_fin IS NULL
                       AND (up.fecha_inicio IS NULL OR up.fecha_inicio <= now())))
    WHERE a.auth_user_id = (SELECT pg_temp.test_uid()) AND a.activo AND a.rol = 'Propietario'
    UNION
    SELECT ua.unidad_id FROM pg_temp.accesos a
    JOIN pg_temp.administradores ad ON ad.id = a.administrador_id AND ad.estado = 'Activo'
    JOIN pg_temp.unidad_administradores ua ON ua.administrador_id = a.administrador_id AND ua.fecha_fin IS NULL
      AND ua.fecha_inicio <= (now() AT TIME ZONE 'America/Santo_Domingo')::date
    WHERE a.auth_user_id = (SELECT pg_temp.test_uid()) AND a.activo AND a.rol = 'Administrador' AND pg_temp.aal2_ok()) x $function$;

CREATE OR REPLACE FUNCTION pg_temp.fn_glp_registrar_consumo(p_unidad_id bigint, p_periodo text, p_fecha date, p_lectura_actual numeric, p_foto text DEFAULT NULL::text, p_precio numeric DEFAULT NULL::numeric, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u record; v_med bigint; v_antl numeric; v_m3 numeric; v_gal numeric; v_precio numeric; v_monto numeric;
        v_ant numeric; v_lid bigint; v_mid bigint; v_fid bigint; v_num text; v_anio text; n int; v_factor numeric; v_estado text; v_aprobacion text;
BEGIN
  SELECT x.id, x.codigo, x.condominio_id, c.glp_factor_m3_galon AS factor INTO u
    FROM pg_temp.unidades x JOIN pg_temp.condominios c ON c.id = x.condominio_id WHERE x.id = p_unidad_id;
  IF u.id IS NULL THEN RAISE EXCEPTION 'Unidad no encontrada'; END IF;
  IF NOT pg_temp.glp_puede(u.condominio_id, 'crear') THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  IF p_periodo IS NULL OR p_periodo !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' THEN RAISE EXCEPTION 'Periodo no valido (AAAA-MM)'; END IF;
  IF p_fecha IS NULL OR p_fecha > (now() AT TIME ZONE 'America/Santo_Domingo')::date + 1 THEN RAISE EXCEPTION 'Fecha de lectura no valida'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || p_unidad_id));
  IF EXISTS (SELECT 1 FROM pg_temp.glp_facturas f
              WHERE f.unidad_id = p_unidad_id AND f.estado_aprobacion IN ('Sometido','En proceso')
                AND upper(coalesce(f.estado, 'ACTIVO')) <> 'ANULADO') THEN
    RAISE EXCEPTION 'Primero apruebe o rechace el consumo pendiente de esta unidad'; END IF;
  v_estado := CASE WHEN pg_temp.es_ceo() THEN 'ACTIVO' ELSE 'PENDIENTE' END;
  SELECT m.id INTO v_med FROM pg_temp.glp_medidores m WHERE m.unidad_id = p_unidad_id ORDER BY m.id DESC LIMIT 1;
  IF v_med IS NULL THEN RAISE EXCEPTION 'La unidad no tiene medidor registrado'; END IF;
  IF EXISTS (SELECT 1 FROM pg_temp.glp_lecturas l WHERE l.unidad_id = p_unidad_id AND l.periodo = p_periodo
               AND upper(coalesce(l.estado,'ACTIVO')) = 'ACTIVO' AND coalesce(l.monto_consumo,0) >= 0) THEN
    RAISE EXCEPTION 'Ya existe un consumo activo para el periodo % de esta unidad (anulelo primero si debe corregirlo)', p_periodo; END IF;
  v_antl := pg_temp.glp_lectura_anterior(p_unidad_id);
  IF p_lectura_actual IS NULL OR p_lectura_actual < v_antl THEN
    RAISE EXCEPTION 'La lectura actual (%) no puede ser menor que la anterior (%)', p_lectura_actual, v_antl; END IF;
  v_precio := coalesce(p_precio, pg_temp.glp_precio_vigente(u.condominio_id, p_fecha));
  IF v_precio IS NULL OR v_precio <= 0 THEN RAISE EXCEPTION 'No hay precio de GLP vigente; registre el precio primero'; END IF;
  v_factor := coalesce(u.factor, 1.22);
  v_m3 := round(p_lectura_actual - v_antl, 4);
  v_gal := round(v_m3 * v_factor, 3);
  v_monto := round(v_m3 * v_factor * v_precio, 2);   -- igual que Access: galones sin redondear x precio
  v_ant := pg_temp.glp_saldo(p_unidad_id);
  INSERT INTO pg_temp.glp_lecturas (condominio_id, medidor_id, unidad_id, periodo, fecha_lectura, lectura_anterior, lectura_actual,
         consumo, precio_unitario, fecha_revision_precio, monto_consumo, foto_ruta, observaciones, fecha_registro, consumo_m3, estado, created_at, updated_at)
  VALUES (u.condominio_id, v_med, u.id, p_periodo, p_fecha::timestamptz, v_antl, p_lectura_actual, v_gal, v_precio, now(), v_monto,
         nullif(p_foto,''), nullif(btrim(p_observaciones),''), now(), v_m3, v_estado, now(), now())
  RETURNING id INTO v_lid;
  INSERT INTO pg_temp.glp_movimientos (condominio_id, unidad_id, medidor_id, lectura_id, periodo, fecha_movimiento, tipo_movimiento, concepto,
         monto, saldo_anterior, saldo_posterior, foto_ruta, estado, fecha_registro, usuario_registro, created_at, updated_at)
  VALUES (u.condominio_id, u.id, v_med, v_lid, p_periodo, p_fecha::timestamptz, 'CONSUMO',
         'Consumo GLP ' || p_periodo || ' (' || v_gal || ' gal)', v_monto, v_ant, v_ant - CASE WHEN v_estado = 'ACTIVO' THEN v_monto ELSE 0 END, nullif(p_foto,''), v_estado,
         now(), pg_temp.nombre_actor(), now(), now())
  RETURNING id INTO v_mid;
  v_anio := to_char(p_fecha, 'YYYY');
  PERFORM pg_advisory_xact_lock(hashtext('glp_factura_' || v_anio));
  SELECT coalesce(max(substring(f.numero_factura FROM '^GLP-FAC-' || v_anio || '-([0-9]+)$')::int), 0) + 1 INTO n FROM pg_temp.glp_facturas f;
  v_num := 'GLP-FAC-' || v_anio || '-' || lpad(n::text, 4, '0');
  INSERT INTO pg_temp.glp_facturas (condominio_id, numero_factura, unidad_id, movimiento_id, lectura_id, periodo, fecha_factura, monto_factura,
         estado, fecha_registro, usuario_registro, created_at, updated_at)
  VALUES (u.condominio_id, v_num, u.id, v_mid, v_lid, p_periodo, now(), v_monto, v_estado, now(), pg_temp.nombre_actor(), now(), now())
  RETURNING id, estado_aprobacion INTO v_fid, v_aprobacion;
  PERFORM 1;
  RETURN jsonb_build_object('lectura_id', v_lid, 'movimiento_id', v_mid, 'factura', v_num, 'm3', v_m3, 'galones', v_gal,
         'precio', v_precio, 'monto', v_monto, 'saldo', pg_temp.glp_saldo(p_unidad_id),
         'estado_aprobacion', v_aprobacion);
END $function$;

CREATE OR REPLACE FUNCTION pg_temp.fn_aprobaciones_bandeja(p_condominio_id bigint)
 RETURNS TABLE(modulo text, registro_id bigint, referencia text, descripcion text, monto numeric, estado text, sometido_por text, sometido_at timestamp with time zone, motivo_rechazo text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_ceo boolean := pg_temp.es_ceo(); v_uid uuid := (SELECT pg_temp.test_uid());
BEGIN
  IF NOT pg_temp.es_staff() THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT * FROM (
    SELECT 'Facturas'::text, f.id, f.no_factura, coalesce(f.tipo_factura, '') || ' | ' || coalesce(f.concepto, ''), f.monto,
           f.estado_aprobacion, pg_temp.nombre_auth(f.sometido_por), f.sometido_at, f.motivo_rechazo
      FROM pg_temp.facturas f WHERE f.condominio_id = p_condominio_id
       AND ((v_ceo AND f.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND f.sometido_por = v_uid))
    UNION ALL
    SELECT 'Pagos', x.id, x.codigo, x.tipo_movimiento || ' | ' || coalesce(x.recibido_de, '') || ' | ' || coalesce(x.metodo, ''), x.monto,
           x.estado_aprobacion, pg_temp.nombre_auth(x.sometido_por), x.sometido_at, x.motivo_rechazo
      FROM pg_temp.pagos x WHERE x.condominio_id = p_condominio_id
       AND ((v_ceo AND x.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND x.sometido_por = v_uid))
    UNION ALL
    SELECT 'Gastos', g.id, g.codigo, coalesce(g.categoria, '') || ' | ' || coalesce(g.descripcion, ''), g.monto,
           g.estado_aprobacion, pg_temp.nombre_auth(g.sometido_por), g.sometido_at, g.motivo_rechazo
      FROM pg_temp.gastos g WHERE g.condominio_id = p_condominio_id
       AND ((v_ceo AND g.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND g.sometido_por = v_uid))
    UNION ALL
    SELECT 'PagosProveedor', pg.id, coalesce(g.codigo, '') || ' / ' || coalesce(pg.referencia, ''), coalesce(pg.metodo_pago, '') || ' | ' || coalesce(pg.nota, ''), pg.monto,
           pg.estado_aprobacion, pg_temp.nombre_auth(pg.sometido_por), pg.sometido_at, pg.motivo_rechazo
      FROM pg_temp.pagos_gastos pg LEFT JOIN pg_temp.gastos g ON g.id = pg.gasto_id WHERE pg.condominio_id = p_condominio_id
       AND ((v_ceo AND pg.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND pg.sometido_por = v_uid))
    UNION ALL
    SELECT 'Proveedores', pr.id, pr.codigo, coalesce(pr.nombre_comercial, pr.nombre), NULL::numeric,
           pr.estado_aprobacion, pg_temp.nombre_auth(pr.sometido_por), pr.sometido_at, pr.motivo_rechazo
      FROM pg_temp.proveedores pr
     WHERE ((v_ceo AND pr.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND pr.sometido_por = v_uid))
    UNION ALL
    SELECT 'GLP', f.id, f.numero_factura, 'Consumo GLP ' || coalesce(f.periodo, ''), f.monto_factura,
           f.estado_aprobacion, pg_temp.nombre_auth(f.sometido_por), f.sometido_at, f.motivo_rechazo
      FROM pg_temp.glp_facturas f WHERE f.condominio_id = p_condominio_id
       AND upper(coalesce(f.estado, 'ACTIVO')) <> 'ANULADO'
       AND ((v_ceo AND f.estado_aprobacion IN ('Sometido','En proceso')) OR (NOT v_ceo AND f.sometido_por = v_uid))
    UNION ALL
    SELECT 'Solicitud', s.id, s.tipo_accion || ' ' || s.tabla || ' #' || s.registro_id,
           coalesce(s.campo, '') || ': ' || coalesce(s.valor_anterior, 'NULL') || ' -> ' || coalesce(s.valor_nuevo, 'NULL') || coalesce(' | ' || s.motivo_solicitud, ''),
           NULL::numeric, s.estado_solicitud, coalesce(s.usuario_solicitante, pg_temp.nombre_auth(s.solicitante_auth)),
           coalesce(s.fecha_solicitud, s.created_at), s.comentario_ceo
      FROM pg_temp.solicitudes_autorizacion s
     WHERE s.modulo <> 'Residentes' AND (s.condominio_id IS NULL OR s.condominio_id = p_condominio_id)
       AND ((v_ceo AND s.estado_solicitud IN ('Pendiente','Sometido','En proceso'))
         OR (NOT v_ceo AND s.solicitante_auth = v_uid))
  ) b
  ORDER BY 8 DESC NULLS LAST;
END $function$;

CREATE OR REPLACE FUNCTION pg_temp.fn_aprobacion_revisar(p_modulo text, p_id bigint, p_estado text, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tabla text; v_actual text; v_uid uuid := (SELECT pg_temp.test_uid()); s pg_temp.solicitudes_autorizacion;
  v_dep text; v_fid bigint; v_valor_hoy text;
BEGIN
  IF NOT pg_temp.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO aprueba o rechaza' USING ERRCODE = '42501'; END IF;
  IF p_estado NOT IN ('En proceso','Aprobado','Rechazado') THEN RAISE EXCEPTION 'Estado no valido'; END IF;
  IF p_estado = 'Rechazado' AND nullif(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo del rechazo'; END IF;

  IF p_modulo = 'Solicitud' THEN
    SELECT * INTO s FROM pg_temp.solicitudes_autorizacion x WHERE x.id = p_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud no encontrada'; END IF;
    IF s.estado_solicitud NOT IN ('Pendiente','Sometido','En proceso') THEN RAISE EXCEPTION 'La solicitud ya fue procesada'; END IF;
    IF p_estado = 'Aprobado' THEN
      IF s.tipo_accion = 'Anulación' THEN
        CASE s.tabla
          WHEN 'facturas' THEN PERFORM pg_temp.fn_factura_anular(s.registro_id, s.motivo_solicitud);
          WHEN 'pagos'    THEN PERFORM pg_temp.fn_pago_anular(s.registro_id, s.motivo_solicitud);
          WHEN 'gastos'   THEN PERFORM pg_temp.axi_gasto_eliminar(s.registro_id);
          ELSE RAISE EXCEPTION 'Anulacion no soportada para %', s.tabla;
        END CASE;
      ELSE
        IF s.tabla NOT IN ('proveedores','gastos','pagos','pagos_gastos','propietarios','inquilinos') THEN RAISE EXCEPTION 'Tabla no soportada'; END IF;
        EXECUTE format('SELECT (%I)::text FROM pg_temp.%I WHERE id = $1', s.campo, s.tabla) INTO v_valor_hoy USING s.registro_id;
        IF v_valor_hoy IS DISTINCT FROM s.valor_anterior THEN
          RAISE EXCEPTION 'El valor actual (%) ya no coincide con el anterior (%)', v_valor_hoy, s.valor_anterior; END IF;
        EXECUTE format('UPDATE pg_temp.%I SET %I = %L, updated_at = now() WHERE id = $1', s.tabla, s.campo, s.valor_nuevo) USING s.registro_id;
        IF s.tabla = 'gastos' THEN PERFORM pg_temp.axi_libro_registrar_gasto(s.registro_id); END IF;
        IF s.tabla = 'pagos' THEN
          PERFORM pg_temp.fn_pago_postear_libro(s.registro_id);
          SELECT factura_id INTO v_fid FROM pg_temp.pagos WHERE id = s.registro_id;
          PERFORM pg_temp.fn_factura_recalcular(v_fid);
        END IF;
      END IF;
    END IF;
    UPDATE pg_temp.solicitudes_autorizacion SET estado_solicitud = p_estado, revisado_por = v_uid,
      autorizado_por_usuario_id = pg_temp.mi_usuario_id(), autorizado_por_nombre = pg_temp.nombre_auth(v_uid),
      comentario_ceo = nullif(btrim(p_motivo), ''), fecha_autorizacion = now(),
      aplicado = (p_estado = 'Aprobado'), fecha_aplicacion = CASE WHEN p_estado = 'Aprobado' THEN now() END, updated_at = now()
     WHERE id = s.id;
    PERFORM 1;
    RETURN jsonb_build_object('modulo', p_modulo, 'id', p_id, 'estado', p_estado);
  END IF;

  v_tabla := CASE p_modulo WHEN 'Facturas' THEN 'facturas' WHEN 'Pagos' THEN 'pagos' WHEN 'Gastos' THEN 'gastos'
                           WHEN 'PagosProveedor' THEN 'pagos_gastos' WHEN 'Proveedores' THEN 'proveedores'
                           WHEN 'GLP' THEN 'glp_facturas' END;
  IF v_tabla IS NULL THEN RAISE EXCEPTION 'Modulo no valido'; END IF;
  IF v_tabla = 'glp_facturas' THEN
    SELECT f.unidad_id INTO v_fid FROM pg_temp.glp_facturas f WHERE f.id = p_id;
    IF v_fid IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || v_fid));
    END IF;
  END IF;
  EXECUTE format('SELECT estado_aprobacion FROM pg_temp.%I WHERE id = $1 FOR UPDATE', v_tabla) INTO v_actual USING p_id;
  IF v_actual IS NULL THEN RAISE EXCEPTION 'Registro no encontrado'; END IF;
  IF v_actual NOT IN ('Sometido','En proceso') THEN RAISE EXCEPTION 'El registro ya fue revisado (estado: %)', v_actual; END IF;

  IF p_estado = 'Aprobado' THEN
    IF v_tabla = 'pagos' THEN
      SELECT f.estado_aprobacion INTO v_dep FROM pg_temp.pagos x JOIN pg_temp.facturas f ON f.id = x.factura_id WHERE x.id = p_id;
      IF v_dep <> 'Aprobado' THEN RAISE EXCEPTION 'Primero apruebe la factura del pago'; END IF;
    ELSIF v_tabla = 'gastos' THEN
      SELECT pr.estado_aprobacion INTO v_dep FROM pg_temp.gastos g JOIN pg_temp.proveedores pr ON pr.id = g.proveedor_id WHERE g.id = p_id;
      IF v_dep <> 'Aprobado' THEN RAISE EXCEPTION 'Primero apruebe el proveedor del gasto'; END IF;
    ELSIF v_tabla = 'pagos_gastos' THEN
      SELECT g.estado_aprobacion INTO v_dep FROM pg_temp.pagos_gastos x JOIN pg_temp.gastos g ON g.id = x.gasto_id WHERE x.id = p_id;
      IF v_dep <> 'Aprobado' THEN RAISE EXCEPTION 'Primero apruebe el gasto de este pago'; END IF;
    END IF;
  END IF;

  EXECUTE format('UPDATE pg_temp.%I SET estado_aprobacion = $1, revisado_por = $2, revisado_at = now(),
                  motivo_rechazo = $3, updated_at = now() WHERE id = $4', v_tabla)
    USING p_estado, v_uid, CASE WHEN p_estado = 'Rechazado' THEN btrim(p_motivo) END, p_id;

  IF p_estado = 'Aprobado' THEN
    IF v_tabla = 'pagos' THEN
      UPDATE pg_temp.pagos SET validado = true, fecha_validacion = pg_temp.hoy() WHERE id = p_id;
      PERFORM pg_temp.fn_pago_postear_libro(p_id);
      SELECT factura_id INTO v_fid FROM pg_temp.pagos WHERE id = p_id;
      PERFORM pg_temp.fn_factura_recalcular(v_fid);
      UPDATE pg_temp.pagos x SET estado = f.estado FROM pg_temp.facturas f
       WHERE x.id = p_id AND f.id = x.factura_id AND coalesce(x.tipo_movimiento, 'Ingreso recibido') = 'Ingreso recibido';
    ELSIF v_tabla = 'gastos' THEN
      PERFORM pg_temp.axi_libro_registrar_gasto(p_id);
    ELSIF v_tabla = 'facturas' THEN
      PERFORM pg_temp.fn_factura_recalcular(p_id);
    END IF;
  END IF;

  PERFORM 1;
  RETURN jsonb_build_object('modulo', p_modulo, 'id', p_id, 'estado', p_estado);
END $function$;

CREATE OR REPLACE FUNCTION pg_temp.portal_mi_glp(p_unidad_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_condo bigint;
BEGIN
  SELECT u.condominio_id INTO v_condo FROM pg_temp.unidades u WHERE u.id = p_unidad_id;
  IF v_condo IS NULL THEN RAISE EXCEPTION 'Unidad no encontrada' USING ERRCODE = '22023'; END IF;
  IF NOT (pg_temp.es_ceo()
          OR v_condo = ANY (pg_temp.staff_condos('GLP','ver'))
          OR p_unidad_id = ANY (pg_temp.unidades_propias())
          OR p_unidad_id = ANY (pg_temp.unidades_inquilino())) THEN
    RAISE EXCEPTION 'Sin acceso a esta unidad' USING ERRCODE = '42501'; END IF;
  RETURN jsonb_build_object(
    'unidad', (SELECT u.codigo FROM pg_temp.unidades u WHERE u.id = p_unidad_id),
    'medidor', (SELECT jsonb_build_object('serie', m.numero_serie, 'marca', m.marca_modelo, 'ubicacion', m.ubicacion_fisica,
                       'unidad_medida', m.unidad_medida, 'lectura_inicial', m.lectura_inicial, 'estado', m.estado_equipo)
                  FROM pg_temp.glp_medidores m WHERE m.unidad_id = p_unidad_id ORDER BY m.id DESC LIMIT 1),
    'precio_vigente', (SELECT pr.precio_galon FROM pg_temp.glp_precios pr WHERE pr.condominio_id = v_condo
                        AND pr.fecha_vigencia <= now() ORDER BY pr.fecha_vigencia DESC LIMIT 1),
    'total_depositos', (SELECT coalesce(sum(x.monto), 0) FROM pg_temp.glp_movimientos x
                         WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO' AND upper(x.tipo_movimiento) = 'DEPOSITO'),
    'total_consumos', (SELECT coalesce(sum(x.monto), 0) FROM pg_temp.glp_movimientos x
                        WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO' AND upper(x.tipo_movimiento) = 'CONSUMO'),
    'saldo', (SELECT coalesce(sum(CASE WHEN upper(x.tipo_movimiento) = 'DEPOSITO' THEN x.monto ELSE -x.monto END), 0)
                FROM pg_temp.glp_movimientos x WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO'),
    'movimientos', (SELECT coalesce(jsonb_agg(jsonb_build_object('fecha', x.fecha_movimiento::date, 'tipo', x.tipo_movimiento,
                       'periodo', x.periodo, 'concepto', x.concepto, 'monto', x.monto, 'saldo', x.saldo_posterior)
                       ORDER BY x.fecha_movimiento DESC, x.id DESC), '[]'::jsonb)
                      FROM pg_temp.glp_movimientos x WHERE x.unidad_id = p_unidad_id AND upper(x.estado) = 'ACTIVO'),
    'lecturas', (SELECT coalesce(jsonb_agg(jsonb_build_object('fecha', l.fecha_lectura::date, 'periodo', l.periodo,
                       'anterior', l.lectura_anterior, 'actual', l.lectura_actual, 'consumo', l.consumo,
                       'precio', l.precio_unitario, 'monto', l.monto_consumo)
                       ORDER BY l.fecha_lectura DESC, l.id DESC), '[]'::jsonb)
                   FROM pg_temp.glp_lecturas l WHERE l.unidad_id = p_unidad_id
                    AND upper(coalesce(l.estado, 'ACTIVO')) = 'ACTIVO' AND coalesce(l.monto_consumo, 0) >= 0));
END $function$;

CREATE OR REPLACE FUNCTION pg_temp.fn_glp_anular(p_movimiento_id bigint, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE x pg_temp.glp_movimientos; v_unidad bigint;
BEGIN
  IF NOT pg_temp.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO anula movimientos de GLP' USING ERRCODE = '42501'; END IF;
  SELECT m.unidad_id INTO v_unidad FROM pg_temp.glp_movimientos m WHERE m.id = p_movimiento_id;
  IF v_unidad IS NULL THEN RAISE EXCEPTION 'Movimiento no encontrado'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || v_unidad));
  SELECT * INTO x FROM pg_temp.glp_movimientos m WHERE m.id = p_movimiento_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Movimiento no encontrado'; END IF;
  IF NOT pg_temp.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO anula movimientos de GLP' USING ERRCODE = '42501'; END IF;
  IF upper(x.estado) = 'ANULADO' THEN RAISE EXCEPTION 'El movimiento ya esta anulado'; END IF;
  IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique el motivo'; END IF;
  UPDATE pg_temp.glp_movimientos SET estado = 'ANULADO', fecha_anulacion = now(), usuario_anulacion = pg_temp.nombre_actor(),
         motivo_anulacion = btrim(p_motivo), updated_at = now() WHERE id = x.id;
  IF x.lectura_id IS NOT NULL THEN
    UPDATE pg_temp.glp_lecturas SET estado = 'ANULADO', fecha_anulacion = now(), usuario_anulacion = pg_temp.nombre_actor(),
           motivo_anulacion = btrim(p_motivo), updated_at = now() WHERE id = x.lectura_id;
  END IF;
  UPDATE pg_temp.glp_facturas SET estado = 'ANULADO', updated_at = now() WHERE movimiento_id = x.id AND upper(estado) <> 'ANULADO';
  UPDATE pg_temp.libro_financiero SET entrada = 0, balance_movimiento = 0, concepto = '[ANULADO] ' || concepto, updated_at = now()
   WHERE codigo_pago = 'GLP-DEP-' || x.id AND concepto NOT LIKE '[ANULADO]%';
  PERFORM 1;
  RETURN jsonb_build_object('id', x.id, 'saldo', pg_temp.glp_saldo(x.unidad_id));
END $function$;

CREATE OR REPLACE FUNCTION pg_temp.trg_glp_aprobacion_efectos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_mov pg_temp.glp_movimientos; v_estado text;
BEGIN
  IF NEW.estado_aprobacion IS NOT DISTINCT FROM OLD.estado_aprobacion
     OR NEW.estado_aprobacion NOT IN ('Aprobado','Rechazado') THEN RETURN NEW; END IF;
  IF NOT pg_temp.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO revisa consumos de GLP' USING ERRCODE = '42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || NEW.unidad_id));
  SELECT * INTO v_mov FROM pg_temp.glp_movimientos WHERE id = NEW.movimiento_id FOR UPDATE;
  IF NOT FOUND OR v_mov.unidad_id IS DISTINCT FROM NEW.unidad_id
     OR v_mov.lectura_id IS DISTINCT FROM NEW.lectura_id
     OR upper(v_mov.tipo_movimiento) <> 'CONSUMO' THEN
    RAISE EXCEPTION 'Factura GLP sin consumo y lectura vinculados correctamente'; END IF;
  IF upper(v_mov.estado) = 'ANULADO' THEN RAISE EXCEPTION 'No se puede revisar un consumo anulado'; END IF;
  v_estado := CASE WHEN NEW.estado_aprobacion = 'Aprobado' THEN 'ACTIVO' ELSE 'RECHAZADO' END;
  UPDATE pg_temp.glp_movimientos SET estado = v_estado, updated_at = now() WHERE id = v_mov.id;
  UPDATE pg_temp.glp_lecturas SET estado = v_estado, updated_at = now() WHERE id = v_mov.lectura_id;
  UPDATE pg_temp.glp_facturas SET estado = v_estado, updated_at = now() WHERE id = NEW.id;
  -- Mantener el orden de registro usado por los saldos anteriores/posteriores.
  -- Solo se actualizan los saldos del movimiento revisado y los posteriores.
  WITH saldos AS (
    SELECT id, sum(CASE WHEN upper(tipo_movimiento) = 'DEPOSITO' THEN monto ELSE -monto END)
      OVER (ORDER BY id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS posterior,
      CASE WHEN upper(tipo_movimiento) = 'DEPOSITO' THEN monto ELSE -monto END AS delta
    FROM pg_temp.glp_movimientos WHERE unidad_id = NEW.unidad_id AND upper(estado) = 'ACTIVO'
  )
  UPDATE pg_temp.glp_movimientos m SET saldo_anterior = s.posterior - s.delta,
         saldo_posterior = s.posterior, updated_at = now()
  FROM saldos s WHERE m.id = s.id AND m.id >= v_mov.id
    AND (m.saldo_anterior IS DISTINCT FROM s.posterior - s.delta OR m.saldo_posterior IS DISTINCT FROM s.posterior);
  RETURN NEW;
END $function$;

CREATE TRIGGER trg_glp_aprobacion_efectos AFTER UPDATE OF estado_aprobacion ON pg_temp.glp_facturas FOR EACH ROW EXECUTE FUNCTION pg_temp.trg_glp_aprobacion_efectos();
CREATE TRIGGER trg_aprobacion BEFORE INSERT OR UPDATE ON pg_temp.glp_facturas FOR EACH ROW EXECUTE FUNCTION pg_temp.trg_aprobacion();
CREATE OR REPLACE FUNCTION pg_temp.fn_glp_registrar_deposito(p_unidad_id bigint, p_monto numeric, p_fecha date, p_concepto text DEFAULT 'Depósito extraordinario'::text, p_foto text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u record; v_med bigint; v_ant numeric; v_id bigint; v_conc text;
BEGIN
  SELECT x.id, x.codigo, x.condominio_id, x.propietario_id INTO u FROM pg_temp.unidades x WHERE x.id = p_unidad_id;
  IF u.id IS NULL THEN RAISE EXCEPTION 'Unidad no encontrada'; END IF;
  IF NOT pg_temp.es_ceo() THEN RAISE EXCEPTION 'Solo el CEO registra depositos de GLP (entrada de dinero)' USING ERRCODE = '42501'; END IF;
  IF p_monto IS NULL OR p_monto <= 0 OR p_monto > 1000000 THEN RAISE EXCEPTION 'Monto no valido'; END IF;
  IF p_fecha IS NULL OR p_fecha > (now() AT TIME ZONE 'America/Santo_Domingo')::date + 1 THEN RAISE EXCEPTION 'Fecha no valida'; END IF;
  v_conc := CASE WHEN p_concepto ILIKE '%inicial%' THEN 'Depósito inicial' ELSE 'Depósito extraordinario' END;
  PERFORM pg_advisory_xact_lock(hashtext('glp_unidad_' || p_unidad_id));
  SELECT m.id INTO v_med FROM pg_temp.glp_medidores m WHERE m.unidad_id = p_unidad_id ORDER BY m.id DESC LIMIT 1;
  v_ant := pg_temp.glp_saldo(p_unidad_id);
  INSERT INTO pg_temp.glp_movimientos (condominio_id, unidad_id, medidor_id, periodo, fecha_movimiento, tipo_movimiento, concepto, monto,
         saldo_anterior, saldo_posterior, foto_ruta, estado, fecha_registro, usuario_registro, created_at, updated_at)
  VALUES (u.condominio_id, u.id, v_med, to_char(p_fecha, 'YYYY-MM'), p_fecha::timestamptz, 'DEPOSITO', v_conc, round(p_monto, 2),
         v_ant, v_ant + round(p_monto, 2), nullif(p_foto, ''), 'ACTIVO', now(), pg_temp.nombre_actor(), now(), now())
  RETURNING id INTO v_id;
  -- Libro: igual que Access (estado de cuenta si, fondo comun no)
  INSERT INTO pg_temp.libro_financiero (condominio_id, fecha, tipo_movimiento, tipo_aplicacion, unidad_id, propietario_id, codigo_pago,
         concepto, entrada, salida, balance_movimiento, afecta_estado_cuenta, afecta_fondo_comun, created_by, created_at, updated_at)
  VALUES (u.condominio_id, p_fecha, 'Deposito GLP', 'GLP', u.id, u.propietario_id, 'GLP-DEP-' || v_id,
         'Aporte a carga de GLP - ' || v_conc, round(p_monto, 2), 0, round(p_monto, 2), true, false, (SELECT pg_temp.test_uid())::text, now(), now());
  PERFORM 1;
  RETURN jsonb_build_object('movimiento_id', v_id, 'saldo', v_ant + round(p_monto, 2));
END $function$;

SELECT set_config('axitest.role','Asistente',true),set_config('axitest.aal','aal2',true);
INSERT INTO pg_temp.condominios(id,nombre,glp_factor_m3_galon) OVERRIDING SYSTEM VALUE VALUES(900001,'TEST',1);
INSERT INTO pg_temp.unidades(id,condominio_id,codigo) OVERRIDING SYSTEM VALUE VALUES(900001,900001,'TEST');
INSERT INTO pg_temp.glp_medidores(id,unidad_id,lectura_inicial) OVERRIDING SYSTEM VALUE VALUES(900001,900001,0);
INSERT INTO pg_temp.glp_movimientos(id,condominio_id,unidad_id,tipo_movimiento,monto,estado,saldo_anterior,saldo_posterior)
 OVERRIDING SYSTEM VALUE VALUES(1,900001,900001,'DEPOSITO',1000,'ACTIVO',0,1000);
DO $tests$
DECLARE r jsonb; fid bigint; mid bigint; did bigint; oldsaldo numeric;
BEGIN
 r := pg_temp.fn_glp_registrar_consumo(900001,'2026-10',current_date,10,NULL,10,NULL);
 mid := (r->>'movimiento_id')::bigint;
 SELECT id INTO fid FROM pg_temp.glp_facturas WHERE movimiento_id=mid;
 PERFORM pg_temp.check_test(r->>'estado_aprobacion'='Sometido','Asistente crea Sometido');
 PERFORM pg_temp.check_test(pg_temp.glp_saldo(900001)=1000,'Pendiente no altera saldo');
 PERFORM pg_temp.check_test((pg_temp.portal_mi_glp(900001)->>'saldo')::numeric=1000,'Portal conserva saldo');
 PERFORM pg_temp.check_test(jsonb_array_length(pg_temp.portal_mi_glp(900001)->'lecturas')=0,'Portal no muestra lectura pendiente');
 PERFORM pg_temp.check_test(pg_temp.glp_lectura_anterior(900001)=0,'Lectura pendiente no avanza base');
 PERFORM pg_temp.check_test(EXISTS(SELECT 1 FROM pg_temp.fn_aprobaciones_bandeja(900001) WHERE modulo='GLP' AND registro_id=fid),'GLP aparece en bandeja');
 BEGIN
  PERFORM pg_temp.fn_glp_registrar_consumo(900001,'2026-11',current_date,20,NULL,10,NULL);
  RAISE EXCEPTION 'TEST FAILED: permitió lectura posterior pendiente';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE 'Primero apruebe o rechace%' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM pg_temp.fn_aprobacion_revisar('GLP',fid,'Aprobado',NULL);
  RAISE EXCEPTION 'TEST FAILED: Asistente aprobó';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM set_config('axitest.role','CEO',true);
 r := pg_temp.fn_glp_registrar_deposito(900001,500,current_date,'Deposito extraordinario',NULL);
 did := (r->>'movimiento_id')::bigint;
 PERFORM pg_temp.check_test(pg_temp.glp_saldo(900001)=1500,'Deposito mientras pendiente');
 PERFORM pg_temp.fn_aprobacion_revisar('GLP',fid,'En proceso',NULL);
 PERFORM pg_temp.check_test(pg_temp.glp_saldo(900001)=1500,'En proceso no afecta saldo');
 PERFORM pg_temp.fn_aprobacion_revisar('GLP',fid,'Aprobado',NULL);
 PERFORM pg_temp.check_test(pg_temp.glp_saldo(900001)=1400,'Aprobar aplica consumo una vez');
 PERFORM pg_temp.check_test(pg_temp.glp_lectura_anterior(900001)=10,'Aprobar avanza lectura');
 PERFORM pg_temp.check_test((SELECT saldo_posterior FROM pg_temp.glp_movimientos WHERE id=did)=1400,'Deposito posterior recalculado');
 PERFORM pg_temp.check_test(jsonb_array_length(pg_temp.portal_mi_glp(900001)->'lecturas')=1,'Lectura aprobada visible');
 BEGIN
  PERFORM pg_temp.fn_aprobacion_revisar('GLP',fid,'Aprobado',NULL);
  RAISE EXCEPTION 'TEST FAILED: doble aprobación permitida';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE 'El registro ya fue revisado%' THEN RAISE; END IF;
 END;
 PERFORM set_config('axitest.role','Asistente',true);
 r := pg_temp.fn_glp_registrar_consumo(900001,'2026-11',current_date,20,NULL,10,NULL);
 mid := (r->>'movimiento_id')::bigint;
 SELECT id INTO fid FROM pg_temp.glp_facturas WHERE movimiento_id=mid;
 PERFORM set_config('axitest.role','CEO',true);
 PERFORM pg_temp.fn_aprobacion_revisar('GLP',fid,'Rechazado','Lectura incorrecta');
 PERFORM pg_temp.check_test(pg_temp.glp_saldo(900001)=1400,'Rechazo no afecta saldo');
 PERFORM pg_temp.check_test(pg_temp.glp_lectura_anterior(900001)=10,'Rechazo no avanza lectura');
 PERFORM pg_temp.check_test((SELECT estado FROM pg_temp.glp_movimientos WHERE id=mid)='RECHAZADO','Consumo rechazado conserva historial');
 PERFORM set_config('axitest.role','Asistente',true);
 r := pg_temp.fn_glp_registrar_consumo(900001,'2026-11',current_date,15,NULL,10,NULL);
 PERFORM pg_temp.check_test(r->>'estado_aprobacion'='Sometido','Reintento tras rechazo permitido');
 SELECT id INTO fid FROM pg_temp.glp_facturas WHERE movimiento_id=(r->>'movimiento_id')::bigint;
 PERFORM set_config('axitest.role','CEO',true);
 PERFORM pg_temp.fn_aprobacion_revisar('GLP',fid,'Aprobado',NULL);
 PERFORM pg_temp.check_test(pg_temp.glp_saldo(900001)=1350,'Corrección aprobada usa última lectura aprobada');
 r := pg_temp.fn_glp_registrar_consumo(900001,'2026-12',current_date,20,NULL,10,NULL);
 PERFORM pg_temp.check_test(r->>'estado_aprobacion'='Aprobado','CEO registra aprobado');
 PERFORM pg_temp.check_test(pg_temp.glp_saldo(900001)=1300,'CEO aplica saldo inmediato');
END $tests$;
-- Asignaciones: futuro, hoy, pasado, 2FA, perfil activo y fecha vacía heredada.
INSERT INTO pg_temp.administradores(id,condominio_id,nombre) OVERRIDING SYSTEM VALUE VALUES(900001,900001,'TEST');
INSERT INTO pg_temp.accesos(auth_user_id,rol,condominio_id,administrador_id,activo)
 VALUES(pg_temp.test_uid(),'Administrador',900001,900001,true);
INSERT INTO pg_temp.unidad_administradores(unidad_id,administrador_id,fecha_inicio) VALUES(900001,900001,current_date+1);
SELECT pg_temp.check_test(cardinality(pg_temp.unidades_propias())=0,'Administrador futuro sin acceso');
UPDATE pg_temp.unidad_administradores SET fecha_inicio=current_date;
SELECT pg_temp.check_test(900001=ANY(pg_temp.unidades_propias()),'Administrador hoy con acceso');
SELECT set_config('axitest.aal','aal1',true);
SELECT pg_temp.check_test(cardinality(pg_temp.unidades_propias())=0,'Administrador sin aal2 sin acceso');
SELECT set_config('axitest.aal','aal2',true);
UPDATE pg_temp.unidad_administradores SET fecha_inicio=current_date-1;
SELECT pg_temp.check_test(900001=ANY(pg_temp.unidades_propias()),'Administrador pasado con acceso');
UPDATE pg_temp.administradores SET estado='Inactivo';
SELECT pg_temp.check_test(cardinality(pg_temp.unidades_propias())=0,'Administrador inactivo sin acceso');
UPDATE pg_temp.accesos SET rol='Propietario',administrador_id=NULL,propietario_id=900002;
INSERT INTO pg_temp.unidad_propietarios(unidad_id,propietario_id,fecha_inicio) VALUES(900001,900002,now()+interval '1 hour');
SELECT pg_temp.check_test(cardinality(pg_temp.unidades_propias())=0,'Propietario futuro sin acceso');
UPDATE pg_temp.unidad_propietarios SET fecha_inicio=now();
SELECT pg_temp.check_test(900001=ANY(pg_temp.unidades_propias()),'Propietario inicio ahora con acceso');
UPDATE pg_temp.unidad_propietarios SET fecha_inicio=NULL;
SELECT pg_temp.check_test(900001=ANY(pg_temp.unidades_propias()),'Propietario fecha vacía heredada conserva acceso');
ROLLBACK;
