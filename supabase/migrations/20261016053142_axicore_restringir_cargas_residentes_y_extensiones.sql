DO $$
BEGIN
  IF (SELECT count(*) FROM pg_policies
      WHERE schemaname='storage' AND tablename='objects'
        AND policyname IN ('axi_comprobantes_subir','axi_documentos_subir','axi_glpfotos_subir','axi_mantev_subir','axi_pagosprov_subir','axi_sesion_unica')) <> 6
  THEN RAISE EXCEPTION 'AXICORE upload policy precondition failed; stopping'; END IF;
  IF (SELECT count(*) FROM storage.buckets
      WHERE id IN ('comprobantes','documentos','glp-fotos','mant-evidencia','pagos-proveedores')) <> 5
  THEN RAISE EXCEPTION 'AXICORE upload bucket precondition failed; stopping'; END IF;
END $$;

DROP POLICY axi_comprobantes_subir ON storage.objects;

UPDATE storage.buckets SET allowed_mime_types=ARRAY['application/pdf','image/jpeg','image/png']::text[] WHERE id='comprobantes';
UPDATE storage.buckets SET allowed_mime_types=ARRAY['application/pdf']::text[] WHERE id='documentos';
UPDATE storage.buckets SET allowed_mime_types=ARRAY['image/jpeg','image/png']::text[] WHERE id='glp-fotos';
UPDATE storage.buckets SET allowed_mime_types=ARRAY['image/jpeg','image/png']::text[] WHERE id='mant-evidencia';
UPDATE storage.buckets SET allowed_mime_types=ARRAY['application/pdf','image/jpeg','image/png']::text[] WHERE id='pagos-proveedores';

DROP POLICY axi_documentos_subir ON storage.objects;
CREATE POLICY axi_documentos_subir ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id='documentos' AND private.puede_gestionar_documento(name)
            AND lower(storage.extension(name))='pdf');

DROP POLICY axi_glpfotos_subir ON storage.objects;
CREATE POLICY axi_glpfotos_subir ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id='glp-fotos'
            AND (storage.foldername(name))[1] ~ '^[0-9]+$'
            AND private.glp_puede(((storage.foldername(name))[1])::bigint, 'crear')
            AND lower(storage.extension(name)) IN ('png','jpg','jpeg'));

DROP POLICY axi_pagosprov_subir ON storage.objects;
CREATE POLICY axi_pagosprov_subir ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id='pagos-proveedores'
            AND (storage.foldername(name))[1] ~ '^[0-9]+$'
            AND (private.es_ceo() OR ((storage.foldername(name))[1])::bigint = ANY (private.staff_condos('Gastos','crear')))
            AND lower(storage.extension(name)) IN ('pdf','png','jpg','jpeg'));