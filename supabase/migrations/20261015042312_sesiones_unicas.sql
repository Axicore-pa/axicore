-- AXI-CGPT-010: primera sesión prevalece; activación separada al terminar el despliegue.
CREATE TABLE private.axi_sesion_config (
  id boolean PRIMARY KEY DEFAULT true CHECK(id),
  habilitada boolean NOT NULL DEFAULT false
);
INSERT INTO private.axi_sesion_config DEFAULT VALUES;
CREATE TABLE private.axi_sesiones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  correo text NOT NULL UNIQUE CHECK(correo = lower(btrim(correo))),
  auth_session_id uuid NOT NULL,
  tab_hash bytea NOT NULL,
  historial_id bigint,
  inicio timestamptz NOT NULL DEFAULT now(),
  ultima_actividad timestamptz NOT NULL DEFAULT now(),
  ultimo_aviso timestamptz,
  agente text
);
CREATE TABLE private.axi_sesion_eventos (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha timestamptz NOT NULL DEFAULT now(),
  tipo text NOT NULL CHECK(tipo IN ('inicio','bloqueo','cierre','liberacion','auth_revocada')),
  auth_user_id uuid,
  actor uuid,
  sesion_id uuid,
  auth_session_id uuid,
  detalle text
);
CREATE INDEX ON private.axi_sesion_eventos(auth_user_id,fecha DESC);
CREATE INDEX ON private.axi_sesion_eventos(auth_session_id) WHERE tipo IN ('cierre','liberacion');
ALTER TABLE private.axi_sesion_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.axi_sesiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.axi_sesion_eventos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.axi_sesion_config,private.axi_sesiones,private.axi_sesion_eventos FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private.axi_sesion_habilitada() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT habilitada FROM private.axi_sesion_config WHERE id;
$$;
CREATE FUNCTION private.axi_tab_hash() RETURNS bytea
LANGUAGE sql STABLE SET search_path='' AS $$
  SELECT CASE WHEN coalesce(nullif(current_setting('request.headers',true),'')::jsonb->>'x-axicore-tab','') ~ '^[a-f0-9]{64}$'
    THEN extensions.digest(nullif(current_setting('request.headers',true),'')::jsonb->>'x-axicore-tab','sha256') END;
$$;
-- Storage/Realtime no siempre propagan cabeceras de la web: validar también auth.sessions.
CREATE FUNCTION private.axi_sesion_auth_valida() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT NOT private.axi_sesion_habilitada() OR EXISTS (
   SELECT 1 FROM private.axi_sesiones s JOIN auth.sessions a ON a.id=s.auth_session_id AND a.user_id=s.auth_user_id
   WHERE s.auth_user_id=(SELECT auth.uid())
     AND s.auth_session_id::text=(SELECT auth.jwt()->>'session_id')
     AND (a.not_after IS NULL OR a.not_after>now())
 );
$$;
CREATE FUNCTION private.axi_sesion_valida() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT NOT private.axi_sesion_habilitada() OR (private.axi_sesion_auth_valida() AND EXISTS (
   SELECT 1 FROM private.axi_sesiones s WHERE s.auth_user_id=(SELECT auth.uid()) AND s.tab_hash=private.axi_tab_hash()
 ));
$$;
CREATE FUNCTION private.axi_sesion_guard() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ruta text := ltrim(coalesce(current_setting('request.path',true),''),'/');
BEGIN
 IF NOT private.axi_sesion_habilitada() OR (SELECT auth.jwt()->>'role')='service_role' THEN RETURN; END IF;
 IF ruta = ANY(ARRAY['rpc/axi_sesion_iniciar','rpc/axi_sesion_cerrar','rpc/axi_sesion_estado','rpc/axi_sesiones_listar','rpc/axi_sesion_liberar']) THEN RETURN; END IF;
 IF NOT private.axi_sesion_valida() THEN
   RAISE EXCEPTION 'AXI_SESSION_INVALID: Sesión no vigente. Inicie sesión en AXICORE.' USING ERRCODE='42501';
 END IF;
