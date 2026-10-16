-- Circulares: archivos privados, alcance por condominio y acuse declarativo por perfil.
-- No altera las tablas ni las colas de otros módulos.
CREATE TABLE private.axi_circulares (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), condominio_id bigint NOT NULL REFERENCES public.condominios(id),
 titulo text NOT NULL CHECK(length(titulo) BETWEEN 1 AND 180), descripcion text NOT NULL DEFAULT '' CHECK(length(descripcion)<=3000),
 archivo text NOT NULL UNIQUE, mime text NOT NULL CHECK(mime IN ('application/pdf','image/png','image/jpeg')),
 tamano bigint NOT NULL CHECK(tamano BETWEEN 1 AND 10485760), creado_por uuid NOT NULL REFERENCES auth.users(id),
 creado_at timestamptz NOT NULL DEFAULT now(), publicado_at timestamptz, enviado_at timestamptz
);
CREATE INDEX axi_circulares_condo ON private.axi_circulares(condominio_id,publicado_at DESC);
CREATE TABLE private.axi_circular_lecturas (
 circular_id uuid NOT NULL REFERENCES private.axi_circulares(id), acceso_id bigint NOT NULL REFERENCES public.accesos(id),
 auth_user_id uuid NOT NULL REFERENCES auth.users(id), visto_at timestamptz NOT NULL DEFAULT now(),
 leido_at timestamptz, comprobante uuid UNIQUE, perfil jsonb,
 PRIMARY KEY(circular_id,acceso_id)
);
CREATE INDEX axi_circular_lecturas_usuario ON private.axi_circular_lecturas(auth_user_id,circular_id);
CREATE TABLE private.axi_circular_correos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), circular_id uuid NOT NULL REFERENCES private.axi_circulares(id),
 clave text NOT NULL UNIQUE, para text NOT NULL, cc text[], asunto text NOT NULL, texto text NOT NULL,
 estado text NOT NULL DEFAULT 'Pendiente' CHECK(estado IN ('Pendiente','Procesando','Enviado','Error')),
 intentos integer NOT NULL DEFAULT 0, creado_at timestamptz NOT NULL DEFAULT now(),
 proximo_at timestamptz NOT NULL DEFAULT now(), tomado_at timestamptz, lote uuid,
 primer_intento_at timestamptz, enviado_at timestamptz, proveedor_id text, error text
);
CREATE INDEX axi_circular_correos_circular ON private.axi_circular_correos(circular_id,estado);
CREATE INDEX axi_circular_correos_pendientes ON private.axi_circular_correos(proximo_at) WHERE estado='Pendiente';
ALTER TABLE private.axi_circulares ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.axi_circular_lecturas ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.axi_circular_correos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.axi_circulares,private.axi_circular_lecturas,private.axi_circular_correos FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private.axi_circular_staff(p_condo bigint) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT (SELECT auth.uid()) IS NOT NULL AND private.axi_sesion_valida() AND private.aal2_ok()
 AND EXISTS(SELECT 1 FROM public.accesos a WHERE a.auth_user_id=(SELECT auth.uid()) AND a.activo
 AND a.rol IN ('CEO','Asistente') AND (a.condominio_id IS NULL OR a.condominio_id=p_condo))
$$;
CREATE FUNCTION private.axi_circular_acceso(p_condo bigint,p_rol text) RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT min(a.id) FROM public.accesos a WHERE a.auth_user_id=(SELECT auth.uid()) AND a.activo AND a.condominio_id=p_condo
 AND a.rol=p_rol AND a.rol IN ('Propietario','Inquilino','Administrador') AND private.axi_sesion_valida()
 AND (a.rol<>'Administrador' OR private.aal2_ok())
 HAVING count(*)=1
$$;
CREATE FUNCTION private.axi_circular_ver(p_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce((SELECT private.axi_circular_staff(c.condominio_id) OR (c.publicado_at IS NOT NULL
 AND private.axi_sesion_valida() AND c.condominio_id=ANY(private.condos_residente())) FROM private.axi_circulares c WHERE c.id=p_id),false)
$$;
CREATE FUNCTION private.axi_circular_storage(p_name text,p_escritura boolean) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce((SELECT CASE WHEN p_escritura THEN c.publicado_at IS NULL AND c.creado_por=(SELECT auth.uid())
 AND private.axi_circular_staff(c.condominio_id) ELSE private.axi_circular_ver(c.id) END
 FROM private.axi_circulares c WHERE c.archivo=p_name),false)
$$;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('circulares','circulares',false,10485760,ARRAY['application/pdf','image/png','image/jpeg']);
CREATE POLICY axi_circulares_subir ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='circulares' AND private.axi_circular_storage(name,true));
CREATE POLICY axi_circulares_ver ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='circulares' AND private.axi_circular_storage(name,false));
CREATE POLICY axi_circulares_limpiar_borrador ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='circulares' AND private.axi_circular_storage(name,true));

