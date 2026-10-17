# BUG: axi-despacho-responder muestra HTML crudo en vez de renderizar

**Fecha:** 2026-10-16  
**Reportado por:** Misael (confirmado 2 veces tras redeploy)  
**Prioridad:** ALTA — bloquea el flujo de respuesta de proveedores  
**Asignar a:** ChatGPT/Codex para resolución

## Descripción

La Edge Function `axi-despacho-responder` (verify_jwt=false) sirve un formulario HTML cuando el proveedor hace clic en el enlace del correo de despacho. El navegador muestra el código fuente HTML como texto plano en lugar de renderizar la página.

## URL de prueba

```
https://qfgyftsnwznsqizriggr.supabase.co/functions/v1/axi-despacho-responder?token=989c5197-9d3d-4228-b198-722a64fd238f
```

## Lo que se intentó (Claude, sin éxito)

1. **Deploy v1** — función `html()` con `Content-Type: text/html; charset=utf-8` → muestra HTML crudo
2. **Redeploy v2** — renombré helper a `htmlRes()`, mismo header explícito → mismo resultado
3. El código tiene `new Response(htmlString, { headers: { "Content-Type": "text/html; charset=utf-8" } })` correcto en ambas versiones

## Código actual del Response (v2)

```typescript
function htmlRes(h: string, s = 200): Response {
  return new Response(h, {
    status: s,
    headers: { ...CORS, "Content-Type": "text/html; charset=utf-8" },
  });
}
```

El GET handler:
```typescript
if (req.method === "GET") {
  const token = url.searchParams.get("token");
  if (!token || token.length < 30) {
    return htmlRes(renderMensaje("Enlace inválido", "...", false), 400);
  }
  return htmlRes(renderForm(token));
}
```

## Evidencia adicional

- El HTML que llega al navegador tiene **encoding roto** (mojibake): `Â¿CuÃ¡ndo` en vez de `¿Cuándo`, `ðŸ•'` en vez de 🕑
- Esto sugiere que aunque el código pone `charset=utf-8`, Supabase Edge Runtime podría estar:
  - Sobreescribiendo el Content-Type a `text/plain`
  - O aplicando doble encoding al body del Response

## Hipótesis a investigar

1. **Supabase Edge Functions podría forzar `text/plain` para funciones con `verify_jwt=false`** — verificar si cambiar a `verify_jwt=true` y pasar anon key como Bearer cambia el comportamiento
2. **El runtime de Deno en Supabase podría no respetar headers custom en `new Response()`** — probar con `Response.json()` vs constructor directo
3. **Podría necesitar `Deno.serve` con handler que retorne headers explícitos** de otra forma
4. **Probar con `TextEncoder`** para forzar el encoding del body:
   ```typescript
   const encoder = new TextEncoder();
   return new Response(encoder.encode(htmlString), {
     headers: { "Content-Type": "text/html; charset=utf-8" }
   });
   ```

## Patrón de referencia que SÍ funciona

La Edge Function `axi-despacho-correo` (verify_jwt=true) retorna JSON sin problemas. El patrón de `axi_circular_tick` (correos de circulares) también funciona, pero retorna JSON, no HTML.

No hay otra Edge Function en AXICORE que sirva HTML directamente — este es el primer caso.

## Contexto del sistema de despacho

- Todo el backend funciona: reporte → trigger → despacho → cron → correo enviado ✓
- El correo llega correctamente al proveedor con el link ✓  
- **Solo falla el paso 5**: proveedor abre el link y ve HTML crudo en vez del formulario
- El formulario tiene 7 opciones de disponibilidad y un botón "Confirmar respuesta"
- POST del formulario llama a RPC `despacho_responder(token, respuesta)`

## Datos de prueba actuales en BD (limpiar después de resolver)

- Reporte: id=40, codigo='RPT-TEST-99999', categoria_id=1 (Plomería)
- Despacho: id=1, mantenimiento_id=40, estado='En espera', ventana_minutos=30
- Respuesta: id=1, despacho_id=1, proveedor_id=12, token='989c5197-...'
- Asignación temporal: proveedor_categorias (proveedor_id=12 → categoria_id=1)


## Cierre — ChatGPT/Codex — 17/10/2026

**Estado: corregido y verificado en producción.**

La causa es una restricción documentada del gateway: bajo el dominio estándar de Supabase, un GET text/html se reescribe como text/plain. Se confirmó en la respuesta pública; el helper de Response y UTF-8 no eran la causa primaria. Fuente: https://supabase.com/docs/guides/functions/limits.

Se conserva el formulario con las siete opciones en https://axicorepard.com/despacho.html. axi-despacho-responder v3 redirige los enlaces antiguos (302, token en fragmento) y mantiene el POST al mismo RPC, sin cambiar verify_jwt=false. No requiere reenviar los correos.

Implementación: https://github.com/Axicore-pa/axicore/pull/8, commit 78d8564272c3f441c682ef7a009e1f9f0fc67757.
Pages: https://github.com/Axicore-pa/axicore/actions/runs/39032838082 (success).
Pruebas: testing/despacho.cjs (18 verificaciones locales), testing/DESPACHO-RESPONDER.md (alcance y reversión).
Navegador público limpio: formulario renderizado con acentos, siete opciones, móvil correcto y cero errores JavaScript. POST real con UUID inexistente devolvió Token inválido.

No se consumió el token de prueba de este informe ni se registraron respuestas, asignaciones o correos de prueba nuevos. Conteos/huellas de las tres tablas y definición del RPC idénticos antes/después. Los registros de prueba indicados arriba se conservaron; su limpieza queda como tarea separada. Ver continuidad compartida AXI-CGPT-023 para detalle y límites.
