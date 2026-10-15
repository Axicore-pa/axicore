# AXICORE — Punto compartido de continuidad
Última actualización documental: 14/10/2026.
Responsable del proyecto: Misael.
Colaboradores: Claude y ChatGPT/Codex.
Estado: conexión Supabase confirmada; revisión inicial del código realizada; contraste detallado de base y pruebas de uso pendientes.

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

## Instrucción permanente de consulta y minutas
Por solicitud expresa de Misael, toda tarea realizada desde ChatGPT/Codex debe dejar una minuta aquí, incluso si solo consiste en análisis, una decisión, un script preparado o una revisión sin cambios. Este mismo procedimiento se solicita a Claude.

### Antes de empezar o retomar
- Leer CONTINUIDAD.md desde GitHub en su versión actual, no solo una copia guardada en memoria.
- Leer el registro de avances y localizar la última minuta del módulo a trabajar.
- Consultar los archivos y scripts enlazados y comparar los commits actuales con las referencias de la minuta.
- Informar brevemente a Misael qué se encontró y cuál es la tarea pendiente que se va a abordar.
- Si una minuta contradice el código o la base, registrar la discrepancia; no asumir que lo documentado está desplegado.
- Si no se puede consultar el documento, indicar la limitación y no afirmar que se conocen los avances recientes. Pedir el contenido vigente cuando sea necesario para continuar correctamente.

### Durante y al cerrar cada tarea
- Registrar cada avance significativo y cada tarea completada, parcial o bloqueada antes de pasar a otra tarea.
- Actualizar también el estado y los pendientes del documento, conservando el historial de minutas.
- Documentar la lógica implementada, las razones de la decisión y los casos límite relevantes.
- Guardar scripts reutilizables en archivos del repositorio y enlazar su ruta y commit. Distinguir preparado, probado y aplicado; incluir orden, parámetros sin secretos y efectos esperados. Para SQL, indicar objetos afectados, si modifica datos y recuperación/reversión cuando corresponda.
- Incluir pruebas realmente ejecutadas, sus resultados y lo que no se verificó. No atribuir a esta sesión pruebas heredadas.
- Si se requiere aprobación de Misael, registrar la decisión exacta y su estado. No inventar autorizaciones.
- Releer el archivo remoto antes de actualizarlo y verificar su lectura después de guardar.
- Si falla la publicación, informar a Misael y entregar la minuta pendiente en el chat; no marcarla como publicada.
- No es necesario registrar cada clic o llamada de herramienta: la unidad es una tarea o avance útil para retomar.

### Formato de cada minuta
- ID único y fecha (hora y zona solo cuando se hayan comprobado).
- Asistente responsable.
- Tarea y solicitud/autorización de Misael.
- Estado: completada / parcial / bloqueada / pendiente de aprobación.
- Punto de partida: rama y commit del código, y estado de base comprobado cuando aplique.
- Trabajo realizado y resultado.
- Lógica y decisiones: motivo, reglas de negocio y casos límite.
- Archivos, scripts y commits: enlaces; indicar si fueron preparados, probados o aplicados.
- Base y servicios: objetos/configuración afectados o “sin cambios”.
- Validación: acciones ejecutadas, resultado y límites.
- Riesgos, pendientes y siguiente paso concreto.
- Para entradas solo documentales, usar el commit devuelto por GitHub como comprobante externo; no intentar incluir el hash del propio commit dentro del mismo archivo.

