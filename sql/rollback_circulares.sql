-- Desactiva únicamente circulares; conserva archivos, acuses e historial.
DO $$BEGIN IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='axicore-circulares-correo') THEN
 PERFORM cron.unschedule('axicore-circulares-correo'); END IF;END$$;
REVOKE EXECUTE ON FUNCTION public.axi_circular_cola_tomar(),public.axi_circular_cola_finalizar(uuid,uuid,text,text,boolean,integer) FROM service_role;
REVOKE EXECUTE ON FUNCTION public.axi_circulares_listar(bigint,text),public.axi_circular_preparar(bigint,text,text,text,bigint),public.axi_circular_publicar(uuid),public.axi_circular_enviar(uuid),public.axi_circular_abrir(uuid,text),public.axi_circular_leida(uuid,text),public.axi_circular_comprobantes(uuid) FROM authenticated;
DROP POLICY IF EXISTS axi_circulares_subir ON storage.objects;
DROP POLICY IF EXISTS axi_circulares_ver ON storage.objects;
DROP POLICY IF EXISTS axi_circulares_limpiar_borrador ON storage.objects;
-- Restaurar el index.html previo y retirar los assets/circulares.* del menú publicado.
