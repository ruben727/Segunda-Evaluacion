-- ============================================================
-- Concertx - Esquema de base de datos (PostgreSQL / Supabase)
-- ============================================================
-- Ejecutar completo en una base de datos vacía.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------
-- usuarios
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL,
    correo          VARCHAR(160) NOT NULL UNIQUE,
    telefono        VARCHAR(20),
    password_hash   VARCHAR(255) NOT NULL,
    tipo            VARCHAR(20) NOT NULL DEFAULT 'usuario', -- usuario | admin
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- estadios
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS estadios (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(160) NOT NULL,
    direccion   VARCHAR(255),
    ciudad      VARCHAR(120),
    capacidad   INTEGER
);

-- ---------------------------------------------------------------
-- conciertos
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conciertos (
    id                      SERIAL PRIMARY KEY,
    artista                 VARCHAR(160) NOT NULL,
    nombre_tour             VARCHAR(160),
    estadio_id              INTEGER REFERENCES estadios(id) ON DELETE SET NULL,
    fecha_inicio            TIMESTAMPTZ NOT NULL,
    imagen_url              VARCHAR(500),
    descripcion             TEXT,
    asistentes_registrados  INTEGER NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- canciones (setlist de cada concierto)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS canciones (
    id                  SERIAL PRIMARY KEY,
    concierto_id        INTEGER NOT NULL REFERENCES conciertos(id) ON DELETE CASCADE,
    numero              INTEGER NOT NULL,
    titulo              VARCHAR(200) NOT NULL,
    duracion_segundos   INTEGER NOT NULL DEFAULT 180
);

-- ---------------------------------------------------------------
-- disenos (diseño de efectos de un usuario para un concierto)
-- ---------------------------------------------------------------
-- Solo se permite UN diseño por concierto (restricción de negocio: el
-- primero que crea el diseño de un concierto es el único; el resto de
-- asistentes se une con su código, no crea uno nuevo). Se aplica a nivel
-- de aplicación (ver diseno.model.js -> existeDisenoParaConcierto), no
-- como UNIQUE de base de datos, para no romper instalaciones que ya
-- tengan datos de prueba con duplicados.
CREATE TABLE IF NOT EXISTS disenos (
    id              SERIAL PRIMARY KEY,
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    concierto_id    INTEGER NOT NULL REFERENCES conciertos(id) ON DELETE CASCADE,
    nombre          VARCHAR(160) NOT NULL,
    codigo          VARCHAR(6) NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- configuraciones_luces (efecto por canción dentro de un diseño)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS configuraciones_luces (
    id              SERIAL PRIMARY KEY,
    diseno_id       INTEGER NOT NULL REFERENCES disenos(id) ON DELETE CASCADE,
    cancion_id      INTEGER NOT NULL REFERENCES canciones(id) ON DELETE CASCADE,
    color_hex       VARCHAR(7) NOT NULL DEFAULT '#3B82F6',
    vibracion       BOOLEAN NOT NULL DEFAULT false,
    intensidad      INTEGER NOT NULL DEFAULT 50
);

-- ---------------------------------------------------------------
-- asistentes_evento (usuarios que se unieron con un código)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS asistentes_evento (
    id              SERIAL PRIMARY KEY,
    diseno_id       INTEGER NOT NULL REFERENCES disenos(id) ON DELETE CASCADE,
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    zona            VARCHAR(20),
    fila            VARCHAR(10),
    asiento         VARCHAR(10),
    conectado       BOOLEAN NOT NULL DEFAULT true, -- sincronizado con la TV/luces en este momento
    fecha_union     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (diseno_id, usuario_id)
);

-- ---------------------------------------------------------------
-- datos_wearable (histórico de lecturas BLE enviadas por el reloj)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS datos_wearable (
    id              SERIAL PRIMARY KEY,
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    diseno_id       INTEGER REFERENCES disenos(id) ON DELETE SET NULL,
    ritmo           INTEGER NOT NULL,
    oxigeno         INTEGER, -- % de saturación de oxígeno (SpO2), simulado
    efecto_color    VARCHAR(7) NOT NULL,
    vibracion       BOOLEAN NOT NULL DEFAULT false,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conciertos_fecha ON conciertos (fecha_inicio);
CREATE INDEX IF NOT EXISTS idx_canciones_concierto ON canciones (concierto_id);
CREATE INDEX IF NOT EXISTS idx_disenos_codigo ON disenos (codigo);
CREATE INDEX IF NOT EXISTS idx_config_luces_diseno ON configuraciones_luces (diseno_id);
CREATE INDEX IF NOT EXISTS idx_wearable_usuario ON datos_wearable (usuario_id, creado_en DESC);

-- ---------------------------------------------------------------
-- Datos de ejemplo (opcional, útil para desarrollo)
-- ---------------------------------------------------------------
INSERT INTO estadios (nombre, direccion, ciudad, capacidad) VALUES
    ('Estadio Azteca', 'Calz. de Tlalpan 3465, Sta. Úrsula Coapa', 'Ciudad de México', 87000),
    ('Foro Sol', 'Av. Viaducto Río de la Piedad, Granjas México', 'Ciudad de México', 65000),
    ('Arena Ciudad de México', 'Av. Presidente Juárez 1, Azcapotzalco', 'Ciudad de México', 22300)
ON CONFLICT DO NOTHING;

INSERT INTO conciertos (artista, nombre_tour, estadio_id, fecha_inicio, imagen_url, descripcion, asistentes_registrados) VALUES
    ('Bad Bunny', 'Most Wanted Tour', 1, '2025-07-12 20:00:00-06', '', 'El fenómeno urbano regresa a México.', 3240),
    ('Karol G', 'Mañana Será Bonito Tour', 2, '2025-09-05 20:30:00-06', '', 'Una noche llena de reggaetón y color.', 1875),
    ('Evan Craft', 'Otro Nivel Tour', 3, '2026-12-05 20:00:00-06', '', 'Concierto de prueba fijo para la Smart TV.', 0)
ON CONFLICT DO NOTHING;

INSERT INTO canciones (concierto_id, numero, titulo, duracion_segundos) VALUES
    (1, 1, 'Monaco', 165),
    (1, 2, 'Titi Me Preguntó', 240),
    (1, 3, 'Callaita', 220),
    (1, 4, 'Diles', 210),
    (1, 5, 'La Santa', 195)
ON CONFLICT DO NOTHING;

-- Setlist de Evan Craft — usado en las pruebas fijas de la Smart TV.
INSERT INTO canciones (concierto_id, numero, titulo, duracion_segundos) VALUES
    (3, 1, 'Otro Nivel', 180),
    (3, 2, 'Nadie Como Tú', 195),
    (3, 3, 'Nada Es Imposible', 210),
    (3, 4, 'Un Buen Día', 200)
ON CONFLICT DO NOTHING;
