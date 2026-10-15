# AXICORE — Punto compartido de continuidad
Última actualización documental: 14/10/2026.
Responsable del proyecto: Misael.
Colaboradores: Claude y ChatGPT/Codex.
Estado: revisión inicial del código realizada; verificación de Supabase y pruebas de uso pendientes.

## Leer primero al retomar
Este archivo es la referencia compartida para retomar el proyecto desde cualquiera de las dos IA. No conecta ni sincroniza sus memorias. Cada asistente necesita acceso al repositorio y debe leer la versión actual antes de trabajar.
El código y los SQL están en este repositorio; el estado efectivo de la base debe comprobarse en Supabase. Una migración presente en GitHub no demuestra que esté aplicada.
El checkpoint y el PDF entregados por Misael son antecedentes del proyecto; sus cifras y resultados históricos no se consideran pruebas ejecutadas de nuevo.
No guardar contraseñas, tokens, claves privadas, datos personales de residentes ni exportaciones de producción en este archivo.

## Reglas acordadas
- Replicar Access: no agregar ni omitir funciones sin consultar a Misael.
- Antes de proponer cambios, explicar riesgos, pros y contras; presentar mockup antes de aplicar cambios visuales.
- Responder de forma concisa en español.
- Actualizar este checkpoint por tarea, distinguiendo cambios, validaciones y pendientes.
- No activar facturación mensual automática sin autorización explícita.
- No convertir decisiones pendientes en requisitos aprobados.

## Fuentes y estado verificado
- Repositorio: Axicore-pa/axicore.
- Web: https://axicore-pa.github.io/axicore/
- Supabase, proyecto informado: qfgyftsnwznsqizriggr, plan FREE.
- Base de código revisada: 5f247be8a1cfd8de51882fbb544559574125c3da.
- Commit anterior del catálogo Administrador: 070f4a0f6b2ad7bf07b636cce95345b22223d9b9.
- index.html revisado: 6.420 líneas. Las aproximadamente 5.000 del resumen eran una estimación.
- Se leyó sql/27_administradores_propiedades.sql: tablas, asignaciones por unidad, permisos, catálogo CEO y exigencia aal2 para Administrador.
- Se leyeron sql/25_glp_tanque.sql y sql/26_glp_llenado_registrar.sql: llenados, remanente, nivel posterior y consulta del tanque.
- Se confirmó en index.html que el selector de rol de Usuarios todavía no incluye Administrador.
- Se confirmó el arranque diferido con setTimeout en onAuthStateChange y la invocación de axi-enviar-correo.
- El último commit y su descripción coinciden con el checkpoint de Misael sobre la cascada GAS y la fila Administrador del PDF. No se probó el envío ni el PDF.
- En el chat de Codex que creó este documento GitHub respondió correctamente; no había herramientas de Supabase disponibles. No se consultó la base ni se ejecutaron SQL.
- No se han vuelto a ejecutar las 298+ pruebas ni las 11/11 reportadas; no se ha repetido el cuadre financiero ni verificado el despliegue.
- PDF leído: AXICORE_Resumen_Migracion_Web.pdf, 7 páginas, entregado por Misael; no se publica aquí su contenido íntegro.

## Arquitectura y alcance informados
SPA index.html en GitHub Pages; backend Supabase/PostgreSQL con RLS, RPC y Edge Functions.
Módulos informados: facturación, pagos, gastos, GLP, mantenimiento, reservas, reportes y automatizaciones; portal por roles y multi-condominio.
Correo Gmail mediante axi-enviar-correo y axi-correo-cola; cola correos_salida con cron cada minuto, según checkpoint.
Reportes de situación: Google Forms + Apps Script + axi-recibir-reporte.
PDF con jsPDF/AutoTable y Excel con ExcelJS. Identidad navy, dorado e ivory.
Roles: CEO, Asistente, Propietario, Inquilino y Administrador de propiedades.
La afirmación histórica de “8/8 módulos completos” describe desarrollo; no certifica equivalencia total con Access ni preparación para producción.

## Decisiones de negocio heredadas (resumen del PDF)
- D1-B: numeración por condominio; conservar numeración existente.
- D2-A: indicar siempre mes cubierto.
- D3-A: FM-03 genera automáticamente; febrero corta el 28.
- D4-A: sincronizar factura de gasto con gasto.
- D5-A: ECG por condominio.
- D6-A: eliminar dependencia de archivo_estado_cuenta_movimientos.
- D7-B: conservar cuatro tipos de movimiento.
- D8-A: código de pago congelado al crear.
- D9-A: permisos según tabla; Asistente con autorización CEO.
- D10-A: estado Vencida automático, cron diario 6am según antecedente.
- D11-A: normalizar en la migración.
- D12-A: solo condominio seleccionado.
Consultar antecedentes originales ante ambigüedad; estos títulos no reemplazan sus especificaciones.
GLP y gastos tipo Unidad quedan fuera de fondo común/ECG.
Anomalías de Access migradas tal cual por decisión de Misael.
2FA obligatorio para CEO, Asistente y Administrador.
Administrador accede a sus unidades asignadas, sin fondo común, gastos/comprobantes del condominio ni morosidad global.
Cascada GAS: inquilino + administrador -> TO inquilino, CC administrador; inquilino sin administrador -> TO inquilino, CC propietario; sin inquilino con administrador -> TO administrador; solo propietario -> TO propietario. WhatsApp sigue la cascada.

