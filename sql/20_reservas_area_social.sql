-- AXICORE | 20 - Reservas del Area Social en la web (decisiones de Misael 11/10/2026)
--  * Solo residentes con cuenta. Area Social exclusiva; opcional Picuzzi y BBQ.
--  * Franjas fijas: 09-11, 09-13, 14-16, 14-18, 18-21 (pausa 13:00-14:00). Lunes a domingo.
--  * Toda reserva queda Pendiente; CEO/Asistente aprueba o rechaza (rechazo con razon). Pendiente bloquea.
--  * Cambio de fecha/horario = nueva solicitud ligada; al aprobarse, la original se libera.
--  * El residente cancela cuando quiera, sin aprobacion; la administracion recibe aviso.
--  * Lista de espera "Avisame si se libera": correo cuando el horario queda libre.
--  * Correos por cola (correos_salida) que procesa la Edge Function axi-correo-cola (Gmail).
--  * Recordatorios 48h / 24h / 4h solo de reservas aprobadas.

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;

-- Permiso del modulo
INSERT INTO public.permisos (id, rol, modulo, puede_ver, puede_crear, puede_editar, puede_eliminar, puede_exportar, requiere_autorizacion, activo, created_at, updated_at)
SELECT (SELECT coalesce(max(id), 0) FROM public.permisos) + row_number() OVER (), r, 'Reservas', true, true, true, true, true, false, true, now(), now()
FROM unnest(ARRAY['CEO','Asistente']) r
WHERE NOT EXISTS (SELECT 1 FROM public.permisos p WHERE p.rol = r AND p.modulo = 'Reservas');

-- ---------------------------------------------------------------- Tablas
CREATE SEQUENCE IF NOT EXISTS public.reservas_num_seq;

CREATE TABLE IF NOT EXISTS public.reservas (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  condominio_id bigint NOT NULL REFERENCES public.condominios(id),
  codigo text UNIQUE NOT NULL,
  unidad_id bigint REFERENCES public.unidades(id),
  propietario_id bigint REFERENCES public.propietarios(id),
  inquilino_id bigint REFERENCES public.inquilinos(id),
  solicitado_por uuid,
  responsable text NOT NULL,
  unidad_texto text,
  email text NOT NULL,
  telefono text NOT NULL,
  nombre_quien_reserva text NOT NULL,
  motivo text NOT NULL,
  cantidad_personas int NOT NULL CHECK (cantidad_personas > 0),
  incluye_picuzzi boolean NOT NULL DEFAULT false,
  incluye_bbq boolean NOT NULL DEFAULT false,
  fecha date NOT NULL,
  franja text NOT NULL,
  hora_inicio time NOT NULL,
  hora_fin time NOT NULL,
  estado text NOT NULL DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente','Aprobada','Rechazada','Cancelada','Reemplazada')),
  motivo_rechazo text,
  motivo_cancelacion text,
  decidido_por text, decidido_at timestamptz,
  cancelado_por text, cancelado_at timestamptz,
  reserva_origen_id bigint REFERENCES public.reservas(id),
  origen text NOT NULL DEFAULT 'Web',
  recordatorio_48h timestamptz, recordatorio_24h timestamptz, recordatorio_4h timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  -- Area Social exclusiva: no puede haber dos reservas activas que se crucen
  CONSTRAINT reservas_sin_cruce EXCLUDE USING gist (
    condominio_id WITH =,
    tsrange(fecha + hora_inicio, fecha + hora_fin, '[)') WITH &&
  ) WHERE (estado IN ('Pendiente','Aprobada'))
);
CREATE INDEX IF NOT EXISTS reservas_fecha_idx ON public.reservas (condominio_id, fecha);
ALTER TABLE public.reservas ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.reservas_espera (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  condominio_id bigint NOT NULL REFERENCES public.condominios(id),
  fecha date NOT NULL,
  franja text NOT NULL,
  auth_user_id uuid NOT NULL,
  email text NOT NULL,
  nombre text,
  notificado_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (condominio_id, fecha, franja, auth_user_id)
);
ALTER TABLE public.reservas_espera ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.correos_salida (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  para text[] NOT NULL DEFAULT '{}',
  cc text[] NOT NULL DEFAULT '{}',
  asunto text NOT NULL,
  html text,
  texto text,
  adjuntos jsonb NOT NULL DEFAULT '[]',
  referencia text,
  estado text NOT NULL DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente','Enviado','Error')),
  intentos int NOT NULL DEFAULT 0,
  error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  enviado_at timestamptz
);
ALTER TABLE public.correos_salida ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reservas, public.reservas_espera, public.correos_salida FROM anon, authenticated;
-- Sin politicas: solo funciones SECURITY DEFINER y el service role tocan estas tablas.

