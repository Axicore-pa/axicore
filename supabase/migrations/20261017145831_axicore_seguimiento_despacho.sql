-- Seguimiento de nuevas asignaciones; no modifica ni notifica registros históricos.
set lock_timeout='5s';
set statement_timeout='30s';

create table private.axi_despacho_seguimientos (
 id bigint generated always as identity primary key,
 despacho_id bigint not null references public.mant_despachos(id),
 respuesta_id bigint not null unique references public.mant_despacho_respuestas(id),
 proveedor_id bigint not null references public.proveedores(id),
 turno integer not null,
 token uuid not null unique default gen_random_uuid(),
 estado text not null default 'Pendiente de hora' check (estado in ('Pendiente de hora','Programado','Llegó','Cancelado','Finalizado')),
 estimada timestamptz,
 llegada timestamptz,
 canal text,
 nota text,
 created_at timestamptz not null default now(),
 cerrado_at timestamptz
);
create unique index axi_despacho_un_activo on private.axi_despacho_seguimientos(despacho_id)
 where estado in ('Pendiente de hora','Programado','Llegó');
create index axi_despacho_vencimiento on private.axi_despacho_seguimientos(estimada) where estado='Programado';
create table private.axi_despacho_eventos (
 id bigint generated always as identity primary key,
 seguimiento_id bigint not null references private.axi_despacho_seguimientos(id),
 accion text not null, canal text not null, nota text, actor uuid,
 created_at timestamptz not null default now()
);
create table private.axi_despacho_avisos (
 id bigint generated always as identity primary key,
 seguimiento_id bigint not null references private.axi_despacho_seguimientos(id),
 tipo text not null check (tipo in ('Asignacion','Cancelacion','Llegada','Sin suplente')),
 unique(seguimiento_id,tipo),
 estado text not null default 'Pendiente' check(estado in ('Pendiente','Enviando','Enviado','Error','Omitido')),
 intentos integer not null default 0, reserva uuid,
 proximo timestamptz not null default now(), created_at timestamptz not null default now(), enviado_at timestamptz
);
alter table private.axi_despacho_seguimientos enable row level security;
alter table private.axi_despacho_eventos enable row level security;
alter table private.axi_despacho_avisos enable row level security;
revoke all on private.axi_despacho_seguimientos,private.axi_despacho_eventos,private.axi_despacho_avisos from public,anon,authenticated;

create function private.axi_despacho_nueva_asignacion() returns trigger
language plpgsql security definer set search_path='' as $$
declare r public.mant_despacho_respuestas; v_id bigint; v_turno int;
begin
 if new.estado<>'Asignado' or new.proveedor_asignado_id is null then return new; end if;
 if exists(select 1 from private.axi_despacho_seguimientos s where s.despacho_id=new.id and s.estado in ('Pendiente de hora','Programado','Llegó')) then return new; end if;
 select * into r from public.mant_despacho_respuestas x where x.despacho_id=new.id and x.proveedor_id=new.proveedor_asignado_id and x.es_ganador;
 if not found then return new; end if;
 if exists(select 1 from private.axi_despacho_seguimientos s where s.respuesta_id=r.id) then return new; end if;
 select count(*)+1 into v_turno from private.axi_despacho_seguimientos s where s.despacho_id=new.id;
 insert into private.axi_despacho_seguimientos(despacho_id,respuesta_id,proveedor_id,turno)
 values(new.id,r.id,r.proveedor_id,v_turno) returning id into v_id;
 insert into private.axi_despacho_eventos(seguimiento_id,accion,canal) values(v_id,'Asignación: confirmar hora concreta','Sistema');
 insert into private.axi_despacho_avisos(seguimiento_id,tipo) values(v_id,'Asignacion');
 return new;
end $$;
revoke all on function private.axi_despacho_nueva_asignacion() from public,anon,authenticated;
create trigger axi_despacho_nueva_asignacion after insert or update of estado,proveedor_asignado_id on public.mant_despachos
 for each row execute function private.axi_despacho_nueva_asignacion();

