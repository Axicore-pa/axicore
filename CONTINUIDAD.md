# AXICORE — Punto compartido de continuidad
Última actualización documental: 14/10/2026.
Responsable del proyecto: Misael.
Colaboradores: Claude y ChatGPT/Codex.
Estado: SQL 25–27 contrastados con Supabase; correcciones de fecha de inicio y aprobación GLP aplicadas (AXI-CGPT-008); pruebas con usuarios reales pendientes.

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

### AXI-CGPT-006 — 14/10/2026 — Permisos: puntos para confirmación de Claude
- Responsable: ChatGPT/Codex.
- Solicitud de Misael: registrar tres observaciones y pedir confirmación independiente a Claude.
- Estado: revisión de definiciones completada; confirmación independiente y pruebas operativas pendientes.
- Referencia de código: 963f57022ae549b4f9928b5255c5f4123982fade.
- Puntos registrados: (1) acumulación de permisos por cuenta vía UNION en unidades_propias; (2) fecha_inicio no verificada en asignaciones; (3) staff_condos permite crear en Facturación/Pagos/Gastos/GLP con requiere_autorizacion=true, y en GLP el saldo refleja consumo antes de aprobación.
- Código, datos y servicios: sin modificaciones. Entrada documental.
- Siguiente paso: Claude confirma las tres observaciones.

### AXI-CLAUDE-001 — 14/10/2026 — Validación independiente de AXI-CGPT-006
- Responsable: Claude.
- Solicitud de Misael: validar los tres hallazgos de ChatGPT sin corregir; solo confirmar veracidad.
- Estado: completada (validación de solo lectura).
- Punto de partida: CONTINUIDAD.md leída desde GitHub (HEAD actual); funciones consultadas directamente en Supabase proyecto qfgyftsnwznsqizriggr.
- Trabajo realizado: lectura de código fuente de `private.unidades_propias`, `private.staff_condos`, `private.trg_aprobacion`, `public.fn_glp_registrar_consumo`, `public.portal_mi_glp`; consulta de políticas RLS de facturas/pagos/glp_lecturas/glp_movimientos; verificación de triggers en glp_facturas, glp_lecturas y glp_movimientos; inspección de columnas de unidad_administradores y unidad_propietarios.

#### Resultado por punto

**Punto 1 — Acumulación de permisos por cuenta: PARCIALMENTE VERAZ.**
- Confirmado: `unidades_propias()` hace UNION de unidades Propietario + Administrador. Si una cuenta tiene ambos accesos, ve la suma.
- Matiz: la frase "consultas globales" sobreestima el efecto. Las políticas RLS filtran `unidad_id = ANY(unidades_propias())`, así que el alcance se limita a unidades asignadas, nunca a todo el condominio. No hay escalación de privilegios ni visibilidad global. Riesgo real: bajo.

**Punto 2 — `fecha_inicio` no verificada: VERAZ.**
- Confirmado: `unidad_administradores` tiene `fecha_inicio` (date, NOT NULL, default CURRENT_DATE). `unidad_propietarios` también tiene `fecha_inicio` (timestamptz, nullable).
- `unidades_propias()` filtra solo `fecha_fin IS NULL` en ambas ramas. No verifica `fecha_inicio <= CURRENT_DATE`.
- Consecuencia: una asignación con fecha_inicio futura y fecha_fin NULL concede acceso inmediato.
- Riesgo real: medio. Corregible con `AND ua.fecha_inicio <= CURRENT_DATE` (y equivalente en la rama Propietario).