-- ---------------------------------------------------------------- Helpers
CREATE OR REPLACE FUNCTION private.res_franjas()
RETURNS TABLE(franja text, inicio time, fin time, etiqueta text) LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  VALUES ('M1','09:00'::time,'11:00'::time,'9:00 a. m. - 11:00 a. m.'),
         ('M2','09:00'::time,'13:00'::time,'9:00 a. m. - 1:00 p. m.'),
         ('T1','14:00'::time,'16:00'::time,'2:00 p. m. - 4:00 p. m.'),
         ('T2','14:00'::time,'18:00'::time,'2:00 p. m. - 6:00 p. m.'),
         ('T3','18:00'::time,'21:00'::time,'6:00 p. m. - 9:00 p. m.')
$$;

CREATE OR REPLACE FUNCTION private.res_ahora() RETURNS timestamp LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT (now() AT TIME ZONE 'America/Santo_Domingo')
$$;

CREATE OR REPLACE FUNCTION private.res_staff_condos() RETURNS bigint[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT private.staff_condos('Reservas', 'editar')
$$;

CREATE OR REPLACE FUNCTION private.res_tipo(p public.reservas) RETURNS text LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT 'Área Social' || CASE WHEN p.incluye_picuzzi AND p.incluye_bbq THEN ' + Picuzzi + BBQ'
                               WHEN p.incluye_picuzzi THEN ' + Picuzzi'
                               WHEN p.incluye_bbq THEN ' + BBQ' ELSE '' END
$$;

CREATE OR REPLACE FUNCTION private.res_hora(t time) RETURNS text LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT ltrim(to_char(t, 'HH12:MI'), '0') || CASE WHEN t < '12:00' THEN ' a. m.' ELSE ' p. m.' END
$$;

-- Plantilla de correo con la marca (misma estructura que el sistema de Google)
CREATE OR REPLACE FUNCTION private.res_html(p_titulo text, p_cuerpo text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT '<div style="font-family:Arial,sans-serif;max-width:650px;color:#263238;">'
    || '<div style="background:#14233F;color:#FFFFFF;padding:20px;"><h2 style="margin:0;">AXICORE PROPERTY ADMINISTRATION</h2>'
    || '<div style="margin-top:5px;font-size:14px;">' || p_titulo || '</div></div>'
    || '<div style="padding:20px;">' || p_cuerpo
    || '<div style="margin-top:30px;padding-top:15px;border-top:1px solid #ddd;font-size:12px;color:#555;">'
    || '<strong>AXICORE PROPERTY ADMINISTRATION</strong><br>Edificio Domhouse<br>Calle las palmeras oriental #16<br>'
    || 'Los triunfadores, Santo Domingo Este<br>Santo Domingo<br>Tel: (809) 282-7776</div></div></div>'
$$;

CREATE OR REPLACE FUNCTION private.res_tabla(r public.reservas) RETURNS text LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT '<table style="width:100%;border-collapse:collapse;">'
    || '<tr><td><strong>Reserva ID</strong></td><td>' || r.codigo || '</td></tr>'
    || '<tr><td><strong>Área</strong></td><td>' || private.res_tipo(r) || '</td></tr>'
    || '<tr><td><strong>Fecha</strong></td><td>' || to_char(r.fecha, 'DD/MM/YYYY') || '</td></tr>'
    || '<tr><td><strong>Horario</strong></td><td>' || private.res_hora(r.hora_inicio) || ' - ' || private.res_hora(r.hora_fin) || '</td></tr>'
    || '<tr><td><strong>Responsable</strong></td><td>' || r.responsable || '</td></tr>'
    || '<tr><td><strong>Unidad / Apto.</strong></td><td>' || coalesce(r.unidad_texto, '') || '</td></tr>'
    || '<tr><td><strong>Nombre de quien reserva</strong></td><td>' || r.nombre_quien_reserva || '</td></tr>'
    || '<tr><td><strong>Motivo</strong></td><td>' || r.motivo || '</td></tr>'
    || '<tr><td><strong>Cantidad de personas</strong></td><td>' || r.cantidad_personas || '</td></tr>'
    || '<tr><td><strong>Teléfono</strong></td><td>' || r.telefono || '</td></tr></table>'
    || CASE WHEN r.cantidad_personas > 5 THEN
       '<div style="background:#fff3cd;padding:12px;border-left:5px solid #ffc107;margin:15px 0;"><strong>AVISO ADMINISTRATIVO:</strong> '
       || 'La reservación supera 5 personas. Conforme a las normas del Área Social, la Administración deberá informar a los demás residentes.</div>'
       ELSE '' END
$$;

CREATE OR REPLACE FUNCTION private.res_calendar_url(r public.reservas) RETURNS text LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT 'https://calendar.google.com/calendar/render?action=TEMPLATE'
    || '&text=' || replace(replace('Reserva ' || private.res_tipo(r) || ' - ' || coalesce(r.unidad_texto, ''), ' ', '%20'), '+', '%2B')
    || '&dates=' || to_char(r.fecha, 'YYYYMMDD') || 'T' || to_char(r.hora_inicio, 'HH24MI') || '00/'
    || to_char(r.fecha, 'YYYYMMDD') || 'T' || to_char(r.hora_fin, 'HH24MI') || '00'
    || '&ctz=America%2FSanto_Domingo&location=Residencial%20DH2'
    || '&details=' || replace('Reserva ID: ' || r.codigo, ' ', '%20')
$$;

CREATE OR REPLACE FUNCTION private.res_ics(r public.reservas) RETURNS jsonb LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT jsonb_build_object('nombre', 'Reserva_' || r.codigo || '.ics', 'mime', 'text/calendar',
    'base64', encode(convert_to(concat_ws(E'\r\n',
      'BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//AXICORE PROPERTY ADMINISTRATION//Reservas//ES','CALSCALE:GREGORIAN','METHOD:PUBLISH',
      'BEGIN:VEVENT','UID:' || r.codigo || '@axicore-property-administration',
      'DTSTAMP:' || to_char(now() AT TIME ZONE 'UTC', 'YYYYMMDD"T"HH24MISS"Z"'),
      'DTSTART;TZID=America/Santo_Domingo:' || to_char(r.fecha, 'YYYYMMDD') || 'T' || to_char(r.hora_inicio, 'HH24MI') || '00',
      'DTEND;TZID=America/Santo_Domingo:' || to_char(r.fecha, 'YYYYMMDD') || 'T' || to_char(r.hora_fin, 'HH24MI') || '00',
      'SUMMARY:Reserva ' || private.res_tipo(r) || ' - ' || coalesce(r.unidad_texto, ''),
      'DESCRIPTION:Reserva ID: ' || r.codigo || '\nResponsable: ' || replace(replace(r.responsable, ',', '\,'), ';', '\;'),
      'LOCATION:Residencial DH2',
      'BEGIN:VALARM','TRIGGER:-PT48H','ACTION:DISPLAY','DESCRIPTION:Recordatorio de reserva - 48 horas','END:VALARM',
      'BEGIN:VALARM','TRIGGER:-PT24H','ACTION:DISPLAY','DESCRIPTION:Recordatorio de reserva - 24 horas','END:VALARM',
      'BEGIN:VALARM','TRIGGER:-PT4H','ACTION:DISPLAY','DESCRIPTION:Recordatorio de reserva - 4 horas','END:VALARM',
      'END:VEVENT','END:VCALENDAR'), 'UTF8'), 'base64'))
$$;

CREATE OR REPLACE FUNCTION private.res_correo(p_para text[], p_cc text[], p_asunto text, p_html text, p_ref text, p_adj jsonb DEFAULT '[]')
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  INSERT INTO public.correos_salida (para, cc, asunto, html, referencia, adjuntos)
  VALUES (p_para, coalesce(p_cc, '{}'), p_asunto, p_html, p_ref, coalesce(p_adj, '[]'::jsonb));
$$;

CREATE OR REPLACE FUNCTION private.res_admin_email() RETURNS text LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT 'axispard@gmail.com'
$$;

-- Avisa a la lista de espera de las franjas que quedaron totalmente libres en esa fecha
CREATE OR REPLACE FUNCTION private.res_avisar_espera(p_condominio bigint, p_fecha date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE e record;
BEGIN
  FOR e IN
    SELECT w.*, f.inicio, f.fin, f.etiqueta FROM public.reservas_espera w
    JOIN private.res_franjas() f ON f.franja = w.franja
    WHERE w.condominio_id = p_condominio AND w.fecha = p_fecha AND w.notificado_at IS NULL
      AND (w.fecha + f.inicio) > private.res_ahora()
      AND NOT EXISTS (SELECT 1 FROM public.reservas r WHERE r.condominio_id = p_condominio AND r.fecha = p_fecha
                       AND r.estado IN ('Pendiente','Aprobada')
                       AND tsrange(r.fecha + r.hora_inicio, r.fecha + r.hora_fin, '[)') && tsrange(p_fecha + f.inicio, p_fecha + f.fin, '[)'))
  LOOP
    PERFORM private.res_correo(ARRAY[e.email], '{}', 'Horario disponible | Área Social ' || to_char(p_fecha, 'DD/MM/YYYY'),
      private.res_html('Aviso de disponibilidad',
        '<p>Hola' || coalesce(' ' || e.nombre, '') || ',</p><p>El horario que usted pidió que le avisáramos ya está <strong>disponible</strong>:</p>'
        || '<p><strong>Fecha:</strong> ' || to_char(p_fecha, 'DD/MM/YYYY') || '<br><strong>Horario:</strong> ' || e.etiqueta || '</p>'
        || '<p>Puede reservarlo entrando a la web de AXICORE. El horario se asigna a quien lo reserve primero.</p>'),
      'ESPERA-' || e.id);
    UPDATE public.reservas_espera SET notificado_at = now() WHERE id = e.id;
  END LOOP;
END $$;

-- ---------------------------------------------------------------- Residente
-- Disponibilidad del dia: solo Disponible / Reservado / No disponible (sin datos de quien reservo)
CREATE OR REPLACE FUNCTION public.fn_reserva_disponibilidad(p_fecha date)
RETURNS TABLE(franja text, etiqueta text, hora_inicio time, hora_fin time, estado text, en_espera boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_condo bigint;
BEGIN
  SELECT u.condominio_id INTO v_condo FROM public.unidades u
   WHERE u.id = ANY (private.unidades_propias() || private.unidades_inquilino()) LIMIT 1;
  IF v_condo IS NULL THEN
    v_condo := (SELECT c FROM unnest(private.res_staff_condos()) c LIMIT 1);
  END IF;
  IF v_condo IS NULL THEN RAISE EXCEPTION 'Su cuenta no tiene una unidad asignada para reservar'; END IF;
  RETURN QUERY
  SELECT f.franja, f.etiqueta, f.inicio, f.fin,
    CASE WHEN (p_fecha + f.inicio) <= private.res_ahora() THEN 'No disponible'
         WHEN EXISTS (SELECT 1 FROM public.reservas r WHERE r.condominio_id = v_condo AND r.fecha = p_fecha
                       AND r.estado IN ('Pendiente','Aprobada')
                       AND tsrange(r.fecha + r.hora_inicio, r.fecha + r.hora_fin, '[)') && tsrange(p_fecha + f.inicio, p_fecha + f.fin, '[)'))
           THEN 'Reservado'
         ELSE 'Disponible' END,
    EXISTS (SELECT 1 FROM public.reservas_espera w WHERE w.condominio_id = v_condo AND w.fecha = p_fecha
             AND w.franja = f.franja AND w.auth_user_id = (SELECT auth.uid()) AND w.notificado_at IS NULL)
  FROM private.res_franjas() f ORDER BY f.inicio, f.fin;
END $$;

-- Datos para precargar el formulario del residente
CREATE OR REPLACE FUNCTION public.fn_reserva_mis_datos()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v jsonb;
BEGIN
  SELECT jsonb_agg(jsonb_build_object('unidad_id', u.id, 'unidad', u.codigo,
           'rol', CASE WHEN u.id = ANY (private.unidades_inquilino()) THEN 'Inquilino' ELSE 'Propietario' END,
           'nombre', coalesce((SELECT i.nombre FROM public.accesos a JOIN public.inquilinos i ON i.id = a.inquilino_id
                                WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Inquilino' AND i.unidad_id = u.id LIMIT 1),
                              (SELECT p.nombre FROM public.accesos a JOIN public.propietarios p ON p.id = a.propietario_id
                                WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Propietario' LIMIT 1)),
           'email', coalesce((SELECT i.email FROM public.accesos a JOIN public.inquilinos i ON i.id = a.inquilino_id
                               WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Inquilino' AND i.unidad_id = u.id LIMIT 1),
                             (SELECT p.email FROM public.accesos a JOIN public.propietarios p ON p.id = a.propietario_id
                               WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Propietario' LIMIT 1),
                             (SELECT au.email FROM auth.users au WHERE au.id = (SELECT auth.uid()))),
           'telefono', coalesce((SELECT i.telefono FROM public.accesos a JOIN public.inquilinos i ON i.id = a.inquilino_id
                                  WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Inquilino' AND i.unidad_id = u.id LIMIT 1),
                                (SELECT p.telefono FROM public.accesos a JOIN public.propietarios p ON p.id = a.propietario_id
                                  WHERE a.auth_user_id = (SELECT auth.uid()) AND a.activo AND a.rol = 'Propietario' LIMIT 1))
         ) ORDER BY u.codigo) INTO v
  FROM public.unidades u WHERE u.id = ANY (private.unidades_propias() || private.unidades_inquilino());
  RETURN coalesce(v, '[]'::jsonb);
END $$;

-- Crear solicitud (nueva o cambio de una existente)
CREATE OR REPLACE FUNCTION public.fn_reserva_crear(p jsonb)
RETURNS public.reservas LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid()); v_unidad public.unidades; f record; v_r public.reservas; v_orig public.reservas;
  v_rol text; v_codigo text; v_inq bigint;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Debe iniciar sesión'; END IF;
  SELECT * INTO v_unidad FROM public.unidades u WHERE u.id = (p->>'unidad_id')::bigint
     AND u.id = ANY (private.unidades_propias() || private.unidades_inquilino());
  IF NOT FOUND THEN RAISE EXCEPTION 'Solo los residentes de la unidad pueden reservar'; END IF;
  v_rol := CASE WHEN v_unidad.id = ANY (private.unidades_inquilino()) THEN 'Inquilino' ELSE 'Propietario' END;
  IF v_rol = 'Inquilino' THEN
    SELECT a.inquilino_id INTO v_inq FROM public.accesos a WHERE a.auth_user_id = v_uid AND a.activo AND a.rol = 'Inquilino' LIMIT 1;
  END IF;

  SELECT * INTO f FROM private.res_franjas() x WHERE x.franja = p->>'franja';
  IF NOT FOUND THEN RAISE EXCEPTION 'Seleccione un horario válido'; END IF;
  IF (p->>'fecha') IS NULL THEN RAISE EXCEPTION 'Seleccione la fecha'; END IF;
  IF ((p->>'fecha')::date + f.inicio) <= private.res_ahora() THEN RAISE EXCEPTION 'Ese horario ya pasó. Seleccione otro.'; END IF;
  IF coalesce(btrim(p->>'responsable'), '') = '' THEN RAISE EXCEPTION 'Debe completar el campo: Nombre y Apellido'; END IF;
  IF coalesce(btrim(p->>'email'), '') !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' THEN RAISE EXCEPTION 'Debe introducir un correo electrónico válido.'; END IF;
  IF coalesce(btrim(p->>'telefono'), '') = '' THEN RAISE EXCEPTION 'Debe completar el campo: Teléfono'; END IF;
  IF coalesce(btrim(p->>'nombre_quien_reserva'), '') = '' THEN RAISE EXCEPTION 'Debe completar el campo: Nombre de quien reserva'; END IF;
  IF coalesce(btrim(p->>'motivo'), '') = '' THEN RAISE EXCEPTION 'Debe completar el campo: Motivo'; END IF;
  IF coalesce((p->>'cantidad_personas')::int, 0) < 1 THEN RAISE EXCEPTION 'La cantidad de personas debe ser mayor que cero.'; END IF;
  IF NOT coalesce((p->>'acepta_reglas')::boolean, false) THEN RAISE EXCEPTION 'Debe confirmar que ha leído y acepta las reglas de uso.'; END IF;

  IF (p->>'reserva_origen_id') IS NOT NULL THEN
    SELECT * INTO v_orig FROM public.reservas r WHERE r.id = (p->>'reserva_origen_id')::bigint AND r.solicitado_por = v_uid
       AND r.estado IN ('Pendiente','Aprobada');
    IF NOT FOUND THEN RAISE EXCEPTION 'La reserva a cambiar no existe o ya no está activa'; END IF;
    IF EXISTS (SELECT 1 FROM public.reservas r WHERE r.reserva_origen_id = v_orig.id AND r.estado = 'Pendiente') THEN
      RAISE EXCEPTION 'Ya existe una solicitud de cambio pendiente para %', v_orig.codigo; END IF;
  END IF;

  v_codigo := 'RES-' || to_char(private.res_ahora(), 'YYYYMMDD') || '-' || lpad(nextval('public.reservas_num_seq')::text, 4, '0');
  BEGIN
    INSERT INTO public.reservas (condominio_id, codigo, unidad_id, propietario_id, inquilino_id, solicitado_por, responsable, unidad_texto,
      email, telefono, nombre_quien_reserva, motivo, cantidad_personas, incluye_picuzzi, incluye_bbq, fecha, franja, hora_inicio, hora_fin,
      reserva_origen_id)
    VALUES (v_unidad.condominio_id, v_codigo, v_unidad.id, v_unidad.propietario_id, v_inq, v_uid, btrim(p->>'responsable'), v_unidad.codigo,
      btrim(p->>'email'), btrim(p->>'telefono'), btrim(p->>'nombre_quien_reserva'), btrim(p->>'motivo'), (p->>'cantidad_personas')::int,
      coalesce((p->>'incluye_picuzzi')::boolean, false), coalesce((p->>'incluye_bbq')::boolean, false),
      (p->>'fecha')::date, f.franja, f.inicio, f.fin, v_orig.id)
    RETURNING * INTO v_r;
  EXCEPTION WHEN exclusion_violation THEN
    RAISE EXCEPTION 'Ese horario acaba de ser reservado. Seleccione otro horario.';
  END;

  PERFORM private.res_correo(ARRAY[v_r.email], ARRAY[private.res_admin_email()],
    CASE WHEN v_orig.id IS NULL THEN 'Solicitud de reservación ' ELSE 'Solicitud de cambio de reservación ' END || v_r.codigo || ' | Pendiente',
    private.res_html('Reservación de Área Común',
      '<p>Su solicitud ' || CASE WHEN v_orig.id IS NULL THEN 'de reservación' ELSE 'de cambio de la reservación ' || v_orig.codigo END
      || ' fue recibida y está <strong>pendiente de aprobación</strong> por la Administración. Le notificaremos la decisión por este medio.</p>'
      || private.res_tabla(v_r)
      || '<p>Las normas de uso, seguridad, higiene y convivencia indicadas en el formulario permanecen aplicables durante toda la reservación.</p>'),
    v_r.codigo);
  PERFORM private.log_portal('Reservas', 'reservas', v_r.id, NULL, NULL, v_r.codigo, 'Creación',
    'Solicitud de reserva ' || v_r.codigo || ' ' || v_r.fecha || ' ' || v_r.franja || coalesce(' (cambio de ' || v_orig.codigo || ')', ''));
  RETURN v_r;
END $$;

-- Mis reservas
CREATE OR REPLACE FUNCTION public.fn_reserva_mias()
RETURNS SETOF public.reservas LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT * FROM public.reservas r WHERE r.solicitado_por = (SELECT auth.uid()) ORDER BY r.fecha DESC, r.hora_inicio DESC
$$;

-- Cancelar (residente: sin aprobacion; staff: con motivo)
CREATE OR REPLACE FUNCTION public.fn_reserva_cancelar(p_id bigint, p_motivo text DEFAULT NULL)
RETURNS public.reservas LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_r public.reservas; v_staff boolean;
BEGIN
  SELECT * INTO v_r FROM public.reservas r WHERE r.id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Reserva no encontrada'; END IF;
  v_staff := v_r.condominio_id = ANY (private.res_staff_condos());
  IF NOT v_staff AND v_r.solicitado_por IS DISTINCT FROM (SELECT auth.uid()) THEN RAISE EXCEPTION 'No puede cancelar esta reserva'; END IF;
  IF v_r.estado NOT IN ('Pendiente','Aprobada') THEN RAISE EXCEPTION 'La reserva ya está %', lower(v_r.estado); END IF;
  IF (v_r.fecha + v_r.hora_inicio) <= private.res_ahora() AND NOT v_staff THEN RAISE EXCEPTION 'La reserva ya comenzó; no se puede cancelar'; END IF;
  IF v_staff AND v_r.solicitado_por IS DISTINCT FROM (SELECT auth.uid()) AND coalesce(btrim(p_motivo), '') = '' THEN
    RAISE EXCEPTION 'Indique el motivo de la cancelación'; END IF;
  UPDATE public.reservas SET estado = 'Cancelada', motivo_cancelacion = nullif(btrim(p_motivo), ''), cancelado_por = private.nombre_actor(),
         cancelado_at = now(), updated_at = now() WHERE id = p_id RETURNING * INTO v_r;
  -- Si cancela una reserva con cambio pendiente, ese cambio tambien se cancela
  UPDATE public.reservas SET estado = 'Cancelada', motivo_cancelacion = 'Se canceló la reserva original', cancelado_por = private.nombre_actor(),
         cancelado_at = now(), updated_at = now() WHERE reserva_origen_id = p_id AND estado = 'Pendiente';
  PERFORM private.res_correo(ARRAY[v_r.email], ARRAY[private.res_admin_email()], 'Reservación ' || v_r.codigo || ' | Cancelada',
    private.res_html('Reservación cancelada', '<p>La reservación fue <strong>cancelada</strong>'
      || CASE WHEN v_r.solicitado_por = (SELECT auth.uid()) THEN ' por el residente.' ELSE ' por la Administración.' END
      || coalesce('<br><strong>Motivo:</strong> ' || v_r.motivo_cancelacion, '') || '</p>' || private.res_tabla(v_r)), v_r.codigo);
  PERFORM private.res_avisar_espera(v_r.condominio_id, v_r.fecha);
  PERFORM private.log_portal('Reservas', 'reservas', v_r.id, 'estado', 'Activa', 'Cancelada', 'Cancelación', coalesce(v_r.motivo_cancelacion, 'Cancelada'));
  RETURN v_r;
END $$;

-- Avisame si se libera
CREATE OR REPLACE FUNCTION public.fn_reserva_espera(p_fecha date, p_franja text, p_activar boolean DEFAULT true)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_condo bigint; v_email text; v_nombre text; v_d jsonb;
BEGIN
  SELECT u.condominio_id INTO v_condo FROM public.unidades u WHERE u.id = ANY (private.unidades_propias() || private.unidades_inquilino()) LIMIT 1;
  IF v_condo IS NULL THEN RAISE EXCEPTION 'Su cuenta no tiene una unidad asignada'; END IF;
  IF NOT EXISTS (SELECT 1 FROM private.res_franjas() x WHERE x.franja = p_franja) THEN RAISE EXCEPTION 'Horario no válido'; END IF;
  IF NOT p_activar THEN
    DELETE FROM public.reservas_espera WHERE condominio_id = v_condo AND fecha = p_fecha AND franja = p_franja AND auth_user_id = (SELECT auth.uid());
    RETURN false;
  END IF;
  v_d := public.fn_reserva_mis_datos() -> 0;
  v_email := coalesce(v_d->>'email', (SELECT au.email FROM auth.users au WHERE au.id = (SELECT auth.uid())));
  v_nombre := v_d->>'nombre';
  INSERT INTO public.reservas_espera (condominio_id, fecha, franja, auth_user_id, email, nombre)
  VALUES (v_condo, p_fecha, p_franja, (SELECT auth.uid()), v_email, v_nombre)
  ON CONFLICT (condominio_id, fecha, franja, auth_user_id) DO UPDATE SET notificado_at = NULL, email = EXCLUDED.email;
  RETURN true;
END $$;

-- ---------------------------------------------------------------- Administracion
CREATE OR REPLACE FUNCTION public.fn_reserva_bandeja(p_condominio_id bigint, p_filtro text DEFAULT 'pendientes')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v jsonb;
BEGIN
  IF NOT (p_condominio_id = ANY (private.res_staff_condos())) THEN RAISE EXCEPTION 'Sin acceso a reservas'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x) || jsonb_build_object('tipo', private.res_tipo(x),
           'cambio_de', o.codigo, 'original_fecha', o.fecha, 'original_franja', o.franja,
           'original_horario', CASE WHEN o.id IS NULL THEN NULL ELSE private.res_hora(o.hora_inicio) || ' - ' || private.res_hora(o.hora_fin) END,
           'horario', private.res_hora(x.hora_inicio) || ' - ' || private.res_hora(x.hora_fin))
         ORDER BY CASE WHEN x.estado = 'Pendiente' THEN 0 ELSE 1 END, x.fecha, x.hora_inicio), '[]'::jsonb) INTO v
  FROM public.reservas x LEFT JOIN public.reservas o ON o.id = x.reserva_origen_id
  WHERE x.condominio_id = p_condominio_id
    AND CASE p_filtro WHEN 'pendientes' THEN x.estado = 'Pendiente'
                      WHEN 'proximas' THEN x.estado IN ('Pendiente','Aprobada') AND (x.fecha + x.hora_fin) >= private.res_ahora()
                      ELSE true END;
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.fn_reserva_decidir(p_id bigint, p_aprobar boolean, p_razon text DEFAULT NULL)
RETURNS public.reservas LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_r public.reservas; v_o public.reservas;
BEGIN
  SELECT * INTO v_r FROM public.reservas r WHERE r.id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Reserva no encontrada'; END IF;
  IF NOT (v_r.condominio_id = ANY (private.res_staff_condos())) THEN RAISE EXCEPTION 'No tiene permiso para decidir reservas'; END IF;
  IF v_r.estado <> 'Pendiente' THEN RAISE EXCEPTION 'La reserva ya está %', lower(v_r.estado); END IF;
  IF NOT p_aprobar AND coalesce(btrim(p_razon), '') = '' THEN RAISE EXCEPTION 'Indique la razón del rechazo'; END IF;

  UPDATE public.reservas SET estado = CASE WHEN p_aprobar THEN 'Aprobada' ELSE 'Rechazada' END,
         motivo_rechazo = CASE WHEN p_aprobar THEN NULL ELSE btrim(p_razon) END,
         decidido_por = private.nombre_actor(), decidido_at = now(), updated_at = now()
   WHERE id = p_id RETURNING * INTO v_r;

  IF p_aprobar THEN
    -- Cambio aprobado: la reserva original se libera
    IF v_r.reserva_origen_id IS NOT NULL THEN
      UPDATE public.reservas SET estado = 'Reemplazada', updated_at = now(), motivo_cancelacion = 'Reemplazada por ' || v_r.codigo
       WHERE id = v_r.reserva_origen_id AND estado IN ('Pendiente','Aprobada') RETURNING * INTO v_o;
      IF v_o.id IS NOT NULL THEN PERFORM private.res_avisar_espera(v_o.condominio_id, v_o.fecha); END IF;
    END IF;
    PERFORM private.res_correo(ARRAY[v_r.email], ARRAY[private.res_admin_email()],
      'Reservación ' || v_r.codigo || ' | Aprobada',
      private.res_html('Reservación de Área Común',
        '<p>Su ' || CASE WHEN v_r.reserva_origen_id IS NULL THEN 'reservación' ELSE 'solicitud de cambio' END
        || ' fue <strong style="color:#2e7d32">APROBADA</strong>.</p>' || private.res_tabla(v_r)
        || '<div style="text-align:center;margin:25px 0;"><a href="' || private.res_calendar_url(v_r) || '" target="_blank" style="display:inline-block;background:#14233F;color:#FFFFFF;text-decoration:none;padding:13px 20px;border-radius:5px;font-weight:bold;">AGREGAR A GOOGLE CALENDAR</a></div>'
        || '<p style="font-size:13px;color:#455a64;">También se adjunta un archivo de calendario (.ics) compatible con Google Calendar, Outlook, Apple Calendar y otros calendarios. El archivo incluye alertas de 48 horas, 24 horas y 4 horas antes.</p>'
        || '<p><strong>AXICORE enviará además recordatorios por correo 48 horas, 24 horas y 4 horas antes de la reservación.</strong></p>'
        || '<p>Las normas de uso, seguridad, higiene y convivencia indicadas en el formulario permanecen aplicables durante toda la reservación.</p>'),
      v_r.codigo, jsonb_build_array(private.res_ics(v_r)));
  ELSE
    PERFORM private.res_correo(ARRAY[v_r.email], ARRAY[private.res_admin_email()],
      'Reservación ' || v_r.codigo || ' | Rechazada',
      private.res_html('Reservación de Área Común',
        '<p>Su ' || CASE WHEN v_r.reserva_origen_id IS NULL THEN 'solicitud de reservación' ELSE 'solicitud de cambio' END
        || ' fue <strong style="color:#c0392b">RECHAZADA</strong>.</p><p><strong>Razón:</strong> ' || v_r.motivo_rechazo || '</p>'
        || CASE WHEN v_r.reserva_origen_id IS NOT NULL THEN '<p>Su reservación original se mantiene sin cambios.</p>' ELSE '' END
        || private.res_tabla(v_r)), v_r.codigo);
    PERFORM private.res_avisar_espera(v_r.condominio_id, v_r.fecha);
  END IF;
  PERFORM private.log_portal('Reservas', 'reservas', v_r.id, 'estado', 'Pendiente', v_r.estado,
    CASE WHEN p_aprobar THEN 'Aprobación' ELSE 'Rechazo' END, coalesce(v_r.motivo_rechazo, 'Aprobada'));
  RETURN v_r;
END $$;

-- ---------------------------------------------------------------- Recordatorios (cada hora)
CREATE OR REPLACE FUNCTION private.fn_reservas_recordatorios()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.reservas; v_min int; v_n int := 0; v_ant text;
BEGIN
  FOR r IN SELECT * FROM public.reservas WHERE estado = 'Aprobada' AND (fecha + hora_inicio) > private.res_ahora()
            AND (fecha + hora_inicio) <= private.res_ahora() + interval '48 hours' LOOP
    v_min := floor(extract(epoch FROM ((r.fecha + r.hora_inicio) - private.res_ahora())) / 60);
    v_ant := NULL;
    IF v_min <= 240 AND r.recordatorio_4h IS NULL THEN
      v_ant := '4 horas';
      UPDATE public.reservas SET recordatorio_4h = now(), recordatorio_24h = coalesce(recordatorio_24h, now()), recordatorio_48h = coalesce(recordatorio_48h, now()) WHERE id = r.id;
    ELSIF v_min > 240 AND v_min <= 1440 AND r.recordatorio_24h IS NULL THEN
      v_ant := '24 horas';
      UPDATE public.reservas SET recordatorio_24h = now(), recordatorio_48h = coalesce(recordatorio_48h, now()) WHERE id = r.id;
    ELSIF v_min > 1440 AND r.recordatorio_48h IS NULL THEN
      v_ant := '48 horas';
      UPDATE public.reservas SET recordatorio_48h = now() WHERE id = r.id;
    END IF;
    IF v_ant IS NOT NULL THEN
      PERFORM private.res_correo(ARRAY[r.email], ARRAY[private.res_admin_email()], 'Recordatorio ' || v_ant || ' | Reserva ' || r.codigo,
        private.res_html('Recordatorio de Reservación',
          '<p>Este es un recordatorio automático: su reservación está programada dentro de <strong>' || v_ant || '</strong>.</p>'
          || private.res_tabla(r)
          || '<div style="text-align:center;margin:22px 0;"><a href="' || private.res_calendar_url(r) || '" target="_blank" style="display:inline-block;background:#14233F;color:#FFFFFF;text-decoration:none;padding:12px 18px;border-radius:5px;font-weight:bold;">AGREGAR / VER EN GOOGLE CALENDAR</a></div>'
          || '<p style="font-size:12px;color:#607080;">Horario de uso del Área Social: 9:00 a. m. a 9:00 p. m.</p>'),
        r.codigo);
      v_n := v_n + 1;
    END IF;
  END LOOP;
  RETURN v_n;
END $$;

-- ---------------------------------------------------------------- Permisos de ejecucion
REVOKE ALL ON FUNCTION public.fn_reserva_disponibilidad(date), public.fn_reserva_mis_datos(), public.fn_reserva_crear(jsonb),
  public.fn_reserva_mias(), public.fn_reserva_cancelar(bigint, text), public.fn_reserva_espera(date, text, boolean),
  public.fn_reserva_bandeja(bigint, text), public.fn_reserva_decidir(bigint, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_reserva_disponibilidad(date), public.fn_reserva_mis_datos(), public.fn_reserva_crear(jsonb),
  public.fn_reserva_mias(), public.fn_reserva_cancelar(bigint, text), public.fn_reserva_espera(date, text, boolean),
  public.fn_reserva_bandeja(bigint, text), public.fn_reserva_decidir(bigint, boolean, text) TO authenticated;
REVOKE ALL ON FUNCTION private.res_correo(text[], text[], text, text, text, jsonb), private.res_avisar_espera(bigint, date),
  private.fn_reservas_recordatorios(), private.res_staff_condos() FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------- Cola de correos y recordatorios (pg_cron)
-- (aplicado como axicore_20e_reservas_cron; la llave es la anon publica de la web)
-- private.fn_procesar_cola_correos(): si hay correos pendientes, llama a la Edge Function axi-correo-cola.
-- cron: axi_cola_correos '* * * * *'  |  axi_reservas_recordatorios '5 * * * *'
