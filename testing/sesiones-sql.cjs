// Modelo de PostgreSQL aislado; no contiene cuentas ni correos reales.
const {PGlite}=require('@electric-sql/pglite');
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
(async()=>{
 const db=new PGlite();
 await db.exec(`
 CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE ROLE authenticator;
 CREATE SCHEMA private; CREATE SCHEMA auth; CREATE SCHEMA extensions; CREATE SCHEMA storage;
 CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT (auth.jwt()->>'sub')::uuid $$;
 CREATE FUNCTION extensions.digest(text,text) RETURNS bytea LANGUAGE sql IMMUTABLE AS $$ SELECT sha256(convert_to($1,'UTF8')) $$;
 CREATE TABLE auth.users(id uuid PRIMARY KEY,email text);
 CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid,not_after timestamptz);
 CREATE TABLE public.accesos(id bigint,auth_user_id uuid,rol text,usuario_id bigint,condominio_id bigint,administrador_id bigint,activo boolean);
 CREATE TABLE public.usuarios(id bigint,nombre_completo text,usuario_login text,nivel_acceso integer);
 CREATE TABLE public.administradores(id bigint,nombre text);
 CREATE TABLE public.historial_sesiones(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,usuario_id bigint,usuario_login text,nombre_usuario text,rol text,nivel_acceso integer,fecha_hora_inicio timestamptz,fecha_hora_fin timestamptz,activa boolean);
 CREATE TABLE public.correos_salida(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,para text[],asunto text,texto text,referencia text);
 CREATE TABLE public.datos(id int); INSERT INTO public.datos VALUES(1);
 ALTER TABLE public.datos ENABLE ROW LEVEL SECURITY;
 CREATE POLICY previa ON public.datos TO authenticated USING(true) WITH CHECK(true);
 GRANT SELECT,INSERT,UPDATE,DELETE ON public.datos TO authenticated;
 GRANT USAGE ON SCHEMA private,auth,extensions TO authenticated,authenticator,service_role;
 CREATE FUNCTION private.aal2_ok() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT (auth.jwt()->>'aal')='aal2' $$;
 CREATE FUNCTION private.es_ceo() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$ SELECT private.aal2_ok() AND EXISTS(SELECT 1 FROM public.accesos WHERE auth_user_id=auth.uid() AND activo AND rol='CEO') $$;
 INSERT INTO auth.users VALUES('00000000-0000-0000-0000-000000000001','usuario@example.test'),('00000000-0000-0000-0000-000000000002','ceo@example.test');
 INSERT INTO auth.sessions VALUES('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',null),('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',null),('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002',null);
 INSERT INTO public.accesos VALUES(1,'00000000-0000-0000-0000-000000000001','Propietario',1,1,null,true),(2,'00000000-0000-0000-0000-000000000002','CEO',2,null,null,true);
 INSERT INTO public.usuarios VALUES(1,'Usuario Prueba','prueba',1),(2,'CEO Prueba','ceo',1);
 `);
 await db.exec(fs.readFileSync(path.join(root,'supabase/migrations/20261015042312_sesiones_unicas.sql'),'utf8'));
 const query=async sql=>(await db.query(sql)).rows;
 const check=async(sql,value,label)=>{assert.deepEqual((await query(sql))[0].v,value,label);console.log('OK '+label)};
 const context=async(user=1,sid=1,tab='a',aal='aal1',route='rpc/axi_sesion_iniciar')=>{
   await db.query("select set_config('request.jwt.claims',$1,false),set_config('request.headers',$2,false),set_config('request.path',$3,false)",[
     JSON.stringify({sub:'00000000-0000-0000-0000-'+String(user).padStart(12,'0'),session_id:'10000000-0000-0000-0000-'+String(sid).padStart(12,'0'),aal,role:'authenticated'}),JSON.stringify({'x-axicore-tab':tab.repeat(64),'user-agent':'Navegador sintético'}),route]);
 };
 await db.exec('UPDATE private.axi_sesion_config SET habilitada=true');
 await context();
 await check("select private.axi_sesion_valida() as v",false,'sin registro no accede');
 await check("select (public.axi_sesion_iniciar()->>'rol') as v",'Propietario','primera entrada');
 await check("select private.axi_sesion_valida() as v",true,'primera autorizada');
 await db.exec("set role authenticated"); await check('select count(*)::int as v from public.datos',1,'RLS permite a la primera'); await db.exec('reset role');
 await check("select (public.axi_sesion_iniciar()->>'rol') as v",'Propietario','recarga idempotente');
 await check('select count(*)::int as v from public.historial_sesiones',1,'recarga no duplica historial');
 await context(1,2,'b');
 await check("select (public.axi_sesion_iniciar()->>'sesion_bloqueada')::boolean as v",true,'segundo dispositivo bloqueado');
 await check('select count(*)::int as v from public.correos_salida',2,'alerta separada al usuario y CEO');
 await check("select private.axi_sesion_valida() as v",false,'segundo sin autorización');
 await db.exec('set role authenticated'); await check('select count(*)::int as v from public.datos',0,'RLS deniega segundo'); await db.exec('reset role');
 await db.exec('select public.axi_sesion_cerrar()');
 await check('select count(*)::int as v from private.axi_sesiones',1,'salida segunda no cierra primera');
 await db.exec('select public.axi_sesion_iniciar()');
 await check('select count(*)::int as v from public.correos_salida',2,'agrupa alertas repetidas');
 await check("select count(*)::int as v from private.axi_sesion_eventos where tipo='bloqueo'",2,'registra cada intento');
 await context(1,1,'b');
 await check("select (public.axi_sesion_iniciar()->>'sesion_bloqueada')::boolean as v",true,'pestaña con mismo JWT y token distinto bloqueada');
 let denied=false; await context(1,2,'b','aal1','rpc/cualquier_rpc');
 try{await db.exec('select private.axi_sesion_guard()')}catch(e){denied=e.message.includes('AXI_SESSION_INVALID')};assert(denied,'pre-request bloquea RPC SECURITY DEFINER');console.log('OK guard de RPC');
 denied=false; try{await db.exec('select public.axi_sesiones_listar()')}catch(e){denied=true};assert(denied,'propietario no recupera');
 await context(2,3,'c');
 await check("select (public.axi_sesion_iniciar()->>'requiere_2fa')::boolean as v",true,'CEO exige MFA');
 denied=false;try{await db.exec('select public.axi_sesiones_listar()')}catch(e){denied=true};assert(denied,'CEO sin MFA no recupera');
 await context(2,3,'c','aal2');
 const sessions=(await query('select public.axi_sesiones_listar() as v'))[0].v;assert.equal(sessions.length,1);
 denied=false;try{await db.query('select public.axi_sesion_liberar($1,$2)',[sessions[0].id,'corto'])}catch(e){denied=true};assert(denied,'motivo obligatorio');
 await db.query('select public.axi_sesion_liberar($1,$2)',[sessions[0].id,'Usuario verificado; navegador abandonado']);
 await context();await check('select private.axi_sesion_valida() as v',false,'recuperación revoca primera inmediatamente');
 denied=false;try{await db.exec('select public.axi_sesion_iniciar()')}catch(e){denied=e.message.includes('cerrada o liberada')};assert(denied,'la sesión liberada no puede reclamar de nuevo');console.log('OK sesión liberada no vuelve a reclamar');
 await context(1,2,'b');await check("select (public.axi_sesion_iniciar()->>'rol') as v",'Propietario','nuevo ingreso tras liberación');
 await context(2,3,'c','aal2');
 denied=false;try{await db.query('select public.axi_sesion_liberar($1,$2)',[sessions[0].id,'Lista antigua; no debe afectar reemplazo'])}catch(e){denied=true};assert(denied,'lista antigua no cierra nueva sesión');
 await context(1,2,'b');await db.exec('select public.axi_sesion_cerrar()');await check('select count(*)::int as v from private.axi_sesiones',0,'cierre propio libera');
 // Revocación Auth (un JWT no vencido tampoco permite continuar).
 await db.exec("insert into auth.sessions values('10000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001',null),('10000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001',null),('10000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000001',null)");
 await context(1,4,'d');await db.exec('select public.axi_sesion_iniciar()');await db.exec("delete from auth.sessions where id='10000000-0000-0000-0000-000000000004'");
 await check('select private.axi_sesion_valida() as v',false,'Auth revocada bloquea JWT restante');
 await context(1,5,'e');await check("select (public.axi_sesion_iniciar()->>'rol') as v",'Propietario','Auth revocada permite ingreso nuevo');
 // Intentos concurrentes enviados al motor: la unicidad conserva un solo propietario.
 await db.exec('select public.axi_sesion_cerrar()');
 await context(1,6,'f');
 const results=await Promise.all(Array.from({length:10},()=>query('select public.axi_sesion_iniciar() as v')));
 assert.equal(results.length,10);await check('select count(*)::int as v from private.axi_sesiones',1,'diez solicitudes conservan una sesión');
 await db.close();console.log('PRUEBAS SQL COMPLETADAS (motor local, datos sintéticos)');
})().catch(e=>{console.error(e);process.exit(1)});