END $$;
-- Las funciones SECURITY DEFINER existentes quedan cubiertas antes de ejecutarse.
REVOKE ALL ON FUNCTION private.axi_sesion_habilitada(),private.axi_tab_hash(),private.axi_sesion_auth_valida(),private.axi_sesion_valida(),private.axi_sesion_guard() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.axi_sesion_habilitada(),private.axi_tab_hash(),private.axi_sesion_auth_valida(),private.axi_sesion_valida(),private.axi_sesion_guard() TO authenticated,service_role,authenticator;
DO $$
DECLARE t record;
BEGIN
 FOR t IN SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE (n.nspname='public' OR (n.nspname='storage' AND c.relname='objects')) AND c.relkind IN ('r','p') AND c.relrowsecurity
   AND has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE')
 LOOP
   EXECUTE format('CREATE POLICY axi_sesion_unica ON %I.%I AS RESTRICTIVE FOR ALL TO authenticated USING ((SELECT private.axi_sesion_auth_valida())) WITH CHECK ((SELECT private.axi_sesion_auth_valida()))',t.nspname,t.relname);
 END LOOP;
END $$;
ALTER ROLE authenticator SET pgrst.db_pre_request='private.axi_sesion_guard';
NOTIFY pgrst,'reload config';

CREATE FUNCTION public.axi_sesion_estado() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE valida boolean := private.axi_sesion_valida();
BEGIN
 IF valida THEN UPDATE private.axi_sesiones SET ultima_actividad=now() WHERE auth_user_id=auth.uid() AND tab_hash=private.axi_tab_hash(); END IF;
 RETURN jsonb_build_object('valida',valida);
END $$;

CREATE OR REPLACE FUNCTION public.axi_sesion_cerrar() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s private.axi_sesiones;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Autenticación requerida'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 SELECT * INTO s FROM private.axi_sesiones WHERE auth_user_id=auth.uid()
   AND auth_session_id::text=(auth.jwt()->>'session_id') AND tab_hash=private.axi_tab_hash() FOR UPDATE;
 IF FOUND THEN
   UPDATE public.historial_sesiones SET activa=false,fecha_hora_fin=now() WHERE id=s.historial_id;
   DELETE FROM private.axi_sesiones WHERE id=s.id;
   INSERT INTO private.axi_sesion_eventos(tipo,auth_user_id,actor,sesion_id,auth_session_id) VALUES('cierre',auth.uid(),auth.uid(),s.id,s.auth_session_id);
 END IF;
END $$;

-- Recuperación: sólo CEO con MFA y sesión de Auth real, incluso si su ingreso fue bloqueado.
CREATE FUNCTION private.axi_sesion_exigir_ceo() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT private.es_ceo() OR EXISTS(SELECT 1 FROM private.axi_sesion_eventos WHERE auth_session_id::text=(auth.jwt()->>'session_id') AND tipo IN ('cierre','liberacion')) OR NOT EXISTS(SELECT 1 FROM auth.sessions WHERE user_id=auth.uid()
   AND id::text=(auth.jwt()->>'session_id') AND (not_after IS NULL OR not_after>now())) THEN
   RAISE EXCEPTION 'Sólo CEO con verificación en dos pasos' USING ERRCODE='42501';
 END IF;
END $$;
REVOKE ALL ON FUNCTION private.axi_sesion_exigir_ceo() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.axi_sesiones_listar() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM private.axi_sesion_exigir_ceo();
 RETURN (SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'correo',correo,'inicio',inicio,'ultima_actividad',ultima_actividad,'agente',agente) ORDER BY inicio),'[]'::jsonb) FROM private.axi_sesiones);
