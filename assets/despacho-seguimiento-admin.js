/* Seguimiento dentro de Mantenimiento. Acceso efectivo validado por RPC. */
(function(){'use strict';let serial=0;
 const el=(tag,text,parent)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(parent)parent.appendChild(n);return n;};
 const fmt=x=>x?new Date(x).toLocaleString('es-DO',{timeZone:'America/Santo_Domingo',dateStyle:'short',timeStyle:'short'})+' RD':'Sin confirmar';
 async function cargar(id){const turn=++serial,root=document.getElementById('mm-despacho');if(!root)return;root.replaceChildren();
  const {data,error}=await sb.rpc('axi_despacho_seguimiento_ver',{p_mantenimiento:id});if(turn!==serial)return;
  if(error){el('p','No se pudo cargar el seguimiento de despacho.',root);return;}
  if(!data?.despachos?.length)return;
  root.className='axi-despacho-panel';el('h3','Seguimiento del proveedor',root);
  const s=data.seguimientos?.[0];
  if(!s){el('p','Estado del despacho: '+data.despachos[0].estado+'. Sin seguimiento activo de visita.',root);}
  else {
   el('p','Turno '+s.turno+' · '+s.proveedor+' · '+s.estado,root).className='axi-estado';
   el('p','Hora estimada: '+fmt(s.estimada),root);
   if(s.estimada)el('p','Ventana de llegada: '+fmt(s.desde)+' a '+fmt(s.hasta)+' (±60 minutos).',root);
   if(s.llegada)el('p','Llegada: '+fmt(s.llegada)+' · Canal: '+s.canal,root);
   if(s.nota)el('p',s.nota,root);
   if(['Pendiente de hora','Programado'].includes(s.estado)&&data.puede_editar){
    const form=el('div',undefined,root),canalLabel=el('label','Canal de confirmación',form),canal=el('select',undefined,canalLabel);
    ['WhatsApp','Llamada','Correo','Presencial'].forEach(v=>{const o=el('option',v,canal);o.value=v;});
    const fechaLabel=el('label','Hora estimada (República Dominicana)',form),fecha=el('input',undefined,fechaLabel);fecha.type='datetime-local';
    const noteLabel=el('label','Confirmación recibida / nota',form),note=el('textarea',undefined,noteLabel);note.maxLength=1000;
    const feedback=el('p','',form);feedback.setAttribute('role','status');
    const save=el('button','Guardar hora estimada',form);save.type='button';save.className='btn btn-sm';
    const arrive=el('button','Registrar llegada',form);arrive.type='button';arrive.className='btn btn-primary btn-sm';
    async function registrar(accion){if(!note.value.trim()){feedback.textContent='Indique cómo se confirmó la llegada o la hora.';return;}if(accion==='fecha'&&!fecha.value){feedback.textContent='Seleccione la fecha y hora estimadas.';return;}
     if(accion==='llegada'&&!confirm('¿Confirma la llegada de '+s.proveedor+' según el aviso recibido por '+canal.value+'?'))return;
     save.disabled=arrive.disabled=true;
     try{const {data:r,error:e}=await sb.rpc('axi_despacho_seguimiento_registrar',{p_id:s.id,p_accion:accion,p_fecha:accion==='fecha'?fecha.value+':00-04:00':null,p_canal:canal.value,p_nota:note.value.trim()});if(e)throw e;if(!r?.ok)throw Error(r?.error||'No se pudo registrar');await cargar(id);}catch(e){feedback.textContent=e.message;save.disabled=arrive.disabled=false;}
    }
    save.addEventListener('click',()=>registrar('fecha'));arrive.addEventListener('click',()=>registrar('llegada'));
    el('p','Puede registrar una llamada o un WhatsApp sin que el proveedor responda el correo. Registrar llegada detiene el relevo automático.',form);
   }
   const hist=el('details',undefined,root);el('summary','Historial y avisos',hist);
   (s.historial||[]).forEach(h=>el('p',fmt(h.fecha)+' · '+h.accion+' · '+h.canal+(h.nota?' · '+h.nota:''),hist));
   (s.correos||[]).forEach(a=>el('p','Correo '+a.tipo+': '+a.estado,hist));
   (data.seguimientos||[]).slice(1).forEach(prev=>{el('h4','Turno '+prev.turno+' · '+prev.proveedor+' · '+prev.estado,hist);(prev.historial||[]).forEach(h=>el('p',fmt(h.fecha)+' · '+h.accion+' · '+h.canal+(h.nota?' · '+h.nota:''),hist));});
  }
  const details=el('details',undefined,root);el('summary','Respuestas y orden de disponibilidad',details);const wrap=el('div',undefined,details);wrap.className='axi-lista';const table=el('table',undefined,wrap),head=el('tr',undefined,el('thead',undefined,table));['Proveedor','Disponibilidad','Respondió','Seleccionado'].forEach(v=>el('th',v,head));const body=el('tbody',undefined,table);(data.candidatos||[]).forEach(c=>{const tr=el('tr',undefined,body);[c.proveedor,c.disponibilidad||'Sin respuesta',fmt(c.respondio),c.seleccionado?'Sí':'—'].forEach(v=>el('td',v,tr));});
  const refresh=el('button','Actualizar seguimiento',root);refresh.type='button';refresh.className='btn btn-sm';refresh.addEventListener('click',()=>cargar(id));
 }
 window.AXIDespachoSeguimiento={cargar};
})();