**Punto 3 — `staff_condos` permite crear con `requiere_autorizacion`: VERAZ.**
- Confirmado en código: para acción `'crear'`, la condición incluye `OR p_modulo IN ('Facturacion','Pagos','Gastos','GLP')`, lo que permite al Asistente crear aunque `requiere_autorizacion` sea true.
- `trg_aprobacion` protege correctamente: en INSERT, si no es CEO → `estado_aprobacion = 'Sometido'`. Solo CEO puede cambiar ese estado. Confirmado.
- Pagos/Gastos/Libro: `fn_pago_postear_libro` y `axi_libro_registrar_gasto` solo se ejecutan dentro de `fn_aprobacion_revisar` cuando `p_estado = 'Aprobado'`. Efectos financieros quedan pendientes hasta aprobación. Confirmado.
- **GLP — hallazgo relevante confirmado:** `fn_glp_registrar_consumo` crea en una transacción: (a) `glp_lecturas` con estado 'ACTIVO' — SIN trigger de aprobación; (b) `glp_movimientos` con estado 'ACTIVO' — SIN trigger de aprobación; (c) `glp_facturas` — SÍ tiene `trg_aprobacion`, queda 'Sometido'. Verificado: `glp_lecturas` y `glp_movimientos` tienen 0 triggers no internos. `portal_mi_glp` calcula saldo sumando TODOS los movimientos ACTIVO sin filtrar por estado de aprobación de la factura asociada. El saldo del propietario refleja el consumo antes de que el CEO apruebe.
- Riesgo: bajo para Facturación/Pagos/Gastos (trigger protege). Medio para GLP (saldo afectado antes de aprobación).
- Nota: confirmar si esto corresponde a la lógica original de Access queda pendiente; Claude no tiene acceso al .accdb.

#### Funciones y objetos consultados (solo lectura)
- `pg_get_functiondef` de: private.unidades_propias, private.staff_condos, private.trg_aprobacion, public.fn_glp_registrar_consumo, public.portal_mi_glp, public.fn_aprobacion_revisar, public.fn_aprobaciones_bandeja.
- `pg_policies` de: facturas, pagos, glp_lecturas, glp_movimientos.
- `pg_trigger` de: glp_facturas, glp_lecturas, glp_movimientos.
- `information_schema.columns` de: unidad_administradores, unidad_propietarios.

- Lógica y decisiones: validación cruzada sin modificar código ni datos. Los hallazgos de ChatGPT son verificables; las correcciones requieren propuesta y consentimiento de Misael.
- Archivos y scripts: ninguno creado ni modificado. Entrada documental.
- Base y servicios: sin cambios; solo consultas SELECT de metadatos.
- Validación: lectura directa de funciones en Supabase PostgreSQL. No se ejecutaron operaciones financieras ni pruebas con usuarios.
- Riesgos: ninguno introducido por esta revisión.
- Siguiente paso: Misael decide si alguno de los tres puntos requiere corrección; cualquier cambio se propone antes de aplicar.


### AXI-CGPT-007 — 14/10/2026 — Precisión del punto 1 para verificación de Claude
- Responsable: ChatGPT/Codex.
- Solicitud y autorización de Misael: actualizar la bitácora para que Claude verifique la precisión sobre roles acumulados; avanzar sin bloquear los puntos coincidentes.
- Estado: precisión documental; verificación independiente pendiente.
- Evidencia consultada en Supabase: definiciones de private.condos_propietario(), public.portal_fondo_comun(bigint) y public.portal_morosidad_global(bigint).
- Precisión: unidades_propias() suma unidades y no concede por sí sola consultas globales. Sin embargo, una cuenta que además tenga acceso activo de Propietario obtiene su condominio mediante condos_propietario(); portal_fondo_comun y portal_morosidad_global aceptan esa autorización y consultan agregados de ese condominio. Por ello, la conclusión de AXI-CLAUDE-001 “nunca a todo el condominio” no cubre estas rutas.
- Interpretación: son permisos del acceso adicional de Propietario; no se afirma escalación indebida ni se propone retirar derechos legítimos.
- Solicitud a Claude: verificar esas tres definiciones y precisar la conclusión del punto 1. Esta revisión no debe bloquear el trabajo sobre fecha_inicio ni la decisión de negocio sobre GLP.
- Acuerdos existentes: fecha_inicio futura no se comprueba; el consumo GLP activo afecta saldo antes de aprobación. No confundir acuerdo sobre el comportamiento observado con autorización de una solución.
- Código, datos y configuración: sin cambios. Solo se añade esta entrada a CONTINUIDAD.md.
- Límites: no se probaron sesiones reales. Cualquier corrección funcional mantiene el requisito de propuesta y consentimiento previo de Misael.