-- Un único orden de bloqueo: despacho -> mantenimiento -> seguimiento.
create function private.axi_despacho_vencer(p_id bigint) returns boolean
language plpgsql security definer set search_path='' as $$
declare s private.axi_despacho_seguimientos; d public.mant_despachos; m public.mantenimientos; r public.mant_despacho_respuestas;
begin
 select * into s from private.axi_despacho_seguimientos where id=p_id;
 if not found then return false; end if;
 select * into d from public.mant_despachos where id=s.despacho_id for update;
 select * into m from public.mantenimientos where id=d.mantenimiento_id for update;
 select * into s from private.axi_despacho_seguimientos where id=p_id for update;
 if s.estado<>'Programado' or s.llegada is not null or s.estimada is null or now()<=s.estimada+interval '60 minutes' then return false; end if;
 if m.estatus in ('Resuelto','Cerrado','Cancelado') or d.estado<>'Asignado' or d.proveedor_asignado_id is distinct from s.proveedor_id or m.proveedor_id is distinct from s.proveedor_id then
   update private.axi_despacho_seguimientos set estado='Finalizado',cerrado_at=now() where id=s.id;
   insert into private.axi_despacho_eventos(seguimiento_id,accion,canal) values(s.id,'Finalizado por estado del reporte o cambio de asignación','Sistema');
   return false;
 end if;
 -- No cancelar si otra asignación técnica vigente ya registra trabajo en proceso.
 if m.estatus='En proceso' and exists(select 1 from public.mant_asignaciones a where a.mantenimiento_id=m.id and a.activa and a.proveedor_id=s.proveedor_id) then
   update private.axi_despacho_seguimientos set estado='Llegó',llegada=now(),canal='Sistema' where id=s.id;
   insert into private.axi_despacho_eventos(seguimiento_id,accion,canal,nota) values(s.id,'Llegada confirmada por trabajo en proceso','Sistema','Asignación técnica activa del mismo proveedor');
   return false;
 end if;
 update private.axi_despacho_seguimientos set estado='Cancelado',cerrado_at=now(),nota='Superó la hora estimada +60 minutos sin llegada registrada' where id=s.id;
 insert into private.axi_despacho_eventos(seguimiento_id,accion,canal) values(s.id,'Cancelación por ausencia al superar +60 minutos','Sistema');
 insert into private.axi_despacho_avisos(seguimiento_id,tipo) values(s.id,'Cancelacion') on conflict do nothing;
 update public.mant_despacho_respuestas set es_ganador=false where despacho_id=d.id and es_ganador;
 update public.mant_asignaciones set activa=false where mantenimiento_id=m.id and proveedor_id=s.proveedor_id and activa;
 select x.* into r from public.mant_despacho_respuestas x join public.proveedores p on p.id=x.proveedor_id
 where x.despacho_id=d.id and x.respuesta is not null and x.prioridad_peso<99
 and p.activo and p.estado_aprobacion='Aprobado'
 and not exists(select 1 from private.axi_despacho_seguimientos z where z.respuesta_id=x.id)
 order by x.prioridad_peso,x.fecha_respuesta,x.id limit 1;
 if found then
   update public.mant_despacho_respuestas set es_ganador=true where id=r.id;
   update public.mant_despachos set proveedor_asignado_id=r.proveedor_id,respuesta_asignada=r.respuesta,updated_at=now() where id=d.id;
   update public.mantenimientos set proveedor_id=r.proveedor_id,updated_at=now() where id=m.id;
 else
   update public.mant_despachos set estado='Sin respuesta',proveedor_asignado_id=null,respuesta_asignada=null,updated_at=now() where id=d.id;
   update public.mantenimientos set proveedor_id=null,updated_at=now() where id=m.id and proveedor_id=s.proveedor_id;
   insert into private.axi_despacho_avisos(seguimiento_id,tipo) values(s.id,'Sin suplente') on conflict do nothing;
 end if;
 return true;
end $$;
revoke all on function private.axi_despacho_vencer(bigint) from public,anon,authenticated;

create function private.axi_despacho_seguimiento_tick() returns void
language plpgsql security definer set search_path='' as $$
declare x record;
begin
 for x in select id from private.axi_despacho_seguimientos where estado='Programado' and estimada+interval '60 minutes'<now() order by id limit 50 loop
   perform private.axi_despacho_vencer(x.id);
 end loop;
 update private.axi_despacho_seguimientos s set estado='Finalizado',cerrado_at=now()
 from public.mant_despachos d join public.mantenimientos m on m.id=d.mantenimiento_id
 where d.id=s.despacho_id and m.estatus in ('Resuelto','Cerrado','Cancelado') and s.estado in ('Pendiente de hora','Programado','Llegó');
