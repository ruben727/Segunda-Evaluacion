const db = require('../config/db');

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function generarCodigo() {
  let codigo = '';
  for (let i = 0; i < 6; i++) {
    codigo += CHARS[Math.floor(Math.random() * CHARS.length)];
  }
  return codigo;
}

async function existeCodigo(codigo) {
  const { rows } = await db.query('SELECT 1 FROM disenos WHERE codigo = $1', [codigo]);
  return rows.length > 0;
}

async function generarCodigoUnico() {
  let codigo = generarCodigo();
  let intentos = 0;
  while (await existeCodigo(codigo)) {
    codigo = generarCodigo();
    intentos += 1;
    if (intentos > 20) throw new Error('No se pudo generar un código único, intenta de nuevo');
  }
  return codigo;
}

/**
 * Regla de negocio: solo se permite un diseño por concierto (el primero
 * que lo crea es el único; el resto de asistentes se une con su código).
 */
async function existeDisenoParaConcierto(concierto_id) {
  const { rows } = await db.query('SELECT id FROM disenos WHERE concierto_id = $1', [concierto_id]);
  return rows[0] || null;
}

/**
 * Crea un diseño junto con sus configuraciones de luces en una transacción.
 * configuraciones: [{ cancion_id, color_hex, vibracion, intensidad }]
 */
async function crear({ usuarioId, concierto_id, nombre, configuraciones }) {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');

    const codigo = await generarCodigoUnico();

    const { rows } = await client.query(
      `INSERT INTO disenos (usuario_id, concierto_id, nombre, codigo)
       VALUES ($1, $2, $3, $4)
       RETURNING id, usuario_id, concierto_id, nombre, codigo, created_at`,
      [usuarioId, concierto_id, nombre, codigo]
    );
    const diseno = rows[0];

    const configuracionesGuardadas = [];
    for (const cfg of configuraciones || []) {
      const { rows: cfgRows } = await client.query(
        `INSERT INTO configuraciones_luces (diseno_id, cancion_id, color_hex, vibracion, intensidad)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, cancion_id, color_hex, vibracion, intensidad`,
        [
          diseno.id,
          cfg.cancion_id,
          cfg.color_hex || '#3B82F6',
          !!cfg.vibracion,
          cfg.intensidad ?? 50,
        ]
      );
      configuracionesGuardadas.push(cfgRows[0]);
    }

    await client.query('COMMIT');
    return { ...diseno, configuraciones: configuracionesGuardadas };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function buscarPorCodigo(codigo) {
  const { rows } = await db.query(
    `SELECT id, usuario_id, concierto_id, nombre, codigo, created_at
     FROM disenos WHERE codigo = $1`,
    [codigo.toUpperCase()]
  );
  if (!rows[0]) return null;

  const { rows: configuraciones } = await db.query(
    `SELECT cl.id, cl.cancion_id, cl.color_hex, cl.vibracion, cl.intensidad,
            c.titulo, c.numero, c.duracion_segundos
     FROM configuraciones_luces cl
     JOIN canciones c ON c.id = cl.cancion_id
     WHERE cl.diseno_id = $1
     ORDER BY c.numero ASC`,
    [rows[0].id]
  );

  return { ...rows[0], configuraciones };
}

async function registrarAsistente({ diseno_id, usuarioId, zona, fila, asiento }) {
  const { rows } = await db.query(
    `INSERT INTO asistentes_evento (diseno_id, usuario_id, zona, fila, asiento, conectado)
     VALUES ($1, $2, $3, $4, $5, true)
     ON CONFLICT (diseno_id, usuario_id)
     DO UPDATE SET zona = EXCLUDED.zona, fila = EXCLUDED.fila, asiento = EXCLUDED.asiento, conectado = true
     RETURNING id, diseno_id, usuario_id, zona, fila, asiento, conectado, fecha_union`,
    [diseno_id, usuarioId, zona, fila, asiento]
  );
  return rows[0];
}

/**
 * Cuenta asistentes actualmente "conectados" (sincronizados) para la
 * tarjeta de "Usuarios conectados" de la Smart TV.
 */
async function contarConectados() {
  const { rows } = await db.query(
    'SELECT COUNT(*)::int AS total FROM asistentes_evento WHERE conectado = true'
  );
  return rows[0].total;
}

async function contarConectadosPorDiseno(diseno_id) {
  const { rows } = await db.query(
    'SELECT COUNT(*)::int AS total FROM asistentes_evento WHERE diseno_id = $1 AND conectado = true',
    [diseno_id]
  );
  return rows[0].total;
}

/** Diseños creados por el usuario ("Mis diseños" en el perfil). */
async function misDisenos(usuarioId) {
  const { rows } = await db.query(
    `SELECT d.id, d.nombre, d.codigo, d.created_at,
            c.id AS concierto_id, c.artista, c.nombre_tour, c.fecha_inicio
     FROM disenos d
     JOIN conciertos c ON c.id = d.concierto_id
     WHERE d.usuario_id = $1
     ORDER BY d.created_at DESC`,
    [usuarioId]
  );
  return rows.map((r) => ({
    id: r.id,
    nombre: r.nombre,
    codigo: r.codigo,
    created_at: r.created_at,
    concierto: {
      id: r.concierto_id,
      artista: r.artista,
      nombre_tour: r.nombre_tour,
      fecha_inicio: r.fecha_inicio,
    },
  }));
}

/** Eventos a los que el usuario se unió con un código ("Mis conciertos"). */
async function misEventos(usuarioId) {
  const { rows } = await db.query(
    `SELECT ae.zona, ae.fila, ae.asiento, ae.fecha_union,
            d.id AS diseno_id, d.codigo, d.nombre AS diseno_nombre,
            c.id AS concierto_id, c.artista, c.nombre_tour, c.fecha_inicio,
            e.nombre AS estadio_nombre, e.ciudad AS estadio_ciudad
     FROM asistentes_evento ae
     JOIN disenos d ON d.id = ae.diseno_id
     JOIN conciertos c ON c.id = d.concierto_id
     LEFT JOIN estadios e ON e.id = c.estadio_id
     WHERE ae.usuario_id = $1
     ORDER BY ae.fecha_union DESC`,
    [usuarioId]
  );
  return rows.map((r) => ({
    zona: r.zona,
    fila: r.fila,
    asiento: r.asiento,
    fecha_union: r.fecha_union,
    diseno: { id: r.diseno_id, codigo: r.codigo, nombre: r.diseno_nombre },
    concierto: {
      id: r.concierto_id,
      artista: r.artista,
      nombre_tour: r.nombre_tour,
      fecha_inicio: r.fecha_inicio,
      estadio: { nombre: r.estadio_nombre, ciudad: r.estadio_ciudad },
    },
  }));
}

/** Diseño (con código) de un concierto específico, si ya existe — usado por la Smart TV. */
async function buscarPorConcierto(concierto_id) {
  const { rows } = await db.query(
    'SELECT id, codigo, nombre, created_at FROM disenos WHERE concierto_id = $1 LIMIT 1',
    [concierto_id]
  );
  return rows[0] || null;
}

module.exports = {
  generarCodigo,
  generarCodigoUnico,
  crear,
  buscarPorCodigo,
  registrarAsistente,
  contarConectados,
  contarConectadosPorDiseno,
  existeDisenoParaConcierto,
  misDisenos,
  misEventos,
  buscarPorConcierto,
};