### AXI-CGPT-008 — 14/10/2026 — Correcciones aprobadas: fechas de asignación y aprobación GLP
- Responsable: ChatGPT/Codex.
- Autorización: Misael aceptó con “ok” la propuesta de corregir fechas de inicio y hacer efectivo el consumo GLP del Asistente solo después de aprobación del CEO, incluyendo SQL versionado, validaciones y minuta. No se modifican los permisos acumulados del punto 1.
- Estado: migración aplicada y comprobada en Supabase; archivos publicados en este cambio. Pruebas con usuarios reales pendientes.
- Punto de partida: main, commit 710023749225ec72f3a9e5830c067cdc6b73ea68; proyecto qfgyftsnwznsqizriggr. Se releyeron continuidad y definiciones antes de aplicar.
- Fechas: private.unidades_propias filtra fecha_inicio de Administrador usando el día de America/Santo_Domingo; el historial de Propietario usa el instante now() por ser timestamptz y conserva fechas NULL heredadas. El vínculo directo unidades.propietario_id conserva su comportamiento. No se cambian fechas ni asignaciones existentes.
- GLP: el Asistente registra lectura/movimiento PENDIENTE y factura Sometido. Los cálculos existentes de saldo/lectura anterior/tanque consideran ACTIVO; portal_mi_glp también limita sus lecturas a ACTIVO. El consumo del CEO permanece aprobado y activo inmediatamente.
- Aprobación/rechazo: nuevo trigger privado en glp_facturas activa lectura/movimiento al aprobar y los marca RECHAZADO al rechazar. Rechazar permite registrar una lectura corregida. No se admiten nuevos consumos de la unidad mientras haya uno pendiente, para evitar encadenar lecturas no aprobadas. Los depósitos siguen permitidos; aprobar recalcula los saldos del consumo y movimientos posteriores en orden de registro. Se utiliza el bloqueo por unidad existente.
- Bandeja: fn_aprobaciones_bandeja incluye GLP; fn_aprobacion_revisar toma el mismo bloqueo antes de revisar GLP. fn_glp_anular usa ese bloqueo antes de anular. Se mantiene el control CEO y aal2 existente.
- Frontend: index.html diferencia estados pendientes/rechazados de activos, excluye los no activos de totales/exportación de estado de cuenta y bloquea emisión/envío de factura no activa o no aprobada; el registro del Asistente informa que el saldo cambiará al aprobar. Sin rediseño visual.
- Migración aplicada: 20261015032620, axicore_asignaciones_inicio_glp_aprobacion. El primer intento falló por ensamblado del SQL y no quedó aplicado; se corrigió, se comprobó el script completo con BEGIN/ROLLBACK y el segundo intento terminó correctamente. Se comprobaron después los siete cuerpos de funciones contra los preparados y permisos conservados; el nuevo trigger solo es ejecutable por su propietario.
- Archivos: [SQL de avance](sql/28_asignaciones_inicio_glp_aprobacion.sql), [reversión](sql/rollback_28_asignaciones_glp.sql), [pruebas temporales](sql/tests/28_asignaciones_glp_temporal.sql), index.html y esta minuta. Los SQL 25-27 permanecen como historia.
- Aplicación/reversión: avance aplicado una vez mediante la integración Supabase y registrado en schema_migrations; no volver a ejecutar encima porque crea un trigger. La reversión restaura definiciones previas y retira el trigger nuevo, pero aborta si hay movimientos PENDIENTE/RECHAZADO que requieran conciliación; no revierte decisiones o datos operativos posteriores.
- Validación: 27 comprobaciones y 3 casos negativos pasaron en tablas temporales con ROLLBACK, usando copias de las funciones y autenticación/log simulados. Cubren pendiente, En proceso, aprobación, rechazo, reintento, doble aprobación, bloqueo de Asistente, depósito intermedio, saldo del portal, lectura anterior, bandeja GLP, fecha futura/hoy/pasada, fecha vacía heredada, perfil inactivo y aal2. Una primera ejecución de las pruebas requirió añadir una tabla temporal faltante al montaje; ejecución final completa correcta.
- Validación adicional: sintaxis del JavaScript correcta; revisión de seguridad Supabase realizada. Persisten avisos previos fuera de alcance (search_path de fn_set_updated_at, extensión unaccent, funciones SECURITY DEFINER públicas y protección de contraseñas). No se modificaron estos objetos/configuraciones. Referencias: https://supabase.com/docs/guides/database/database-linter y https://supabase.com/docs/guides/auth/password-security.
- Datos reales: sin INSERT/UPDATE/DELETE operativos. Antes/después coinciden 26 movimientos (suma monto 30592.88), 20 lecturas (suma monto_consumo -5354.59) y 12 facturas (suma monto_factura 5237.95). Las 12 facturas estaban aprobadas antes; no se reclasificó historia. Estas sumas verifican conservación, no un nuevo cuadre financiero.
- Límites: las pruebas temporales aíslan efectos y no prueban RLS con sesiones reales ni interacción de navegador. No se ejecutaron envíos ni consumos/cobros reales.
- Siguiente paso para Claude: revisar estas correcciones aplicadas y sus pruebas; confirmar el punto 1 pendiente mediante condos_propietario/portal_fondo_comun/portal_morosidad_global, sin bloquear los cambios ya autorizados. Cualquier corrección adicional requiere propuesta y consentimiento de Misael.


