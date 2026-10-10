-- AXICORE | PUNTO DE RESTAURACION previo a axicore_07_seguridad (10/10/2026)
-- Revierte la tarea A si alguna pantalla deja de funcionar.
-- Estado previo: todas las funciones public tenian EXECUTE para PUBLIC, anon y authenticated
-- (excepto mi_perfil, portal_* y revisar_comprobante, que ya excluian anon).

-- 1) Permisos de ejecucion (estado previo)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.mi_perfil(), public.portal_fondo_comun(bigint),
  public.portal_gastos_fondo_comun(bigint,date,date), public.portal_mantenimientos_condominio(bigint),
  public.portal_actualizar_contacto(text,text,text), public.revisar_comprobante(bigint,text,text),
  public.portal_reportar_averia(text,text,text,text,bigint),
  public.portal_registrar_comprobante(bigint,date,numeric,text,text,text,text,text) FROM PUBLIC, anon;

-- 2) Vista de cobros (antes corria con permisos del dueno)
ALTER VIEW public.v_cobros_pendientes RESET (security_invoker);

-- 3) webapp_pages / zz_axi_probe2 (antes abiertas)
ALTER POLICY "Service role full access" ON public.webapp_pages TO public USING (true) WITH CHECK (true);
GRANT ALL ON public.webapp_pages, public.zz_axi_probe2 TO anon, authenticated;
ALTER TABLE public.zz_axi_probe2 DISABLE ROW LEVEL SECURITY;

-- 4) Funciones del dashboard: cuerpo original
CREATE OR REPLACE FUNCTION public.axi_mora_resumen(p_condominio_id bigint)
 RETURNS TABLE(unidad_codigo text, saldo_pendiente numeric) LANGUAGE sql STABLE SECURITY DEFINER
AS $function$
  SELECT unidad_codigo, COALESCE(SUM(balance_pendiente), 0) AS saldo_pendiente
  FROM v_cobros_pendientes WHERE condominio_id = p_condominio_id GROUP BY unidad_codigo
  UNION ALL
  SELECT u.codigo, 0::numeric FROM unidades u
  WHERE u.condominio_id = p_condominio_id
    AND u.codigo NOT IN (SELECT DISTINCT unidad_codigo FROM v_cobros_pendientes WHERE condominio_id = p_condominio_id);
$function$;

CREATE OR REPLACE FUNCTION public.axi_flujo_mensual(p_condominio_id bigint)
 RETURNS TABLE(mes text, ingresos numeric, egresos numeric) LANGUAGE sql STABLE SECURITY DEFINER
AS $function$
  WITH meses AS (
    SELECT DISTINCT to_char(d, 'YYYY-MM') AS mes FROM (
      SELECT fecha_pago AS d FROM pagos WHERE condominio_id = p_condominio_id AND estado != 'Eliminado'
      UNION SELECT fecha AS d FROM gastos WHERE condominio_id = p_condominio_id AND estado != 'Eliminado') t
    WHERE d IS NOT NULL),
  ing AS (SELECT to_char(fecha_pago, 'YYYY-MM') AS mes, COALESCE(SUM(monto), 0) AS total FROM pagos
          WHERE condominio_id = p_condominio_id AND estado != 'Eliminado' AND fecha_pago IS NOT NULL GROUP BY 1),
  egr AS (SELECT to_char(fecha, 'YYYY-MM') AS mes, COALESCE(SUM(monto), 0) AS total FROM gastos
          WHERE condominio_id = p_condominio_id AND estado != 'Eliminado' AND fecha IS NOT NULL GROUP BY 1)
  SELECT m.mes, COALESCE(i.total, 0), COALESCE(e.total, 0)
  FROM meses m LEFT JOIN ing i ON i.mes = m.mes LEFT JOIN egr e ON e.mes = m.mes ORDER BY m.mes;
$function$;

-- 5) axi_codigo_inquilino/propietario/proveedor y fn_facturacion_mensual_preview:
--    el cambio solo AGREGA una linea de validacion al inicio (IF NOT private.es_staff() ... RAISE).
--    Para revertir, quitar esa linea (cuerpos originales en el historial de git de este archivo / backup_20261009).
