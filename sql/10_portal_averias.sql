-- AXICORE | P2 Reportar averia (10/10/2026)
-- Ya existian: portal_reportar_averia (crea AXI-RPT-AAAA-NNNNN, valida unidad propia, 5-2000 caracteres)
-- y portal_mantenimientos_condominio. Nuevo: portal_mis_reportes() (lo reportado por la cuenta
-- o, para registros historicos sin reportado_por, los de su unidad), con respuesta de la administracion.
CREATE OR REPLACE FUNCTION public.portal_mis_reportes()
RETURNS TABLE(codigo text, unidad text, tipo text, area_aplicacion text, prioridad text, estatus text, descripcion text,
              fecha_solicitud timestamptz, fecha_atencion timestamptz, fecha_cierre timestamptz, observaciones_admin text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE mias bigint[] := private.unidades_propias() || private.unidades_inquilino();
BEGIN
  IF NOT private.es_residente() THEN RAISE EXCEPTION 'Solo propietarios e inquilinos' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT m.codigo, u.codigo, m.tipo, m.area_aplicacion, m.prioridad, m.estatus, m.descripcion,
         m.fecha_solicitud, m.fecha_atencion, m.fecha_cierre, m.observaciones_admin
    FROM public.mantenimientos m LEFT JOIN public.unidades u ON u.id = m.unidad_id
   WHERE m.reportado_por = (SELECT auth.uid()) OR (m.unidad_id = ANY (mias) AND m.reportado_por IS NULL AND m.unidad_id IS NOT NULL)
   ORDER BY m.fecha_solicitud DESC NULLS LAST, m.id DESC LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.portal_mis_reportes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.portal_mis_reportes() TO authenticated;
