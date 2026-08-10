const db = require('../config/db');

const CAMPOS_PUBLICOS = 'id, nombre, correo, telefono, tipo, created_at';

async function crear({ nombre, correo, telefono, passwordHash }) {
  const { rows } = await db.query(
    `INSERT INTO usuarios (nombre, correo, telefono, password_hash)
     VALUES ($1, $2, $3, $4)
     RETURNING ${CAMPOS_PUBLICOS}`,
    [nombre, correo, telefono, passwordHash]
  );
  return rows[0];
}

async function buscarPorCorreo(correo) {
  const { rows } = await db.query('SELECT * FROM usuarios WHERE correo = $1', [correo]);
  return rows[0] || null;
}

async function buscarPorId(id) {
  const { rows } = await db.query(
    `SELECT ${CAMPOS_PUBLICOS} FROM usuarios WHERE id = $1`,
    [id]
  );
  return rows[0] || null;
}

module.exports = { crear, buscarPorCorreo, buscarPorId };
