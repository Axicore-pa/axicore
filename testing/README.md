# Pruebas de sesión única

Incluye avisos de sesión aceptada al CEO: aplicar las tres migraciones en el motor local mediante sesiones-sql.cjs. Cada INSERT de sesión aceptada encola un aviso por CEO distinto; UPDATE, recarga y rechazo no lo hacen. Los avisos de rechazo conservan destinatarios y agrupación originales. Se comprueban contenido, destinatario único, inicios sucesivos y diez solicitudes sin duplicados. No prueba entrega SMTP real.

Sólo datos sintéticos. No se conecta a Supabase ni se envían correos.

Instalar con pnpm en esta carpeta usando package.json y pnpm-lock.yaml; ejecutar `node sesiones-sql.cjs`.
PGlite usa un reemplazo de extensions.digest basado en sha256 nativo; producción usa pgcrypto. Sus llamadas concurrentes se serializan: no equivale a dos conexiones PostgreSQL reales. La exclusión de producción usa advisory locks transaccionales y restricciones UNIQUE.

Para navegador se requiere Playwright y Chrome: AXICORE_NODE_MODULES apunta a su carpeta de módulos y AXICORE_BROWSER al ejecutable. Descargar para pruebas el UMD exacto https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js como testing/supabase-2.45.4.js (archivo ignorado); ejecutar `node sesiones-browser.cjs`. Se usa el SDK real y un servidor simulado. El dashboard se sustituye para probar específicamente autenticación, pestañas, recarga, cierre y revocación.

La migración inicia con habilitada=false. Activar sólo después de publicar index.html, assets/sesiones.js y la Edge Function que propaga x-axicore-tab. No se debe reejecutar la migración ni desactivar controles para realizar pruebas reales.

El registro private.axi_sesiones es la autoridad; las filas históricas previas de historial_sesiones no se interpretan como bloqueos. Cerrar navegador no libera el registro. CEO debe verificar al usuario y dejar motivo en la recuperación. No hay tiempo de gracia ni reemplazo automático de la primera sesión.

Alcance: sesiones interactivas de AXICORE. Procesos automáticos de correo, reportes y cron conservan su autorización existente. Los archivos públicos y enlaces firmados ya emitidos conservan sus reglas y vencimiento; liberar sesión no borra descargas ni revoca enlaces firmados. Un JWT y la prueba de pestaña copiados íntegramente fuera del flujo normal requieren gestión adicional de credenciales; esta regla no sustituye MFA ni protección de la cuenta.

