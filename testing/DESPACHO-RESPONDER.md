# Respuesta pública de proveedores

El gateway de Supabase convierte HTML en text/plain en su dominio estándar (documentación: https://supabase.com/docs/guides/functions/limits). No es un fallo del helper, de UTF-8 ni de verify_jwt.

## Solución

- despacho.html y assets/despacho.{css,js} conservan el formulario y sus siete opciones.
- axi-despacho-responder GET/HEAD redirige 302 a https://axicorepard.com/despacho.html#token=UUID. Los enlaces actuales del worker de correo siguen funcionando.
- POST sigue llamando al RPC existente despacho_responder(uuid,text); sin migraciones ni cambios en reglas, plazos, datos, asignaciones, correo o demo.
- verify_jwt=false se conserva: proveedores autentican la respuesta mediante el token de su enlace y no tienen cuenta de residente. No añadir claves privilegiadas al cliente.
- Valida UUID y siete opciones; CORS para axicorepard.com, JSON, no-store, no-referrer. HTML externo sin dependencias; CSP y mensajes con textContent. El token no se interpola en scripts. Se elimina del enlace al confirmar.
- GET no consume el token ni confirma ninguna respuesta. El RPC conserva los mensajes de token inválido, respuesta ya registrada o despacho cerrado.

## Validación local

Node >=24 y Playwright/Chrome. Ejecutar: node testing/despacho.cjs.
18 comprobaciones aprobadas de API simulada y navegador, selección, siete opciones UTF-8, duplicación de clics, errores, aislamiento de origen, inyección HTML y móvil390px. Servicios simulados, sin login ni envíos reales.

## Publicación y reversión

1. Publicar los tres archivos estáticos en GitHub Pages; comprobar HTTP200 y coincidencia de contenido.
2. Desplegar axi-despacho-responder desde el archivo versionado, verify_jwt=false.
3. Comprobar GET sin seguir redirección y luego navegación completa con UUID inexistente; POST de UUID inexistente debe devolver Token inválido, sin cambios en tablas.
4. Comparar huellas de mantenimientos, mant_despachos y mant_despacho_respuestas y definición del RPC antes/después. No responder usando tokens vigentes de proveedores.

Para revertir sin tocar datos, deshacer este cambio de código y redesplegar la versión anterior de la función (v2 disponible como versión previa en Supabase; copia local de referencia). Eso recupera el fallo de HTML crudo. No ejecutar DROP, borrar despachos ni reenviar correos como parte de la reversión.

No se elimina el reporte de prueba de Claude ni su relación de categoría/proveedor: la corrección no requiere modificar esos registros. Su eventual limpieza es una tarea separada que debe confirmar su alcance antes de borrar datos.
