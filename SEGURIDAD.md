# Endurecimiento inmediato — 16 de octubre de 2026

## Cambios

- webapp-upload exige JWT, getUser, perfil de servidor, CEO y AAL2 antes de crear el cliente service_role. Solo POST; rechazos sin revelar errores internos. La comprobación anónima real devolvió 401.
- mant-evidencia conserva permiso de carga exclusivo de CEO, tipos image/png e image/jpeg y lectura original; añade límite de 10 MB y extensión png/jpg/jpeg en servidor.
- fn_set_updated_at fija search_path vacío; se verificó que sigue actualizando fechas.
- 483 interpolaciones escalares de plantillas HTML se escapan. Se protegen además errores concatenados, argumentos de rutas en controladores y enlaces de documentos. Se conserva el formato generado intencionadamente por las funciones internas revisadas.
- Política de navegador básica para bloquear objetos incrustados, cambios de base y formularios externos. No es una CSP completa contra scripts: la aplicación todavía utiliza scripts y controladores inline.

## Validación

- security-core.cjs: GET/POST anónimos, token/perfil inválidos, residente, CEO sin MFA y CEO con MFA. No crea cliente privilegiado en casos rechazados. Datos simulados.
- security-sql.cjs: límite acotado al bucket, extensiones válidas/ilegales, rechazo a no CEO, actualización del trigger y reversión en PostgreSQL simulado.
- security-browser.cjs: renderizadores de propietarios, inquilinos, proveedores, usuarios, unidades y portal de inquilinos con etiquetas y atributos maliciosos; conservación literal de texto; cuatro casos de argumentos con comillas, barras y saltos de línea; bloqueo de protocolos activos.
- Regresión: flujo completo de circulares y PDF de dos páginas; entrada, duplicación, recarga, salida y rechazo de sesión con SDK real y servidor simulado. No se enviaron correos ni se alteraron cuentas reales.

## Límites y pendientes

No se modifican asignaciones de roles. Faltan pruebas con cuentas reales y revisión completa de las funciones SECURITY DEFINER. Esta corrección no certifica ausencia total de XSS en toda la aplicación: permanecen renderizadores compuestos y controladores antiguos que necesitan revisión continua. No se cambia la extensión unaccent de esquema sin comprobar sus dependencias. La protección contra contraseñas filtradas y cobertura MFA de cuentas externas quedan pendientes.

El rollback SQL conserva datos y documentos; se mantiene una copia local de la función anterior, sin secretos. Reabrir publicación anónima no es una reversión recomendada. Para el frontal, revertir el commit conserva datos, pero reintroduce las debilidades corregidas.
