-- Desactiva exclusivamente la regla de sesión única. Conserva auditoría y cola.
-- Ejecutar sólo si Misael autoriza una reversión.
UPDATE private.axi_sesion_config SET habilitada = false WHERE id = true;
NOTIFY pgrst, 'reload config';

