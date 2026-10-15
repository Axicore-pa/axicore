-- AXI-CGPT-011: un aviso silencioso por sesión nueva aceptada, sólo al CEO.
CREATE FUNCTION private.axi_sesion_avisar_inicio() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_nombre text;
  v_rol text;
  v_destino text;
  v_texto text;
BEGIN
  SELECT coalesce(nullif(u.nombre_completo,''),nullif(ad.nombre,''),NEW.correo),a.rol
    INTO v_nombre,v_rol
    FROM public.accesos a
    LEFT JOIN public.usuarios u ON u.id=a.usuario_id
    LEFT JOIN public.administradores ad ON ad.id=a.administrador_id
    WHERE a.auth_user_id=NEW.auth_user_id AND a.activo
    ORDER BY CASE a.rol WHEN 'CEO' THEN 1 WHEN 'Asistente' THEN 2 WHEN 'Administrador' THEN 3 ELSE 4 END,a.id
    LIMIT 1;
  v_texto := concat_ws(E'\n',
    'AXICORE aceptó un nuevo inicio de sesión.',
    'Usuario: '||coalesce(v_nombre,NEW.correo),
    'Correo: '||NEW.correo,
    'Rol: '||coalesce(v_rol,'Sin rol vigente'),
    'Fecha y hora (UTC): '||to_char(NEW.inicio AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS'),
    'Navegador declarado: '||regexp_replace(coalesce(nullif(NEW.agente,''),'No informado'),'[[:cntrl:]]',' ','g'),
    'Referencia: '||NEW.id,
    'Aviso automático de seguridad al CEO. Una recarga o renovación de esta misma sesión no genera otro aviso.');
  FOR v_destino IN
    SELECT DISTINCT lower(btrim(u.email)) FROM auth.users u
    JOIN public.accesos a ON a.auth_user_id=u.id
    WHERE a.activo AND a.rol='CEO' AND coalesce(btrim(u.email),'')<>''
  LOOP
    INSERT INTO public.correos_salida(para,asunto,texto,referencia)
    VALUES(ARRAY[v_destino],'AXICORE | Inicio de sesión aceptado',v_texto,'seguridad-inicio:'||NEW.id);
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.axi_sesion_avisar_inicio() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER axi_sesion_aviso_inicio
AFTER INSERT ON private.axi_sesiones
FOR EACH ROW EXECUTE FUNCTION private.axi_sesion_avisar_inicio();

