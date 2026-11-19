-- Práctica 12 – optimización (idempotente; solo agrega, no modifica filas existentes).
-- 1) Índices que cubren el ORDER BY de los listados de incidencias (evitan el Sort y permiten LIMIT temprano).
CREATE INDEX IF NOT EXISTS idx_incidencias_creador_fecha ON incidencias (creado_por, fecha DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_incidencias_fecha ON incidencias (fecha DESC, id DESC);
-- 2) Idempotencia de escrituras: la misma clave del mismo usuario no puede crear dos filas.
ALTER TABLE incidencias ADD COLUMN IF NOT EXISTS clave_idempotencia uuid;
CREATE UNIQUE INDEX IF NOT EXISTS incidencias_creador_clave_key ON incidencias (creado_por, clave_idempotencia);
