-- No modifica roles, registros de negocio ni políticas de lectura.
BEGIN;
ALTER FUNCTION public.fn_set_updated_at() SET search_path = '';
UPDATE storage.buckets
SET file_size_limit = 10485760
WHERE id = 'mant-evidencia';
ALTER POLICY axi_mantev_subir ON storage.objects
WITH CHECK (
  bucket_id = 'mant-evidencia'
  AND (SELECT private.es_ceo())
  AND lower(storage.extension(name)) IN ('png', 'jpg', 'jpeg')
);
COMMIT;
