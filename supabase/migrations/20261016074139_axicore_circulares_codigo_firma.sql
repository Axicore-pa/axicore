-- Código manual para nuevas circulares; conserva títulos y acuses existentes.
ALTER TABLE private.axi_circulares ADD COLUMN codigo text CHECK (codigo IS NULL OR (length(codigo) BETWEEN 3 AND 80 AND codigo ~ '^[A-Z0-9]+(-[A-Z0-9]+)*$'));
-- Recupera solo códigos inequívocos ya escritos en el título, sin renombrar documentos.
UPDATE private.axi_circulares SET codigo=substring(upper(titulo) from '^(CIR-[A-Z0-9]+-[0-9]+-[0-9]{4}) - ') WHERE titulo ~* '^CIR-[A-Z0-9]+-[0-9]+-[0-9]{4} - ';
CREATE UNIQUE INDEX axi_circulares_codigo_unico ON private.axi_circulares(codigo) WHERE codigo IS NOT NULL;
CREATE FUNCTION private.axi_circular_asunto(p_codigo text,p_titulo text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_codigo IS NULL OR left(upper(p_titulo),length(p_codigo)+3)=p_codigo||' - ' THEN p_titulo ELSE p_codigo||' - '||p_titulo END
$$;
REVOKE ALL ON FUNCTION private.axi_circular_asunto(text,text) FROM PUBLIC,anon,authenticated;
DROP FUNCTION public.axi_circular_preparar(bigint,text,text,text,bigint);
CREATE OR REPLACE FUNCTION public.axi_circular_preparar(p_condominio_id bigint,p_titulo text,p_descripcion text,p_mime text,p_tamano bigint,p_codigo text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE cid uuid:=gen_random_uuid(); ruta text; ext text;
BEGIN
 IF NOT private.axi_circular_staff(p_condominio_id) THEN RAISE EXCEPTION 'Solo CEO o Asistente autorizado con verificación en dos pasos' USING ERRCODE='42501'; END IF;
 p_codigo:=upper(btrim(p_codigo));
 IF p_codigo IS NULL OR length(p_codigo) NOT BETWEEN 3 AND 80 OR p_codigo !~ '^[A-Z0-9]+(-[A-Z0-9]+)*$' THEN RAISE EXCEPTION 'Introduzca el código del documento (letras, números y guiones). Si no ve el campo, actualice la página.'; END IF;
 ext:=CASE p_mime WHEN 'application/pdf' THEN 'pdf' WHEN 'image/png' THEN 'png' WHEN 'image/jpeg' THEN 'jpg' END;
 IF ext IS NULL THEN RAISE EXCEPTION 'Solo PDF, PNG o JPG'; END IF;
 ruta:=p_condominio_id::text||'/'||cid::text||'.'||ext;
 INSERT INTO private.axi_circulares(id,condominio_id,codigo,titulo,descripcion,archivo,mime,tamano,creado_por)
 VALUES(cid,p_condominio_id,p_codigo,btrim(p_titulo),coalesce(btrim(p_descripcion),''),ruta,p_mime,p_tamano,auth.uid());
 RETURN jsonb_build_object('id',cid,'archivo',ruta);
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'Este código de circular ya está registrado. Utilice el código único del documento.' USING ERRCODE='23505';
END $$;
REVOKE ALL ON FUNCTION public.axi_circular_preparar(bigint,text,text,text,bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.axi_circular_preparar(bigint,text,text,text,bigint,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.axi_circulares_listar(p_condominio_id bigint,p_rol text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE staff boolean:=private.axi_circular_staff(p_condominio_id); aid bigint; result jsonb;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT private.axi_sesion_valida() THEN RAISE EXCEPTION 'Sesión no válida' USING ERRCODE='42501'; END IF;
 aid:=private.axi_circular_acceso(p_condominio_id,p_rol);
 IF NOT staff AND aid IS NULL THEN RAISE EXCEPTION 'Sin acceso al condominio y perfil seleccionado' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(t ORDER BY t.publicado_at DESC NULLS FIRST,t.creado_at DESC),'[]'::jsonb) INTO result FROM (
 SELECT c.id,c.codigo,c.titulo,c.descripcion,c.mime,c.creado_at,c.publicado_at,c.enviado_at,r.leido_at,
 CASE WHEN staff THEN (SELECT count(*) FROM private.axi_circular_lecturas l WHERE l.circular_id=c.id AND l.leido_at IS NOT NULL) END AS lecturas,
 CASE WHEN staff THEN (SELECT jsonb_build_object('total',count(*),'enviados',count(*) FILTER(WHERE m.estado='Enviado'),
 'pendientes',count(*) FILTER(WHERE m.estado IN ('Pendiente','Procesando')),'errores',count(*) FILTER(WHERE m.estado='Error'))
 FROM private.axi_circular_correos m WHERE m.circular_id=c.id AND m.clave LIKE 'aviso:%') END AS envios
 FROM private.axi_circulares c LEFT JOIN private.axi_circular_lecturas r ON r.circular_id=c.id AND r.acceso_id=aid
 WHERE c.condominio_id=p_condominio_id AND (staff OR c.publicado_at IS NOT NULL)) t;
 RETURN jsonb_build_object('staff',staff,'circulares',result,'destinatarios',CASE WHEN staff THEN (SELECT count(*) FROM private.axi_circular_destinatarios(p_condominio_id)) END);
END $$;
CREATE OR REPLACE FUNCTION public.axi_circular_enviar(p_id uuid) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c private.axi_circulares; n integer; condo text;
BEGIN
 SELECT * INTO c FROM private.axi_circulares WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR NOT private.axi_circular_staff(c.condominio_id) THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE='42501'; END IF;
 IF c.publicado_at IS NULL THEN RAISE EXCEPTION 'Publique la circular antes de enviarla'; END IF;
 IF c.enviado_at IS NOT NULL THEN SELECT count(*) INTO n FROM private.axi_circular_correos WHERE circular_id=c.id AND clave LIKE 'aviso:%'; RETURN n; END IF;
 SELECT nombre INTO condo FROM public.condominios WHERE id=c.condominio_id;
 INSERT INTO private.axi_circular_correos(circular_id,clave,para,cc,asunto,texto)
 SELECT c.id,'aviso:'||c.id::text||':'||d.correo,d.correo,ARRAY['axispard@gmail.com'],
 private.axi_circular_asunto(c.codigo,c.titulo),
 'Condominio: '||condo||E'\nCircular: '||private.axi_circular_asunto(c.codigo,c.titulo)||E'\n\n'||c.descripcion||
 E'\n\nInicie sesión en AXICORE y abra Informaciones y circulares para consultarla y confirmar su lectura.\nhttps://axicore-pa.github.io/axicore/\n\nNo se adjuntan archivos.\n\nAPA | AxiCore Property Administration\nTel. 809-282-7776\naxispard@gmail.com'
 FROM private.axi_circular_destinatarios(c.condominio_id) d ON CONFLICT(clave) DO NOTHING;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n=0 THEN RAISE EXCEPTION 'No hay residentes activos con email válido en este condominio'; END IF;
 UPDATE private.axi_circulares SET enviado_at=now() WHERE id=p_id;
 RETURN n;
END $$;
CREATE OR REPLACE FUNCTION public.axi_circular_leida(p_id uuid,p_rol text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c private.axi_circulares; aid bigint; lectura private.axi_circular_lecturas; a public.accesos; p jsonb; nombre text; correo text; unidades text; condo text; recibo uuid:=gen_random_uuid(); fecha timestamptz:=now();
BEGIN
 SELECT * INTO c FROM private.axi_circulares WHERE id=p_id;
 IF NOT FOUND OR c.publicado_at IS NULL THEN RAISE EXCEPTION 'Circular no disponible'; END IF;
 aid:=private.axi_circular_acceso(c.condominio_id,p_rol);
 IF aid IS NULL THEN RAISE EXCEPTION 'Solo puede confirmar su propio perfil del condominio' USING ERRCODE='42501'; END IF;
 INSERT INTO private.axi_circular_lecturas(circular_id,acceso_id,auth_user_id) VALUES(c.id,aid,auth.uid()) ON CONFLICT DO NOTHING;
 SELECT * INTO lectura FROM private.axi_circular_lecturas WHERE circular_id=c.id AND acceso_id=aid FOR UPDATE;
 IF lectura.leido_at IS NOT NULL THEN RETURN jsonb_build_object('comprobante',lectura.comprobante,'leido_at',lectura.leido_at); END IF;
 SELECT * INTO a FROM public.accesos WHERE id=aid;
 IF a.rol='Propietario' THEN
 SELECT x.nombre,x.email INTO nombre,correo FROM public.propietarios x WHERE x.id=a.propietario_id;
 ELSIF a.rol='Inquilino' THEN
 SELECT x.nombre,x.email INTO nombre,correo FROM public.inquilinos x WHERE x.id=a.inquilino_id;
 ELSE SELECT x.nombre,x.email INTO nombre,correo FROM public.administradores x WHERE x.id=a.administrador_id; END IF;
 SELECT string_agg(u.codigo,', ' ORDER BY u.codigo) INTO unidades FROM public.unidades u WHERE u.condominio_id=c.condominio_id AND (
 (a.rol='Inquilino' AND EXISTS(SELECT 1 FROM public.inquilinos i WHERE i.id=a.inquilino_id AND i.unidad_id=u.id)) OR
 (a.rol='Propietario' AND (u.propietario_id=a.propietario_id OR EXISTS(SELECT 1 FROM public.unidad_propietarios up WHERE up.unidad_id=u.id AND up.propietario_id=a.propietario_id AND up.fecha_fin IS NULL AND (up.fecha_inicio IS NULL OR up.fecha_inicio<=now())))) OR
 (a.rol='Administrador' AND EXISTS(SELECT 1 FROM public.unidad_administradores ua WHERE ua.unidad_id=u.id AND ua.administrador_id=a.administrador_id AND ua.fecha_fin IS NULL AND ua.fecha_inicio<=(now() AT TIME ZONE 'America/Santo_Domingo')::date)));
 SELECT x.nombre INTO condo FROM public.condominios x WHERE x.id=c.condominio_id;
 p:=jsonb_build_object('nombre',nombre,'correo',correo,'rol',a.rol,'perfil_id',coalesce(a.propietario_id,a.inquilino_id,a.administrador_id),
 'condominio',condo,'unidades',unidades,'usuario',auth.uid());
 UPDATE private.axi_circular_lecturas SET leido_at=fecha,comprobante=recibo,perfil=p WHERE circular_id=c.id AND acceso_id=aid;
 INSERT INTO private.axi_circular_correos(circular_id,clave,para,asunto,texto)
 VALUES(c.id,'lectura:'||c.id::text||':'||aid::text,'axispard@gmail.com','Comprobante de lectura: '||private.axi_circular_asunto(c.codigo,c.titulo),
 'Comprobante: '||recibo::text||E'\nCircular: '||private.axi_circular_asunto(c.codigo,c.titulo)||E'\nCircular ID: '||c.id::text||E'\nCondominio: '||coalesce(condo,'')||
 E'\nNombre: '||coalesce(nombre,'')||E'\nPerfil: '||a.rol||E'\nPerfil ID: '||coalesce(a.propietario_id,a.inquilino_id,a.administrador_id)::text||
 E'\nCorreo del perfil: '||coalesce(correo,'')||E'\nUnidades: '||coalesce(unidades,'')||E'\nCuenta: '||auth.uid()::text||
 E'\nFecha (UTC): '||to_char(fecha AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS')||E'\n\nEl usuario ha declarado haber leído y estar en conocimiento de esta información. Este acuse no acredita comprensión ni aprobación del contenido.\n\nAPA | AxiCore Property Administration\nTel. 809-282-7776\naxispard@gmail.com');
 RETURN jsonb_build_object('comprobante',recibo,'leido_at',fecha);
END $$;
NOTIFY pgrst, 'reload schema';

