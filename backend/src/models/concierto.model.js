const db = require('../config/db');

async function listar() {
  const { rows } = await db.query(
    `SELECT c.id, c.artista, c.nombre_tour, c.fecha_inicio, c.imagen_url,
            c.descripcion, c.asistentes_registrados,
            e.id AS estadio_id, e.nombre AS estadio_nombre,
            e.direccion AS estadio_direccion, e.ciudad AS estadio_ciudad
     FROM conciertos c
     LEFT JOIN estadios e ON e.id = c.estadio_id
     ORDER BY c.fecha_inicio ASC`
  );

  return rows.map(mapConcierto);
}

async function buscarPorId(id) {
  const { rows } = await db.query(
    `SELECT c.id, c.artista, c.nombre_tour, c.fecha_inicio, c.imagen_url,
            c.descripcion, c.asistentes_registrados,
            e.id AS estadio_id, e.nombre AS estadio_nombre,
            e.direccion AS estadio_direccion, e.ciudad AS estadio_ciudad
     FROM conciertos c
     LEFT JOIN estadios e ON e.id = c.estadio_id
     WHERE c.id = $1`,
    [id]
  );
  if (!rows[0]) return null;

  const { rows: canciones } = await db.query(
    `SELECT id, numero, titulo, duracion_segundos
     FROM canciones WHERE concierto_id = $1 ORDER BY numero ASC`,
    [id]
  );

  return { ...mapConcierto(rows[0]), canciones };
}

function mapConcierto(row) {
  return {
    id: row.id,
    artista: row.artista,
    nombre_tour: row.nombre_tour,
    fecha_inicio: row.fecha_inicio,
    imagen_url: row.imagen_url,
    descripcion: row.descripcion,
    asistentes_registrados: row.asistentes_registrados,
    estadio: row.estadio_id
      ? {
          id: row.estadio_id,
          nombre: row.estadio_nombre,
          direccion: row.estadio_direccion,
          ciudad: row.estadio_ciudad,
        }
      : null,
  };
}

module.exports = { listar, buscarPorId };
