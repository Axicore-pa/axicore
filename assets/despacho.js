/* AXICORE: formulario público por enlace de despacho. Sin sesión de residente. */
(function () {
  'use strict';
  var endpoint = 'https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-despacho-responder';
  var uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  var fragment = new URLSearchParams(window.location.hash.slice(1));
  var query = new URLSearchParams(window.location.search);
  var token = fragment.get('token') || query.get('token') || '';
  // Los nuevos enlaces usan fragmento. Migrar consultas antiguas sin recargar.
  if (query.has('token')) {
    query.delete('token');
    window.history.replaceState(null, '', window.location.pathname +
      (query.toString() ? '?' + query.toString() : '') +
      '#token=' + encodeURIComponent(token));
  }
  var form = document.getElementById('form');
  var btn = document.getElementById('btnEnviar');
  var opts = Array.prototype.slice.call(document.querySelectorAll('.opt'));
  var status = document.getElementById('estado');
  var seleccion = null, sending = false, finished = false;
  function message(title, detail, ok) {
    var div = document.createElement('div');
    div.className = 'msg ' + (ok ? 'ok' : 'err');
    div.setAttribute('role', 'status');
    var h = document.createElement('h2');
    h.textContent = title;
    div.appendChild(h);
    if (detail) {
      var p = document.createElement('p');
      p.textContent = detail;
      div.appendChild(p);
    }
    form.replaceChildren(div);
  }
  if (!uuid.test(token)) {
    message('Enlace inválido', 'Abra el enlace completo recibido en el correo de AXICORE.', false);
    return;
  }
  opts.forEach(function (opt) {
    opt.addEventListener('click', function () {
      if (sending || finished) return;
      seleccion = opt.getAttribute('data-val');
      opts.forEach(function (other) {
        var chosen = other === opt;
        other.classList.toggle('selected', chosen);
        other.setAttribute('aria-pressed', String(chosen));
      });
      status.textContent = '';
      btn.disabled = false;
    });
  });
  btn.addEventListener('click', async function () {
    if (!seleccion || sending || finished) return;
    sending = true;
    btn.disabled = true;
    btn.textContent = 'Enviando...';
    opts.forEach(function (opt) { opt.disabled = true; });
    var controller = new AbortController();
    var timeout = window.setTimeout(function () { controller.abort(); }, 20000);
    try {
      var res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'omit',
        referrerPolicy: 'no-referrer',
        cache: 'no-store',
        body: JSON.stringify({ token: token, respuesta: seleccion }),
        signal: controller.signal
      });
      var data = await res.json();
      if (res.ok && data && data.ok === true) {
        finished = true;
        token = '';
        window.history.replaceState(null, '', window.location.pathname);
        message('✅ ' + (typeof data.mensaje === 'string' ? data.mensaje : 'Respuesta registrada'),
          'Puede cerrar esta página.', true);
      } else if (res.status >= 500 || res.status === 429) {
        status.textContent = 'No se pudo confirmar el envío. Intente nuevamente.';
      } else {
        finished = true;
        message('⚠️ ' + (data && typeof data.error === 'string' ? data.error : 'No se pudo registrar la respuesta'), '', false);
      }
    } catch {
      status.textContent = 'No se pudo confirmar el envío. Revise su conexión e intente nuevamente.';
    } finally {
      window.clearTimeout(timeout);
      sending = false;
      if (!finished) {
        btn.disabled = false;
        btn.textContent = 'Confirmar respuesta';
        opts.forEach(function (opt) { opt.disabled = false; });
      }
    }
  });
})();
