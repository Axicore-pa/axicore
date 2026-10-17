# AXICORE — Punto compartido de continuidad
Última actualización documental: 17/10/2026.
Responsable del proyecto: Misael.
Colaboradores: Claude y ChatGPT/Codex.
Estado: dominio y envíos de invitación verificados; cargas y circulares publicados; remitente administrativo, firma APA y código manual de circular aplicados y verificados (AXI-CGPT-018).

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


### AXI-CGPT-014 — 14/10/2026 — Precisión del punto 1 para verificación de Claude
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


### AXI-CGPT-011 — 15/10/2026 — Avisos silenciosos de sesión aceptada al CEO; preparación del piloto passkey
- Autorización: Misael aprobó la recomendación de implementar primero correos al CEO y después realizar una prueba controlada de huella/rostro. No se autorizó asignar roles nuevos ni extender el piloto a todos los usuarios.
- Estado: avisos al CEO aplicados y activos en Supabase. Migración 20261015045436, axicore_avisos_inicio_ceo; archivo [SQL](supabase/migrations/20261015045436_axicore_avisos_inicio_ceo.sql). El archivo generado por CLI se concilió con la versión registrada por MCP, conservando su contenido.
- Funcionamiento: trigger AFTER INSERT en private.axi_sesiones encola un correo separado por cada CEO activo con correo distinto. Se genera únicamente cuando se crea una sesión aceptada. Una recarga, renovación, heartbeat, cambio de condominio o rechazo no crea otra sesión ni otro aviso de aceptación. Incluye el inicio del propio CEO. Los avisos anteriores de intentos simultáneos conservan destinatarios y agrupación.
- Contenido: nombre del usuario, correo, rol, fecha/hora UTC, navegador declarado (no identificación certificada del equipo) y referencia de sesión. Sin claves, tokens, prueba de pestaña, adjuntos ni copias al usuario. No hay cambios de interfaz. El envío se procesa automáticamente con la cola/cron existente; su entrega no bloquea esperando SMTP. Un fallo de escritura en cola revierte la transacción de inicio; no se oculta como envío exitoso.
- Seguridad: función trigger SECURITY DEFINER en esquema privado, search_path vacío; EXECUTE revocado a PUBLIC, anon, authenticated y service_role. Los clientes no pueden invocarla ni fabricar INSERT de sesiones. No se modificó axi_sesion_iniciar, MFA, permisos, políticas ni la regla de primera sesión.
- Validación: pruebas SQL locales con datos sintéticos cubren destinatario sólo CEO, contenido y saltos de línea, primer inicio, recarga sin duplicado, rechazo sin aviso de aceptación, varios inicios legítimos, diez solicitudes con un único aviso y múltiples accesos CEO al mismo correo sin duplicar. Regresión de sesión única, MFA, cierre, recuperación y revocación pasó.
- Verificación en Supabase: trigger habilitado; cuerpo de función idéntico al probado; cliente sin EXECUTE; sesión única sigue habilitada. Permanecen 36 pagos y suma 145500.00, cuatro cron activos y cero avisos de inicio al comprobar. No se enviaron correos de prueba ni se usaron contraseñas reales. La recepción real en Gmail/Outlook sigue pendiente.
- Asesores de seguridad: sin nuevos avisos respecto a AXI-CGPT-010. Referencia de funciones privilegiadas: [linter Supabase](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- Reversión, sólo con autorización separada: deshabilitar exclusivamente el trigger axi_sesion_aviso_inicio. Conservar cola, auditoría, sesión única y mensajes anteriores; no se ejecutó reversión.
- Piloto biométrico: Misael designó una cuenta concreta y confirmó su correo; se conserva en esta conversación, no en el repositorio público. La consulta actual del proyecto encuentra la identidad Auth pero ninguna fila enlazada en public.accesos. No se asignó, reactivó ni cambió ningún permiso.
- Prerrequisitos del piloto: confirmar/revisar el vínculo de acceso y el dispositivo; las opciones públicas de Auth actualmente muestran passkeys_enabled=false. La web sigue con Supabase JS 2.45.4; no se actualizó producción ni se habilitaron passkeys a nivel de proyecto para simular una prueba aislada.
- Supabase documenta passkeys experimentales desde JS 2.105.0. Habilitarlas afecta la configuración del proyecto; ocultar un botón no restringe el backend a una sola cuenta. Preparar aislamiento real y plan de recuperación antes de modificar esa configuración. Validar convivencia con MFA y sesión única, sin suponer que passkey equivale automáticamente a aal2. [Documentación oficial](https://supabase.com/docs/guides/auth/passkeys).
- Misael indicó realizar la prueba real hoy 15/10/2026 alrededor de las 7:00 p. m.; dispositivo y zona horaria de esa cita por confirmar. No se creó recordatorio ni automatización y no se registró ninguna passkey. El piloto no se presenta como realizado.
- Para Claude: confirmar que el trigger sólo actúa sobre INSERT y mantiene las alertas de rechazo; revisar aislamiento y vínculo de la cuenta del piloto antes de proponer cambios adicionales.


### AXI-CGPT-012 — 15/10/2026 — Ayuda / Help fija en el menú
- Autorización: después de aprobar la preparación local, Misael pidió publicarla e incorporarla al menú con la misma fuente, tamaño y color, debajo de Automatizaciones. No se publicó el simulador ni sus selectores de perfil.
- Cambio: nueva página Ayuda dentro de index.html, con acceso común para CEO, Asistente, Propietario, Inquilino y Administrador de propiedades. En el menú del personal aparece inmediatamente después del módulo Automatizaciones, como sección del mismo estilo. En el portal de residentes y administradores aparece al final del menú. Funciona también con menú contraído y en móvil.
- Estilo comprobado en Chrome: etiqueta del nuevo módulo y etiqueta de Automatizaciones coinciden en fontFamily, fontSize, fontStyle, fontWeight, color y textTransform: Segoe UI/system-ui, 11.52 px, dorado rgb(192,136,56). Los enlaces del portal residente heredan el estilo de sus demás enlaces. CSS nuevo limitado a la ayuda y su enlace.
- Idioma: Español/English dentro de Ayuda; cambia el contenido y el nombre de los dos enlaces Ayuda/Help. Elección conservada sólo en ese navegador mediante axi_help_lang; sin columnas ni configuración de cuenta. El resto del portal sigue en español y las guías inglesas conservan los nombres reales de sus botones.
- Contenido inicial: 19 preguntas fijas, traducidas y filtradas por perfil; CEO 7, Asistente 7, Propietario 14, Inquilino 12, Administrador 14. Temas: navegación, sesión, reportes, reservas, cuenta, documentos y alcance del perfil. Incluye buscador, filtros, preguntas desplegables, estado sin resultados y orientación para contactar a la administración.
- Fuentes: interfaz del repositorio y funciones de navegación/rol, Reportar Avería y seguimiento, reservas, comprobantes, contacto y recuperación de sesiones. Corregido el texto de salida para que coincida con el botón real Salir. La apertura del formulario externo se explica, pero no se probaron sus campos ni envíos; no se promete entrega real de correos.
- Seguridad y alcance: sin IA, búsquedas externas, conexión de datos desde Ayuda ni acciones de envío. No cambia permisos, autenticación, sesión única, MFA, pagos, SQL ni Edge Functions. El filtro editorial por rol no se presenta como barrera de seguridad: los archivos contienen guías generales sin datos privados. No se incorporaron leyes o circulares sin aprobar.
- Archivos: index.html; [estilos](assets/ayuda.css); [interfaz](assets/ayuda.js); [contenido](assets/ayuda-contenido.js). Se conservan las versiones actuales de los scripts de recibos y sesiones. No se requiere migración de base.
- Verificación local: página real con SDK Supabase y servicios simulados, cinco perfiles y ambos idiomas; ruta ayuda permitida, guías correspondientes, búsqueda y restablecimiento, idioma recordado tras recarga, menú contraído, menú móvil y ausencia de desborde horizontal a 390 px. Cero consultas a datos de Supabase desde el flujo de ayuda y cero errores JS. Vistas de computadora/móvil inspeccionadas. Regresión de login, pestaña nueva/duplicada, recarga, salida y revocación pasó.
- Estado de esta publicación: código y documentación preparados en este commit. Verificación de despliegue se registra después; la vista local anterior no constituye prueba de publicación.
- Reversión, sólo con autorización: retirar enlaces, ruta y assets de ayuda restaurando la versión anterior de index.html; no hay datos de negocio que revertir.
- Para Claude: revisar ubicación bajo Automatizaciones, estilo heredado, ruta común y alcance de guías por perfil. No ampliar permisos ni sustituir Salir por un botón que no exista en la interfaz.

- Cierre verificado: [implementación 3a3edf3](https://github.com/Axicore-pa/axicore/commit/3a3edf3a9dd25545f2b24cfd20aaf9bd4e0c0d76); [GitHub Pages completado con success](https://github.com/Axicore-pa/axicore/actions/runs/38724046837). Los cinco archivos publicados se recuperaron de GitHub y coincidieron con lo preparado. La web real se abrió en Chrome limpio; los tres assets públicos coincidieron con los locales, 19 guías cargadas y cero errores JS. Se verificó la página con perfil CEO simulado únicamente en memoria, sin autenticación ni consultas a Supabase: ubicación bajo Automatizaciones, estilo coincidente y cambio a Help. Las verificaciones de los demás perfiles siguen siendo con servicios simulados, no con cuentas reales. Para ver el menú nuevo en una página ya abierta, recargar AXICORE con Ctrl+F5; el idioma se elige dentro de Ayuda.


### AXI-CGPT-013 — 15/10/2026 — Carrusel residencial en acceso
- Autorización expresa de Misael: “Muy de acuerdo con esta ultima version puedes implementar.” Versión B, cuatro escenas residenciales aprobadas después de revisar personajes, posturas y ambientes; logo original sin modificar.
- Alcance: pantalla de acceso; cuatro fondos ilustrativos (comunicación, cuentas, reservas, ayuda), mensajes relacionados con el portal y formulario fijo. Logo original PNG conservado byte por byte; fotografías convertidas a WebP (aprox. 590 KB en total). Sin fotografías de condominios reales ni datos de residentes.
- Carrusel: cada 8 segundos, transición suave, anterior/siguiente, selección directa y pausa. Se suspende al escribir en el formulario, cuando la pestaña no está visible y cuando se oculta el acceso. Movimiento reducido inicia pausado y elimina la transición.
- Adaptación: formulario central en escritorio; mensajes debajo en móvil/tablet para evitar superposición. Formularios de contraseña y MFA siguen dentro de la misma tarjeta, con altura variable.
- Archivos: index.html; assets/login-carrusel.css; assets/login-carrusel.js; assets/login/ (cuatro WebP y logo-original.png); testing/login-carrusel.cjs. No modifica scripts de negocio existentes, credenciales, permisos, sesiones, SQL, datos ni configuración de Supabase.
- Validaciones locales: scripts inline y bloque de formularios de autenticación idénticos a la versión anterior; logo idéntico byte por byte. Chrome: cuatro imágenes cargadas, navegación, avance automático, pausa al escribir, movimiento reducido, tamaños 390/768/1024 y escritorio 1600, sin desborde horizontal ni errores JS; formulario MFA accesible. Regresión de sesiones con SDK real y servicios simulados pasó: ingreso, segundo intento, pestaña duplicada, recarga, salida y revocación. No se usaron cuentas reales ni se enviaron avisos de prueba.
- Estado: preparado y probado localmente; publicación y comprobación de Pages se anotarán al finalizar. Pruebas con credenciales reales y MFA real no ejecutadas en esta tarea.
- Reversión, sólo con autorización separada: restaurar index.html previo y retirar referencias a assets/login-carrusel; no hay datos que revertir.
- Para Claude: revisar esta implementación visual y conservar el logo original, la aprobación de las escenas residenciales y la lógica de acceso existente.


- Cierre verificado AXI-CGPT-013: [implementación 0f6c596](https://github.com/Axicore-pa/axicore/commit/0f6c596a9c3a2b1bed3e9338b7f827dd6d5b9d6b); [GitHub Pages completado con success](https://github.com/Axicore-pa/axicore/actions/runs/38844150716). Sitio público abierto en Chrome limpio sin iniciar sesión: cuatro escenas y logo cargados, controles operativos, siete assets públicos idénticos a los preparados y cero errores JavaScript. Revisión de escritorio y móvil realizada localmente; pruebas de sesión con servicios simulados. Para ver el cambio en una página antigua, Ctrl+F5.


### AXI-CGPT-014 — 16/10/2026 — Registro por invitación y aprobación administrativa
- Responsable: ChatGPT/Codex.
- Solicitud y autorización: Misael confirmó mantener la invitación y completar el registro para Inquilinos, Propietarios y Administradores; cada solicitud queda pendiente hasta aprobación del CEO, y al aprobar se envía confirmación por correo. Confirmó además que rol y alcance deben venir del perfil ya existente.
- Estado: implementado en Supabase y preparado para publicar el código del portal en este commit. No se enviaron invitaciones ni se generaron solicitudes reales durante la implementación.
- Punto de partida: rama main, commit de código cc6d268260335239baee75b9562294b267e11a99; Supabase qfgyftsnwznsqizriggr activo.
- Hallazgo de asignación: 16 correos de perfil revisados; ninguno coincide entre roles. El backend identifica el perfil por el correo y exige coincidencia única; el invitado no puede escoger su rol ni alterar las unidades asignadas. Inquilinos usan unidad principal y enlaces activos de unidad_inquilinos; Propietarios usan propietario directo y enlaces activos; Administradores usan unidad_administradores vigentes.
- Trabajo: formularios de contraseña/información solo desde enlace de invitación; controles visibles para mínimo 6 caracteres, mayúscula, minúscula, número y carácter especial, repetición coincidente; invitaciones se inician desde los registros de persona; aprobación CEO con MFA crea usuarios/accesos del rol del perfil y encola correo de confirmación.
- Lógica de seguridad: la solicitud pendiente no recibe fila activa en accesos; el acceso se crea únicamente al aprobar. La Edge Function requiere JWT de CEO con AAL2. El usuario solo completa la solicitud ligada a su auth.uid y correo confirmado. Los cambios de contacto se aplican al aprobar; rol, condominio y unidades no se aceptan del cliente.
- Archivos preparados: index.html; supabase/migrations/20261016043221_axicore_registro_invitacion_aprobacion.sql; supabase/migrations/20261016043436_axicore_registro_unidades_inquilino.sql; supabase/functions/axi-registro-invitacion/index.ts.
- Base y servicios: migraciones aplicadas (20261016043221 y 20261016043436); Edge Function axi-registro-invitacion activa, versión 1, verify_jwt=true. Ningún registro de solicitud creado. Accesos activos permanecieron en 1.
- Validación: SQL ejecutado en transacción y revertido antes de aplicar; migraciones verificadas en Supabase; permisos comprobaron anon=false y service_role-only para RPCs de invitación/perfil; RLS habilitado en la tabla privada; el HTML/JS pasó node --check; Edge Function desplegada con compilación aceptada. El asesor de seguridad muestra las advertencias preexistentes del proyecto y las funciones SECDEF de registro que tienen controles de auth.uid/CEO+AAL2 revisados.
- Límites: no se probó el envío real de invitación ni el correo de aprobación para evitar crear cuentas o enviar mensajes reales. La entrega del mensaje final depende del procesador de correos existente.
- Siguiente paso: Misael puede invitar desde el registro de la persona y probar con una cuenta controlada; luego verificar que el CEO vea la solicitud, apruebe y el usuario reciba el correo antes de acceder.


### AXI-CGPT-015 — 16/10/2026 — Cierre de invitaciones y dominio propio
- Autorización de Misael: enlazar axicorepard.com, comprado en GoDaddy, para los envíos de AXICORE. Dominio verificado en Resend después de registrar DKIM y CNAME de envío. El sitio continúa en https://axicore-pa.github.io/axicore/.
- Supabase Auth usa SMTP de Resend configurado directamente por Misael. Remitente de invitaciones invitaciones@axicorepard.com. Error SMTP 535 resuelto al corregir la clave. No registrar claves aquí.
- Evidencia nueva respecto a AXI-CGPT-014: una invitación real enviada correctamente desde el portal a una propietaria; mensaje de éxito observado por Misael. No se verificó en esta tarea completar registro, aprobación CEO ni entrega del correo final.
- Otro perfil consultado ya tenía cuenta Auth confirmada pero sin acceso activo del flujo nuevo; no se borró ni se volvió a invitar. No divulgar datos personales de esos perfiles en esta bitácora.

### AXI-CGPT-016 — 16/10/2026 — Cargas exclusivas de CEO y Asistente
- Autorización expresa: restringir las cargas accesibles por perfil a CEO y Asistente, tipos PDF/PNG/JPG/JPEG. Residentes Inquilino/Propietario/Administrador conservan consulta.
- Publicado: PR https://github.com/Axicore-pa/axicore/pull/1 ; commit 8567ec81e0e131eb14921220b89fc1e7cc0cebfa ; Pages exitoso https://github.com/Axicore-pa/axicore/actions/runs/38856438677 .
- Supabase: migración 20261016053142_axicore_restringir_cargas_residentes_y_extensiones aplicada. Archivo y reversión conservadora en supabase/migrations y sql/rollback_axicore_restringir_cargas_residentes_y_extensiones.sql.
- Se retiró carga nueva de comprobantes del portal residente. El flujo actual exige adjunto, por lo que residentes no pueden enviar nuevos comprobantes. Historial conservado.
- Evidencia de mantenimiento permanece CEO-only por regla previa; no se amplió a Asistente. No se modificaron tablas de negocio ni sesión única.
- Validación: pruebas simuladas de roles, permisos, aislamiento, extensiones y reversión; políticas de Storage verificadas; sin cargas con cuentas reales.

### AXI-CGPT-017 — 16/10/2026 — Informaciones y circulares con acuses
- Autorización: menú Informaciones y circulares. CEO/Asistente publican para condominio seleccionado; residentes solo consultan. PDF/PNG/JPG hasta 10 MB en bucket privado circulares.
- Publicado: PR https://github.com/Axicore-pa/axicore/pull/2 ; commit ce255ea0a04b617a8b4d3d623c783b41c28dac28 ; Pages exitoso https://github.com/Axicore-pa/axicore/actions/runs/38863973522 .
- Migraciones aplicadas por MCP: 20261016065357_axicore_circulares_confirmacion y 20261016065508_axicore_circulares_programacion. Archivos fuente CLI: 20261016063556 y 20261016064911 respectivamente.
- Tablas privadas axi_circulares, axi_circular_lecturas, axi_circular_correos con RLS y sin acceso directo de anon/authenticated. Funciones validan cuenta, sesión/tab, rol y condominio; staff y Administrador requieren MFA donde corresponde.
- Formulario Subir y publicar / Enviar. Enviar publica y pide confirmar el lote. Avisos separados TO a email válido de residentes activos (inquilinos, propietarios, administradores) del condominio, deduplicados; CC axispard@gmail.com. Sin adjuntos; enlace al portal. Aceptación del proveedor no implica llegada a bandeja ni lectura.
- Login: Nueva Circular Disponible con Abrir circular / Leída / No leída. No leída reaparece al próximo inicio. Leída confirma directamente; Abrir confirma tras render correcto de imagen/primera página PDF. No exige recorrer todas las páginas ni acredita comprensión/aprobación.
- Acuse por perfil/circular idempotente, con comprobante al CEO y datos del perfil/unidad/condominio/fecha UTC. Texto visible: Se ha notificado a la Asamblea de que está en conocimiento de esta información. El correo se dirige al CEO; no implica correo colectivo a Asamblea.
- Visor canvas con marca personal y X/Cerrar para volver al inicio de unidad; sin controles de descarga/impresión. Un usuario autorizado puede copiar datos o capturas; no existe garantía absoluta de impedir descarga.
- Edge Function axi-circulares-correo v1 con JWT activo, secreto RESEND_API_KEY agregado directamente por Misael. Cron axicore-circulares-correo cada minuto, solo cola propia; no modifica axi-correo-cola/Gmail. Lotes de 5, idempotencia y reintentos acotados.
- Pruebas al publicar: 35 verificaciones SQL simuladas, navegador con imagen y PDF real de dos páginas, cierre/acuses/errores/móvil, worker Resend simulado. Producción con cola vacía respondió HTTP 200 (0 envíos). No se crearon circulares ni envíos de prueba reales.
- Estado visto al retomar el ajuste de correo: seis circulares reales ya publicadas por uso posterior; la cola estaba vacía. No confundir con datos de prueba de Codex.

### AXI-CGPT-018 — 16/10/2026 — Checkpoint de reanudación: correo de circulares
- Autorizado por Misael después de revisar la vista previa: remitente AXICORE <Admin@axicorepard.com>; firma APA | AxiCore Property Administration / Tel. 809-282-7776 / axispard@gmail.com; asunto código - título, ejemplo CIR-DH2-006-2026 - Importancia de la Asamblea.
- Misael eligió introducir manualmente el código del documento al subirlo. Nuevo campo separado, obligatorio, mayúsculas y código único; no generación automática.
- Estado al guardar este checkpoint: cambios locales y pruebas preparados; publicación todavía pendiente. No asumir que este bloque acredita despliegue.
- Compatibilidad: conservar títulos y acuses anteriores. Recuperar únicamente códigos CIR inequívocos ya incluidos en títulos; asunto no repite prefijo. Títulos históricos sin código separado conservan su texto.
- Pruebas locales actuales: 44 verificaciones SQL aprobadas; navegador aprobado (carga, aviso, apertura, acuse, PDF, móvil); worker con remitente Admin aprobado con Resend simulado. No envíos reales durante las pruebas.
- Incidencia: ejecución local de la ayuda CLI Supabase bloqueada por escritura fuera del proyecto; escalación no ejecutada porque revisión automática agotó su límite de uso. No se eludió. Cambios y despliegues se continuarán por herramientas conectadas dentro del alcance autorizado.
- Siguiente paso: publicar migración/worker/formulario, verificar estado efectivo y actualizar este bloque con resultado, versiones y enlaces. Invitaciones Auth conservan su remitente propio; el cambio solicitado corresponde a circulares.


#### Cierre verificado de AXI-CGPT-018 — 16/10/2026
- Estado final: aplicado y publicado. Autorización explícita: Misael indicó “Bien, aplícalo” y pidió retomar, registrar el checkpoint y actualizar este archivo al terminar.
- PR de implementación integrado: https://github.com/Axicore-pa/axicore/pull/3 . Commit a5bc21040acd93c94184256e65e1c17c3bfe90e6.
- GitHub Pages completó con success: https://github.com/Axicore-pa/axicore/actions/runs/38868899873 . Portal público abierto después en Chrome limpio: assets/circulares.js?v=20261016-2 coincide con el código probado, módulo cargado, sin sesión y cero errores JavaScript.
- Supabase: migración 20261016074139_axicore_circulares_codigo_firma aplicada. SQL exacto guardado en supabase/migrations/20261016074139_axicore_circulares_codigo_firma.sql y sql/circulares_codigo_correo.sql. La migración recibió su identificador del servicio conectado; no se inventó una fecha local.
- Edge Function axi-circulares-correo versión 2 ACTIVE con verify_jwt=true. Lectura posterior confirmó AXICORE <Admin@axicorepard.com> como remitente. No requiere compartir ni modificar RESEND_API_KEY.
- Verificación efectiva: seis circulares conservadas; dos códigos CIR recuperados de títulos existentes; cola vacía; índice de código único presente; código manual obligatorio para nuevas cargas; anon sin ejecutar preparar y authenticated sin INSERT directo. Cron de circulares activo.
- Asunto del ejemplo confirmado en producción: CIR-DH2-006-2026 - Importancia de la Asamblea, tanto con título nuevo sin prefijo como con el título previo que ya lo contiene. Firma y teléfono presentes en la función de encolado; el comprobante también identifica código y firma.
- Pruebas locales: 44 comprobaciones SQL, navegador con carga de código manual normalizado/imagen/PDF real/móvil y worker con Resend simulado aprobados. Se actualizó la firma de preparar en rollback_circulares.sql. testing/circulares-publicado.cjs documenta la comprobación pública.
- Asesor de seguridad: mismos tipos y conteos de avisos antes/después; no surgieron avisos nuevos por esta actualización. Se mantienen controles de sesión, MFA, rol y condominio previos.
- Límites y pendientes: no se publicó una circular de prueba ni se envió un email real de prueba; la llegada a bandeja del primer aviso con el nuevo remitente debe observarse al usar Enviar. Admin@axicorepard.com está configurado como remitente de circulares; no se creó un buzón de recepción. Las cuatro circulares históricas sin código CIR separado conservan su título completo original; no se les asignaron códigos inventados.
- Incidencia de verificación: la lectura pública inicial no resolvió DNS dentro del entorno restringido; la misma comprobación de solo lectura fue autorizada y pasó fuera de esa restricción. El bloqueo anterior de la ayuda CLI no impidió aplicar y verificar los cambios mediante el conector.
- Para Claude: leer este cierre y contrastar estado antes de trabajar. No repetir migración, reenvíos, invitaciones ni pruebas con residentes por considerar pendientes los estados históricos anteriores. El trabajo autorizado de este ajuste está completo; una prueba real de correo o cambios adicionales requieren el alcance que Misael indique.




### AXI-CGPT-019 — 16/10/2026 — Seguridad inmediata y respaldo en preparación
- Misael autorizó actuar de inmediato sobre los hallazgos de seguridad; difiere pruebas con roles hasta disponer de usuarios reales. Eligió nube del correo para respaldo. Google Drive confirmado como axispard@gmail.com; carpeta privada creada, único permiso propietario observado: https://drive.google.com/drive/folders/1jMkR2PPQkpDlFVhqbTE1F6MjdvE1At_N.
- Seguridad aplicada y publicada: PR https://github.com/Axicore-pa/axicore/pull/5, commit 47366b0700e484104235c4ae1c033cdc3d91d3aa, Pages success https://github.com/Axicore-pa/axicore/actions/runs/38869838784. Lectura pública en navegador limpio confirmó HTML idéntico al probado, funciones de escape/CSP básica cargadas, cero errores y sin sesión.
- webapp-upload v5 ACTIVE, verify_jwt=true, getUser + mi_perfil + CEO/AAL2 antes del cliente privilegiado, solo POST. Prueba anónima real desde pg_net respondió 401. No se ejecutó una publicación de prueba.
- Migración 20261016074250_axicore_endurecimiento_archivos_trigger aplicada: mant-evidencia 10 MB, extensiones png/jpg/jpeg conservando CEO-only y MIME previo; fn_set_updated_at fija search_path vacío. Configuración releída y confirmada.
- Frontal: 483 interpolaciones escalares protegidas, errores concatenados, rutas de comprobantes/documentos y enlaces revisados. Protección CSP básica object-src/base-uri/form-action, sin afirmar CSP completa contra scripts. Se conservó la actualización concurrente de código/firma de circulares de los PR 3 y 4.
- Validación: pruebas sintéticas de función y PostgreSQL/reversión; seis renderizadores con entradas maliciosas y cuatro argumentos con caracteres especiales; regresiones de sesiones y circulares/PDF/móvil. Sin cuentas reales, cargas de negocio ni correos. Persisten revisión de funciones privilegiadas, renderizadores compuestos y pruebas reales de roles; no garantía de riesgo cero.
- Supabase Free confirmado. No se presume backup automático administrado. Proceso Python preparado para dump consistente, objetos, código/historial, funciones/configuración, manifiesto, cifrado RSA-OAEP/AES-GCM y subida/relectura con hash en Drive. Pruebas locales de cifrado/alteración/clave incorrecta y orquestación simulada aprobadas. NO se probó extracción ni restauración integral de producción.
- Flujo diario previsto 06:17 UTC = 02:17 America/La_Paz, deshabilitado por guardia AXICORE_BACKUPS_ENABLED hasta configurar cuatro secretos de ejecución y custodiar clave privada. El conector Drive de la conversación no proporciona OAuth al ejecutor externo. No se activó esa variable ni se configuraron secretos. No anunciar respaldo diario activo.
- Solo la clave pública se conserva en el repositorio. Clave privada de recuperación en archivo local separado para custodia offline; nunca subirla al repositorio ni a la carpeta de respaldos. Consultar backup/LEER-PRIMERO.md para límites: secretos reales/Vault, DNS y recursos Google externos requieren custodia/inventario separado; retención automática y alertas independientes aún pendientes.
- Se prepara copia inicial cifrada de código sin datos; su existencia no acredita respaldo completo. La entrega final del chat precisará el resultado efectivo de esa subida.


### AXI-CGPT-020 — 16/10/2026 — Dominio web y variante www verificados
- Misael conectó axicorepard.com a GitHub Pages siguiendo los pasos del chat: cuatro A de @ a 185.199.108.153, 185.199.109.153, 185.199.110.153 y 185.199.111.153; CNAME www a axicore-pa.github.io. El archivo CNAME del repositorio contiene axicorepard.com. Registros de envío de correo conservados.
- Solicitud expresa posterior: resolver la variante www.axicorepard.com. Diagnóstico inicial: DNS correcto y error TLS RemoteCertificateNameMismatch. La comprobación IPv6 no encontró un registro AAAA ajeno: www hereda los cuatro destinos IPv6 de GitHub.
- Resultado al retomar tras el aviso de sesión de Misael: la emisión automática de GitHub ya se completó. Se verificó TLS normal contra axicorepard.com y www.axicorepard.com, sin ignorar errores ni omitir la validación. Certificado CN=axicorepard.com con SAN que contiene ambas variantes; vencimiento observado 2027-01-14 11:35:19 UTC.
- Comprobación de cabeceras HTTPS, sin iniciar sesión ni descargar contenido: https://axicorepard.com/ respondió 200; https://www.axicorepard.com/ terminó en https://axicorepard.com/ con 200. Variante resuelta y dominio principal sin www.
- No fue necesario modificar de nuevo DNS, quitar el dominio de Pages ni desactivar HTTPS. El navegador de administración disponible al agente no tenía sesión de GitHub; la verificación pública posterior acreditó el resultado sin cambiar configuraciones.
- Alcance pendiente separado: no se actualizaron en esta tarea Site URL/Redirect URLs de Supabase ni los enlaces antiguos escritos en invitaciones y avisos de circulares. Migrar esas rutas y comprobar el flujo completo corresponde al siguiente trabajo autorizado; no anunciar que ya están migradas.
- Se conserva íntegra AXI-CGPT-019 sobre respaldos y sus pendientes; esta entrada no activa respaldos ni altera secretos.


### AXI-CGPT-021 — 16/10/2026 — Inquilinos: excluir mantenimiento en producción y demo
- Autorización expresa posterior de Misael: revisar el perfil Inquilino en ambos entornos y corregir lo necesario. Este alcance autoriza únicamente la corrección de visibilidad financiera en producción; no amplía otros trabajos diferidos de la demo, respaldos, DNS o correo.
- Se confirmó la misma regla incorrecta en ambos: facturas/pagos por inquilino_id sin verificar que fueran a cargo de Inquilino y sin excluir mantenimiento. Los RPC de estado por unidad repetían la condición.
- Aplicadas migraciones administradas 20261016231622 en DEMO jvrjtxckmpcslwjphhew y 20261016231740 en producción qfgyftsnwznsqizriggr, nombre axicore_inquilino_sin_cuota_mantenimiento. El archivo local se generó con CLI como 20261016231355_axicore_inquilino_sin_cuota_mantenimiento.sql; la API asignó su propia hora al aplicar.
- La regla exige factura aprobada, tipo_facturacion Inquilino, identidad y unidad vigentes, sin cuota de mantenimiento por categoría/indicador/concepto histórico. Se corrigieron tres políticas SELECT y cuatro funciones existentes; dos helpers privados nuevos. Pagos deben estar vinculados a factura permitida de su unidad/condominio. También quedan cubiertos detalle, resumen, movimientos, comprobantes y lectura de archivos propios ligados a mantenimiento. Recibos internos permanecen exclusivos del personal autorizado.
- Se conservan las ramas de CEO, Asistente, Propietario y Administrador con MFA. No se cambiaron código visual, asignaciones, Auth, MFA, permisos de carga ni envíos; no se modificaron registros financieros. Comparación de conteos y hashes completos de facturas, pagos, detalle_factura y comprobantes_pago antes/después: idénticos en ambos entornos.
- Validación: 22 comprobaciones PostgreSQL/PGlite con datos ficticios, incluidas reproducción del error, cargos legítimos de reparación/GLP, aislamiento entre perfiles/condominios, Storage, RPC, MFA y reversión. Relectura de seis funciones y tres políticas en cada servidor: idénticas entre demo y real. RLS habilitada; helpers sin EXECUTE anónimo. Asesores de seguridad consultados; no se presenta esto como auditoría integral de los avisos generales existentes.
- No se inició sesión con cuentas reales ni se crearon transacciones/correos reales de prueba. Se preservó la sesión de inquilino abierta en la demo. La validación de pantallas con usuarios reales no se ha ejecutado; recargar el portal hace que consulte las reglas nuevas.
- Prueba reproducible: testing/tenant-maintenance.cjs; explicación testing/INQUILINOS-MANTENIMIENTO.md; reversión conservadora sql/rollback_inquilinos_mantenimiento.sql. La reversión devuelve la regla incorrecta y requiere decisión explícita antes de ejecutarla.
- Demo vigente: https://demo.axicorepard.com, acceso web directo SIN cuenta de ChatGPT, datos/acciones protegidos por AXICORE. Guías y contraseñas de demo permanecen locales y privadas; no publicarlas en este repositorio. La comercialización y el headquarters de soporte siguen diferidos.


### AXI-CGPT-022 — 17/10/2026 — Búsqueda de nueva nota de Claude
- Solicitud de Misael: leer la bitácora compartida dejada por Claude y resolver el problema descrito allí.
- Estado: parcial; referencia nueva pendiente de localizar. Se leyó CONTINUIDAD.md desde GitHub, el checkpoint histórico docs/CHECKPOINT_Migracion_web-3.md, el árbol del repositorio, los cinco commits recientes, las ramas y los PR abiertos.
- Evidencia: main seguía en a42f6dec60e588b07473acbabad40f47bba096b0; la última minuta antes de esta lectura era AXI-CGPT-021. La única entrada identificada de Claude es AXI-CLAUDE-001 del 14/10/2026. No había PR abiertos ni una nueva nota identificable en los archivos del repositorio revisados.
- No se ha determinado a qué problema nuevo se refiere la solicitud. Se pidió a Misael el enlace o texto de la nota para evitar atribuirle un diagnóstico no comprobado.
- Código funcional, base de datos, demo, producción y servicios: sin cambios. No se ejecutaron pruebas funcionales; esta tarea fue de lectura documental.
- Aclaración posterior de Misael: la nota se llama claude/BUG_despacho_responder_raw_html.md y está en SharePoint. No se encontró en el árbol GitHub ni en los archivos locales disponibles. La búsqueda del conector confirmó SharePoint disponible pero no instalado/conectado en esta sesión; se ofreció habilitarlo. El diagnóstico del documento todavía no ha sido leído.
- Siguiente paso: obtener acceso al documento de SharePoint o su archivo/contenido, contrastar su diagnóstico y resolver dentro del alcance autorizado. No tomar esta entrada como resolución del problema.


### AXI-CGPT-023 — 17/10/2026 — Respuesta de despacho: HTML crudo resuelto
- Solicitud de Misael: leer el informe de Claude BUG_despacho_responder_raw_html.md, finalmente publicado en la raíz del repositorio, y resolver el problema. Esta tarea completa la localización pendiente de AXI-CGPT-022.
- Estado: corregido, publicado y verificado. Punto de partida main a246d65e982927b76771aa5dfa61f531b5df61a0; función axi-despacho-responder v2, verify_jwt=false.
- Causa confirmada: el gateway de Supabase convierte GET text/html en text/plain bajo el dominio estándar; comprobación HTTP real devolvió 200 text/plain. Documentación oficial: https://supabase.com/docs/guides/functions/limits. Renombrar helpers, TextEncoder o cambiar JWT no corrigen esta restricción. No se contrató un dominio de API de pago.
- Solución: despacho.html y assets/despacho.js/.css sirven el formulario desde https://axicorepard.com. Diseño y siete opciones conservados. GET/HEAD de axi-despacho-responder redirigen 302 al portal con el UUID en fragmento; correos ya enviados y futuros del worker actual mantienen sus enlaces y no requieren reenvío. GET no registra respuestas.
- POST continúa usando public.despacho_responder(uuid,text), con validación de UUID y de las siete opciones originales. Se conserva verify_jwt=false porque proveedores usan el token del enlace, sin cuenta de residente. CORS limitado al portal; no-store, no-referrer, mensajes mediante textContent, sin interpolar tokens en HTML ni exponer claves privilegiadas. El formulario retira el token del enlace al confirmar.
- Archivos y código: PR https://github.com/Axicore-pa/axicore/pull/8 integrado como 78d8564272c3f441c682ef7a009e1f9f0fc67757. Pruebas reutilizables testing/despacho.cjs y explicación/reversión testing/DESPACHO-RESPONDER.md. Pages success https://github.com/Axicore-pa/axicore/actions/runs/39032838082.
- Orden aplicado: primero publicar y comparar los tres archivos estáticos (HTTP200, MIME/UTF-8 correctos, contenido idéntico al probado), después desplegar función v3 ACTIVE con verify_jwt=false. Relectura del código desplegado idéntica al archivo versionado.
- Validación: 18 comprobaciones locales API simulada/Chrome aprobadas: siete opciones, UTF-8, selección única, doble clic, mensajes de negocio, recuperación de red, CORS, tokens inválidos, rechazo de HTML inyectado y móvil390px. Vistas escritorio/móvil inspeccionadas.
- Validación pública adicional en Chrome limpio: enlace antiguo → redirección → formulario renderizado; siete opciones, UTF-8, móvil sin desborde y cero errores JS. Una única solicitud POST con UUID confirmado inexistente devolvió Token inválido, verificando API y CORS reales sin registrar respuesta. No se usó el token vigente del informe, no se enviaron correos ni se inició sesión de residente.
- Base/servicios: sin migraciones. Conteos y huellas completas de mantenimientos, mant_despachos y mant_despacho_respuestas idénticos antes/después; definición del RPC idéntica. axi-despacho-correo v2 idéntico; index.html principal conserva su blob anterior. Demo, DNS, secretos, Auth, MFA, cron, reglas de asignación y datos sin cambios.
- Límite: la aceptación de una respuesta con token vigente se probó con RPC simulado; no se consumió un enlace real ni se afirmó una nueva entrega de correo. La limpieza del reporte de prueba de Claude y su relación de proveedor/categoría queda separada: no fue necesaria para corregir el fallo y no se borraron registros.
- Para Claude: no volver a servir HTML directamente desde el dominio estándar de Edge Functions ni cambiar verify_jwt para intentar corregir su renderizado. Conservar la página estática y el POST por token. No repetir despliegues, correos o pruebas con tokens vigentes por considerar pendiente el informe original.


### AXI-CGPT-024 — 17/10/2026 — Consulta sobre seguimiento del proveedor seleccionado
- Solicitud: Misael pregunta si hay herramienta de seguimiento después de seleccionar proveedor por disponibilidad; adjunta mensaje Este despacho ya fue cerrado.
- Estado: revisión documental y de definiciones completada; sin implementación nueva autorizada en esta pregunta.
- Verificado: frontend Mantenimiento ofrece bandeja, técnico/proveedor de la asignación activa, fecha estimada, avance, estados, historial, reasignación y comunicación. fn_mant_cambiar_estado registra asignación técnica y fecha estimada, obligatorias para En proceso.
- Brecha: despacho_cerrar_ventana escoge menor prioridad_peso (disponibilidad más pronta), desempata por fecha_respuesta y escribe ganador, despacho y mantenimientos.proveedor_id. No crea mant_asignaciones ni incorpora esa elección al historial de mantenimiento. El frontend revisado no contiene visor de despachos/respuestas o ganador; se basa en la asignación técnica activa.
- Conclusión: existe seguimiento manual en Mantenimiento, pero falta integrar automáticamente el proveedor seleccionado por despacho con ese seguimiento y ofrecer su panel. Propuesta pendiente: selección y disponibilidad, confirmación/fecha de visita, llegada, ejecución, cierre e incidencias/alertas. No tomar esta propuesta como alcance aprobado.
- El mensaje de la imagen significa que se cerró la recepción de respuestas; por sí solo no acredita proveedor seleccionado ni servicio resuelto.
- Validación: lectura de index.html actual y definiciones/columnas desplegadas (despacho_cerrar_ventana, despacho_responder, fn_mant_cambiar_estado, fn_mant_detalle). No pruebas operativas, correos, cambios de código funcional ni de base.


### AXI-CGPT-025 — 17/10/2026 — Seguimiento aprobado; tolerancia y relevo; consulta WhatsApp
- Misael aprueba las sugerencias de seguimiento de AXI-CGPT-024 y añade llegada estimada con tolerancia +/-60 minutos; superado el límite sin llegada, notificar cancelación al proveedor y asignar al siguiente elegible (opción B).
- Estado: definición de flujo en curso; no implementado ni activado. Se pidió confirmar quién registra/verifica la llegada (administración/conserjería o aviso del proveedor verificado) y si el número usa WhatsApp normal o Business. Evitar cancelar automáticamente una visita ya ocurrida por falta de confirmación.
- Interpretación presentada: hora estimada T, ventana T-60 a T+60; cancelación al superar T+60 sin llegada confirmada. Requiere hora concreta: opciones amplias como mañana en la tarde no fijan por sí solas un vencimiento. Para B, solicitar disponibilidad actualizada antes de dar por confirmada una visita; no asumir que su oferta anterior sigue vigente.
- WhatsApp: técnicamente viable como integración de AXICORE mediante WhatsApp Business Platform/API con un número empresarial, plantillas aprobadas y consentimiento de proveedores, no basta con una sesión de WhatsApp Web. Consultadas fuentes oficiales https://whatsappbusiness.com/products/business-platform/ y https://whatsappbusiness.com/policy/ (política actualizada23/09/2026). Pueden existir cargos; no se contrataron servicios ni configuró facturación.
- Búsqueda de integración disponible: no se encontró plugin WhatsApp en esta sesión. No existe conexión confirmada ni envío automatizado habilitado. No se pidieron contraseñas ni se enviaron mensajes.
- Código, base, funciones, cron, demo y producción: sin modificaciones funcionales en esta consulta. Pendientes las respuestas operativas y el diseño revisable de la pantalla antes de cambios visuales. La autorización de seguimiento no acredita implementación ni entrega de avisos.


### AXI-CGPT-026 — 17/10/2026 — Seguimiento y llegada por cualquier canal; relevo automático
- Autorización: Misael aprobó seguimiento del proveedor y solicitó ventana ±60 minutos, cancelación al superar el límite sin llegada y siguiente proveedor. Precisó llegada por enlace de correo o registro de administración tras llamada/WhatsApp/correo/presencial, sin depender de una acción del proveedor. Confirmó uso de WhatsApp Business.
- Estado: seguimiento y correos publicados/activos en producción para nuevas selecciones. BOT WhatsApp pendiente de conexión API; no se activó ni se enviaron mensajes de WhatsApp ni se contrató facturación. Se registran manualmente los avisos recibidos por ese canal.
- Código integrado: PR https://github.com/Axicore-pa/axicore/pull/9 commit 997f607658879f12e6a44c6c7b6f3c0369661b58; ajuste final PR https://github.com/Axicore-pa/axicore/pull/10 commit d106861b0b1d6fee7072e9f15c5f53760133c5c3. Pages del código de interfaz success: https://github.com/Axicore-pa/axicore/actions/runs/39044000440. Cinco recursos públicos comparados con lo probado: HTTP200 e idénticos.
- Migraciones efectivas: 20261017151145_axicore_seguimiento_despacho y 20261017151434_axicore_seguimiento_cola_cierre. Archivos CLI fuente: 20261017145831 y 20261017151346 respectivamente. No repetir por diferencia de hora. Proyecto productivo qfgyftsnwznsqizriggr comprobado ACTIVE_HEALTHY; demo sin cambios.
- Tres tablas nuevas private con RLS: axi_despacho_seguimientos, axi_despacho_eventos y axi_despacho_avisos; sin lectura directa anon/authenticated. Trigger de nueva selección crea seguimiento con token distinto del de respuesta y aviso. No se migraron selecciones históricas ni se iniciaron sus notificaciones.
- Uso administrativo: Mantenimiento → Abrir reporte → Seguimiento del proveedor. Canal, hora estimada, nota y Registrar llegada; no exige correo del proveedor. Historial de turnos, respuestas por disponibilidad, horas y estado del correo. La interfaz principal solo añade contenedor/gancho y assets; no se reescribieron funciones existentes.
- Proveedor recibe enlace a despacho-seguimiento.html para confirmar hora concreta en RD (America/Santo_Domingo) o Ya llegué al lugar; abrir/consultar no confirma llegada. Puede avisar por llamada/WhatsApp y administración registra canal/nota. Se admite llegada incluso antes de fijar una hora. Llegada repetida idempotente.
- Regla: T-60 a T+60; al superar T+60 sin llegada, tick de despacho existente cada minuto cancela seguimiento A, notifica cancelación, desactiva técnico pendiente del mismo proveedor y activa siguiente elegible por prioridad/fecha de respuesta. B confirma hora nueva. Sin suplentes notifica CEO y deja Sin respuesta. Sin hora concreta NO se inventa vencimiento. No es un temporizador al segundo.
- Protecciones: no relevar un trabajo En proceso con técnico activo del mismo proveedor; no pisar reasignación manual posterior; reportes Resuelto/Cerrado/Cancelado finalizan seguimiento. Proveedor no cambia su propia hora ya confirmada; administración puede ajustar antes de vencer con nota. Una asignación ya cancelada no admite llegada retroactiva por su enlace. Técnico/cédula y avance/resolución siguen en el control de Mantenimiento existente.
- Funciones staff validan auth.uid, sesión, MFA y permiso/condominio. RPC por token, cola y resultado solo service_role; la Edge pública autoriza mediante UUID del enlace. despacho_cerrar_ventana ahora solo servidor/service_role para impedir selección anticipada desde clientes. Toda función nueva fija search_path vacío. Cierre inicial bloquea el despacho y excluye proveedores inactivos/no aprobados.
- Servicios: axi-despacho-seguimiento v1 ACTIVE verify_jwt=false; axi-despacho-correo v3 ACTIVE verify_jwt=true. Relectura exacta al código versionado. Worker conserva invitaciones y agrega cola propia de seguimiento por Resend, remitente Admin@axicorepard.com, CC CEO en avisos al proveedor; llegada/sin suplente avisa CEO. Sin adjuntos ni envíos de prueba reales.
- Cola: reserva de2min, cuatro intentos e Idempotency-Key por aviso; finaliza Error si última ejecución interrumpida. Estado Enviado significa aceptación por Resend, no entrega/lectura. Se ven estados en el historial. La cola Gmail y la de circulares permanecen intactas.
- Validación:72 comprobaciones locales, 40 PostgreSQL/PGlite,22 API/Chrome y10 Resend simulado, con datos inventados. Incluyen canales manuales, tokens/roles, MFA, sesión revocada, aislamiento, tolerancia, relevo, proveedor inactivo, protección de trabajo/reasignación, cola e inyección.
- Verificación pública: página/API+CORS real rechaza UUID inexistente sin cambios; panel en portal publicado renderizado en móvil con fixture de RPC únicamente en memoria, sin login real; worker rechaza POST sin JWT con401 sin ejecutar envíos. Cero errores JS. No se probó un token vigente ni la entrega real de un aviso de asignación/cancelación.
- Estado efectivo al cerrar: nuevas tablas sin seguimientos/avisos; reportes, despachos, respuestas y asignaciones conservan conteos y hashes íntegros antes/después. Cinco ejecuciones recientes de cron, cero fallos. Asesores revisados: nuevas tablas privadas RLS sin políticas directas intencionadamente; se eliminó search_path mutable del tick. Persisten advertencias generales anteriores; no afirmar auditoría integral ni riesgo cero.
- Archivos reproducibles: testing/SEGUIMIENTO-DESPACHO.md, testing/seguimiento-db.cjs, testing/seguimiento-ui.cjs, testing/seguimiento-correo.cjs y SQL enlazado allí. Reversión conservadora sql/rollback_seguimiento_despacho.sql, sin borrar tablas/historial; conserva cierre restringido al servidor. Revertir también worker/pantallas si se decide, no ejecutar automáticamente.
- Pendientes: conectar API oficial WhatsApp Business, credenciales en secretos y plantillas/consentimiento antes de enviar automáticamente. No basta la aplicación Business instalada. No pedir secretos en chat. La primera entrega real de correo y uso con proveedor vigente se observarán en operación; no considerarlos probados por fixtures. Comercialización/headquarters continúan diferidos.


### AXI-CGPT-027 — 17/10/2026 — Localizar respuesta de disponibilidad de prueba
- Misael indica que el proveedor respondió que asistiría en2horas y pregunta dónde verlo.
- Revisión de solo lectura: al consultar producción solo existe el despacho1 del reporte RPT-TEST-99999, mantenimiento40/condominio5, estado Sin respuesta. Su respuesta y fecha_respuesta permanecen NULL, es_ganador=false y no hay seguimiento/estimada. No se constató una respuesta guardada de Dentro de2horas ni otro despacho.
- Ruta de consulta publicada: Mantenimiento → Abrir reporte → Seguimiento del proveedor → Respuestas y orden de disponibilidad. La respuesta inicial de disponibilidad y la posterior hora concreta de visita son pasos distintos.
- Se debe aclarar si el proveedor confirmó mediante el formulario y vio éxito, o respondió al correo/WhatsApp por texto. No se afirma que una respuesta externa se importe automáticamente: WhatsApp API no conectado y correo entrante no tiene lector automático implementado. No reabrir ni fabricar respuestas del despacho cerrado sin nueva instrucción.
- Código funcional, datos, correo, cron y demo sin cambios; no se consumieron tokens ni se hicieron envíos. Esta minuta documenta la comprobación, no una corrección operativa.
