-- AXICORE: lectura coherente del recibo de un pago aprobado de residente.
-- No modifica datos, códigos ni saldos. Solo CEO o staff con Pagos/ver y aal2.
CREATE OR REPLACE FUNCTION public.fn_pago_recibo(p_pago_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE p public.pagos; f public.facturas; a public.configuracion_administracion;
 v_antes numeric; v_prop jsonb; v_inq jsonb; v_admin jsonb; v_unidad text; v_condo text;
BEGIN
 IF NOT (private.es_ceo() OR cardinality(private.staff_condos('Pagos','ver'))>0) THEN
  RAISE EXCEPTION 'Sin permiso para consultar recibos' USING ERRCODE='42501'; END IF;
 SELECT * INTO p FROM public.pagos WHERE id=p_pago_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Pago no encontrado' USING ERRCODE='22023'; END IF;
 IF NOT (private.es_ceo() OR p.condominio_id=ANY(private.staff_condos('Pagos','ver'))) THEN
  RAISE EXCEPTION 'Sin permiso para consultar este recibo' USING ERRCODE='42501'; END IF;
 IF p.estado_aprobacion IS DISTINCT FROM 'Aprobado'
    OR lower(coalesce(p.estado,'')) IN ('anulado','anulada','eliminado')
    OR coalesce(p.tipo_movimiento,'Ingreso recibido') <> 'Ingreso recibido' THEN
  RAISE EXCEPTION 'Solo se emiten recibos de ingresos aprobados y vigentes'; END IF;
 SELECT * INTO f FROM public.facturas WHERE id=p.factura_id AND condominio_id=p.condominio_id;
 IF NOT FOUND OR f.estado_aprobacion IS DISTINCT FROM 'Aprobado' OR lower(coalesce(f.estado,''))='anulada' THEN
  RAISE EXCEPTION 'El pago no tiene una factura aprobada y vigente'; END IF;
 IF (SELECT count(*) FROM public.configuracion_administracion WHERE lower(coalesce(estado,'activo'))='activo') <> 1 THEN
  RAISE EXCEPTION 'Debe existir una única configuración activa de la administración'; END IF;
 SELECT * INTO a FROM public.configuracion_administracion WHERE lower(coalesce(estado,'activo'))='activo';
 SELECT coalesce(sum(x.monto),0) INTO v_antes FROM public.pagos x
 WHERE x.factura_id=f.id AND x.condominio_id=p.condominio_id AND x.estado_aprobacion='Aprobado'
   AND coalesce(x.tipo_movimiento,'Ingreso recibido')='Ingreso recibido'
   AND lower(coalesce(x.estado,'')) NOT IN ('anulado','anulada','eliminado')
   AND (x.fecha_pago,x.id) < (p.fecha_pago,p.id);
 SELECT u.codigo,c.nombre INTO v_unidad,v_condo FROM public.unidades u
 JOIN public.condominios c ON c.id=u.condominio_id WHERE u.id=f.unidad_id;
 SELECT jsonb_build_object('nombre',x.nombre,'email',x.email) INTO v_prop FROM public.propietarios x WHERE x.id=f.propietario_id;
 SELECT jsonb_build_object('nombre',x.nombre,'email',x.email) INTO v_inq FROM public.inquilinos x WHERE x.id=f.inquilino_id;
 SELECT jsonb_build_object('nombre',ad.nombre,'email',ad.email) INTO v_admin
 FROM public.unidad_administradores ua JOIN public.administradores ad ON ad.id=ua.administrador_id
 WHERE ua.unidad_id=f.unidad_id AND ua.fecha_fin IS NULL
   AND ua.fecha_inicio <= (now() AT TIME ZONE 'America/Santo_Domingo')::date AND ad.estado='Activo'
 ORDER BY ua.id DESC LIMIT 1;
 RETURN jsonb_build_object(
 'id',p.id,'codigo',coalesce(nullif(btrim(p.codigo),''),'PG-'||p.id::text),'fecha_pago',p.fecha_pago,
 'recibido_de',coalesce(nullif(btrim(p.recibido_de),''), CASE WHEN f.tipo_facturacion='Inquilino' THEN coalesce(v_admin->>'nombre',v_prop->>'nombre') ELSE v_prop->>'nombre' END,''),
 'metodo',p.metodo,'banco',p.banco,'referencia',p.referencia,'observaciones',p.observaciones,
 'concepto',coalesce(nullif(btrim(p.concepto),''),f.concepto,''),
 'factura',f.no_factura,'tipo_facturacion',f.tipo_facturacion,'periodo',f.periodo,
 'condominio',v_condo,'unidad',v_unidad,'monto_factura',f.monto,
 'abonado_antes',v_antes,'este_pago',p.monto,'balance',f.monto-v_antes-p.monto,
 'empresa',jsonb_build_object('nombre',coalesce(nullif(a.nombre_comercial,''),a.nombre),
   'direccion',a.direccion,'telefono',a.telefono,'email',a.email,'banco',a.banco,
   'tipo_cuenta',a.tipo_cuenta,'numero_cuenta',a.numero_cuenta,'beneficiario',a.beneficiario),
 'propietario',v_prop,'inquilino',v_inq,'administrador',v_admin);
END $function$;
REVOKE ALL ON FUNCTION public.fn_pago_recibo(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_pago_recibo(bigint) TO authenticated;
