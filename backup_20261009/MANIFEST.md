# AXICORE — Respaldo frío del proyecto Supabase
**Fecha:** 2026-10-09 (hora Bolivia) · **Proyecto Supabase:** `qfgyftsnwznsqizriggr` (axicore, región us-east-1, Postgres 17) · **Plan:** free

Este respaldo existe porque en el plan **free** de Supabase **no hay backups automáticos ni point-in-time recovery**, y el esquema completo no estaba versionado en ningún repositorio. Con estos archivos puedes reconstruir el proyecto desde cero en un Supabase nuevo.

## Contenido

| Archivo | Qué es | Cobertura |
|---|---|---|
| `schema_full.sql` | Estructura + lógica completa | 49 tablas, 137 constraints, índices, 89 funciones (public+private), 10 triggers, RLS + 179 políticas |
| `data_business.json` | Datos operativos (lo irreemplazable de Access) | 24 tablas · 432 filas |
| `data_reference.json` | Catálogos y GLP | 11 tablas · 926 filas (incluye geografía RD) |
| `storage_pagos-proveedores.json` | Inventario de comprobantes | 4 archivos (solo rutas; ver nota abajo) |

**Total de filas respaldadas: 1.358.**

## Qué NO está incluido (y por qué)
- **Bytes de los comprobantes del Storage** (4 imágenes, ~512 KB). Solo se respaldan las rutas. Descárgalos desde el panel de Supabase → *Storage → pagos-proveedores*, o desde la app con el botón "Ver comprobante". El bucket es privado por diseño.
- **Usuarios de autenticación** (`auth.users`). Se recrean al dar de alta los accesos; la tabla `public.accesos` sí está respaldada y enlaza cada usuario a su condominio/rol.
- **Logs de auditoría** (`log_actividad` 631, `historial_sesiones` 110, `busqueda_global_snapshot` 73, `log_automatizacion`, `log_comunicaciones`). Son reproducibles/no críticos; se omiten para mantener el respaldo liviano.
- La tabla de prueba `zz_axi_probe2` (vacía, descartable).

## Cómo restaurar (en un proyecto Supabase nuevo)
1. Crear el proyecto nuevo en Supabase.
2. SQL Editor → ejecutar **`schema_full.sql`** completo (crea esquema `private`, tablas, constraints, funciones, triggers y políticas).
3. Cargar los datos. Para cada tabla de `data_business.json` y `data_reference.json`:
   ```sql
   -- ejemplo para la tabla facturas; repetir por cada tabla
   INSERT INTO public.facturas
   SELECT * FROM json_populate_recordset(NULL::public.facturas, '<pegar aquí el array JSON de esa tabla>');
   ```
   (Cargar primero las tablas sin dependencias: condominios → unidades → propietarios/inquilinos → proveedores → facturas → pagos/gastos, etc. Si algún FK se queja, cargar primero la tabla referenciada.)
4. Recrear el bucket privado `pagos-proveedores` y sus 2 políticas (están en `schema_full.sql` si el bucket es tabla gestionada; si no, recrearlo desde *Storage* y volver a subir las imágenes).
5. Dar de alta los usuarios en *Authentication* y confirmar que `accesos.auth_user_id` apunta a los UUID correctos.

> Para una restauración asistida, abrir este respaldo con Claude y pedir "restaura AXICORE desde backup_20261009"; el paso 3 se puede automatizar.

## Recomendación de frecuencia
Regenerar este respaldo **después de cada sesión con cambios de datos** y antes de cualquier migración de esquema. Mientras el proyecto siga en free, además **entrar al panel de Supabase cada pocos días** para que no se pause por inactividad.

## Nota técnica
El volcado se generó con 3 funciones auxiliares en el esquema `private` (`axi_dump`, `axi_dump_schema`, `axi_dump_logic`). Viven en `private` (sin acceso para roles `authenticated`/`anon`, no expuesto por la API) y son de solo lectura; quedan en la base. Pueden eliminarse con `DROP FUNCTION` cuando se desee.
