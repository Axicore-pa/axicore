// ============================================================
//  AXICORE | RPT_Web.gs — Puente Google Form -> Web AXICORE
//  Agregar como ARCHIVO NUEVO en el mismo proyecto de Apps Script
//  donde estan RPT_Setup.gs y RPT_Motor.gs. No modifica nada de lo
//  que ya funciona: si la web no responde, el reporte sigue su flujo
//  normal (PDF, correo, Calendar) y solo se te avisa por correo.
// ============================================================

var AXI_WEB = {
  url: 'https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-recibir-reporte'
};

// PASO 1 (una sola vez): ejecuta esta funcion, copia la llave del
// registro de ejecucion y pegala en Supabase (Edge Functions > Secrets,
// nombre AXI_FORM_KEY). La llave queda guardada aqui en Script Properties.
function generarLlaveAxi() {
  var llave = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '');
  PropertiesService.getScriptProperties().setProperty('AXI_FORM_KEY', llave);
  Logger.log('Llave generada y guardada. Copiala en Supabase como AXI_FORM_KEY:\n' + llave);
}

// PASO 2: en RPT_Motor.gs, dentro de onReporteSubmit, justo DESPUES de
// registrar el reporte en la hoja, agrega esta linea:
//     enviarAWeb_(datos, e);
// (usa el mismo nombre de variable que tenga tu objeto de datos: d, datos, etc.)
function enviarAWeb_(d, e) {
  try {
    var llave = PropertiesService.getScriptProperties().getProperty('AXI_FORM_KEY');
    if (!llave) { registrarError_('RPT_Web: falta AXI_FORM_KEY. Ejecuta generarLlaveAxi().'); return; }

    var payload = {
      referencia:  d.referencia,
      fecha:       new Date().toISOString(),
      condominio:  d.condominio || '',
      nombre:      d.nombre || '',
      telefono:    d.telefono || '',
      correo:      d.correo || '',
      unidad:      d.unidad || '',
      categoria:   d.categoria || '',
      descripcion: d.descripcion || '',
      bloque:      d.bloque || '',
      area:        d.area || '',
      prioridad:   d.prioridad || 'Media',
      evidencia:   evidenciaUrls_(e)
    };

    var resp = UrlFetchApp.fetch(AXI_WEB.url, {
      method: 'post',
      contentType: 'application/json',
      headers: { 'x-axi-key': llave },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    });
    var code = resp.getResponseCode();
    if (code !== 200) {
      registrarError_('RPT_Web: la web no registro ' + d.referencia + ' (HTTP ' + code + '): ' + resp.getContentText().substring(0, 300));
    }
  } catch (err) {
    registrarError_('RPT_Web: fallo al enviar ' + (d && d.referencia) + ' a la web: ' + err.message);
  }
}

// Enlaces de las fotos subidas en el formulario (pregunta de archivo)
function evidenciaUrls_(e) {
  var urls = [];
  try {
    if (!e || !e.response) return urls;
    e.response.getItemResponses().forEach(function (ir) {
      if (ir.getItem().getType() === FormApp.ItemType.FILE_UPLOAD) {
        var ids = ir.getResponse() || [];
        ids.forEach(function (id) { urls.push('https://drive.google.com/file/d/' + id + '/view'); });
      }
    });
  } catch (x) { /* sin evidencia */ }
  return urls;
}

// PRUEBA: envia un reporte ficticio a la web (crea AXI-RPT-AAAA-99999).
// Despues de probar, avisa para borrarlo de la web.
function probarEnvioWeb() {
  enviarAWeb_({
    referencia: 'AXI-RPT-' + new Date().getFullYear() + '-99999',
    condominio: 'Residencial DH2', nombre: 'PRUEBA Sistema', telefono: '809-555-0000', correo: '',
    unidad: '1-D', categoria: 'Otro', descripcion: 'Prueba de conexion Form -> Web', bloque: '',
    area: 'Otro', prioridad: 'Baja'
  }, null);
  Logger.log('Enviado. Si no llego un correo de error, la conexion funciona.');
}