END $$;
CREATE FUNCTION public.axi_sesion_liberar(p_id uuid,p_motivo text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s private.axi_sesiones;
BEGIN
 PERFORM private.axi_sesion_exigir_ceo();
 IF length(btrim(coalesce(p_motivo,'')))<10 OR length(p_motivo)>500 THEN RAISE EXCEPTION 'Explique el motivo (10 a 500 caracteres) después de verificar al usuario'; END IF;
 SELECT * INTO s FROM private.axi_sesiones WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'La sesión ya cambió. Actualice la lista.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(s.auth_user_id::text,0));
 DELETE FROM private.axi_sesiones WHERE id=p_id RETURNING * INTO s;
 IF NOT FOUND THEN RAISE EXCEPTION 'La sesión ya cambió. Actualice la lista.'; END IF;
 UPDATE public.historial_sesiones SET activa=false,fecha_hora_fin=now() WHERE id=s.historial_id;
 INSERT INTO private.axi_sesion_eventos(tipo,auth_user_id,actor,sesion_id,auth_session_id,detalle) VALUES('liberacion',s.auth_user_id,auth.uid(),s.id,s.auth_session_id,btrim(p_motivo));
END $$;
REVOKE ALL ON FUNCTION public.axi_sesion_estado(),public.axi_sesiones_listar(),public.axi_sesion_liberar(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.axi_sesion_estado(),public.axi_sesiones_listar(),public.axi_sesion_liberar(uuid,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.axi_sesion_iniciar()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_acceso public.accesos;
  v_usuario public.usuarios;
  v_nombre text;
  v_id bigint;
  v_sid uuid;
  v_mail text;
  v_tab bytea;
  v_s private.axi_sesiones;
  v_to text;
  v_event bigint;
  v_body text;
BEGIN
  SELECT * INTO v_acceso FROM public.accesos a
   WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo
   ORDER BY CASE a.rol WHEN 'CEO' THEN 1 WHEN 'Asistente' THEN 2 WHEN 'Administrador' THEN 3 ELSE 4 END
   LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no tiene acceso al sistema';
  END IF;
  SELECT * INTO v_usuario FROM public.usuarios u WHERE u.id = v_acceso.usuario_id;
  v_nombre := coalesce(v_usuario.nombre_completo,
                       (SELECT ad.nombre FROM public.administradores ad WHERE ad.id = v_acceso.administrador_id), '');
  IF v_acceso.rol IN ('CEO','Asistente','Administrador') AND NOT private.aal2_ok() THEN
    RETURN jsonb_build_object('requiere_2fa', true, 'rol', v_acceso.rol, 'nombre', v_nombre);
  END IF;

  v_tab := private.axi_tab_hash();
  -- Compatibilidad temporal antes de activar la regla, sin crear bloqueos heredados.
  IF NOT private.axi_sesion_habilitada() AND v_tab IS NULL THEN
    INSERT INTO public.historial_sesiones(usuario_id,usuario_login,nombre_usuario,rol,nivel_acceso,fecha_hora_inicio,activa)
    VALUES(v_acceso.usuario_id,v_usuario.usuario_login,v_nombre,v_acceso.rol,v_usuario.nivel_acceso,now(),true);
    RETURN jsonb_build_object('rol',v_acceso.rol,'usuario_id',v_acceso.usuario_id,'nombre',v_nombre,'condominio_id',v_acceso.condominio_id);
  END IF;
  IF v_tab IS NULL THEN RAISE EXCEPTION 'Recargue AXICORE para actualizar la seguridad de acceso.'; END IF;
  SELECT a.id,lower(btrim(u.email)) INTO v_sid,v_mail FROM auth.sessions a JOIN auth.users u ON u.id=a.user_id
    WHERE a.id::text=(auth.jwt()->>'session_id') AND a.user_id=auth.uid() AND (a.not_after IS NULL OR a.not_after>now());
  IF NOT FOUND OR coalesce(v_mail,'')='' THEN RAISE EXCEPTION 'Sesión de autenticación no vigente'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
  -- Correo normalizado también es único; este bloqueo cubre identidades anómalas.
  PERFORM pg_advisory_xact_lock(hashtextextended('correo:'||v_mail,0));
  IF EXISTS(SELECT 1 FROM private.axi_sesion_eventos WHERE auth_session_id=v_sid AND tipo IN ('cierre','liberacion')) THEN
    RAISE EXCEPTION 'Esta sesión fue cerrada o liberada. Inicie sesión nuevamente con su correo, clave y verificación si corresponde.';
  END IF;
  SELECT * INTO v_s FROM private.axi_sesiones WHERE auth_user_id=auth.uid() OR correo=v_mail FOR UPDATE;
  IF FOUND AND NOT EXISTS(SELECT 1 FROM auth.sessions a WHERE a.id=v_s.auth_session_id AND a.user_id=v_s.auth_user_id AND (a.not_after IS NULL OR a.not_after>now())) THEN
    UPDATE public.historial_sesiones SET activa=false,fecha_hora_fin=now() WHERE id=v_s.historial_id;
    DELETE FROM private.axi_sesiones WHERE id=v_s.id;
    INSERT INTO private.axi_sesion_eventos(tipo,auth_user_id,actor,sesion_id) VALUES('auth_revocada',v_s.auth_user_id,auth.uid(),v_s.id);
    v_s := NULL;
  END IF;
  IF v_s.id IS NOT NULL THEN
    IF v_s.auth_user_id=auth.uid() AND v_s.auth_session_id=v_sid AND v_s.tab_hash=v_tab THEN
      UPDATE private.axi_sesiones SET ultima_actividad=now() WHERE id=v_s.id;
      RETURN jsonb_build_object('rol',v_acceso.rol,'usuario_id',v_acceso.usuario_id,'nombre',v_nombre,'condominio_id',v_acceso.condominio_id);
    END IF;
    INSERT INTO private.axi_sesion_eventos(tipo,auth_user_id,actor,sesion_id,detalle)
      VALUES('bloqueo',auth.uid(),auth.uid(),v_s.id,'Segundo ingreso rechazado; primera sesión conservada') RETURNING id INTO v_event;
    IF v_s.ultimo_aviso IS NULL OR v_s.ultimo_aviso<=now()-interval '5 minutes' THEN
      v_body := 'AXICORE bloqueó un intento de abrir una segunda sesión de su cuenta ('||v_mail||').'
        ||E'\nFecha (UTC): '||to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS')
        ||E'\nLa primera sesión permanece abierta. Para acceder desde otra ventana o dispositivo, cierre primero la sesión actual.'
        ||E'\nSi no reconoce este intento, contacte al CEO para revisar su cuenta.'
        ||E'\nReferencia de seguridad: '||v_event;
      FOR v_to IN SELECT DISTINCT lower(btrim(email)) FROM (
          SELECT v_mail AS email UNION ALL
          SELECT u.email FROM auth.users u JOIN public.accesos a ON a.auth_user_id=u.id WHERE a.activo AND a.rol='CEO'
        ) destinatarios WHERE coalesce(btrim(email),'')<>''
      LOOP
        INSERT INTO public.correos_salida(para,asunto,texto,referencia)
        VALUES(ARRAY[v_to],'AXICORE | Segundo inicio de sesión bloqueado',v_body,'seguridad-sesion:'||v_event);
      END LOOP;
      UPDATE private.axi_sesiones SET ultimo_aviso=now() WHERE id=v_s.id;
    END IF;
    RETURN jsonb_build_object('sesion_bloqueada',true,'rol',v_acceso.rol,
      'mensaje','Ya existe una sesión en curso con este correo. Cierra la otra sesión para acceder.');
  END IF;

  INSERT INTO public.historial_sesiones (
    usuario_id, usuario_login, nombre_usuario, rol, nivel_acceso, fecha_hora_inicio, activa
  ) VALUES (
    v_acceso.usuario_id, v_usuario.usuario_login, v_nombre, v_acceso.rol, v_usuario.nivel_acceso, now(), true
  ) RETURNING id INTO v_id;
  INSERT INTO private.axi_sesiones(auth_user_id,correo,auth_session_id,tab_hash,historial_id,agente)
  VALUES(auth.uid(),v_mail,v_sid,v_tab,v_id,left(coalesce(nullif(current_setting('request.headers',true),'')::jsonb->>'user-agent',''),250)) RETURNING * INTO v_s;
  INSERT INTO private.axi_sesion_eventos(tipo,auth_user_id,actor,sesion_id) VALUES('inicio',auth.uid(),auth.uid(),v_s.id);
  RETURN jsonb_build_object('rol', v_acceso.rol, 'usuario_id', v_acceso.usuario_id,
    'nombre', v_nombre, 'condominio_id', v_acceso.condominio_id);
END $function$


