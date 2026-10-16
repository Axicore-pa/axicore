# Circulares y confirmación de conocimiento

Actualización de correo autorizada el 16/10/2026: remitente AXICORE <Admin@axicorepard.com>, firma APA | AxiCore Property Administration / Tel. 809-282-7776 / axispard@gmail.com en avisos y comprobantes. Las invitaciones Auth siguen su configuración SMTP propia.

Código de documento manual, obligatorio para nuevas cargas, normalizado a mayúsculas y único. Campo separado del título, de 3 a 80 caracteres alfanuméricos y guiones, sin saltos de línea. Asunto: código - título. La lista, aviso, visor, envío y comprobante identifican la circular con ese encabezado. La confirmación de envío muestra remitente y asunto antes de encolar.

SQL de actualización: sql/circulares_codigo_correo.sql, aplicado como 20261016074139_axicore_circulares_codigo_firma y guardado con ese mismo identificador en supabase/migrations. Conserva títulos históricos y acuses; solo recupera prefijos CIR inequívocos existentes sin duplicarlos en el asunto. Los títulos previos sin código separado se conservan completos. No se reenvían correos ni se crean circulares durante el despliegue.

Autorizado: CEO/Asistente cargan PDF, PNG o JPG de hasta 10 MB para el condominio seleccionado. Los perfiles de residentes con acceso activo a ese condominio consultan sus publicaciones. Una dirección válida por perfil activo (Inquilino/Propietario/Administrador), deduplicada y normalizada, recibe un aviso con CC a axispard@gmail.com cuando staff pulsa Enviar. No se envían adjuntos ni se modifican los correos de otros módulos.

Al iniciar sesión se ofrece Leída, No leída y Abrir circular. Leída es una declaración explícita de conocimiento; Abrir circular genera la misma declaración tras renderizar correctamente la primera página o imagen. No leída no cambia el estado persistente. No se exige llegar a la última página. Un acuse por acceso/perfil y circular, transaccional con su correo al CEO; no acredita comprensión, asistencia ni aprobación. El texto notifica a la Asamblea dentro del registro de AXICORE; la interfaz distingue el correo en cola de su aceptación por el proveedor.

Archivos privados y controles de permisos en PostgreSQL y Storage; no se entregan URLs públicas ni firmadas. El navegador obtiene bytes autorizados y los dibuja en canvas con marca de consulta. No existen controles de descarga/impresión, pero un dispositivo autorizado puede copiar los datos o tomar capturas. PDF.js 4.10.38 se carga desde jsDelivr con evaluación dinámica y XFA deshabilitados.

La nueva función axi-circulares-correo usa RESEND_API_KEY como secreto de Supabase (introducido por el usuario). Las invitaciones siguen usando SMTP. El cron nuevo procesa solo esta cola cada minuto y no altera axi-correo-cola ni sus avisos Gmail. Lotes de cinco con arrendamiento de cinco minutos, exclusión entre lotes e idempotency key estable en Resend. Los reintentos se limitan a seis y a 23 horas desde el primer intento, dentro de las 24 horas de idempotencia del proveedor. Un fallo permanente exige revisión; no se reenvía automáticamente un lote ya encolado.

Pruebas locales con datos sintéticos y sin SMTP real:

    node --max-old-space-size=4096 --liftoff-only --no-wasm-tier-up testing/circulares-sql.cjs
    node testing/circulares-browser.cjs
    node testing/circulares-correo.cjs

El motor local verifica permisos, MFA, sesión revocada, Storage, separación entre condominios, deduplicación de destinatarios y acuses. El navegador ejecuta el HTML integrado y el módulo real con servicios simulados, imagen y PDF real de dos páginas; comprueba las tres opciones, cierre, errores, carga staff y vista móvil. El worker se ejecuta con respuesta Resend simulada para comprobar sobres, idempotencia y errores. Los módulos PDF.js de pruebas deben descargarse en testing/ usando la misma versión del módulo del visor. El arnés browser usa Playwright del runtime local y Chrome instalado; no se conecta a cuentas reales.

Reversión: sql/rollback_circulares.sql desactiva accesos y cron conservando información. Restaurar el HTML anterior. No eliminar filas reales ni objetos para deshacer el despliegue.
