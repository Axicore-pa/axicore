-- Visibilidad financiera de Inquilino. Solo reglas de lectura y autorización: no modifica registros ni importes.
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='20s';
DO $guard$ BEGIN
IF (SELECT qual FROM pg_policies WHERE schemaname='public' AND tablename='facturas' AND policyname='ver') IS DISTINCT FROM '(( SELECT private.es_ceo() AS es_ceo) OR (condominio_id = ANY (( SELECT private.staff_condos(''Facturacion''::text, ''ver''::text) AS staff_condos)::bigint[])) OR ((estado_aprobacion = ''Aprobado''::text) AND ((unidad_id = ANY (( SELECT private.unidades_propias() AS unidades_propias)::bigint[])) OR (inquilino_id = ANY (( SELECT private.mis_inquilinos() AS mis_inquilinos)::bigint[])))))' THEN RAISE EXCEPTION 'La política facturas.ver cambió; revisar concurrencia antes de aplicar.'; END IF;
IF (SELECT qual FROM pg_policies WHERE schemaname='public' AND tablename='pagos' AND policyname='ver') IS DISTINCT FROM '(( SELECT private.es_ceo() AS es_ceo) OR (condominio_id = ANY (( SELECT private.staff_condos(''Pagos''::text, ''ver''::text) AS staff_condos)::bigint[])) OR ((estado_aprobacion <> ''Rechazado''::text) AND ((unidad_id = ANY (( SELECT private.unidades_propias() AS unidades_propias)::bigint[])) OR (inquilino_id = ANY (( SELECT private.mis_inquilinos() AS mis_inquilinos)::bigint[])))))' THEN RAISE EXCEPTION 'La política pagos.ver cambió; revisar concurrencia antes de aplicar.'; END IF;
IF (SELECT qual FROM pg_policies WHERE schemaname='public' AND tablename='comprobantes_pago' AND policyname='ver') IS DISTINCT FROM '(( SELECT private.es_ceo() AS es_ceo) OR (condominio_id = ANY (( SELECT private.staff_condos(''Pagos''::text, ''ver''::text) AS staff_condos)::bigint[])) OR (unidad_id = ANY (( SELECT private.unidades_propias() AS unidades_propias)::bigint[])) OR (subido_por = ( SELECT auth.uid() AS uid)))' THEN RAISE EXCEPTION 'La política comprobantes_pago.ver cambió; revisar concurrencia antes de aplicar.'; END IF;
END $guard$;
CREATE FUNCTION private.axi_es_cuota_mantenimiento(p_tipo text,p_concepto text,p_afecta boolean) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
 SELECT coalesce(p_afecta,false) OR lower(coalesce(p_tipo,'')) ~ '(mantenim|mantto)' OR lower(coalesce(p_concepto,'')) ~ '(mantenim|mantto|cuota[[:space:]]+(de[[:space:]]+)?mant[.])'
$function$;
CREATE FUNCTION private.axi_factura_cargo_inquilino(p_factura_id bigint) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
 SELECT (SELECT auth.uid()) IS NOT NULL AND (SELECT private.axi_sesion_auth_valida()) AND EXISTS(
 SELECT 1 FROM public.facturas f WHERE f.id=p_factura_id AND f.estado_aprobacion='Aprobado' AND lower(btrim(coalesce(f.tipo_facturacion,'')))='inquilino'
 AND f.inquilino_id=ANY((SELECT private.mis_inquilinos())::bigint[])
 AND f.unidad_id=ANY((SELECT private.unidades_inquilino())::bigint[])
 AND NOT private.axi_es_cuota_mantenimiento(f.tipo_factura,f.concepto,f.afecta_cuota_mantenimiento))
