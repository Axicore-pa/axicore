/* Circulares: permisos efectivos y acuses se resuelven en el servidor. */
(() => {
 'use strict';
 const $=id=>document.getElementById(id);
 const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
 const date=v=>v?new Date(v).toLocaleString('es-DO'):'—';
 let ctx=null,generation=0,listSeq=0,rows=[],staff=false,recipients=0,dismissed=new Set(),scope='';
 let pdfModule=null,viewerCleanup=null;
 const dialogs=new Set();
 const active=g=>ctx&&generation===g;
 async function rpc(name,args){const {data,error}=await ctx.sb.rpc(name,args);if(error)throw Error(error.message);return data;}
 function button(text,fn,cls='btn btn-outline'){const b=el('button',text,cls);b.type='button';b.onclick=fn;return b;}
 function status(box,text,cls='axi-circ-error'){box.className=cls;box.textContent=text;}
 function dialog(title,cls=''){
  const d=el('dialog',undefined,'axi-circ-dialog '+cls);d.setAttribute('aria-label',title);
  const x=button('×',()=>d.close(),'axi-circ-close');x.setAttribute('aria-label','Cerrar');
  d.append(x,el('h2',title));document.body.append(d);dialogs.add(d);
  d.addEventListener('close',()=>{dialogs.delete(d);d.remove();},{once:true});return d;
 }
 function closeAll(){for(const d of [...dialogs])d.close();if(viewerCleanup){viewerCleanup();viewerCleanup=null;}document.body.classList.remove('axi-circ-viewing');}
 function errorPage(message){const box=$('axi-circ-list');box.replaceChildren(el('p',message,'axi-circ-error'),button('Reintentar',()=>load()));}
 async function load(){
  if(!ctx)return;const g=generation,seq=++listSeq;const condo=ctx.sesion.condominio_id,rol=ctx.sesion.rol;
  $('axi-circ-list').textContent='Cargando circulares…';
  try{const data=await rpc('axi_circulares_listar',{p_condominio_id:condo,p_rol:rol});if(!active(g)||seq!==listSeq)return;
   rows=data.circulares||[];staff=data.staff;recipients=data.destinatarios||0;render();return rows;
  }catch(e){if(active(g)&&seq===listSeq)errorPage(e.message);}
 }
 function render(){
  $('axi-circ-new').hidden=!staff;$('axi-circ-scope').textContent=ctx.nombreCondominio;
  $('axi-circ-intro').textContent=staff?'Publica información para este condominio y envía un aviso individual por correo a sus residentes.':'Consulta la información de tu condominio. Elegir Leída o abrir una circular registra tu acuse de conocimiento.';
  const root=$('axi-circ-list');root.replaceChildren();
  if(!rows.length){root.append(el('div','Todavía no hay circulares disponibles.','axi-circ-card'));return;}
  for(const c of rows){
   const card=el('article',undefined,'axi-circ-card'),state=!c.publicado_at?'Borrador':c.leido_at?'Leída':staff?'Publicada':'No leída';
   card.append(el('span',state,'axi-circ-state '+(c.leido_at?'read':!staff?'pending':'')),el('h3',c.titulo),el('p',c.descripcion));
   card.append(el('div',(c.publicado_at?'Publicada: '+date(c.publicado_at):'Creada: '+date(c.creado_at))+(c.leido_at?' · Lectura: '+date(c.leido_at):''),'axi-circ-meta'));
   const actions=el('div',undefined,'axi-circ-actions');
   actions.append(button('Abrir circular',()=>open(c)));
   if(staff){
    if(!c.publicado_at)actions.append(button('Publicar',()=>publish(c),'btn btn-primary'));
    else{
     const send=button(c.enviado_at?'Aviso encolado':'Enviar',()=>sendMail(c),'btn btn-primary');send.disabled=!!c.enviado_at;actions.append(send);
     actions.append(button('Lecturas y envíos',()=>details(c)));
     if(c.envios?.total)card.append(el('p',`Correos: ${c.envios.enviados} aceptados por el proveedor · ${c.envios.pendientes} pendientes · ${c.envios.errores} con error.`,'axi-circ-meta'));
     card.append(el('div',`${c.lecturas||0} confirmaciones de lectura`,'axi-circ-meta'));
    }
   }else if(!c.leido_at)actions.append(button('Leída',()=>readDirect(c),'btn btn-primary'));
   card.append(actions);root.append(card);
  }
 }
 function notice(){
  if(!ctx||staff||[...dialogs].some(d=>d.open))return;
  const c=rows.find(r=>r.publicado_at&&!r.leido_at&&!dismissed.has(r.id));if(!c)return;
  const d=dialog('Nueva Circular Disponible','axi-circ-notice');
  d.append(el('h3',c.titulo),el('p',ctx.nombreCondominio),el('p','Al elegir Leída o Abrir circular se registrará tu acuse de conocimiento y se enviará un comprobante al CEO. No leída mantiene el aviso para tu próximo inicio de sesión.'));
  const actions=el('div',undefined,'axi-circ-actions');
  actions.append(button('Abrir circular',()=>{d.close();open(c);},'btn btn-primary'),button('Leída',()=>{d.close();readDirect(c);}),button('No leída',()=>{dismissed.add(c.id);d.close();notice();}));d.append(actions);
  d.addEventListener('cancel',()=>dismissed.add(c.id));d.querySelector('.axi-circ-close').onclick=()=>{dismissed.add(c.id);d.close();notice();};d.showModal();
 }
 const readMessage='Se ha notificado a la Asamblea de que está en conocimiento de esta información.';
 async function mark(c,g){
  const s={...ctx.sesion};const data=await rpc('axi_circular_leida',{p_id:c.id,p_rol:s.rol});
  if(!active(g))return null;c.leido_at=data.leido_at;
  const current=rows.find(r=>r.id===c.id);if(current)current.leido_at=data.leido_at;render();return data;
 }
 async function readDirect(c){
  const g=generation,d=dialog('Confirmación de lectura'),msg=el('p','Registrando confirmación…');d.append(msg);d.showModal();
  try{const data=await mark(c,g);if(!active(g)||!data)return;
   status(msg,readMessage,'axi-circ-success');d.append(el('p','Acuse registrado. El correo al CEO está en cola de envío.'),el('small','Comprobante: '+data.comprobante),button('Cerrar',()=>{d.close();notice();}));
  }catch(e){if(active(g)){status(msg,e.message);d.append(button('Reintentar',()=>{d.close();readDirect(c);}));}}
 }
 async function open(c){
  if(!ctx)return;const g=generation,session={...ctx.sesion},isStaff=staff;
  const d=dialog(c.titulo,'axi-circ-viewer');const title=d.querySelector('h2');const bar=el('div',undefined,'axi-circ-viewer-bar');bar.append(title);
  const x=d.querySelector('.axi-circ-close');bar.append(x);d.prepend(bar);
  const msg=el('p','Cargando circular…'),wrap=el('div',undefined,'axi-circ-canvas-wrap'),canvas=el('canvas');wrap.append(canvas);wrap.oncontextmenu=e=>e.preventDefault();
  const nav=el('div',undefined,'axi-circ-page-nav'),counter=el('span'),prev=button('Anterior',()=>turn(-1)),next=button('Siguiente',()=>turn(1));nav.append(prev,counter,next);nav.hidden=true;
  const foot=el('div',undefined,'axi-circ-actions');foot.append(button('Cerrar y volver al inicio',()=>d.close()));d.append(msg,wrap,nav,foot);d.showModal();document.body.classList.add('axi-circ-viewing');
  let pdf=null,task=null,page=1,total=1,url=null,busy=false,closed=false,readError=false;
  const clean=()=>{closed=true;task?.destroy();pdf?.destroy();if(url)URL.revokeObjectURL(url);canvas.width=canvas.height=0;};viewerCleanup=clean;
  d.addEventListener('close',()=>{clean();viewerCleanup=null;document.body.classList.remove('axi-circ-viewing');if(active(g)){ctx.inicio();if(!readError)notice();}},{once:true});
  function watermark(){const x=canvas.getContext('2d');x.save();x.font=Math.max(12,Math.round(canvas.width/75))+'px sans-serif';x.fillStyle='rgba(27,42,73,.50)';x.fillText('AXICORE · '+session.nombre+' · Consulta personal',14,canvas.height-14);x.restore();}
  async function renderPage(){if(closed||!active(g))return;busy=true;prev.disabled=next.disabled=true;const p=await pdf.getPage(page);const base=p.getViewport({scale:1}),vp=p.getViewport({scale:Math.min(1.8,1400/base.width)});canvas.width=vp.width;canvas.height=vp.height;await p.render({canvasContext:canvas.getContext('2d'),viewport:vp}).promise;if(closed||!active(g))return;watermark();counter.textContent=`Página ${page} de ${total}`;busy=false;prev.disabled=page===1;next.disabled=page===total;}
  async function turn(delta){if(busy)return;page=Math.max(1,Math.min(total,page+delta));try{await renderPage();}catch(e){status(msg,'No se pudo mostrar la página: '+e.message);}}
  async function acknowledge(){try{const data=await mark(c,g);if(data&&!closed){status(msg,readMessage+' Acuse registrado; correo al CEO en cola de envío.','axi-circ-success');readError=false;}}
   catch(e){if(!closed){readError=true;status(msg,'La circular se abrió, pero no se pudo registrar el acuse: '+e.message);const retry=button('Reintentar confirmación',async()=>{retry.disabled=true;await acknowledge();retry.remove();});foot.append(retry);}}}
  try{
   const meta=await rpc('axi_circular_abrir',{p_id:c.id,p_rol:session.rol});if(closed||!active(g))return;
   const {data:blob,error}=await ctx.sb.storage.from('circulares').download(meta.archivo);if(error)throw Error(error.message);if(closed||!active(g))return;
   if(meta.mime==='application/pdf'){
    if(!pdfModule)pdfModule=import('https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.min.mjs').catch(e=>{pdfModule=null;throw e;});
    const lib=await pdfModule;lib.GlobalWorkerOptions.workerSrc='https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.worker.min.mjs';
    task=lib.getDocument({data:new Uint8Array(await blob.arrayBuffer()),isEvalSupported:false,enableXfa:false});pdf=await task.promise;
    if(closed||!active(g)){pdf.destroy();return;}total=pdf.numPages;nav.hidden=total<2;await renderPage();
   }else{
    url=URL.createObjectURL(blob);const img=new Image();img.src=url;await img.decode();if(closed||!active(g))return;
    const scale=Math.min(1,1600/img.naturalWidth,2400/img.naturalHeight);canvas.width=img.naturalWidth*scale;canvas.height=img.naturalHeight*scale;canvas.getContext('2d').drawImage(img,0,0,canvas.width,canvas.height);watermark();URL.revokeObjectURL(url);url=null;
   }
   if(closed||!active(g))return;msg.textContent='';if(!isStaff&&!c.leido_at)await acknowledge();else msg.textContent=c.leido_at?'Lectura confirmada: '+date(c.leido_at):'Vista de la circular';
  }catch(e){if(!closed&&active(g))status(msg,'No se pudo abrir la circular. No se registró un acuse nuevo. '+e.message);}
 }
 function create(){
  if(!staff)return;const g=generation,condo=ctx.sesion.condominio_id;
  const d=dialog('Nueva circular'),form=el('form'),t=el('input'),desc=el('textarea'),file=el('input'),msg=el('p');
  t.id='axi-circ-title';t.required=true;t.maxLength=180;desc.id='axi-circ-description';desc.maxLength=3000;file.id='axi-circ-file';file.type='file';file.required=true;file.accept='.pdf,.png,.jpg,.jpeg';
  const field=(text,input)=>{const label=el('label',text);label.htmlFor=input.id;form.append(label,input);};
  form.append(el('p','Condominio: '+ctx.nombreCondominio));field('Título',t);field('Descripción',desc);field('Circular (PDF, PNG o JPG · máximo 10 MB)',file);
  const save=button('Subir y publicar',null,'btn btn-primary');save.type='submit';const actions=el('div',undefined,'axi-circ-actions');actions.append(save,button('Cancelar',()=>d.close()));form.append(msg,actions);d.append(form);d.showModal();
  let draft=null,uploaded=false;
  form.onsubmit=async e=>{e.preventDefault();if(!active(g))return;save.disabled=true;
   try{
    if(!draft){const f=file.files[0];if(!f||f.size<1||f.size>10485760)throw Error('Seleccione un archivo de hasta 10 MB.');
     const ext=f.name.split('.').pop().toLowerCase(),mime={pdf:'application/pdf',png:'image/png',jpg:'image/jpeg',jpeg:'image/jpeg'}[ext];if(!mime)throw Error('Solo PDF, PNG o JPG.');
     const bytes=new Uint8Array(await f.slice(0,8).arrayBuffer());const magic=mime==='application/pdf'?String.fromCharCode(...bytes.slice(0,5))==='%PDF-':mime==='image/png'?bytes.slice(0,8).join(',')==='137,80,78,71,13,10,26,10':bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
     if(!magic)throw Error('El contenido no corresponde al tipo de archivo.');
     status(msg,'Subiendo circular…','axi-circ-meta');draft=await rpc('axi_circular_preparar',{p_condominio_id:condo,p_titulo:t.value.trim(),p_descripcion:desc.value.trim(),p_mime:mime,p_tamano:f.size});
     draft.file=f;draft.mime=mime;t.disabled=desc.disabled=file.disabled=true;
    }
    if(!active(g))return;
    if(!uploaded){const r=await ctx.sb.storage.from('circulares').upload(draft.archivo,draft.file,{contentType:draft.mime,upsert:false});if(r.error)throw Error(r.error.message);uploaded=true;}
    if(!active(g))return;await rpc('axi_circular_publicar',{p_id:draft.id});if(!active(g))return;d.close();await load();
   }catch(e){if(active(g)){status(msg,e.message+(draft?' El borrador se conserva; puede reintentar o publicarlo desde la lista.':''));save.textContent='Reintentar';}}
   finally{save.disabled=false;}
  };
 }
 async function publish(c){const g=generation;try{await rpc('axi_circular_publicar',{p_id:c.id});if(active(g))await load();}catch(e){if(active(g))alert(e.message);}}
 function sendMail(c){
  const g=generation,d=dialog('Enviar circular'),msg=el('p',`Se enviará un correo individual a ${recipients} direcciones únicas de residentes activos de ${ctx.nombreCondominio}. Cada correo llevará CC a axispard@gmail.com.`);
  d.append(msg,el('p','Los correos incluirán el enlace al portal, sin adjuntar el archivo. El estado Enviado confirma aceptación por el proveedor, no lectura ni entrega en bandeja.'));
  const send=button('Enviar',async()=>{send.disabled=true;try{const n=await rpc('axi_circular_enviar',{p_id:c.id});if(!active(g))return;status(msg,`${n} avisos en cola de envío.`,'axi-circ-success');send.remove();await load();}catch(e){if(active(g)){status(msg,e.message);send.disabled=false;}}},'btn btn-primary');
  const actions=el('div',undefined,'axi-circ-actions');actions.append(send,button('Cerrar',()=>d.close()));d.append(actions);d.showModal();
 }
 async function details(c){
  const g=generation,d=dialog('Lecturas y envíos'),body=el('div'),msg=el('p','Cargando…');d.append(msg,body);
  const refresh=button('Actualizar',draw);d.append(refresh,button('Cerrar',()=>d.close()));d.showModal();await draw();
  async function draw(){refresh.disabled=true;try{const data=await rpc('axi_circular_comprobantes',{p_id:c.id});if(!active(g)||!d.open)return;body.replaceChildren();msg.textContent=c.titulo;
   function table(title,headers,records){body.append(el('h3',title));if(!records.length){body.append(el('p','Sin registros.'));return;}const wrap=el('div',undefined,'axi-circ-table-wrap'),t=el('table',undefined,'axi-circ-details'),head=el('tr');for(const h of headers)head.append(el('th',h));t.append(head);for(const record of records){const r=el('tr');for(const value of record)r.append(el('td',value||'—'));t.append(r);}wrap.append(t);body.append(wrap);}
   table('Confirmaciones de conocimiento',['Perfil','Correo','Unidades','Fecha','Comprobante'],data.lecturas.map(r=>[r.perfil.nombre+' · '+r.perfil.rol,r.perfil.correo,r.perfil.unidades,date(r.leido_at),r.comprobante]));
   table('Correos',['Destino','Tipo','Estado','Detalle'],data.correos.map(r=>[r.para,r.tipo,r.estado,r.error||date(r.enviado_at)]));
  }catch(e){if(active(g))status(msg,e.message);}finally{refresh.disabled=false;}}
 }
 window.AXICirculares={
  async iniciar(options){const next=[options.sesion.usuario_id,options.sesion.rol,options.sesion.condominio_id].join(':');if(scope!==next){generation++;closeAll();rows=[];staff=false;recipients=0;dismissed=new Set();scope=next;$('axi-circ-new').hidden=true;}ctx={...options,sesion:{...options.sesion}};const g=generation;const result=await load();if(active(g)&&result)notice();},
  mostrar:load,
  cerrar(){generation++;closeAll();ctx=null;rows=[];scope='';dismissed.clear();},
 };
 document.addEventListener('DOMContentLoaded',()=>{$('axi-circ-new').onclick=create;$('axi-circ-refresh').onclick=()=>load();});
})();
