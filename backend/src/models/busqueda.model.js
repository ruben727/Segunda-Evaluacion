const db = require('../config/db');

// Puntaje mínimo (0 a 1) para considerar que un texto "se parece" a la
// consulta. Calibrado con los datos reales: errores típicos ("karl g",
// "bad buny", "azteka") puntúan >= 0.43 y el ruido se queda <= 0.33.
const UMBRAL = 0.4;

/**
 * Todo lo que se puede buscar, en una sola lista: artista, tour, estadio y
 * ciudad (→ concierto) y título de canción (→ canción de un concierto).
 * `texto` es el campo con el que se compara la consulta.
 */
const DOCUMENTOS = `
  SELECT 'concierto' AS tipo, c.id, c.id AS concierto_id, 'artista' AS campo,
         c.artista AS texto, c.artista AS titulo,
         concat_ws(' · ', c.nombre_tour, e.nombre) AS subtitulo, c.fecha_inicio
  FROM conciertos c LEFT JOIN estadios e ON e.id = c.estadio_id
  UNION ALL
  SELECT 'concierto', c.id, c.id, 'tour', c.nombre_tour, c.artista,
         concat_ws(' · ', c.nombre_tour, e.nombre), c.fecha_inicio
  FROM conciertos c LEFT JOIN estadios e ON e.id = c.estadio_id
  WHERE c.nombre_tour IS NOT NULL
  UNION ALL
  SELECT 'concierto', c.id, c.id, 'estadio', e.nombre, c.artista,
         concat_ws(' · ', e.nombre, e.ciudad), c.fecha_inicio
  FROM conciertos c JOIN estadios e ON e.id = c.estadio_id
  UNION ALL
  SELECT 'concierto', c.id, c.id, 'ciudad', e.ciudad, c.artista,
         concat_ws(' · ', e.nombre, e.ciudad), c.fecha_inicio
  FROM conciertos c JOIN estadios e ON e.id = c.estadio_id
  WHERE e.ciudad IS NOT NULL
  UNION ALL
  SELECT 'cancion', ca.id, c.id, 'cancion', ca.titulo, ca.titulo,
         concat('Canción de ', c.artista), c.fecha_inicio
  FROM canciones ca JOIN conciertos c ON c.id = ca.concierto_id`;

/**
 * Búsqueda difusa. Para cada documento calcula:
 *  - word_similarity: qué tanto se parece la consulta a la PARTE más
 *    parecida del texto ("monte" vs "Manny Montes").
 *  - similarity: parecido del texto completo (desempata).
 *  - contiene/prefijo: coincidencia literal, puntaje 1.
 * Se queda con el mejor campo de cada resultado y ordena por puntaje.
 */
async function buscar(consulta, limite) {
  const { rows } = await db.query(
    `WITH q AS (SELECT buscar_normalizar($1) AS t),
     docs AS (${DOCUMENTOS}),
     puntuados AS (
       SELECT d.*,
              CASE
                -- Consultas de 1-2 letras: solo inicio de palabra ("k" → Karol G).
                WHEN length(q.t) < 3 THEN
                  CASE WHEN ' ' || buscar_normalizar(d.texto) LIKE '% ' || q.t || '%' THEN 1.0 ELSE 0 END
                WHEN buscar_normalizar(d.texto) LIKE '%' || q.t || '%' THEN 1.0
                ELSE GREATEST(word_similarity(q.t, buscar_normalizar(d.texto)),
                              similarity(q.t, buscar_normalizar(d.texto)))
              END AS puntaje,
              similarity(q.t, buscar_normalizar(d.texto)) AS parecido
       FROM docs d, q
     ),
     mejores AS (
       SELECT DISTINCT ON (tipo, id) *
       FROM puntuados
       WHERE puntaje >= $2
       ORDER BY tipo, id, puntaje DESC, parecido DESC
     )
     SELECT tipo, id, concierto_id, campo, texto, titulo, subtitulo, fecha_inicio,
            round(puntaje::numeric, 2)::float AS puntaje
     FROM mejores
     ORDER BY puntaje DESC, parecido DESC, (tipo = 'concierto') DESC, fecha_inicio
     LIMIT $3`,
    [consulta, UMBRAL, limite]
  );
  return rows;
}

module.exports = { buscar, UMBRAL };
