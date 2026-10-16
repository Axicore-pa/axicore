# Inquilinos: excluir mantenimiento de sus finanzas

El portal permitía leer facturas por `inquilino_id` sin comprobar a quién se facturaban ni si correspondían a la cuota de mantenimiento. Las funciones de estado de cuenta repetían esa autorización. La misma regla existía en producción y en la demo.

La migración conserva las ramas de CEO, Asistente, Propietario y Administrador. El inquilino solo accede a facturas aprobadas, expresamente facturadas a Inquilino, vinculadas a su perfil y unidad vigente y ajenas al mantenimiento. Este se identifica por categoría, indicador de cuota o concepto histórico reconocible. Los pagos requieren una factura permitida y coincidencia de unidad y condominio. Se cubren detalle, comprobantes propios, permisos de Storage y RPC de resumen/movimientos; se conserva la prohibición previa de recibos internos a residentes.

No se modifican facturas, pagos, importes, saldos, cargos, cuotas, contactos, cuentas Auth, MFA, asignaciones ni envíos. No se modifica el frontend. El cambio se ejecuta en el servidor y aplica también a navegadores que ya tengan la versión actual del sitio.

## Prueba reproducible

Con las dependencias de `testing/package.json` instaladas:

```text
node testing/tenant-maintenance.cjs
```

Ejecuta 22 comprobaciones con PostgreSQL/PGlite y datos exclusivamente ficticios: reproduce la filtración y los totales anteriores; prueba categorías, bandera y conceptos de mantenimiento; facturas del propietario etiquetadas con inquilino; otros residentes y condominios; detalles y comprobantes/Storage; cargos legítimos de reparación y GLP; resumen y movimientos; rechazo de recibos y de registrar comprobantes de mantenimiento; sesión no vigente; continuidad de propietarios, administradores con MFA, Asistente y CEO; reversión.

Las estructuras de las tablas y definiciones anteriores están en `testing/fixtures/inquilinos-*.json`. Contienen solo metadatos y código, sin datos de producción ni credenciales. No se simula una sesión de un residente real.

## Aplicación y verificación

Aplicada primero en DEMO `jvrjtxckmpcslwjphhew` y después en producción `qfgyftsnwznsqizriggr`, por autorización expresa del usuario de revisar y corregir ambos. Se releyeron las seis funciones y las tres políticas: ambas instalaciones contienen reglas idénticas, RLS sigue habilitada y los helpers privados no son ejecutables por `anon`.

Se compararon antes y después conteos y hashes del contenido íntegro de `facturas`, `pagos`, `detalle_factura` y `comprobantes_pago`: sin cambios en ambos entornos. No se crearon sesiones, cuentas, pagos ni correos de prueba en producción. No se cerró la sesión de demo que tenía el usuario.

La migración comprueba que las tres políticas originales no hayan cambiado antes de sustituirlas y utiliza tiempos de bloqueo/ejecución acotados. Se consultaron los asesores de seguridad; los avisos generales de funciones privilegiadas y configuración de Auth ajenos a este cambio requieren su propia revisión, no se han eliminado permisos para silenciarlos. Referencia: https://supabase.com/docs/guides/database/postgres/row-level-security

## Reversión

`sql/rollback_inquilinos_mantenimiento.sql` restaura las definiciones y políticas previas y elimina solo los dos helpers nuevos. No modifica registros. Restauraría también la visibilidad incorrecta de mantenimiento al inquilino, por lo que no se debe ejecutar salvo decisión explícita de reversión.