end $$;
revoke all on function private.axi_despacho_seguimiento_tick() from public,anon,authenticated;

create function private.axi_despacho_guard(p_mantenimiento bigint,p_editar boolean) returns void
language plpgsql stable security definer set search_path='' as $$
declare v_condo bigint;
begin
 if (select auth.uid()) is null or not private.axi_sesion_auth_valida() then raise exception 'Sesión no válida' using errcode='42501'; end if;
 select condominio_id into v_condo from public.mantenimientos where id=p_mantenimiento;
 if not found or not (private.es_ceo() or v_condo=any(private.staff_condos('Mantenimientos',case when p_editar then 'editar' else 'ver' end))) then raise exception 'Sin permiso' using errcode='42501'; end if;
end $$;
revoke all on function private.axi_despacho_guard(bigint,boolean) from public,anon,authenticated;

create function public.axi_despacho_seguimiento_ver(p_mantenimiento bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.axi_despacho_guard(p_mantenimiento,false);
 select jsonb_build_object(
  'puede_editar',(private.es_ceo() or (select m.condominio_id from public.mantenimientos m where m.id=p_mantenimiento)=any(private.staff_condos('Mantenimientos','editar'))),
  'despachos',(select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'estado',d.estado,'seleccionado',d.proveedor_asignado_id) order by d.id desc),'[]'::jsonb) from public.mant_despachos d where d.mantenimiento_id=p_mantenimiento),
  'seguimientos',(select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'proveedor',coalesce(p.nombre_comercial,p.nombre),'turno',s.turno,'estado',s.estado,'estimada',s.estimada,'desde',s.estimada-interval '60 minutes','hasta',s.estimada+interval '60 minutes','llegada',s.llegada,'canal',s.canal,'nota',s.nota,'correos',(select coalesce(jsonb_agg(jsonb_build_object('tipo',a.tipo,'estado',a.estado)),'[]'::jsonb) from private.axi_despacho_avisos a where a.seguimiento_id=s.id),'historial',(select coalesce(jsonb_agg(jsonb_build_object('accion',e.accion,'canal',e.canal,'nota',e.nota,'fecha',e.created_at) order by e.id),'[]'::jsonb) from private.axi_despacho_eventos e where e.seguimiento_id=s.id)) order by s.id desc),'[]'::jsonb) from private.axi_despacho_seguimientos s join public.mant_despachos d on d.id=s.despacho_id join public.proveedores p on p.id=s.proveedor_id where d.mantenimiento_id=p_mantenimiento),
  'candidatos',(select coalesce(jsonb_agg(jsonb_build_object('proveedor',coalesce(p.nombre_comercial,p.nombre),'disponibilidad',r.respuesta,'respondio',r.fecha_respuesta,'seleccionado',r.es_ganador) order by r.prioridad_peso,r.fecha_respuesta,r.id),'[]'::jsonb) from public.mant_despacho_respuestas r join public.mant_despachos d on d.id=r.despacho_id join public.proveedores p on p.id=r.proveedor_id where d.mantenimiento_id=p_mantenimiento)
 ) into result;
 return result;
end $$;
revoke all on function public.axi_despacho_seguimiento_ver(bigint) from public,anon;
grant execute on function public.axi_despacho_seguimiento_ver(bigint) to authenticated;