CREATE FUNCTION private.axi_circular_destinatarios(p_condo bigint) RETURNS TABLE(correo text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT DISTINCT lower(btrim(email)) FROM (
 SELECT email FROM public.propietarios WHERE condominio_id=p_condo AND estado='Activo'
 UNION ALL SELECT email FROM public.inquilinos WHERE condominio_id=p_condo AND estado='Activo'
 UNION ALL SELECT email FROM public.administradores WHERE condominio_id=p_condo AND estado='Activo') q
 WHERE btrim(email) ~ '^[^[:space:]@,;]+@[^[:space:]@,;]+\.[^[:space:]@,;]+$'
$$;
CREATE FUNCTION public.axi_circulares_listar(p_condominio_id bigint,p_rol text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE staff boolean:=private.axi_circular_staff(p_condominio_id); aid bigint; result jsonb;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT private.axi_sesion_valida() THEN RAISE EXCEPTION 'Sesión no válida' USING ERRCODE='42501'; END IF;
 aid:=private.axi_circular_acceso(p_condominio_id,p_rol);
 IF NOT staff AND aid IS NULL THEN RAISE EXCEPTION 'Sin acceso al condominio y perfil seleccionado' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(t ORDER BY t.publicado_at DESC NULLS FIRST,t.creado_at DESC),'[]'::jsonb) INTO result FROM (
 SELECT c.id,c.titulo,c.descripcion,c.mime,c.creado_at,c.publicado_at,c.enviado_at,r.leido_at,
 CASE WHEN staff THEN (SELECT count(*) FROM private.axi_circular_lecturas l WHERE l.circular_id=c.id AND l.leido_at IS NOT NULL) END AS lecturas,
 CASE WHEN staff THEN (SELECT jsonb_build_object('total',count(*),'enviados',count(*) FILTER(WHERE m.estado='Enviado'),
 'pendientes',count(*) FILTER(WHERE m.estado IN ('Pendiente','Procesando')),'errores',count(*) FILTER(WHERE m.estado='Error'))
 FROM private.axi_circular_correos m WHERE m.circular_id=c.id AND m.clave LIKE 'aviso:%') END AS envios
 FROM private.axi_circulares c LEFT JOIN private.axi_circular_lecturas r ON r.circular_id=c.id AND r.acceso_id=aid
 WHERE c.condominio_id=p_condominio_id AND (staff OR c.publicado_at IS NOT NULL)) t;
 RETURN jsonb_build_object('staff',staff,'circulares',result,'destinatarios',CASE WHEN staff THEN (SELECT count(*) FROM private.axi_circular_destinatarios(p_condominio_id)) END);
END $$;
CREATE FUNCTION public.axi_circular_preparar(p_condominio_id bigint,p_titulo text,p_descripcion text,p_mime text,p_tamano bigint) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE cid uuid:=gen_random_uuid(); ruta text; ext text;
BEGIN
 IF NOT private.axi_circular_staff(p_condominio_id) THEN RAISE EXCEPTION 'Solo CEO o Asistente autorizado con verificación en dos pasos' USING ERRCODE='42501'; END IF;
 ext:=CASE p_mime WHEN 'application/pdf' THEN 'pdf' WHEN 'image/png' THEN 'png' WHEN 'image/jpeg' THEN 'jpg' END;
 IF ext IS NULL THEN RAISE EXCEPTION 'Solo PDF, PNG o JPG'; END IF;
 ruta:=p_condominio_id::text||'/'||cid::text||'.'||ext;
 INSERT INTO private.axi_circulares(id,condominio_id,titulo,descripcion,archivo,mime,tamano,creado_por)
 VALUES(cid,p_condominio_id,btrim(p_titulo),coalesce(btrim(p_descripcion),''),ruta,p_mime,p_tamano,auth.uid());
 RETURN jsonb_build_object('id',cid,'archivo',ruta);
END $$;
CREATE FUNCTION public.axi_circular_publicar(p_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c private.axi_circulares;
BEGIN
 SELECT * INTO c FROM private.axi_circulares WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR NOT private.axi_circular_staff(c.condominio_id) THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE='42501'; END IF;
 IF c.publicado_at IS NOT NULL THEN RETURN; END IF;
 IF NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='circulares' AND o.name=c.archivo
 AND (o.metadata->>'size')::bigint BETWEEN 1 AND 10485760 AND o.metadata->>'mimetype'=c.mime) THEN
 RAISE EXCEPTION 'Primero cargue el archivo completo y válido'; END IF;
 UPDATE private.axi_circulares SET publicado_at=now() WHERE id=p_id;
END $$;
CREATE FUNCTION public.axi_circular_enviar(p_id uuid) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c private.axi_circulares; n integer; condo text;
BEGIN
 SELECT * INTO c FROM private.axi_circulares WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR NOT private.axi_circular_staff(c.condominio_id) THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE='42501'; END IF;
 IF c.publicado_at IS NULL THEN RAISE EXCEPTION 'Publique la circular antes de enviarla'; END IF;
 IF c.enviado_at IS NOT NULL THEN SELECT count(*) INTO n FROM private.axi_circular_correos WHERE circular_id=c.id AND clave LIKE 'aviso:%'; RETURN n; END IF;
 SELECT nombre INTO condo FROM public.condominios WHERE id=c.condominio_id;
 INSERT INTO private.axi_circular_correos(circular_id,clave,para,cc,asunto,texto)
 SELECT c.id,'aviso:'||c.id::text||':'||d.correo,d.correo,ARRAY['axispard@gmail.com'],
 'Nueva circular disponible: '||c.titulo,
 'Condominio: '||condo||E'\nCircular: '||c.titulo||E'\n\n'||c.descripcion||
 E'\n\nInicie sesión en AXICORE y abra Informaciones y circulares para consultarla y confirmar su lectura.\nhttps://axicore-pa.github.io/axicore/\n\nNo se adjuntan archivos.'
 FROM private.axi_circular_destinatarios(c.condominio_id) d ON CONFLICT(clave) DO NOTHING;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n=0 THEN RAISE EXCEPTION 'No hay residentes activos con email válido en este condominio'; END IF;
 UPDATE private.axi_circulares SET enviado_at=now() WHERE id=p_id;
 RETURN n;
END $$;
CREATE FUNCTION public.axi_circular_abrir(p_id uuid,p_rol text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c private.axi_circulares; aid bigint;
BEGIN
 SELECT * INTO c FROM private.axi_circulares WHERE id=p_id;
 IF NOT FOUND OR NOT private.axi_circular_ver(p_id) THEN RAISE EXCEPTION 'Sin acceso a la circular' USING ERRCODE='42501'; END IF;
 aid:=private.axi_circular_acceso(c.condominio_id,p_rol);
 IF aid IS NOT NULL AND c.publicado_at IS NOT NULL THEN
 INSERT INTO private.axi_circular_lecturas(circular_id,acceso_id,auth_user_id) VALUES(c.id,aid,auth.uid()) ON CONFLICT DO NOTHING;
 END IF;
 RETURN jsonb_build_object('archivo',c.archivo,'mime',c.mime,'titulo',c.titulo);
END $$;
CREATE FUNCTION public.axi_circular_leida(p_id uuid,p_rol text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
 VALUES(c.id,'lectura:'||c.id::text||':'||aid::text,'axispard@gmail.com','Comprobante de lectura: '||c.titulo,
 'Comprobante: '||recibo::text||E'\nCircular: '||c.titulo||E'\nCircular ID: '||c.id::text||E'\nCondominio: '||coalesce(condo,'')||
 E'\nNombre: '||coalesce(nombre,'')||E'\nPerfil: '||a.rol||E'\nPerfil ID: '||coalesce(a.propietario_id,a.inquilino_id,a.administrador_id)::text||
 E'\nCorreo del perfil: '||coalesce(correo,'')||E'\nUnidades: '||coalesce(unidades,'')||E'\nCuenta: '||auth.uid()::text||
 E'\nFecha (UTC): '||to_char(fecha AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS')||E'\n\nEl usuario ha declarado haber leído y estar en conocimiento de esta información. Este acuse no acredita comprensión ni aprobación del contenido.');
 RETURN jsonb_build_object('comprobante',recibo,'leido_at',fecha);
END $$;
CREATE FUNCTION public.axi_circular_comprobantes(p_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE c private.axi_circulares;
BEGIN
 SELECT * INTO c FROM private.axi_circulares WHERE id=p_id;
 IF NOT FOUND OR NOT private.axi_circular_staff(c.condominio_id) THEN RAISE EXCEPTION 'Sin permiso' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('lecturas',(SELECT coalesce(jsonb_agg(jsonb_build_object('comprobante',r.comprobante,'leido_at',r.leido_at,'perfil',r.perfil) ORDER BY r.leido_at DESC),'[]')
 FROM private.axi_circular_lecturas r WHERE r.circular_id=c.id AND r.leido_at IS NOT NULL),
 'correos',(SELECT coalesce(jsonb_agg(jsonb_build_object('para',m.para,'tipo',CASE WHEN m.clave LIKE 'lectura:%' THEN 'Comprobante' ELSE 'Aviso' END,
 'estado',m.estado,'enviado_at',m.enviado_at,'error',m.error) ORDER BY m.creado_at),'[]') FROM private.axi_circular_correos m WHERE m.circular_id=c.id));
END $$;

-- Solo el servicio de correo puede tomar y finalizar trabajos. Lotes con arrendamiento y exclusión global.
CREATE FUNCTION public.axi_circular_cola_tomar() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; token uuid:=gen_random_uuid();
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Solo servicio' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(74261016);
 UPDATE private.axi_circular_correos SET estado='Error',error='Requiere revisión: límite de reintentos o ventana de envío superada.'
 WHERE estado IN ('Pendiente','Procesando') AND (intentos>=6 OR primer_intento_at<now()-interval '23 hours')
 AND (tomado_at IS NULL OR tomado_at<now()-interval '5 minutes');
 IF EXISTS(SELECT 1 FROM private.axi_circular_correos WHERE estado='Procesando' AND tomado_at>now()-interval '5 minutes') THEN RETURN '[]'; END IF;
 UPDATE private.axi_circular_correos SET estado='Pendiente',lote=NULL WHERE estado='Procesando' AND tomado_at<=now()-interval '5 minutes';
 WITH jobs AS(SELECT id FROM private.axi_circular_correos WHERE estado='Pendiente' AND proximo_at<=now() AND intentos<6 ORDER BY creado_at LIMIT 5 FOR UPDATE SKIP LOCKED),
 taken AS(UPDATE private.axi_circular_correos m SET estado='Procesando',tomado_at=now(),lote=token,intentos=m.intentos+1,primer_intento_at=coalesce(m.primer_intento_at,now())
 FROM jobs WHERE m.id=jobs.id RETURNING m.id,m.lote,m.para,m.cc,m.asunto,m.texto,m.intentos)
 SELECT coalesce(jsonb_agg(taken),'[]') INTO result FROM taken;
 RETURN result;
END $$;
CREATE FUNCTION public.axi_circular_cola_finalizar(p_id uuid,p_lote uuid,p_proveedor text,p_error text,p_reintentar boolean DEFAULT false,p_espera integer DEFAULT 300) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Solo servicio' USING ERRCODE='42501'; END IF;
 UPDATE private.axi_circular_correos SET estado=CASE WHEN p_error IS NULL THEN 'Enviado' WHEN p_reintentar AND intentos<6 THEN 'Pendiente' ELSE 'Error' END,
 enviado_at=CASE WHEN p_error IS NULL THEN now() END,proveedor_id=p_proveedor,error=left(p_error,500),
 proximo_at=now()+make_interval(secs=>greatest(60,least(p_espera,7200))),lote=NULL,tomado_at=NULL
 WHERE id=p_id AND lote=p_lote AND estado='Procesando';
 IF NOT FOUND THEN RAISE EXCEPTION 'Lote vencido o ya finalizado'; END IF;
END $$;

-- Lista cerrada de permisos: ningún RPC de negocio admite anon o service_role por omisión.
REVOKE ALL ON FUNCTION private.axi_circular_staff(bigint),private.axi_circular_acceso(bigint,text),private.axi_circular_ver(uuid),private.axi_circular_storage(text,boolean),private.axi_circular_destinatarios(bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.axi_circular_storage(text,boolean) TO authenticated;
REVOKE ALL ON FUNCTION public.axi_circulares_listar(bigint,text),public.axi_circular_preparar(bigint,text,text,text,bigint),public.axi_circular_publicar(uuid),public.axi_circular_enviar(uuid),public.axi_circular_abrir(uuid,text),public.axi_circular_leida(uuid,text),public.axi_circular_comprobantes(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.axi_circulares_listar(bigint,text),public.axi_circular_preparar(bigint,text,text,text,bigint),public.axi_circular_publicar(uuid),public.axi_circular_enviar(uuid),public.axi_circular_abrir(uuid,text),public.axi_circular_leida(uuid,text),public.axi_circular_comprobantes(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.axi_circular_cola_tomar(),public.axi_circular_cola_finalizar(uuid,uuid,text,text,boolean,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.axi_circular_cola_tomar(),public.axi_circular_cola_finalizar(uuid,uuid,text,text,boolean,integer) TO service_role;