$function$;
REVOKE ALL ON FUNCTION private.axi_es_cuota_mantenimiento(text,text,boolean),private.axi_factura_cargo_inquilino(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.axi_es_cuota_mantenimiento(text,text,boolean),private.axi_factura_cargo_inquilino(bigint) TO authenticated,service_role;
ALTER POLICY ver ON public.facturas USING ((( SELECT private.es_ceo() AS es_ceo) OR (condominio_id = ANY (( SELECT private.staff_condos('Facturacion'::text, 'ver'::text) AS staff_condos)::bigint[])) OR ((estado_aprobacion = 'Aprobado'::text) AND ((unidad_id = ANY (( SELECT private.unidades_propias() AS unidades_propias)::bigint[])) OR private.axi_factura_cargo_inquilino(id)))));
ALTER POLICY ver ON public.pagos USING ((( SELECT private.es_ceo() AS es_ceo) OR (condominio_id = ANY (( SELECT private.staff_condos('Pagos'::text, 'ver'::text) AS staff_condos)::bigint[])) OR ((estado_aprobacion <> 'Rechazado'::text) AND ((unidad_id = ANY (( SELECT private.unidades_propias() AS unidades_propias)::bigint[])) OR (EXISTS(SELECT 1 FROM public.facturas fi WHERE fi.id=pagos.factura_id AND fi.unidad_id=pagos.unidad_id AND fi.condominio_id=pagos.condominio_id AND private.axi_factura_cargo_inquilino(fi.id)))))));
ALTER POLICY ver ON public.comprobantes_pago USING ((( SELECT private.es_ceo() AS es_ceo) OR (condominio_id = ANY (( SELECT private.staff_condos('Pagos'::text, 'ver'::text) AS staff_condos)::bigint[])) OR (unidad_id = ANY (( SELECT private.unidades_propias() AS unidades_propias)::bigint[])) OR (subido_por=(SELECT auth.uid()) AND (cardinality(private.mis_inquilinos())=0 OR private.axi_factura_cargo_inquilino(factura_id)))));
CREATE OR REPLACE FUNCTION public.axi_ec_unidad_resumen(p_unidad_id bigint)
 RETURNS TABLE(unidad_id bigint, unidad_codigo text, propietario_nombre text, total_facturado numeric, total_pagado numeric, balance_pendiente numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_solo_inq boolean;
BEGIN
  v_solo_inq := NOT private.puede_ver_unidad(p_unidad_id);
  IF v_solo_inq AND NOT (p_unidad_id = ANY (private.unidades_inquilino())) THEN
    RAISE EXCEPTION 'Sin acceso a esta unidad' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT u.id, u.codigo, p.nombre, coalesce(sum(f.monto), 0), coalesce(sum(f.monto_pagado), 0), coalesce(sum(f.balance_pendiente), 0)
    FROM public.unidades u
    LEFT JOIN public.propietarios p ON p.id = u.propietario_id
    LEFT JOIN public.facturas f ON f.unidad_id = u.id AND lower(f.estado) <> 'anulada' AND f.estado_aprobacion = 'Aprobado'
         AND (NOT v_solo_inq OR private.axi_factura_cargo_inquilino(f.id))
   WHERE u.id = p_unidad_id
   GROUP BY u.id, u.codigo, p.nombre;
END $function$;
CREATE OR REPLACE FUNCTION public.axi_ec_unidad_movimientos(p_unidad_id bigint)
 RETURNS TABLE(fecha date, tipo text, referencia text, concepto text, cargo numeric, abono numeric, balance_ref numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_solo_inq boolean; v_inq bigint[];
BEGIN
  v_solo_inq := NOT private.puede_ver_unidad(p_unidad_id);
  IF v_solo_inq AND NOT (p_unidad_id = ANY (private.unidades_inquilino())) THEN
    RAISE EXCEPTION 'Sin acceso a esta unidad' USING ERRCODE = '42501'; END IF;
  v_inq := private.mis_inquilinos();
  RETURN QUERY
  SELECT x.fecha, x.tipo, x.referencia, x.concepto, x.cargo, x.abono, x.balance_ref FROM (
    SELECT f.fecha_factura AS fecha, 'Factura'::text AS tipo, f.no_factura AS referencia, f.concepto,
           f.monto AS cargo, 0::numeric AS abono, f.balance_pendiente AS balance_ref
      FROM public.facturas f
     WHERE f.unidad_id = p_unidad_id AND lower(f.estado) <> 'anulada' AND f.estado_aprobacion = 'Aprobado'
       AND (NOT v_solo_inq OR private.axi_factura_cargo_inquilino(f.id))
    UNION ALL
    SELECT pg.fecha_pago, 'Pago'::text, pg.codigo, pg.concepto, 0::numeric, pg.monto, 0::numeric
      FROM public.pagos pg JOIN public.facturas f2 ON f2.id = pg.factura_id
     WHERE f2.unidad_id = p_unidad_id AND pg.estado_aprobacion = 'Aprobado'
       AND lower(coalesce(pg.estado, '')) NOT IN ('anulado','anulada')
       AND (NOT v_solo_inq OR (private.axi_factura_cargo_inquilino(f2.id) AND pg.unidad_id=f2.unidad_id AND pg.condominio_id=f2.condominio_id))) x
  ORDER BY x.fecha, x.tipo DESC;
END $function$;
CREATE OR REPLACE FUNCTION private.puede_ver_comprobante(p_nombre text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
 SELECT ((storage.foldername(p_nombre))[1]=(SELECT auth.uid())::text
 AND NOT EXISTS(SELECT 1 FROM public.comprobantes_pago c WHERE c.archivo_ruta=p_nombre
 AND NOT (private.es_ceo() OR c.condominio_id=ANY(private.staff_condos('Pagos','ver')) OR c.unidad_id=ANY(private.unidades_propias()) OR (c.subido_por=(SELECT auth.uid()) AND private.axi_factura_cargo_inquilino(c.factura_id)))))
 OR EXISTS(SELECT 1 FROM public.comprobantes_pago c WHERE c.archivo_ruta=p_nombre
 AND (private.es_ceo() OR c.condominio_id=ANY(private.staff_condos('Pagos','ver')) OR c.unidad_id=ANY(private.unidades_propias()) OR (c.subido_por=(SELECT auth.uid()) AND private.axi_factura_cargo_inquilino(c.factura_id))))
$function$;
CREATE OR REPLACE FUNCTION public.portal_registrar_comprobante(p_factura_id bigint, p_fecha_pago date, p_monto numeric, p_archivo_ruta text, p_metodo text DEFAULT 'Transferencia'::text, p_banco text DEFAULT NULL::text, p_referencia text DEFAULT NULL::text, p_nota text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE f record; es_dueno boolean; cid bigint; inq bigint;
BEGIN
  IF NOT private.es_residente() THEN RAISE EXCEPTION 'Solo propietarios e inquilinos' USING ERRCODE = '42501'; END IF;
  SELECT x.id, x.condominio_id, x.unidad_id, x.propietario_id, x.inquilino_id, x.no_factura INTO f FROM public.facturas x WHERE x.id = p_factura_id;
  IF f.id IS NULL THEN RAISE EXCEPTION 'Factura no encontrada' USING ERRCODE = '22023'; END IF;
  es_dueno := coalesce(f.unidad_id = ANY (private.unidades_propias()), false);
  IF NOT coalesce(es_dueno OR private.axi_factura_cargo_inquilino(f.id), false) THEN RAISE EXCEPTION 'Esa factura no le pertenece' USING ERRCODE = '42501'; END IF;
  IF p_monto IS NULL OR p_monto <= 0 OR p_monto > 10000000 THEN RAISE EXCEPTION 'Monto no valido' USING ERRCODE = '22023'; END IF;
  IF p_fecha_pago IS NULL OR p_fecha_pago > (now() AT TIME ZONE 'America/Santo_Domingo')::date OR p_fecha_pago < date '2020-01-01' THEN
    RAISE EXCEPTION 'Fecha de pago no valida' USING ERRCODE = '22023'; END IF;
  IF p_archivo_ruta IS NULL OR (storage.foldername(p_archivo_ruta))[1] IS DISTINCT FROM (SELECT auth.uid())::text
     OR NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id = 'comprobantes' AND o.name = p_archivo_ruta) THEN
    RAISE EXCEPTION 'Suba primero el archivo del comprobante' USING ERRCODE = '22023'; END IF;
  IF EXISTS (SELECT 1 FROM public.comprobantes_pago c WHERE c.archivo_ruta = p_archivo_ruta) THEN
    RAISE EXCEPTION 'Este comprobante ya fue enviado' USING ERRCODE = '23505'; END IF;
  IF NOT es_dueno THEN inq := f.inquilino_id; END IF;
  INSERT INTO public.comprobantes_pago (condominio_id, factura_id, unidad_id, propietario_id, inquilino_id, subido_por, fecha_pago, monto,
         metodo, banco, referencia, archivo_ruta, nota)
  VALUES (f.condominio_id, f.id, f.unidad_id, CASE WHEN es_dueno THEN f.propietario_id END, inq, (SELECT auth.uid()), p_fecha_pago, round(p_monto, 2),
         left(nullif(btrim(p_metodo), ''), 50), left(nullif(btrim(p_banco), ''), 120), left(nullif(btrim(p_referencia), ''), 120),
         p_archivo_ruta, left(nullif(btrim(p_nota), ''), 1000))
  RETURNING id INTO cid;
  PERFORM private.log_portal('Pagos', 'comprobantes_pago', cid, 'factura', NULL, f.no_factura, 'Creación', 'Comprobante de pago enviado desde el portal');
  RETURN cid;
END $function$;
