-- Procesa exclusivamente la cola de circulares, sin tocar la cola de otros avisos.
CREATE FUNCTION private.axi_circular_tick() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM private.axi_circular_correos WHERE
 (estado='Pendiente' AND proximo_at<=now()) OR (estado='Procesando' AND tomado_at<now()-interval '5 minutes')) THEN
 PERFORM net.http_post(
 url:='https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-circulares-correo',
 headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmZ3lmdHNud3puc3FpenJpZ2dyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0MDgxODgsImV4cCI6MjEwNjk4NDE4OH0.i-icCG4lJ7Vjkp6c_j_a4Mrwt2w5Ig2GYUcfgWoIugQ'),
 body:='{}'::jsonb,timeout_milliseconds:=55000);
 END IF;
END $$;
REVOKE ALL ON FUNCTION private.axi_circular_tick() FROM PUBLIC,anon,authenticated,service_role;
SELECT cron.schedule('axicore-circulares-correo','* * * * *','select private.axi_circular_tick()');