## Minutas detalladas de trabajo desde ChatGPT/Codex
### AXI-CGPT-001 — 14/10/2026 — Evaluación inicial
- Responsable: ChatGPT/Codex.
- Solicitud: revisar checkpoint, PDF y estado actual en GitHub/Supabase.
- Estado: parcial; revisión documental y de código completada, contraste de base pendiente.
- Punto de partida: código 5f247be8a1cfd8de51882fbb544559574125c3da; lectura del index.html fijada a ese commit.
- Trabajo: extracción y lectura de las siete páginas del PDF, consulta de commits recientes y lectura del frontend y SQL 25–27.
- Lógica examinada: tanque calcula nivel posterior con remanente + galones limitado por capacidad; SQL 27 incorpora Administrador, asignación por unidad y requisito aal2; arranque de sesión diferido con setTimeout.
- Resultado: último commit coincide con checkpoint; Administrador sigue ausente del selector Usuarios; frontend tiene 6.420 líneas.
- Fuentes: [index.html](https://github.com/Axicore-pa/axicore/blob/5f247be8a1cfd8de51882fbb544559574125c3da/index.html), [SQL 25](https://github.com/Axicore-pa/axicore/blob/5f247be8a1cfd8de51882fbb544559574125c3da/sql/25_glp_tanque.sql), [SQL 26](https://github.com/Axicore-pa/axicore/blob/5f247be8a1cfd8de51882fbb544559574125c3da/sql/26_glp_llenado_registrar.sql), [SQL 27](https://github.com/Axicore-pa/axicore/blob/5f247be8a1cfd8de51882fbb544559574125c3da/sql/27_administradores_propiedades.sql).
- Scripts nuevos: ninguno. La extracción local del PDF fue auxiliar; no modifica el sistema ni es una migración.
- Base y servicios: sin cambios; sin conexión Supabase disponible para esta revisión.
- Validación: lecturas mediante conector GitHub y extracción PDF correctas. Una consulta a un nombre supuesto sql/24_2fa_totp.sql devolvió 404; esto no demuestra ausencia del SQL 24, cuyo nombre exacto no se verificó.
- Límites: no se probó cascada de envío, generación PDF, interfaz, permisos reales, cron, restauración ni cuadre financiero.
- Siguiente paso: habilitar/comprobar conexión Supabase para contraste de solo lectura.

### AXI-CGPT-002 — 14/10/2026 — Creación de referencia compartida
- Responsable: ChatGPT/Codex.
- Solicitud: crear un punto compartido para que Claude conozca los avances y retome el trabajo.
- Estado: completada.
- Trabajo: creación de CONTINUIDAD.md en el repositorio con contexto, reglas, decisiones, evidencias y pendientes.
- Lógica: GitHub conserva una referencia versionada accesible a ambos asistentes; las memorias de los chats no se sincronizan.
- Archivo: [CONTINUIDAD.md](https://github.com/Axicore-pa/axicore/blob/main/CONTINUIDAD.md).
- Commit publicado: [e4f679e4a76d9cbd48e169b52f3461891f369908](https://github.com/Axicore-pa/axicore/commit/e4f679e4a76d9cbd48e169b52f3461891f369908).
- Scripts, base y servicios: sin cambios.
- Validación: lectura posterior de GitHub; contenido recuperado idéntico al enviado.
- Límite: no se comprobó acceso desde la cuenta o sesión de Claude.
- Siguiente paso: Misael comparte el enlace y las instrucciones con Claude.

### AXI-CGPT-003 — 14/10/2026 — Protocolo obligatorio de minutas
- Responsable: ChatGPT/Codex.
- Solicitud: instrucciones para que Claude consulte los avances antes de continuar y registrar cada tarea, lógica, scripts y contexto útil.
- Estado: completada si el guardado y la lectura posterior de esta actualización se confirman; el resultado se entrega a Misael en el chat.
- Trabajo: ampliación de este documento con consulta previa, actualización por tarea, formato de minuta y reconstrucción fiel de las tareas AXI-CGPT-001 y 002.
- Lógica: separar evidencia comprobada de antecedentes; enlazar scripts y commits; distinguir código preparado de cambios aplicados en la base; conservar historial y pendientes.
- Archivos: CONTINUIDAD.md. Scripts nuevos: ninguno.
- Base y servicios: sin cambios.
- Validación prevista: guardar con SHA actual del archivo y recuperar el contenido para comprobar coincidencia.
- Siguiente paso: entregar a Misael la instrucción para Claude; luego continuar revisión de Supabase cuando exista conexión.

### AXI-CGPT-004 — 14/10/2026 — Preparación de conexión Supabase
- Responsable: ChatGPT/Codex.
- Solicitud: explicar cómo habilitar acceso Supabase en este chat.
- Estado: parcial; integración encontrada, instalación y autorización pendientes del usuario.
- Trabajo: comprobación de herramientas disponibles y búsqueda de Supabase en el directorio de plugins. El directorio indica que está disponible pero no instalado; se ofreció su instalación/conexión.
- Resultado: todavía no se ha confirmado conexión ni acceso al proyecto qfgyftsnwznsqizriggr.
- Lógica: usar la integración disponible y autorización de cuenta antes de inspeccionar la base; no solicitar contraseñas o claves por chat.
- Corrección de orientación previa: cerrar y reabrir el chat no establece por sí mismo la conexión; primero se requiere instalar/conectar la integración y autorizar acceso.
- Código, scripts, base y servicios: sin cambios.
- Validación: búsqueda del directorio completada; ningún SQL ejecutado.
- Siguiente paso: Misael instala/conecta Supabase y autoriza acceso a la organización/proyecto correspondiente; después comprobar mediante lectura que el proyecto es accesible.

### AXI-CGPT-005 — 14/10/2026 — Conexión Supabase comprobada
- Responsable: ChatGPT/Codex.
- Solicitud: habilitar y comprobar acceso a Supabase.
- Estado: completada para comprobación de conexión; auditoría funcional pendiente.
- Trabajo: tras la instalación confirmada, consulta de metadatos del proyecto y SELECT de existencia de objetos; lectura de esta referencia compartida.
- Resultado: acceso al proyecto qfgyftsnwznsqizriggr, nombre axicore, estado ACTIVE_HEALTHY, PostgreSQL 17.11.0.003.
- Consulta de solo lectura ejecutada: SELECT current_database() AS database_name, to_regclass('public.administradores') IS NOT NULL AS administradores_existe, to_regclass('public.unidad_administradores') IS NOT NULL AS asignaciones_existe, to_regclass('public.glp_llenados') IS NOT NULL AS glp_llenados_existe;
- Validación: las tres tablas existen. Esto no verifica funciones, políticas, datos, migraciones completas ni comportamiento por rol.
- Scripts nuevos, código funcional, base y servicios: sin modificaciones.
- Actualización de estado: las limitaciones de acceso descritas en minutas anteriores quedan superadas por esta comprobación.
- Siguiente paso: contraste de solo lectura de migraciones, funciones, RLS, MFA, Edge Functions y cron con el repositorio.
