const fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'..');
const original=fs.readFileSync(path.join(root,'supabase/migrations/20261016063556_axicore_circulares_confirmacion.sql'),'utf8');
const extract=name=>{const m=original.match(new RegExp('CREATE FUNCTION public\\.'+name+'\\([\\s\\S]*?END \\$\\$;'));if(!m)throw Error(name);return m[0].replace('CREATE FUNCTION','CREATE OR REPLACE FUNCTION');};
let prepare=extract('axi_circular_preparar')
 .replace('p_tamano bigint)','p_tamano bigint,p_codigo text DEFAULT NULL)')
 .replace(' ext:=CASE',()=>" p_codigo:=upper(btrim(p_codigo));\n IF p_codigo IS NULL OR length(p_codigo) NOT BETWEEN 3 AND 80 OR p_codigo !~ '^[A-Z0-9]+(-[A-Z0-9]+)*$' THEN RAISE EXCEPTION 'Introduzca el código del documento (letras, números y guiones). Si no ve el campo, actualice la página.'; END IF;\n ext:=CASE")
 .replace('id,condominio_id,titulo,','id,condominio_id,codigo,titulo,')
 .replace('VALUES(cid,p_condominio_id,btrim(p_titulo)','VALUES(cid,p_condominio_id,p_codigo,btrim(p_titulo)')
 .replace('END $$;',()=>"EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'Este código de circular ya está registrado. Utilice el código único del documento.' USING ERRCODE='23505';\nEND $$;");
let list=extract('axi_circulares_listar').replace('SELECT c.id,c.titulo','SELECT c.id,c.codigo,c.titulo');
let send=extract('axi_circular_enviar').replace("'Nueva circular disponible: '||c.titulo","private.axi_circular_asunto(c.codigo,c.titulo)")
 .replace("E'\\nCircular: '||c.titulo","E'\\nCircular: '||private.axi_circular_asunto(c.codigo,c.titulo)")
 .replace("No se adjuntan archivos.'","No se adjuntan archivos.\\n\\nAPA | AxiCore Property Administration\\nTel. 809-282-7776\\naxispard@gmail.com'");
let read=extract('axi_circular_leida').replace("'Comprobante de lectura: '||c.titulo","'Comprobante de lectura: '||private.axi_circular_asunto(c.codigo,c.titulo)")
 .replace("E'\\nCircular: '||c.titulo","E'\\nCircular: '||private.axi_circular_asunto(c.codigo,c.titulo)")
 .replace("aprobación del contenido.'","aprobación del contenido.\\n\\nAPA | AxiCore Property Administration\\nTel. 809-282-7776\\naxispard@gmail.com'");
const sql=`-- Código manual para nuevas circulares; conserva títulos y acuses existentes.
ALTER TABLE private.axi_circulares ADD COLUMN codigo text CHECK (codigo IS NULL OR (length(codigo) BETWEEN 3 AND 80 AND codigo ~ '^[A-Z0-9]+(-[A-Z0-9]+)*$'));
-- Recupera solo códigos inequívocos ya escritos en el título, sin renombrar documentos.
UPDATE private.axi_circulares SET codigo=substring(upper(titulo) from '^(CIR-[A-Z0-9]+-[0-9]+-[0-9]{4}) - ') WHERE titulo ~* '^CIR-[A-Z0-9]+-[0-9]+-[0-9]{4} - ';
CREATE UNIQUE INDEX axi_circulares_codigo_unico ON private.axi_circulares(codigo) WHERE codigo IS NOT NULL;
CREATE FUNCTION private.axi_circular_asunto(p_codigo text,p_titulo text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_codigo IS NULL OR left(upper(p_titulo),length(p_codigo)+3)=p_codigo||' - ' THEN p_titulo ELSE p_codigo||' - '||p_titulo END
$$;
REVOKE ALL ON FUNCTION private.axi_circular_asunto(text,text) FROM PUBLIC,anon,authenticated;
DROP FUNCTION public.axi_circular_preparar(bigint,text,text,text,bigint);
${prepare}
REVOKE ALL ON FUNCTION public.axi_circular_preparar(bigint,text,text,text,bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.axi_circular_preparar(bigint,text,text,text,bigint,text) TO authenticated;
${list}
${send}
${read}
NOTIFY pgrst, 'reload schema';
`;
fs.writeFileSync(path.join(root,'sql/circulares_codigo_correo.sql'),sql);
