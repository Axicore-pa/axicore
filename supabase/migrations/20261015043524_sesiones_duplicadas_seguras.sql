-- Una copia notifica un rechazo, nunca reclama un registro sin propietario.
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

  IF nullif(current_setting('request.headers',true),'')::jsonb->>'x-axicore-duplicate' = '1' THEN
    RETURN jsonb_build_object('sesion_bloqueada',true,'mensaje','Cierre la pestaña duplicada o inicie sesión nuevamente con su correo y clave.');
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




