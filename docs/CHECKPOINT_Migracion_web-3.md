# CHECKPOINT — Migración Access a plataforma web-3 (11/10/2026 16:15)

Leer primero. Viene de los chats "Transicion a Web", "Migración Access a plataforma web-2" y su continuación.
Memoria: areas/migracion-web-3.md (este checkpoint), areas/transicion-web.md (historial), areas/modulo-glp.md, areas/modulo-mantenimiento-web.md, preferences.md.

## Reglas de trabajo
- No dejar fuera ni agregar nada sin consultar a Misael al 100%.
- Antes de actuar: riesgos, pros y contras; mockup para cambios visuales antes de aplicar.
- Respuestas concisas en español; replicar Access; checkpoint en memoria por tarea.

## Estado técnico
- Supabase `qfgyftsnwznsqizriggr` (FREE). SPA `index.html` en `Axicore-pa/axicore` → https://axicore-pa.github.io/axicore/. Último commit `6ac3b15`. SQL de registro en `sql/` hasta 22.
- Correo Gmail axispard: Edge Functions `axi-enviar-correo` (web) y `axi-correo-cola` (cola `correos_salida`, cron cada minuto). Funciona.
- `apply_migration`/`execute_sql` cancelan sentencias con DROP: partir migraciones; pruebas en DO con RAISE final.

## Pendientes — acciones de Misael
1. Puente Google Form → web: pegar `apps-script/RPT_Web.gs`, ejecutar `generarLlaveAxi`, crear secreto `AXI_FORM_KEY`, agregar `enviarAWeb_(datos, e);` en `onReporteSubmit`, ejecutar `probarEnvioWeb` (borrar AXI-RPT-AAAA-99999 después).
2. CSV de la hoja de Reservas → migrar reservas futuras (desde 12/10) como Aprobadas.
3. Avisar cuando todos tengan cuenta → apagar web app de reservas Google y cambiar QR.
4. Invitar cuentas reales en Supabase Auth; unidad de asia.mashtak@gmail.com (no 1-D).
5. Pruebas con clics (aplazadas).
6. Confirmar si Outlook carga el CCO del .eml.

## Decisiones pendientes
- ¿'Pago móvil' en métodos de pago?
- GLP: ¿sección 1 y email/WhatsApp al inquilino cuando existe?
- PDF factura/recibo general (capturas de Access) y envío de recordatorios de cobro.
- Opcional: PDF de ejemplo del Google Form.
- Facturación mensual automática (cron desactivado, requiere OK).

## Trabajo futuro
- Módulo Cumplimiento de Metas; UI fases 2–4.
- Regenerar respaldo frío (último `ffa6314`, 09/10).
- Datos: inquilino 10 (u6) sin teléfono; revisar pago inquilino 11 (u8).
