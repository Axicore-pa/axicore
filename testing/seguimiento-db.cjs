// Base local de fixtures. No conexión remota ni correos.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PGlite}=require(require.resolve('@electric-sql/pglite',{paths:[__dirname,path.resolve(__dirname,'../../axicore-work/testing')]}));
const root=path.resolve(__dirname,'..');
(async()=>{
 const db=new PGlite();let checks=0;const ok=(v,n)=>{assert(v,n);checks++;console.log('OK '+n);};
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema private;create schema auth;create schema net;
 grant usage on schema public,private,auth to anon,authenticated,service_role;
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 create function private.axi_sesion_auth_valida() returns boolean language sql stable as $$select current_setting('test.valid',true)='true'$$;
 create function private.es_ceo() returns boolean language sql stable as $$select current_setting('test.role',true)='CEO' and current_setting('test.aal',true)='aal2'$$;
 create function private.staff_condos(text,text) returns bigint[] language sql stable as $$select case when current_setting('test.role',true)='Asistente' and current_setting('test.aal',true)='aal2' then array[1]::bigint[] else '{}'::bigint[] end$$;
 create function net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds int) returns bigint language sql as $$select 1::bigint$$;
 create table public.proveedores(id bigint primary key,nombre text,nombre_comercial text,email text,activo boolean,estado_aprobacion text);
 create table public.mantenimientos(id bigint primary key,codigo text,condominio_id bigint,proveedor_id bigint,estatus text,updated_at timestamptz);
 create table public.mant_despachos(id bigint primary key,mantenimiento_id bigint,estado text,proveedor_asignado_id bigint,respuesta_asignada text,fecha_cierre timestamptz,updated_at timestamptz);
 create table public.mant_despacho_respuestas(id bigint primary key,despacho_id bigint,proveedor_id bigint,respuesta text,prioridad_peso int,fecha_respuesta timestamptz,es_ganador boolean default false,notificado boolean default false);
 create table public.mant_asignaciones(mantenimiento_id bigint,proveedor_id bigint,activa boolean);
 create function public.despachos_vencidos() returns table(despacho_id bigint) language sql as $$select id from public.mant_despachos where false$$;
 insert into public.proveedores values(1,'A',null,'a@example.test',true,'Aprobado'),(2,'B',null,'b@example.test',true,'Aprobado'),(3,'C',null,'c@example.test',true,'Aprobado'),(4,'Inactivo',null,'d@example.test',false,'Aprobado');
 `);
 await db.exec(fs.readFileSync(path.join(root,'sql/seguimiento_despacho.sql'),'utf8')+fs.readFileSync(path.join(root,'sql/seguimiento_despacho_integracion.sql'),'utf8'));
 const q=async(sql,args=[])=>(await db.query(sql,args)).rows;
 async function fixture(id,condo=1){await db.query("insert into public.mantenimientos values($1,'TEST-'||$1::bigint::text,$2,null,'Recibido',now());",[id,condo]);await db.query("insert into public.mant_despachos(id,mantenimiento_id,estado) values($1,$1,'En espera')",[id]);
 for(const [p,peso] of [[1,1],[2,2],[3,2],[4,1]])await db.query("insert into public.mant_despacho_respuestas values($1,$2,$3,'Fixture',$4,now()+make_interval(secs=>$3::bigint::int),false,true)",[id*10+p,id,p,peso]);
 // Ganador A ya seleccionado por flujo existente.
 await db.query('update public.mant_despacho_respuestas set es_ganador=true where id=$1',[id*10+1]);await db.query("update public.mant_despachos set estado='Asignado',proveedor_asignado_id=1 where id=$1",[id]);await db.query('update public.mantenimientos set proveedor_id=1 where id=$1',[id]);
 return (await q('select * from private.axi_despacho_seguimientos where despacho_id=$1',[id]))[0];}
 const a=await fixture(1);ok(a.estado==='Pendiente de hora'&&a.estimada===null,'asignación nueva exige hora concreta');
 ok((await q("select count(*)::int as n from private.axi_despacho_avisos where seguimiento_id=$1",[a.id]))[0].n===1,'aviso inicial encolado una vez');
 await db.exec("select private.axi_despacho_seguimiento_tick()");ok((await q('select estado from private.axi_despacho_seguimientos where id=$1',[a.id]))[0].estado==='Pendiente de hora','sin hora no se cancela ni inventa plazo');
 const provider=async(s,action,date=null)=>(await q('select public.axi_despacho_seguimiento_proveedor($1,$2,$3) as r',[s.token,action,date]))[0].r;
 ok((await provider(a,'consultar')).ok,'consulta por token válido');
 ok(!(await q("select public.axi_despacho_seguimiento_proveedor('00000000-0000-0000-0000-000000000000','consultar') r"))[0].r.ok,'token ajeno no consulta');
 let r=await provider(a,'fecha',new Date(Date.now()+7200000).toISOString());ok(r.ok,'proveedor fija hora futura');
 r=await provider(a,'fecha',new Date(Date.now()+14400000).toISOString());ok(!r.ok,'proveedor no extiende su propio plazo confirmado');
 let w=(await q('select extract(epoch from ((estimada+interval \'60 minutes\')-(estimada-interval \'60 minutes\')))::int n from private.axi_despacho_seguimientos where id=$1',[a.id]))[0];ok(w.n===7200,'ventana exacta de ±60 minutos');
 r=await provider(a,'llegada');ok(r.ok,'llegada por enlace');r=await provider(a,'llegada');ok(r.ok,'llegada repetida idempotente');
 ok((await q("select count(*)::int n from private.axi_despacho_eventos where seguimiento_id=$1 and accion='Llegada confirmada'",[a.id]))[0].n===1,'sin doble llegada ni doble aviso');
 await db.query("update private.axi_despacho_seguimientos set estimada=now()-interval '3 hours' where id=$1",[a.id]);await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select estado from private.axi_despacho_seguimientos where id=$1',[a.id]))[0].estado==='Llegó','llegada detiene relevo aunque venza estimada');
 const b=await fixture(2);await db.query("update private.axi_despacho_seguimientos set estimada=now()-interval '59 minutes',estado='Programado' where id=$1",[b.id]);await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select estado from private.axi_despacho_seguimientos where id=$1',[b.id]))[0].estado==='Programado','no cancela dentro de +60');
 await db.query("update private.axi_despacho_seguimientos set estimada=now()-interval '61 minutes' where id=$1",[b.id]);await db.exec('select private.axi_despacho_seguimiento_tick()');
 ok((await q('select estado from private.axi_despacho_seguimientos where id=$1',[b.id]))[0].estado==='Cancelado','cancela al superar +60 sin llegada');
 let supl=(await q("select * from private.axi_despacho_seguimientos where despacho_id=2 and estado='Pendiente de hora'"))[0];ok(Number(supl.proveedor_id)===2&&supl.estimada===null&&supl.turno===2,'opción B elegible desempata por respuesta y confirma nueva hora; excluye inactivo');
 ok((await q('select proveedor_id from public.mantenimientos where id=2'))[0].proveedor_id===2,'relevo enlaza proveedor con mantenimiento');
 ok(!(await provider(b,'llegada')).ok,'token cancelado no registra llegada ni modifica B');
 await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select count(*)::int n from private.axi_despacho_seguimientos where despacho_id=2'))[0].n===2,'cron repetido no duplica suplente');
 await db.exec("select set_config('test.uid','00000000-0000-0000-0000-000000000001',false);select set_config('test.role','CEO',false);select set_config('test.aal','aal2',false);select set_config('test.valid','true',false);set role authenticated");
 r=(await q("select public.axi_despacho_seguimiento_registrar($1,'llegada',null,'WhatsApp','Proveedor llamó a conserjería') r",[supl.id]))[0].r;ok(r.ok,'administración confirma llegada por WhatsApp sin acción de proveedor');
 await db.exec('reset role');ok((await q('select canal from private.axi_despacho_seguimientos where id=$1',[supl.id]))[0].canal==='WhatsApp','canal manual y nota conservados');
 const c=await fixture(3,2);await db.exec("select set_config('test.role','Asistente',false);set role authenticated");let denied=false;try{await q('select public.axi_despacho_seguimiento_ver(3)');}catch{denied=true;}ok(denied,'asistente no ve otro condominio');await db.exec('reset role');
 await db.exec("select set_config('test.role','CEO',false);select set_config('test.aal','aal1',false);set role authenticated");denied=false;try{await q('select public.axi_despacho_seguimiento_ver(1)');}catch{denied=true;}ok(denied,'MFA obligatoria para administrar');await db.exec('reset role');
 await db.exec("select set_config('test.aal','aal2',false);select set_config('test.valid','false',false);set role authenticated");denied=false;try{await q('select public.axi_despacho_seguimiento_ver(1)');}catch{denied=true;}ok(denied,'sesión revocada no administra');await db.exec('reset role');
 for(const role of ['anon','authenticated']){ok((await q("select has_function_privilege($1,'public.axi_despacho_seguimiento_proveedor(uuid,text,timestamptz)','execute') yes",[role]))[0].yes===false,role+' no ejecuta RPC por token directamente');}
 await db.exec('set role authenticated');denied=false;try{await q('select * from private.axi_despacho_seguimientos');}catch{denied=true;}ok(denied,'tabla privada sin acceso directo');await db.exec('reset role');
 const d=await fixture(4);await db.exec("update public.mantenimientos set estatus='Resuelto' where id=4");await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select estado from private.axi_despacho_seguimientos where id=$1',[d.id]))[0].estado==='Finalizado','reporte resuelto finaliza seguimiento sin cancelación');
 const e=await fixture(5);await db.exec('delete from public.mant_despacho_respuestas where despacho_id=5 and proveedor_id<>1');await db.query("update private.axi_despacho_seguimientos set estado='Programado',estimada=now()-interval '61 minutes' where id=$1",[e.id]);await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select estado from public.mant_despachos where id=5'))[0].estado==='Sin respuesta','sin suplentes requiere intervención, sin ganador inventado');
 const mails=(await q('select public.axi_despacho_seguimiento_cola() r'))[0].r;ok(mails.length>0&&mails.every(x=>x.reserva&&x.email&&!x.link?.includes('?token=')),'cola con reserva y token solo en fragmento');
 const ids=new Set(mails.map(x=>x.id));const again=(await q('select public.axi_despacho_seguimiento_cola() r'))[0].r;ok(!again.some(x=>ids.has(x.id)),'arrendamiento evita envíos simultáneos');
 const mail=mails[0];await q('select public.axi_despacho_seguimiento_correo_resultado($1,$2,true)',[mail.id,mail.reserva]);ok((await q('select estado from private.axi_despacho_avisos where id=$1',[mail.id]))[0].estado==='Enviado','resultado vinculado a reserva exacta');
 const f=await fixture(6);await db.exec("insert into public.mant_asignaciones values(6,1,true);update public.mantenimientos set estatus='En proceso' where id=6");await db.query("update private.axi_despacho_seguimientos set estado='Programado',estimada=now()-interval '61 minutes' where id=$1",[f.id]);await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select estado from private.axi_despacho_seguimientos where id=$1',[f.id]))[0].estado==='Llegó','trabajo ya en proceso con técnico activo no se cancela');
 const g=await fixture(7);await db.exec('update public.mantenimientos set proveedor_id=3 where id=7');await db.query("update private.axi_despacho_seguimientos set estado='Programado',estimada=now()-interval '61 minutes' where id=$1",[g.id]);await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select proveedor_id from public.mantenimientos where id=7'))[0].proveedor_id===3,'relevo no pisa reasignación manual posterior');
 const h=await fixture(8);await db.exec('insert into public.mant_asignaciones values(8,1,true)');await db.query("update private.axi_despacho_seguimientos set estado='Programado',estimada=now()-interval '61 minutes' where id=$1",[h.id]);await db.exec('select private.axi_despacho_seguimiento_tick()');ok((await q('select activa from public.mant_asignaciones where mantenimiento_id=8'))[0].activa===false,'técnico pendiente del proveedor cancelado deja de figurar activo');
 for(const canal of ['Llamada','Correo','Presencial']){const s=await fixture(20+checks);await db.exec("select set_config('test.role','CEO',false);select set_config('test.aal','aal2',false);select set_config('test.valid','true',false);set role authenticated");const r=(await q("select public.axi_despacho_seguimiento_registrar($1,'llegada',null,$2,'Confirmación recibida por administración') r",[s.id,canal]))[0].r;ok(r.ok,'llegada manual por '+canal);await db.exec('reset role');}
 console.log(JSON.stringify({checks,synthetic:true,remoteWrites:0}));await db.close();
})().catch(e=>{console.error(e.message,e.detail||'');process.exit(1);});
