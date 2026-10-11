-- AXICORE | 22 Reservas: texto de normas dentro del AVISO ADMINISTRATIVO (decision de Misael 11/10/2026)
-- > 5 personas: el aviso amarillo agrega "<strong>Las normas de uso</strong>, seguridad, ..." y se quita el parrafo suelto.
-- <= 5 personas: queda igual que antes (parrafo normal, sin aviso).
-- Aplica a: solicitud pendiente (fn_reserva_crear), aprobada (fn_reserva_decidir) y registrada por CEO (fn_reserva_crear_admin).
-- No toca: rechazo, cancelacion ni recordatorios (siguen con private.res_tabla).

CREATE OR REPLACE FUNCTION private.res_tabla_n(r public.reservas)
RETURNS text LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT replace(private.res_tabla(r), 'demás residentes.</div>',
    'demás residentes.<br><br><strong>Las normas de uso</strong>, seguridad, higiene y convivencia indicadas en el formulario permanecen aplicables durante toda la reservación.</div>');
$$;
REVOKE ALL ON FUNCTION private.res_tabla_n(public.reservas) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  f text; d text;
  v_old text := '''<p>Las normas de uso, seguridad, higiene y convivencia indicadas en el formulario permanecen aplicables durante toda la reservación.</p>''';
  v_new text := '(CASE WHEN v_r.cantidad_personas > 5 THEN '''' ELSE ''<p>Las normas de uso, seguridad, higiene y convivencia indicadas en el formulario permanecen aplicables durante toda la reservación.</p>'' END)';
BEGIN
  FOREACH f IN ARRAY ARRAY['public.fn_reserva_crear(jsonb)', 'public.fn_reserva_decidir(bigint,boolean,text)', 'public.fn_reserva_crear_admin(jsonb)'] LOOP
    d := pg_get_functiondef(f::regprocedure);
    IF position(v_old IN d) = 0 OR position('private.res_tabla(v_r)' IN d) = 0 THEN
      RAISE EXCEPTION 'Texto esperado no encontrado en %', f;
    END IF;
    d := replace(d, v_old, v_new);
    d := regexp_replace(d, 'private\.res_tabla\(v_r\)', 'private.res_tabla_n(v_r)');  -- solo la primera (en decidir = aprobada)
    EXECUTE d;
  END LOOP;
END $$;
