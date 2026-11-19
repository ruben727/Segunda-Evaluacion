-- ============================================================
-- Buscador difuso (tolerante a errores de escritura)
-- Usa pg_trgm (similitud por trigramas) + unaccent, incluidas en
-- PostgreSQL/Supabase: no requiere Elasticsearch ni otro servicio.
-- Idempotente: se puede ejecutar varias veces.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Normaliza texto para comparar: minúsculas y sin acentos
-- ("Mañana Será" -> "manana sera"). Se declara IMMUTABLE para poder
-- usarla en índices.
CREATE OR REPLACE FUNCTION buscar_normalizar(t text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$ SELECT lower(public.unaccent('public.unaccent'::regdictionary, coalesce(t, ''))) $$;

-- Índices de trigramas: aceleran la búsqueda cuando crezcan las tablas.
CREATE INDEX IF NOT EXISTS idx_buscar_conciertos_artista
    ON conciertos USING gin (buscar_normalizar(artista) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_buscar_conciertos_tour
    ON conciertos USING gin (buscar_normalizar(nombre_tour) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_buscar_canciones_titulo
    ON canciones USING gin (buscar_normalizar(titulo) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_buscar_estadios_nombre
    ON estadios USING gin (buscar_normalizar(nombre) gin_trgm_ops);
