-- ============================================================
-- Prácticas 7, 8, 9 y 10: sistema de incidencias + roles
-- Idempotente: se puede ejecutar varias veces.
-- ============================================================

-- Rol del usuario. Se reutiliza la columna existente usuarios.tipo
-- (ya viaja en el JWT) con tres valores: usuario | agente | admin.
UPDATE usuarios SET tipo = 'usuario' WHERE tipo NOT IN ('usuario', 'agente', 'admin');
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_tipo_check;
ALTER TABLE usuarios ADD CONSTRAINT usuarios_tipo_check
    CHECK (tipo IN ('usuario', 'agente', 'admin'));

CREATE TABLE IF NOT EXISTS incidencias (
    id               SERIAL PRIMARY KEY,
    tipo             VARCHAR(40) NOT NULL
        CHECK (tipo IN ('Falla de equipo', 'Acceso perdido', 'Proceso de atención', 'Otro')),
    equipo           VARCHAR(40) NOT NULL
        CHECK (equipo IN ('Teléfono', 'Smartwatch', 'Pantalla TV', 'Pulsera LED', 'Otro')),
    prioridad        VARCHAR(10) NOT NULL CHECK (prioridad IN ('Baja', 'Media', 'Alta')),
    estado           VARCHAR(20) NOT NULL DEFAULT 'Pendiente'
        CHECK (estado IN ('Pendiente', 'En proceso', 'Resuelto')),
    creado_por       INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    agente_asignado  INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
    fecha            TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_incidencias_creado_por ON incidencias(creado_por);
CREATE INDEX IF NOT EXISTS idx_incidencias_estado ON incidencias(estado);
