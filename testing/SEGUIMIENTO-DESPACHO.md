# Seguimiento de proveedores de despacho

Misael aprobó la integración del despacho con seguimiento y relevo. Confirmó que administración puede registrar llegada comunicada por WhatsApp, llamada, correo o presencial; no depende del clic del proveedor. WhatsApp Business existe, pero API/plantillas no conectadas.

## Uso
Mantenimiento → Abrir reporte → Seguimiento del proveedor.
La selección futura crea un seguimiento y correo desde Admin@axicorepard.com (CC axispard@gmail.com). El enlace permite confirmar hora concreta y avisar llegada. Administración dispone de Guardar hora estimada y Registrar llegada con canal y nota. Horas visibles y formulario en America/Santo_Domingo (RD), UTC en base.

Se conserva el orden de disponibilidad de las siete respuestas; desempate por fecha de respuesta. Proveedores inactivos/no aprobados no se seleccionan. El seguimiento solicita una hora concreta; no inventa hora para mañana en la tarde y no inicia cancelación sin hora confirmada.

La ventana es T-60 a T+60 minutos. Tras superar T+60 sin llegada, el cron existente procesa cancelación y suplente en la misma transacción. Si nadie más respondió de forma elegible, requiere intervención y avisa al CEO. La opción B confirma una nueva hora, no hereda una promesa vencida. La comprobación se ejecuta cada minuto, por lo que no es un temporizador al segundo.

Registrar llegada por cualquiera de las dos vías detiene el relevo. Las confirmaciones de llegada son idempotentes. No se permite que proveedor cambie indefinidamente su propia hora confirmada; administración puede modificarla antes del vencimiento, con nota. Un registro vencido ya cancelado no admite llegada retroactiva desde su enlace.

No reemplaza el control técnico existente: datos del técnico/cédula, En proceso/Resuelto/Cerrado y comunicación siguen en Mantenimiento. Protege trabajos en proceso con técnico activo y reasignaciones manuales posteriores. Al cancelar un proveedor aún pendiente, desactiva su asignación técnica pendiente y conserva su historial.

## Seguridad y avisos
Tres tablas private con RLS y sin acceso directo anon/authenticated; RPC staff valida auth.uid, sesión vigente, MFA y permisos/condominio. RPC por token, cola y resultados son service_role-only. Edge pública nueva conserva autorización por UUID del enlace, CORS del dominio, JSON/no-store/no-referrer; no sirve HTML desde Supabase ni expone claves.

Avisos propios con reserva de dos minutos, hasta cuatro intentos e Idempotency-Key de Resend por aviso. Aceptado por proveedor de correo no equivale a leído/entregado. La cola muestra Pendiente/Enviando/Enviado/Error/Omitido; se consulta desde el historial. No se alteran avisos de invitación anteriores ni la cola Gmail/circulares. El worker axi-despacho-correo sigue verify_jwt=true.

WhatsApp BOT NO activo. Se registra manualmente el canal cuando administración recibe un aviso. Para enviar/recibir automáticamente desde WhatsApp faltan alta API oficial, número/identificadores, credenciales guardadas como secretos y plantillas aprobadas. No se solicitaron secretos en chat ni se contrató facturación.

## Fuente, pruebas y publicación
- SQL fuente: sql/seguimiento_despacho.sql + sql/seguimiento_despacho_integracion.sql.
- Migración fuente CLI: supabase/migrations/20261017145831_axicore_seguimiento_despacho.sql. La versión efectiva MCP se documenta en CONTINUIDAD.md.
- SQL probado en PGlite con fixtures sintéticos: testing/seguimiento-db.cjs (40 comprobaciones).
- API y navegador Chrome con RPC simulado: testing/seguimiento-ui.cjs (22 comprobaciones), móvil/proveedor y registro por llamada.
- Resend simulado: testing/seguimiento-correo.cjs (10 comprobaciones). Sin correos/cuentas/transacciones reales.
- Verificación de sintaxis del index; no se reescriben sus funciones, solo el contenedor/gancho y assets del seguimiento.
- Las tablas nuevas parten vacías y el trigger solo sigue nuevas selecciones. No se reinscriben proveedores ni se notifican asignaciones históricas.

Desplegar esquema y Edge de consulta; publicar/validar estáticos; después actualizar worker de correo. No ejecutar pruebas con token real ni activar envíos para registros históricos. Verificar huellas de las tablas anteriores y ACL/RLS/despliegues después.

## Reversión
sql/rollback_seguimiento_despacho.sql restaura el tick y cierre de ventana previos y quita el trigger, conservando historial de seguimiento. Revertir también código de página/worker y retirar Edge nueva. No ejecutar sin decidir reversión: desactiva el relevo automático. No borrar las tablas/historial ni reasignar trabajos reales como prueba.

Ajuste adicional: supabase/migrations/20261017151346_axicore_seguimiento_cola_cierre.sql y sql/seguimiento_cola_cierre.sql cierran avisos interrumpidos tras el cuarto intento como Error desde el tick y restringen despacho_cerrar_ventana al servidor/service_role. Total final:72 comprobaciones locales. La reversión conserva la restricción del cierre al servidor.