create function private.axi_despacho_registrar(p_id bigint,p_accion text,p_fecha timestamptz,p_canal text,p_nota text,p_actor uuid,p_proveedor boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s private.axi_despacho_seguimientos; d public.mant_despachos; m public.mantenimientos;
begin
 select * into s from private.axi_despacho_seguimientos where id=p_id;
 if not found then return jsonb_build_object('ok',false,'error','Asignación no encontrada'); end if;
 select * into d from public.mant_despachos where id=s.despacho_id for update;
 select * into m from public.mantenimientos where id=d.mantenimiento_id for update;
 select * into s from private.axi_despacho_seguimientos where id=p_id for update;
 if s.estado in ('Cancelado','Finalizado') or m.estatus in ('Resuelto','Cerrado','Cancelado') or d.estado<>'Asignado' or d.proveedor_asignado_id is distinct from s.proveedor_id or m.proveedor_id is distinct from s.proveedor_id then return jsonb_build_object('ok',false,'error','Esta asignación ya no está activa'); end if;
 if s.estado='Programado' and now()>s.estimada+interval '60 minutes' then
   perform private.axi_despacho_vencer(s.id);
   return jsonb_build_object('ok',false,'error','La asignación venció y se activó el relevo');
 end if;
 if p_canal is null or p_canal not in ('WhatsApp','Llamada','Correo','Presencial','Enlace del proveedor') or length(coalesce(p_nota,''))>1000 then return jsonb_build_object('ok',false,'error','Canal o nota inválidos'); end if;
 if not p_proveedor and coalesce(btrim(p_nota),'')='' then return jsonb_build_object('ok',false,'error','Indique la confirmación recibida o el motivo'); end if;
 if p_accion='fecha' then
   if s.estado='Llegó' then return jsonb_build_object('ok',false,'error','La llegada ya fue registrada'); end if;
   if p_proveedor and s.estimada is not null then return jsonb_build_object('ok',false,'error','La hora ya fue confirmada; contacte a administración para modificarla'); end if;
   if p_fecha is null or p_fecha<now() or p_fecha>now()+interval '30 days' then return jsonb_build_object('ok',false,'error','Indique una hora futura dentro de los próximos 30 días'); end if;
   if not p_proveedor and coalesce(btrim(p_nota),'')='' then return jsonb_build_object('ok',false,'error','Indique el motivo o la confirmación recibida'); end if;
   update private.axi_despacho_seguimientos set estimada=p_fecha,estado='Programado',canal=p_canal,nota=p_nota where id=s.id;
   insert into private.axi_despacho_eventos(seguimiento_id,accion,canal,nota,actor) values(s.id,'Hora estimada confirmada: '||to_char(p_fecha at time zone 'America/Santo_Domingo','DD/MM/YYYY HH24:MI')||' (RD); tolerancia ±60 minutos',p_canal,p_nota,p_actor);
 elsif p_accion='llegada' then
   if s.estado='Llegó' then return jsonb_build_object('ok',true,'mensaje','La llegada ya estaba registrada'); end if;
   update private.axi_despacho_seguimientos set estado='Llegó',llegada=now(),canal=p_canal,nota=p_nota where id=s.id;
   insert into private.axi_despacho_eventos(seguimiento_id,accion,canal,nota,actor) values(s.id,'Llegada confirmada',p_canal,p_nota,p_actor);
   insert into private.axi_despacho_avisos(seguimiento_id,tipo) values(s.id,'Llegada') on conflict do nothing;
 else return jsonb_build_object('ok',false,'error','Acción no válida'); end if;
 return jsonb_build_object('ok',true,'mensaje',case p_accion when 'fecha' then 'Hora registrada con tolerancia de ±60 minutos' else 'Llegada registrada. El relevo automático queda detenido.' end);
end $$;
revoke all on function private.axi_despacho_registrar(bigint,text,timestamptz,text,text,uuid,boolean) from public,anon,authenticated;

create function public.axi_despacho_seguimiento_registrar(p_id bigint,p_accion text,p_fecha timestamptz default null,p_canal text default 'Llamada',p_nota text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_mant bigint;
begin
 select d.mantenimiento_id into v_mant from private.axi_despacho_seguimientos s join public.mant_despachos d on d.id=s.despacho_id where s.id=p_id;
 perform private.axi_despacho_guard(v_mant,true);
 return private.axi_despacho_registrar(p_id,p_accion,p_fecha,p_canal,p_nota,(select auth.uid()),false);
end $$;
revoke all on function public.axi_despacho_seguimiento_registrar(bigint,text,timestamptz,text,text) from public,anon;
grant execute on function public.axi_despacho_seguimiento_registrar(bigint,text,timestamptz,text,text) to authenticated;

-- Solo la función Edge con service_role puede consultar/registrar por token.
create function public.axi_despacho_seguimiento_proveedor(p_token uuid,p_accion text,p_fecha timestamptz default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s private.axi_despacho_seguimientos; v_codigo text;
begin
 select * into s from private.axi_despacho_seguimientos where token=p_token;
 if not found then return jsonb_build_object('ok',false,'error','Enlace inválido'); end if;
 if p_accion='consultar' then
   select m.codigo into v_codigo from public.mant_despachos d join public.mantenimientos m on m.id=d.mantenimiento_id where d.id=s.despacho_id;
   return jsonb_build_object('ok',true,'estado',s.estado,'codigo',v_codigo,'estimada',s.estimada,'desde',s.estimada-interval '60 minutes','hasta',s.estimada+interval '60 minutes','llegada',s.llegada);
 end if;
 return private.axi_despacho_registrar(s.id,p_accion,p_fecha,'Enlace del proveedor',null,null,true);
end $$;
revoke all on function public.axi_despacho_seguimiento_proveedor(uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function public.axi_despacho_seguimiento_proveedor(uuid,text,timestamptz) to service_role;

create function public.axi_despacho_seguimiento_cola() returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.axi_despacho_avisos; s private.axi_despacho_seguimientos; p public.proveedores; m public.mantenimientos; v_res uuid; v_text text; items jsonb='[]'::jsonb; v_email text;
begin
 for a in select * from private.axi_despacho_avisos where estado in ('Pendiente','Enviando') and proximo<=now() and intentos<4 order by id for update skip locked limit 5 loop
   select * into s from private.axi_despacho_seguimientos where id=a.seguimiento_id;
   select * into p from public.proveedores where id=s.proveedor_id;
   select x.* into m from public.mantenimientos x join public.mant_despachos d on d.mantenimiento_id=x.id where d.id=s.despacho_id;
   if a.tipo='Asignacion' and s.estado not in ('Pendiente de hora','Programado') then
     update private.axi_despacho_avisos set estado='Omitido' where id=a.id; continue;
   end if;
   v_email=case when a.tipo in ('Llegada','Sin suplente') then 'axispard@gmail.com' else p.email end;
   if coalesce(v_email,'') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then update private.axi_despacho_avisos set estado='Error' where id=a.id; continue; end if;
   v_text=case a.tipo
    when 'Asignacion' then 'Ha sido seleccionado para atender este reporte. Confirme una hora concreta de llegada en el enlace. La ventana será de 60 minutos antes a 60 minutos después de esa hora. Si no se registra su llegada antes de superar el límite, su asignación quedará cancelada y se activará el siguiente proveedor.'
    when 'Cancelacion' then 'Su asignación queda cancelada porque se superó la hora estimada más 60 minutos sin llegada registrada. No acuda bajo esta asignación. Si existe alguna diferencia, contacte a administración.'
    when 'Llegada' then 'Se registró la llegada del proveedor por el canal: '||coalesce(s.canal,'No indicado')||'. El relevo automático queda detenido.'
    else 'No quedan proveedores elegibles que hayan respondido. El reporte requiere intervención de administración.' end;
   v_res=gen_random_uuid();
   update private.axi_despacho_avisos set estado='Enviando',intentos=intentos+1,reserva=v_res,proximo=now()+interval '2 minutes' where id=a.id;
   items=items||jsonb_build_object('id',a.id,'reserva',v_res,'email',v_email,'cc',case when v_email='axispard@gmail.com' then null else 'axispard@gmail.com' end,'asunto','AXICORE | '||a.tipo||' de servicio | '||coalesce(m.codigo,'Reporte'),'texto',v_text,'proveedor',coalesce(p.nombre_comercial,p.nombre),'reporte',m.codigo,'link',case when a.tipo='Asignacion' then 'https://axicorepard.com/despacho-seguimiento.html#token='||s.token::text else null end);
 end loop;
 update private.axi_despacho_avisos set estado='Error' where estado='Enviando' and intentos>=4 and proximo<=now();
 return items;
end $$;
revoke all on function public.axi_despacho_seguimiento_cola() from public,anon,authenticated;
grant execute on function public.axi_despacho_seguimiento_cola() to service_role;

create function public.axi_despacho_seguimiento_correo_resultado(p_id bigint,p_reserva uuid,p_ok boolean) returns void
language sql security definer set search_path='' as $$
 update private.axi_despacho_avisos set estado=case when p_ok then 'Enviado' when intentos>=4 then 'Error' else 'Pendiente' end,enviado_at=case when p_ok then now() else null end
 where id=p_id and reserva=p_reserva and estado='Enviando';
$$;
revoke all on function public.axi_despacho_seguimiento_correo_resultado(bigint,uuid,boolean) from public,anon,authenticated;
grant execute on function public.axi_despacho_seguimiento_correo_resultado(bigint,uuid,boolean) to service_role;

-- Se usa el cron de despacho existente; el reemplazo exacto se añade al preparar.

CREATE OR REPLACE FUNCTION private.axi_despacho_tick()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_rec RECORD;
BEGIN
  PERFORM private.axi_despacho_seguimiento_tick();
  -- PASO 1: Cerrar ventanas vencidas
  FOR v_rec IN SELECT despacho_id FROM public.despachos_vencidos()
  LOOP
    PERFORM public.despacho_cerrar_ventana(v_rec.despacho_id);
  END LOOP;

  -- PASO 2: Enviar correos pendientes via Edge Function
  IF EXISTS(
    SELECT 1
    FROM public.mant_despacho_respuestas r
    JOIN public.mant_despachos d ON d.id = r.despacho_id
    WHERE r.notificado = false
      AND d.estado IN ('Abierto','En espera')
  ) OR EXISTS (SELECT 1 FROM private.axi_despacho_avisos WHERE estado IN ('Pendiente','Enviando') AND proximo<=now() AND intentos<4) THEN
    PERFORM net.http_post(
      url:='https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-despacho-correo',
      headers:=jsonb_build_object(
        'Content-Type','application/json',
        'Authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmZ3lmdHNud3puc3FpenJpZ2dyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0MDgxODgsImV4cCI6MjEwNjk4NDE4OH0.i-icCG4lJ7Vjkp6c_j_a4Mrwt2w5Ig2GYUcfgWoIugQ'
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=55000
    );
  END IF;
END
$function$;

CREATE OR REPLACE FUNCTION public.despacho_cerrar_ventana(p_despacho_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_despacho record;
  v_ganador record;
BEGIN
  SELECT * INTO v_despacho
  FROM public.mant_despachos
  WHERE id = p_despacho_id AND estado = 'En espera' FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Despacho no encontrado o no está en espera');
  END IF;

  -- Buscar la mejor respuesta (menor peso, excluir 99=No puede)
  SELECT dr.id, dr.proveedor_id, dr.respuesta, dr.prioridad_peso,
         p.nombre AS proveedor_nombre
  INTO v_ganador
  FROM public.mant_despacho_respuestas dr
  JOIN public.proveedores p ON p.id = dr.proveedor_id
  WHERE dr.despacho_id = p_despacho_id
    AND p.activo = true AND p.estado_aprobacion = 'Aprobado'
    AND dr.prioridad_peso IS NOT NULL
    AND dr.prioridad_peso < 99
  ORDER BY dr.prioridad_peso ASC, dr.fecha_respuesta ASC
  LIMIT 1;

  IF FOUND THEN
    -- Marcar ganador
    UPDATE public.mant_despacho_respuestas
    SET es_ganador = true
    WHERE id = v_ganador.id;

    -- Actualizar despacho
    UPDATE public.mant_despachos
    SET estado = 'Asignado',
        proveedor_asignado_id = v_ganador.proveedor_id,
        respuesta_asignada = v_ganador.respuesta,
        fecha_cierre = now(),
        updated_at = now()
    WHERE id = p_despacho_id;

    -- Actualizar proveedor en el mantenimiento
    UPDATE public.mantenimientos
    SET proveedor_id = v_ganador.proveedor_id,
        updated_at = now()
    WHERE id = v_despacho.mantenimiento_id;

    RETURN jsonb_build_object(
      'ok', true,
      'estado', 'Asignado',
      'proveedor', v_ganador.proveedor_nombre,
      'respuesta', v_ganador.respuesta
    );
  ELSE
    -- Nadie respondió o todos dijeron "No puedo"
    UPDATE public.mant_despachos
    SET estado = 'Sin respuesta',
        fecha_cierre = now(),
        updated_at = now()
    WHERE id = p_despacho_id;

    RETURN jsonb_build_object(
      'ok', true,
      'estado', 'Sin respuesta'
    );
  END IF;
END;
$function$;
