(function(){'use strict';
 const api='https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-despacho-seguimiento';
 let token=new URLSearchParams(location.hash.slice(1)).get('token')||'',busy=false,current=null;
 const $=id=>document.getElementById(id),valid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(token);
 const fmt=x=>new Date(x).toLocaleString('es-DO',{timeZone:'America/Santo_Domingo',dateStyle:'short',timeStyle:'short'});
 async function call(accion,fecha){
  const r=await fetch(api,{method:'POST',headers:{'Content-Type':'application/json'},credentials:'omit',referrerPolicy:'no-referrer',cache:'no-store',signal:AbortSignal.timeout(20000),body:JSON.stringify({token,accion,fecha})});
  if(!r.ok)throw Error('No se pudo confirmar la operación. Intente nuevamente.');return r.json();
 }
 function render(d){current=d;$('hora').hidden=true;$('llegue').hidden=true;
  if(!d.ok){$('titulo').textContent='Enlace no disponible';$('detalle').textContent=d.error||'Consulte a administración.';return;}
  $('titulo').textContent=(d.codigo||'Servicio')+' · '+d.estado;
  $('detalle').textContent=d.llegada?'Llegada registrada: '+fmt(d.llegada)+'.':d.estimada?'Llegada estimada: '+fmt(d.estimada)+'. Ventana: '+fmt(d.desde)+' a '+fmt(d.hasta)+' (hora de República Dominicana).':'Confirme una hora concreta antes de su visita.';
  if(d.estado==='Pendiente de hora')$('hora').hidden=false;
  if(['Pendiente de hora','Programado'].includes(d.estado))$('llegue').hidden=false;
  if(['Cancelado','Finalizado'].includes(d.estado))$('detalle').textContent='Esta asignación ya no está activa. Contacte a administración antes de acudir.';
 }
 async function run(action,date){if(busy)return;busy=true;document.querySelectorAll('button').forEach(b=>b.disabled=true);$('estado').textContent='Procesando…';try{const d=await call(action,date);if(action!=='consultar')$('estado').textContent=d.mensaje||d.error||'';else $('estado').textContent='';if(action==='consultar')render(d);else render(await call('consultar'));}catch(e){$('estado').textContent=e.message;}finally{busy=false;document.querySelectorAll('button').forEach(b=>b.disabled=false);}}
 $('confirmar').addEventListener('click',()=>{if(!$('fecha').value){$('estado').textContent='Seleccione una fecha y hora.';return;}run('fecha',$('fecha').value+':00-04:00');});
 $('llegue').addEventListener('click',()=>{if(confirm('¿Confirma que ya se encuentra en el lugar del servicio?'))run('llegada');});
 $('actualizar').addEventListener('click',()=>{if(valid)run('consultar');});
 if(valid)run('consultar');else render({ok:false,error:'Abra el enlace completo del correo de asignación.'});
})();
