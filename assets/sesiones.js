/* AXICORE: autenticación por pestaña y prueba de posesión; autoridad en PostgreSQL. */
(() => {
  'use strict';
  const random = () => Array.from(crypto.getRandomValues(new Uint8Array(32)), b => b.toString(16).padStart(2, '0')).join('');
  let token = sessionStorage.getItem('axi-tab-v1') || random();
  sessionStorage.setItem('axi-tab-v1', token);
  let release;
  let duplicateSession = null;
  const clearLocal = () => {
    for (let i = sessionStorage.length - 1; i >= 0; i--) {
      const k = sessionStorage.key(i);
      if (k.startsWith('axi-auth-v3')) sessionStorage.removeItem(k);
    }
  };
  const ready = new Promise((resolve, reject) => {
    if (!navigator.locks) { reject(new Error('Actualice su navegador para usar el acceso seguro de AXICORE.')); return; }
    const hold = async (lock) => {
      if (!lock) {
        // Una copia no debe renovar el refresh_token compartido con su original.
        try {
          const access = JSON.parse(sessionStorage.getItem('axi-auth-v3'))?.access_token;
          if (access) duplicateSession = {access_token:access};
        } catch (_) {}
        clearLocal();
        token = random();
        sessionStorage.setItem('axi-tab-v1', token);
        return navigator.locks.request('axi-tab-' + token, {ifAvailable: true}, hold);
      }
      resolve();
      await new Promise(r => { release = r; });
    };
    navigator.locks.request('axi-tab-' + token, {ifAvailable: true}, hold).catch(reject);
  });
  // No dejar rechazos sin manejar antes de que se intente abrir la aplicación.
  ready.catch(() => {});
  window.addEventListener('pagehide', () => { if (release) release(); });
  window.addEventListener('pageshow', e => { if (e.persisted) location.reload(); });
  // BroadcastChannel de Supabase usa storageKey. Una clave por documento impide
  // que un login nuevo transmita sus tokens a la primera pestaña.
  const runtimeKey = 'axi-runtime-' + random();
  const key = k => 'axi-auth-v3' + k.slice(runtimeKey.length);
  const storage = {
    getItem: async k => { await ready; return sessionStorage.getItem(key(k)); },
    setItem: (k, v) => sessionStorage.setItem(key(k), v),
    removeItem: k => sessionStorage.removeItem(key(k)),
  };
  let lastInvalid = 0;
  window.AXISession = {
    ready,
    takeDuplicateSession() { const copy = duplicateSession; duplicateSession = null; return copy; },
    options: {
      auth: {storage, storageKey: runtimeKey, persistSession: true, autoRefreshToken: true, detectSessionInUrl: true},
      global: {fetch: async (input, init = {}) => {
        await ready;
        const url = new URL(typeof input === 'string' ? input : input.url);
        const headers = new Headers(init.headers || (input instanceof Request ? input.headers : undefined));
        if (/^\/(rest|storage|functions)\/v1\//.test(url.pathname)) headers.set('x-axicore-tab', token);
        const response = await fetch(input, {...init, headers});
        if (!response.ok && url.pathname.startsWith('/rest/v1/')) {
          const body = await response.clone().json().catch(() => ({}));
          if (String(body.message || '').includes('AXI_SESSION_INVALID') && Date.now() - lastInvalid > 1000) {
            lastInvalid = Date.now();
            setTimeout(() => window.dispatchEvent(new Event('axi-session-invalid')), 0);
          }
        }
        return response;
      }},
    },
    clearLocal,
  };
})();

