-- Pruebas aisladas: copias temporales, sin datos reales; ROLLBACK final.

BEGIN;
CREATE TEMP TABLE pagos (LIKE public.pagos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE facturas (LIKE public.facturas INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE configuracion_administracion (LIKE public.configuracion_administracion INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE unidades (LIKE public.unidades INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE condominios (LIKE public.condominios INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE propietarios (LIKE public.propietarios INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE inquilinos (LIKE public.inquilinos INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE unidad_administradores (LIKE public.unidad_administradores INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE TEMP TABLE administradores (LIKE public.administradores INCLUDING DEFAULTS INCLUDING IDENTITY) ON COMMIT DROP;
CREATE FUNCTION pg_temp.es_ceo() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('axirecibo.role',true)='CEO'$$;
CREATE FUNCTION pg_temp.staff_condos(text,text) RETURNS bigint[] LANGUAGE sql AS $$SELECT CASE WHEN current_setting('axirecibo.role',true)='Asistente' AND current_setting('axirecibo.aal',true)='aal2' THEN ARRAY[900001::bigint] ELSE '{}'::bigint[] END$$;
CREATE FUNCTION pg_temp.check_test(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'TEST FAILED: %',label; END IF; END$$;
-- AXICORE: lectura coherente del recibo de un pago aprobado de residente.
-- No modifica datos, códigos ni saldos. Solo CEO o staff con Pagos/ver y aal2.
CREATE OR REPLACE FUNCTION pg_temp.fn_pago_recibo(p_pago_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE p pg_temp.pagos; f pg_temp.facturas; a pg_temp.configuracion_administracion;
 v_antes numeric; v_prop jsonb; v_inq jsonb; v_admin jsonb; v_unidad text; v_condo text;
BEGIN
 IF NOT (pg_temp.es_ceo() OR cardinality(pg_temp.staff_condos('Pagos','ver'))>0) THEN
  RAISE EXCEPTION 'Sin permiso para consultar recibos' USING ERRCODE='42501'; END IF;
 SELECT * INTO p FROM pg_temp.pagos WHERE id=p_pago_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Pago no encontrado' USING ERRCODE='22023'; END IF;
 IF NOT (pg_temp.es_ceo() OR p.condominio_id=ANY(pg_temp.staff_condos('Pagos','ver'))) THEN
  RAISE EXCEPTION 'Sin permiso para consultar este recibo' USING ERRCODE='42501'; END IF;
 IF p.estado_aprobacion IS DISTINCT FROM 'Aprobado'
    OR lower(coalesce(p.estado,'')) IN ('anulado','anulada','eliminado')
    OR coalesce(p.tipo_movimiento,'Ingreso recibido') <> 'Ingreso recibido' THEN
  RAISE EXCEPTION 'Solo se emiten recibos de ingresos aprobados y vigentes'; END IF;
 SELECT * INTO f FROM pg_temp.facturas WHERE id=p.factura_id AND condominio_id=p.condominio_id;
 IF NOT FOUND OR f.estado_aprobacion IS DISTINCT FROM 'Aprobado' OR lower(coalesce(f.estado,''))='anulada' THEN
  RAISE EXCEPTION 'El pago no tiene una factura aprobada y vigente'; END IF;
 IF (SELECT count(*) FROM pg_temp.configuracion_administracion WHERE lower(coalesce(estado,'activo'))='activo') <> 1 THEN
  RAISE EXCEPTION 'Debe existir una única configuración activa de la administración'; END IF;
 SELECT * INTO a FROM pg_temp.configuracion_administracion WHERE lower(coalesce(estado,'activo'))='activo';
 SELECT coalesce(sum(x.monto),0) INTO v_antes FROM pg_temp.pagos x
 WHERE x.factura_id=f.id AND x.condominio_id=p.condominio_id AND x.estado_aprobacion='Aprobado'
   AND coalesce(x.tipo_movimiento,'Ingreso recibido')='Ingreso recibido'
   AND lower(coalesce(x.estado,'')) NOT IN ('anulado','anulada','eliminado')
   AND (x.fecha_pago,x.id) < (p.fecha_pago,p.id);
 SELECT u.codigo,c.nombre INTO v_unidad,v_condo FROM pg_temp.unidades u
 JOIN pg_temp.condominios c ON c.id=u.condominio_id WHERE u.id=f.unidad_id;
 SELECT jsonb_build_object('nombre',x.nombre,'email',x.email) INTO v_prop FROM pg_temp.propietarios x WHERE x.id=f.propietario_id;
 SELECT jsonb_build_object('nombre',x.nombre,'email',x.email) INTO v_inq FROM pg_temp.inquilinos x WHERE x.id=f.inquilino_id;
 SELECT jsonb_build_object('nombre',ad.nombre,'email',ad.email) INTO v_admin
 FROM pg_temp.unidad_administradores ua JOIN pg_temp.administradores ad ON ad.id=ua.administrador_id
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

SELECT set_config('axirecibo.role','CEO',true),set_config('axirecibo.aal','aal2',true);
INSERT INTO pg_temp.condominios(id,nombre) OVERRIDING SYSTEM VALUE VALUES(900001,'TEST');
INSERT INTO pg_temp.unidades(id,condominio_id,codigo) OVERRIDING SYSTEM VALUE VALUES(900001,900001,'TEST');
INSERT INTO pg_temp.configuracion_administracion(id,nombre,nombre_comercial,estado) OVERRIDING SYSTEM VALUE VALUES(1,'EMPRESA TEST','EMPRESA TEST','Activo');
INSERT INTO pg_temp.facturas(id,condominio_id,unidad_id,no_factura,monto,estado_aprobacion,estado,tipo_facturacion)
 OVERRIDING SYSTEM VALUE VALUES(900001,900001,900001,'TEST',4500,'Aprobado','Parcial','Propietario');
INSERT INTO pg_temp.pagos(id,condominio_id,factura_id,fecha_pago,monto,estado_aprobacion,estado,tipo_movimiento,codigo,recibido_de)
 OVERRIDING SYSTEM VALUE VALUES
 (1,900001,900001,'2026-10-14',1000,'Aprobado','Aplicado','Ingreso recibido',NULL,'PRUEBA'),
 (2,900001,900001,'2026-10-14',2000,'Aprobado','Aplicado','Ingreso recibido','TEST-2','PRUEBA'),
 (3,900001,900001,'2026-10-15',500,'Aprobado','Aplicado','Ingreso recibido','TEST-3','PRUEBA'),
 (4,900001,900001,'2026-10-13',900,'Rechazado','Registrado','Ingreso recibido','TEST-4','PRUEBA'),
 (5,900001,900001,'2026-10-13',500,'Aprobado','Anulado','Ingreso recibido','TEST-5','PRUEBA'),
 (6,900001,900001,'2026-10-13',300,'Aprobado','Aplicado','Ajuste','TEST-6','PRUEBA');
SELECT pg_temp.check_test((pg_temp.fn_pago_recibo(2)->>'abonado_antes')::numeric=1000,'abonos previos sin futuros rechazados anulados ni ajustes');
SELECT pg_temp.check_test((pg_temp.fn_pago_recibo(2)->>'este_pago')::numeric=2000,'importe de este pago');
SELECT pg_temp.check_test((pg_temp.fn_pago_recibo(2)->>'balance')::numeric=1500,'balance parcial correcto');
SELECT pg_temp.check_test(pg_temp.fn_pago_recibo(2)->>'codigo'='TEST-2','codigo almacenado conservado');
SELECT pg_temp.check_test(pg_temp.fn_pago_recibo(1)->>'codigo'='PG-1','fallback determinista sin escribir código');
SELECT pg_temp.check_test((pg_temp.fn_pago_recibo(1)->>'abonado_antes')::numeric=0,'primer pago cero abonado antes');
SELECT pg_temp.check_test((pg_temp.fn_pago_recibo(3)->>'abonado_antes')::numeric=3000,'pago posterior acumula anteriores');
SELECT set_config('axirecibo.role','Asistente',true);
SELECT pg_temp.check_test(pg_temp.fn_pago_recibo(2)->>'codigo'='TEST-2','Asistente autorizado aal2 puede leer');
DO $tests$
BEGIN
 BEGIN PERFORM pg_temp.fn_pago_recibo(4);RAISE EXCEPTION 'TEST FAILED: rechazado emitido';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Solo se emiten%' THEN RAISE;END IF;END;
 BEGIN PERFORM pg_temp.fn_pago_recibo(5);RAISE EXCEPTION 'TEST FAILED: anulado emitido';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Solo se emiten%' THEN RAISE;END IF;END;
 BEGIN PERFORM pg_temp.fn_pago_recibo(6);RAISE EXCEPTION 'TEST FAILED: ajuste emitido';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Solo se emiten%' THEN RAISE;END IF;END;
 PERFORM set_config('axirecibo.aal','aal1',true);
 BEGIN PERFORM pg_temp.fn_pago_recibo(2);RAISE EXCEPTION 'TEST FAILED: aal1 permitido';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('axirecibo.aal','aal2',true);
 UPDATE pg_temp.pagos SET condominio_id=900002 WHERE id=2;
 BEGIN PERFORM pg_temp.fn_pago_recibo(2);RAISE EXCEPTION 'TEST FAILED: otro condominio permitido';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 UPDATE pg_temp.pagos SET condominio_id=900001 WHERE id=2;
 PERFORM set_config('axirecibo.role','Administrador',true);
 BEGIN PERFORM pg_temp.fn_pago_recibo(2);RAISE EXCEPTION 'TEST FAILED: rol no permitido';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('axirecibo.role','CEO',true);
 UPDATE pg_temp.facturas SET estado='Anulada' WHERE id=900001;
 BEGIN PERFORM pg_temp.fn_pago_recibo(2);RAISE EXCEPTION 'TEST FAILED: factura anulada';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'El pago no tiene%' THEN RAISE;END IF;END;
END $tests$;
ROLLBACK;