- Comprobaciones posteriores al guardado: los cinco archivos se recuperaron desde GitHub y coincidieron con lo preparado; cinco casos JavaScript de emisión/totales pasaron (aprobado permitido; pendiente, rechazado, anulado y no aprobado bloqueados).
- Commit de implementación: [9273abed3c134b5a700b459c687904ef5139efe5](https://github.com/Axicore-pa/axicore/commit/9273abed3c134b5a700b459c687904ef5139efe5).
- Despliegue web de ese commit: [GitHub Pages completado correctamente](https://github.com/Axicore-pa/axicore/actions/runs/38676447898). Esto confirma el despliegue; no sustituye pruebas de interfaz con usuarios reales.


### AXI-CGPT-009 — 15/10/2026 — Recibo de pagos conforme al modelo Access
- Responsable: ChatGPT/Codex.
- Solicitud/autorización: Misael aprobó guardar solo/guardar y preparar correo, imprimir, preparar recibo .eml con PDF y botón ↓ PDF entre Editar y Anular; pidió conservar el diseño del PDF de ejemplo con datos actualizados. Precisó destinatarios: factura de Inquilino → solo administrador asignado o, si no existe, propietario; factura de Propietario → solo propietario. Nunca se envía al inquilino ni se agregan copias por defecto.
- Estado: consulta de recibos aplicada en Supabase; frontend y scripts publicados con esta minuta. Comprobación del despliegue se registra después.
- Punto de partida: main, ed087bd24c4c7730a5577f3dbc7769d90ebed33f. Lectura del PDF Access entregado por Misael; una página de 612.16 × 792.06 pt. El PDF original y sus datos personales no se publican en GitHub.
- Formato: se conservaron posiciones, encabezado azul, líneas doradas, Segoe UI, columnas, cuatro importes, datos de transferencia y pie. La vista previa, impresión y PDF usan el mismo dibujo de alta resolución (300 ppp) incluido en un PDF carta. Es un PDF visual rasterizado, no un formulario ni texto seleccionable. En Windows se comprobó el renderizado con Segoe UI; otros sistemas pueden usar la fuente de sustitución.
- Datos dinámicos: código almacenado del pago (fallback determinista PG-id si un registro heredado carece de código), fecha real del pago, pagador, factura, concepto, método, banco, referencia y observaciones. Datos de AXICORE y cuenta de transferencia salen de configuracion_administracion activa, sin copiar datos antiguos del ejemplo. No se crean códigos nuevos al descargar, imprimir o preparar correo.
- Importes: monto de factura; suma de ingresos aprobados y vigentes anteriores por (fecha_pago,id), excluyendo ajustes, rechazados y anulados; este pago; balance = monto_factura − abonado_antes − este_pago. El balance es el posterior a ese pago, no el saldo después de otros pagos posteriores. No se modifica el libro ni los saldos guardados.
- Seguridad: nueva fn_pago_recibo(bigint), STABLE, solo lectura; requiere CEO o personal con Pagos/ver (helpers existentes con aal2), y permiso en el condominio del pago. Exige ingreso y factura aprobados/vigentes. anon y PUBLIC sin EXECUTE; authenticated con EXECUTE sujeto a esos controles. No permite recibos de movimientos tipo Ajuste o Pago a suplidor.
- Migración: 20261015040053, axicore_pago_recibo_lectura, aplicada correctamente. El cuerpo desplegado coincide con el probado. Sin cambios de tablas, políticas ni registros operativos.
- Interfaz: botón ↓ PDF entre lápiz y Anular. Tras guardar un ingreso aprobado, vista del recibo con Imprimir, Enviar recibo, ↓ PDF y Cerrar. Guardar y preparar correo abre el flujo existente de correo con asunto, cuerpo y PDF; se mantiene .eml y la configuración existente. Un pago sometido espera aprobación. Doble clic bloqueado; fallo documental no registra de nuevo el pago.
- Destinatarios: se proponen según la regla expresa de Misael y pueden revisarse antes de descargar .eml. Si el administrador asignado carece de correo, no se reemplaza silenciosamente por otro contacto: se deja vacío para completar en la revisión. Asignaciones futuras o perfiles inactivos no se consideran administradores vigentes.
- Validación SQL: 8 comprobaciones y 7 casos negativos en tablas temporales con ROLLBACK; pagos parciales y posteriores, mismo día ordenado por ID, código estable/fallback, exclusión de rechazados/anulados/ajustes, permiso de Asistente, aal2, otro condominio, rol no permitido y factura anulada.
- Validación navegador: 16 comprobaciones de documento/destinatarios/MIME y 2 de guardado con servicios simulados. Se comprobó .eml con X-Unsent, asunto único, MIME application/pdf y contenido del adjunto; sin envío real. PDF de muestra renderizado desde el propio PDF e inspeccionado visualmente; página carta, sin recortes. Sintaxis de ambos scripts correcta.
- Conservación: antes/después permanecen 36 pagos y suma de monto 145500.00. No se registraron pagos, recibos operativos ni correos de prueba en las tablas reales.
- Revisión de seguridad: aviso esperado por RPC SECURITY DEFINER accesible a authenticated, protegido dentro de la función; sin permisos anon. Otros avisos previos fuera de alcance se mantienen. Referencia: [linter 0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- Archivos: index.html; [generador](assets/recibos-pago.js); [SQL 29](sql/29_pago_recibo.sql); [pruebas SQL](sql/tests/29_pago_recibo_temporal.sql); [pruebas navegador](tests/recibos-pago.test.cjs).
- Reproducción: ejecutar SQL de pruebas completo (tablas temporales y ROLLBACK); para navegador, Node + Playwright, AXICORE_NODE_MODULES si el paquete no está en node_modules, AXICORE_BROWSER si se usa Chrome instalado y JSPDF_PATH apuntando a jsPDF 2.5.1 local. Luego node tests/recibos-pago.test.cjs. Los tests del repositorio contienen solo datos sintéticos.
- Reversión: restaurar index.html del commit de partida y retirar la carga del generador; después puede retirarse fn_pago_recibo(bigint). No hay datos operativos que revertir. Cualquier reversión es un cambio separado y requiere autorización.
- Límites: no se verificó todavía Outlook real, la asociación de archivos .eml de la PC ni impresión física. El navegador descarga el borrador para abrirlo y enviarlo manualmente. La inspección visual reproduce el modelo; no se afirma igualdad binaria del PDF. Datos muy largos se adaptan al espacio o se bloquean antes de recortarlos.
- Pendiente para Claude: revisar SQL/cliente y confirmar la nueva regla de destinatarios; no modificarla ni ampliar la cascada GLP a estos recibos.


- Cierre verificado: los seis archivos publicados se recuperaron desde GitHub y coincidieron con lo preparado. [Commit de implementación 9c6d0edea2f6674baa3ae8e59d60282c84dedbb6](https://github.com/Axicore-pa/axicore/commit/9c6d0edea2f6674baa3ae8e59d60282c84dedbb6).
- [Despliegue GitHub Pages](https://github.com/Axicore-pa/axicore/actions/runs/38679507952): completado con success para ese commit. Recibo de muestra con datos sintéticos entregado a Misael para revisión visual. Outlook e impresión física siguen pendientes de comprobar en su PC.


### AXI-CGPT-010 — 15/10/2026 — Una sesión interactiva por cuenta
- Responsable: ChatGPT/Codex. Autorización expresa de Misael: “Adelante con la sugerencia. Descarta la alternativa.” Se implementa primera sesión prevalece; descartada la alternativa nativa que sustituye la sesión anterior.
- Estado de esta publicación: base preparada con habilitada=false; Edge axi-enviar-correo v5 desplegada; web y pruebas en este commit. La activación se registra al verificar Pages.
- Regla: una cuenta/correo Auth normalizado tiene un único registro privado; reclamos serializados por usuario/correo y restricciones UNIQUE. El ingreso posterior se rechaza conservando el primero. Se valida auth.sessions, session_id y prueba aleatoria por pestaña, guardada sólo como hash en servidor. La recarga es idempotente; sesión nueva y pestaña duplicada no sustituyen la primera.
- Alcance del servidor: guard antes de todas las consultas/RPC de PostgREST, incluyendo SECURITY DEFINER; 52 políticas restrictivas adicionales (51 tablas public y storage.objects), conservando permisos/políticas previas. Storage/Realtime validan la sesión Auth registrada; PostgREST exige además prueba de pestaña. Los procesos automáticos con service_role mantienen su funcionamiento.
- Autenticación de la web: sessionStorage por pestaña; canal de Auth separado por documento para impedir que Supabase transmita los tokens del segundo login a la primera pestaña. Web Locks distingue pestañas clonadas. No se migra automáticamente la autenticación antigua de localStorage. Las páginas anteriores deben recargarse e iniciar sesión con la versión nueva.
- Mensaje: “Ya existe una sesión en curso con este correo. Cierra la otra sesión para acceder.”
- Avisos automáticos: cada rechazo después de autenticación y MFA cuando corresponde se registra; primer rechazo encola correo separado al usuario y a los CEO activos, sin exponer destinatarios entre ellos. Intentos repetidos se anotan todos; correos agrupados por cuenta durante cinco minutos. Se usa la cola/cron existente, no .eml manual. No se enviaron alertas de prueba a personas reales.
- Cierre: sólo registro que coincide con usuario, sesión Auth y pestaña; signOut local, nunca global. Un segundo intento no cierra la primera sesión ni su historial. Las filas históricas previas no se convierten en bloqueos.
- Recuperación: cerrar navegador no libera sesión; no hay expiración automática de este registro. CEO con MFA puede revisar sesiones en Usuarios / Sesiones activas, o desde su pantalla de ingreso bloqueado; debe verificar al usuario, confirmar y escribir motivo. Liberación dirigida al UUID exacto evita actuar sobre una sesión reemplazada. Se registra actor/motivo y se impide reclamar de nuevo con la autorización liberada: se necesita un nuevo login.
- Archivos: [migración](supabase/migrations/20261015043045_axicore_sesiones_unicas_preparacion.sql), [cliente](assets/sesiones.js), index.html, [Edge](supabase/functions/axi-enviar-correo/index.ts), [pruebas y reproducción](testing/README.md), [desactivación de emergencia](sql/rollback_30_sesiones.sql). Desactivar sería otro cambio que requiere autorización; no se ejecutó.
- Validación: SQL con PGlite/datos sintéticos (rechazo, primer ingreso, recarga, historial, RLS, mismos/diferentes session_id, cierre ajeno, auditoría, dos destinatarios, agrupación, MFA, recuperación, autorización liberada, lista antigua, Auth revocada y diez solicitudes). PGlite serializa sus llamadas: no se presenta como prueba de dos conexiones PostgreSQL de producción.
- Navegador Chrome con SDK real Supabase 2.45.4 y servicios simulados: primera entrada; nueva pestaña sin Auth heredado; segundo ingreso sin alterar primera; pestaña duplicada con prueba distinta sin signOut; recarga sin historial extra; cierre local; ingreso posterior y rechazo del servidor que oculta la aplicación. Sin errores de JavaScript. Regresión del recibo: sus 16 comprobaciones documentales y las de guardado pasaron.
- Supabase: cuatro comprobaciones negativas con rol authenticated y contexto sintético dentro de transacción con ROLLBACK (guard, RLS, estado, recuperación sin CEO). Ningún registro operativo ni correo de prueba comprometido. Conservación: 36 pagos, suma 145500.00; cuatro cron activos; cero alertas nuevas al preparar.
- Revisión de seguridad: tres RPC nuevas SECURITY DEFINER son deliberadas con controles internos; tablas privadas sin políticas permiten sólo al propietario del backend y tienen permisos cliente revocados. Avisos previos fuera del alcance se conservan: [linter de funciones](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Primer intento de migración fue revertido completamente por una tabla interna de Storage no modificable; se limitó la política Storage a objects, que es la superficie usada por AXICORE; migración posterior correcta.
- Límites explícitos: no es un límite nativo de emisión de JWT de Supabase Auth: el segundo JWT no obtiene acceso interactivo a AXICORE. Storage/Realtime identifican la sesión Auth; la prueba adicional distingue las pestañas en Data API. Copia íntegra deliberada de JWT y prueba fuera del flujo normal no equivale a un nuevo login y requiere gestionar credenciales. Archivos públicos, descargas y enlaces firmados previos conservan reglas/vencimiento. No se prometen revocaciones retroactivas de archivos. Referencia: [sesiones Supabase](https://supabase.com/docs/guides/auth/sessions).
- Pendientes de comprobación real: dos dispositivos con cuentas autorizadas, MFA real, llegada de alertas Gmail y recuperación por CEO. No se conocen contraseñas ni se utilizaron cuentas de residentes para probar.
- Para Claude: revisar exclusión transaccional, excepciones del guard, permisos de recuperación y destinatarios/agrupación de alertas; confirmar resultados sin cambiar reglas aprobadas ni ampliar el alcance.

- Ajuste antes de activar: una pestaña duplicada descarta la copia de Auth antes de que el SDK pueda renovar su refresh_token; sólo notifica el intento usando el access_token existente, sin reclamar un registro vacío. Prueba adicional con copia próxima a vencer pasó sin renovación. Restauración desde caché de navegación recarga para recuperar el bloqueo de pestaña. [Migración complementaria](supabase/migrations/20261015043602_axicore_sesiones_duplicadas_seguras.sql) aplicada; no cambia la regla de primera sesión ni destinatarios. La migración inicial conserva el contenido exacto ya aplicado.

- **Cierre y activación verificados:** habilitada=true desde 15/10/2026 04:40:43 UTC. [Código web final ba83f38](https://github.com/Axicore-pa/axicore/commit/ba83f383294699cb2729babd50cbffceb9da6c42); [Pages completado con success](https://github.com/Axicore-pa/axicore/actions/runs/38682633311). Sitio público abierto en Chrome limpio, cliente v20261015-2 coincide con el preparado, sin errores JavaScript; petición anónima rechazada con 42501. Se comprobó también aceptación CORS de la cabecera de seguridad. Los 12 archivos iniciales y los ajustes posteriores se recuperaron de GitHub y coincidieron con lo preparado.
- Historial Supabase: 20261015043045 / axicore_sesiones_unicas_preparacion; 20261015043602 / axicore_sesiones_duplicadas_seguras. Los archivos generados inicialmente por CLI se renombraron a esas versiones efectivamente registradas por MCP, conservando contenido, para evitar que CLI los interprete como migraciones aún pendientes. El cuerpo desplegado de axi_sesion_iniciar coincide exactamente con el probado. No volver a aplicar estas migraciones.
- Al activar: cero registros de sesión y cero alertas de prueba; 36 pagos, suma 145500.00 y cuatro cron activos. No se usaron credenciales reales ni se mandaron mensajes a Claude: este archivo queda disponible para que él lo consulte. Falta confirmar con Misael ingreso real en dos dispositivos y llegada de los avisos; esa comprobación no se presenta como realizada.
- Para usar la nueva versión: recargar AXICORE con Ctrl+F5 e iniciar sesión. Salir mediante Cerrar sesión antes de cambiar de pestaña o dispositivo; cerrar la ventana solamente conserva el registro y puede requerir recuperación CEO.
