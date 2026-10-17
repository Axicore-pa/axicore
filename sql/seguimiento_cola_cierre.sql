-- Recuperar avisos cuya cuarta ejecución terminó sin registrar resultado.
create or replace function private.axi_despacho_seguimiento_tick() returns void
language plpgsql security definer set search_path='' as $$
declare x record;
begin
 update private.axi_despacho_avisos set estado='Error'
 where estado='Enviando' and intentos>=4 and proximo<=now();
 for x in select id from private.axi_despacho_seguimientos where estado='Programado' and estimada+interval '60 minutes'<now() order by id limit 50 loop
   perform private.axi_despacho_vencer(x.id);
 end loop;
 update private.axi_despacho_seguimientos s set estado='Finalizado',cerrado_at=now()
 from public.mant_despachos d join public.mantenimientos m on m.id=d.mantenimiento_id
 where d.id=s.despacho_id and m.estatus in ('Resuelto','Cerrado','Cancelado') and s.estado in ('Pendiente de hora','Programado','Llegó');
end $$;
-- La selección automática es tarea del cron/servidor, no una operación pública.
revoke all on function public.despacho_cerrar_ventana(bigint) from public,anon,authenticated;
grant execute on function public.despacho_cerrar_ventana(bigint) to service_role;

