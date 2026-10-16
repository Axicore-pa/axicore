# Respaldo diario cifrado en Google Drive

Estado al 16/10/2026: proceso preparado; NO activado, sin primer respaldo integral ni simulacro de restauración del sistema. Cifrado y descifrado probados con archivos vacíos, texto, binarios de más de 2 MB, alteraciones y clave incorrecta. No se guardaron credenciales en el repositorio.

Destino confirmado: carpeta privada de axispard@gmail.com:
https://drive.google.com/drive/folders/1jMkR2PPQkpDlFVhqbTE1F6MjdvE1At_N
Al crearla, el único permiso observado era el propietario. Drive no equivale a un depósito inmutable y la misma cuenta de correo puede borrarlo; se necesita además una copia offline o bajo otra cuenta para cubrir ese riesgo.

## Antes de activar

El acceso de esta conversación a Drive NO aporta credenciales duraderas a GitHub Actions. Configurar estas cuatro credenciales en Settings → Secrets and variables → Actions del repositorio, nunca en el chat ni en archivos de código:

| Nombre del secreto | Contenido |
|---|---|
| AXICORE_DATABASE_URL | Conexión de Supabase con usuario y contraseña, preferentemente Session pooler; cliente PostgreSQL 17 compatible |
| AXICORE_SUPABASE_SERVICE_KEY | Clave legacy service_role para copiar objetos privados; tratar como credencial administrativa |
| AXICORE_MANAGEMENT_TOKEN | Token limitado al proyecto con lectura de funciones, configuración Auth e inventario de secretos |
| AXICORE_RCLONE_CONFIG | Configuración de rclone con remoto llamado axicore, tipo drive, autorizado para la carpeta; contiene token de refresco y sus datos OAuth |

Preparar el remoto con `rclone config` en un equipo de confianza. No reutilizar ni extraer tokens internos del conector de esta conversación. Elegir alcance de Drive mínimo compatible y mantener privada la carpeta. El proceso no borra ni mueve archivos existentes.

La clave privada de recuperación se entrega por archivo local separado. Guardar dos copias offline; no subirla al repositorio, a los secretos del ejecutor ni a la carpeta de respaldos. La clave pública recovery-public.pem puede publicarse. Perder la privada hace irrecuperables los paquetes cifrados con ella.

Solo después de custodiar la clave y configurar los cuatro secretos, crear la variable AXICORE_BACKUPS_ENABLED=true. Ejecutar manualmente el flujo y comprobar su éxito antes de depender de él. La tarea programada queda propuesta a las 02:17 de America/La_Paz, equivalente a 06:17 UTC. GitHub puede retrasar o no ejecutar tareas programadas; comprobar cada día que hay una copia reciente y mantener alertas operativas independientes. La variable todavía no se configuró en este trabajo.

## Qué hace el proceso

1. Valida configuración y herramientas antes de extraer datos.
2. Obtiene un inventario de buckets/objetos y genera un pg_dump completo con snapshot transaccional, formato custom, esquema, datos, ACL y RLS. Conserva roles sin contraseñas y exporta cron por separado.
3. Descarga todos los objetos con manifestación de ruta, tamaño y SHA256. Si el inventario cambia durante el proceso, falla en vez de declarar una copia consistente.
4. Descarga cuerpos y metadatos de todas las funciones y configuración Auth, inventario de nombres/digests de secretos, código Git y su historial.
5. Genera manifiesto con hashes, versión y fecha. Comprime y cifra con AES-256-GCM; protege su clave con RSA-OAEP-SHA256. El ejecutor solo necesita la clave pública.
6. Sube el archivo .axibak a Drive y relee sus bytes cifrados para comparar el hash. Solo entonces declara subida verificada. No publica datos ni artefactos sin cifrar en GitHub.

El servidor usa conexión PostgreSQL cifrada con sslmode=require; antes de activación definitiva evaluar verificación completa con el certificado del proyecto. Ejecutar en una ventana sin despliegues ni cambios de configuración; el dump es coherente internamente, pero inventarios de proveedores son capturas separadas. La comparación inicial/final de archivos reduce el riesgo de desalineación y no sustituye un simulacro.

El proceso usa un directorio temporal privado y lo elimina al terminar. En ejecutores efímeros, el entorno completo se destruye al acabar. No ejecutar en equipos compartidos sin protección.

## Qué falta para una recuperación integral

- Los valores de los secretos de Edge Functions no se recuperan del inventario de nombres/digests. Mantener un sobre cifrado independiente con los valores vigentes necesarios, material criptográfico de Vault si se usa, cuentas de recuperación y procedimiento de rotación. No extraer secretos del entorno de producción para imprimirlos.
- DNS, registrador, configuración GitHub Pages y cualquier Google Form/Apps Script ajeno al repositorio requieren inventario y recuperación propia. No están incluidos automáticamente por copiar PostgreSQL.
- Un dump completo contiene objetos de esquemas administrados de Supabase. No aplicarlo a ciegas encima de un proyecto activo: la selección de objetos, los roles administrados, Auth, Storage, extensiones, cron y claves criptográficas deben resolverse en el simulacro.
- Los cuerpos de funciones se conservan con su Content-Type original; verificar su extracción y redeploy en el primer simulacro.
- La retención automática todavía NO está implementada. Todas las copias se conservan; vigilar cuota y establecer eliminación aprobada después de validar recuperabilidad. No conceder al ejecutor acceso a eliminar copias offline.
- El flujo no envía emails ni genera alertas independientes. Configurar notificaciones de fallos de GitHub y un control diario de ausencia de copias. El botón de activación no sustituye esta vigilancia.

## Descargar y recuperar

Descargar el .axibak desde Drive. En un equipo aislado y de confianza:

```text
python backup/secure_archive.py decrypt copia.axibak recuperacion.tar.gz --key clave-privada.pem
```

El resultado solo se entrega si la autenticación criptográfica es correcta. No sobrescribe un archivo existente. Extraer el tar únicamente después de verificar su procedencia; no ejecutar automáticamente su contenido.

Para el simulacro: crear un destino aislado, deshabilitar cron/correos/webhooks antes de restaurar datos, analizar el listado de pg_restore, restaurar esquema/datos seleccionados y permisos con el procedimiento Supabase, recuperar objetos con sus rutas originales, reconstruir funciones/configuración, introducir o rotar secretos por canales seguros y validar saldos, documentos y accesos. Medir pérdida máxima y tiempo de recuperación antes de anunciar el respaldo como operativo.

Referencias oficiales:
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- https://supabase.com/docs/reference/api/v1-get-a-function-body
- https://rclone.org/drive/
