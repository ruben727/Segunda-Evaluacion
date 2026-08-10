const db = require('../config/db');

async function guardarDato({ usuarioId, diseno_id, ritmo, oxigeno, efecto_color, vibracion }) {
  const { rows } = await db.query(
    `INSERT INTO datos_wearable (usuario_id, diseno_id, ritmo, oxigeno, efecto_color, vibracion)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, usuario_id, diseno_id, ritmo, oxigeno, efecto_color, vibracion, creado_en`,
    [usuarioId, diseno_id || null, ritmo, oxigeno ?? null, efecto_color, !!vibracion]
  );
  return rows[0];
}

async function ultimos(usuarioId, limite = 60) {
  const { rows } = await db.query(
    `SELECT id, usuario_id, diseno_id, ritmo, oxigeno, efecto_color, vibracion, creado_en
     FROM datos_wearable
     WHERE usuario_id = $1
     ORDER BY creado_en DESC
     LIMIT $2`,
    [usuarioId, limite]
  );
  return rows;
}

module.exports = { guardarDato, ultimos };
