-- Solo revierte este endurecimiento; no elimina archivos ni datos.
BEGIN;
ALTER FUNCTION public.fn_set_updated_at() RESET search_path;
UPDATE storage.buckets SET file_size_limit = NULL WHERE id = 'mant-evidencia';
ALTER POLICY axi_mantev_subir ON storage.objects
WITH CHECK (bucket_id = 'mant-evidencia' AND (SELECT private.es_ceo()));
COMMIT;
