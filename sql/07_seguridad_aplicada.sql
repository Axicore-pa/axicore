-- AXICORE | axicore_07_seguridad (APLICADA 10/10/2026, autorizada por Misael)
-- Cierra fuga: visitantes sin sesion leian cobros/saldos y escribian bitacora/solicitudes.
-- Restauracion: sql/rollback_pre_07_seguridad.sql
ALTER VIEW public.v_cobros_pendientes SET (security_invoker = true);
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;
-- Funciones internas (solo las llaman otras funciones; la app no las usa):
REVOKE EXECUTE ON FUNCTION public.axi_codigo_condominio(text), public.axi_codigo_mantenimiento(),
  public.axi_factura_gasto_generar_no(date), public.axi_gasto_generar_codigo(date),
  public.axi_log_actividad(text,text,bigint,text,text,text,text,text), public.axi_requiere_autorizacion(text,text),
  public.axi_solicitud_crear(text,text,bigint,text,text,text,text), public.fn_factura_aplicar_recurrencia(bigint,text,integer,integer),
  public.fn_factura_recalcular(bigint), public.fn_factura_siguiente_numero(bigint), public.fn_facturacion_mensual_sugerencias(text),
  public.fn_pago_generar_codigo(bigint,date), public.fn_recordatorio_generar(bigint), public.axi_libro_registrar_gasto(bigint),
  public.fn_pago_postear_libro(bigint), public.fn_pago_gasto_aplicar(), public.fn_set_updated_at() FROM authenticated;
REVOKE SELECT ON public.v_cobros_pendientes FROM anon;
REVOKE ALL ON public.webapp_pages, public.zz_axi_probe2 FROM anon, authenticated;
ALTER TABLE public.zz_axi_probe2 ENABLE ROW LEVEL SECURITY;
ALTER POLICY "Service role full access" ON public.webapp_pages TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;
-- axi_mora_resumen: CEO o staff Facturacion.ver (lee facturas directo, search_path='')
-- axi_flujo_mensual: CEO o staff EstadoCuenta.ver; mismo criterio que ECG (libro_financiero)
-- axi_codigo_inquilino/propietario/proveedor: gate private.es_staff() (marca AXI_GATE)
-- fn_facturacion_mensual_preview: gate CEO o staff Facturacion.ver (marca AXI_GATE)
-- Verificado: visitante bloqueado en todo; propietario ve 2 cobros (los suyos); inquilino 0;
-- flujo dashboard = 127000.00/93597.16/33402.84 (= ECG).
