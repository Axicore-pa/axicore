-- Recuperación de policies/configuración previa a la migración 20261016053142.
-- No restaura archivos borrados porque esta migración no elimina objetos.
CREATE POLICY axi_comprobantes_subir ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='comprobantes'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND (SELECT private.es_residente())
);

UPDATE storage.buckets SET allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp','image/heic','application/pdf']::text[] WHERE id='comprobantes';
UPDATE storage.buckets SET allowed_mime_types=ARRAY['application/pdf']::text[] WHERE id='documentos';
UPDATE storage.buckets SET allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp','image/heic']::text[] WHERE id='glp-fotos';
UPDATE storage.buckets SET allowed_mime_types=NULL WHERE id='mant-evidencia';
UPDATE storage.buckets SET allowed_mime_types=ARRAY['application/pdf','image/png','image/jpeg','image/jpg','image/webp','image/heic']::text[] WHERE id='pagos-proveedores';

DROP POLICY axi_documentos_subir ON storage.objects;
CREATE POLICY axi_documentos_subir ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id='documentos' AND private.puede_gestionar_documento(name));

DROP POLICY axi_glpfotos_subir ON storage.objects;
CREATE POLICY axi_glpfotos_subir ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='glp-fotos'
  AND (storage.foldername(name))[1] ~ '^[0-9]+$'
  AND private.glp_puede(((storage.foldername(name))[1])::bigint, 'crear')
);

DROP POLICY axi_pagosprov_subir ON storage.objects;
CREATE POLICY axi_pagosprov_subir ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='pagos-proveedores'
  AND (storage.foldername(name))[1] ~ '^[0-9]+$'
  AND (private.es_ceo() OR ((storage.foldername(name))[1])::bigint = ANY (private.staff_condos('Gastos','crear')))
);