## Pendientes de Misael y habilitación
- Recuperar acceso al panel Supabase; verificar acceso disponible para cada asistente.
- Entregar CSV de Reservas para migrar futuras como Aprobadas.
- Invitar cuentas reales en Supabase Auth y vincular perfiles/unidades correctamente.
- Confirmar unidad correcta de la residente indicada en el checkpoint privado (no 1-D).
- Crear cuenta real Domhouse y vincular unidades 2A, 3B y 3D.
- Cuando todos tengan cuenta, autorizar retiro de web de reservas Google y cambio de QR.
- Realizar pruebas con clics y usuarios reales.
- Confirmar si Outlook carga CCO del .eml.

## Decisiones todavía pendientes
- Método “Pago móvil”.
- PDF factura/recibo general: obtener capturas de Access; definir recordatorios de cobro.
- PDF de ejemplo de Google Form, opcional.
- Facturación mensual automática: cron desactivado según checkpoint; requiere OK.
- Marcar anulados en gris en GLP, opcional.
- Layout Mi Gas tras prueba con usuario real.

## Desarrollo y datos pendientes
- Administrador en página Usuarios: vínculo al perfil y nombre del perfil.
- Módulo Cumplimiento de Metas.
- Fases visuales 2–4, sujetas a aprobación y mockup.
- Regenerar respaldo frío; último informado: backup_20261009/, referencia ffa6314.
- Revisar inquilino 10 (u6) sin teléfono y pago de inquilino 11 (u8), sin reproducir datos personales aquí.
- Revisar Cancelados 17/21/26 de Access.

## Próxima revisión propuesta (solo lectura)
1. Verificar disponibilidad de conexión Supabase sin pedir ni publicar secretos.
2. Contrastar migraciones aplicadas, funciones, RLS, permisos, MFA, Edge Functions y cron con el repositorio.
3. Comprobar respaldo actual y procedimiento de restauración.
4. Preparar matriz de pruebas por rol y proceso para revisión de Misael. No generar cobros, correos, invitaciones o reservas reales como parte de una inspección.
5. Contrastar pantallas y reglas con Access; documentar diferencias antes de corregir.
Ventaja: detectar diferencias entre documentación, código y despliegue antes de continuar.
Límite: la lectura del código no demuestra seguridad efectiva, resultados financieros ni comportamiento real.

## Antecedentes técnicos que requieren contexto
Las observaciones sobre cancelaciones de DROP/DELETE, timeout y comportamiento STABLE provienen del entorno de Claude; no se han reproducido aquí ni deben tomarse como reglas universales. No eludir controles de herramientas.
Evitar llamadas Supabase con await dentro de onAuthStateChange; el código revisado difiere el arranque.
Verificar validación de autenticación/secretos en Edge Functions y permisos de funciones privadas usadas por cron; todavía no auditado.
Registro de SQL histórico hasta 27 según checkpoint; los archivos no sustituyen un inventario de la base desplegada.

## Protocolo de trabajo entre Claude y ChatGPT
1. Leer este archivo y comprobar el HEAD actual; comparar con la base revisada arriba.
2. Identificar una tarea y su alcance. Mantener las decisiones pendientes como pendientes.
3. Evitar editar simultáneamente los mismos archivos o ejecutar migraciones en paralelo. Si hay trabajo concurrente, usar ramas separadas y revisar antes de integrar.
4. Antes de guardar, releer la versión remota para no sobrescribir avances del otro asistente.
5. Al cerrar cada tarea, actualizar estado y añadir una entrada al registro: asistente, tarea, archivos/commits, cambios de base, pruebas con resultado y pendientes.
6. Registrar la referencia del commit de código; no declarar una migración aplicada sin comprobación en Supabase.
7. Si falta acceso o evidencia, registrarlo explícitamente y entregar a Misael el enlace actualizado.
Actualizar este archivo es una tarea explícita al cierre; no existe sincronización automática en segundo plano.

## Registro de avances
### 14/10/2026 — ChatGPT/Codex — Revisión inicial y continuidad compartida
- Solicitud de Misael: establecer una referencia accesible a Claude para consultar avances y retomar.
- Leídos: checkpoint proporcionado, PDF de 7 páginas, index.html y SQL 25–27; consultados commits recientes.
- Confirmaciones y límites: detallados arriba. Supabase y pruebas operativas pendientes.
- Cambio realizado: creación de este documento de continuidad.
- Código funcional y base de datos: sin modificaciones.
- Siguiente paso: verificar acceso a Supabase y realizar el contraste de solo lectura.
