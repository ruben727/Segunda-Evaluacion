const db = require('../config/db');

// Listas cerradas: el usuario solo elige opciones (no hay texto libre).
// Deben coincidir con los CHECK de migraciones/002_incidencias.sql y con
// lib/core/models/incidencia.dart en la app.
const TIPOS = ['Falla de equipo', 'Acceso perdido', 'Proceso de atención', 'Otro'];
const EQUIPOS = ['Teléfono', 'Smartwatch', 'Pantalla TV', 'Pulsera LED', 'Otro'];
const PRIORIDADES = ['Baja', 'Media', 'Alta'];
const ESTADOS = ['Pendiente', 'En proceso', 'Resuelto'];

// Columnas que se pueden actualizar (lista blanca para armar el UPDATE).
const COLUMNAS_EDITABLES = ['tipo', 'equipo', 'prioridad', 'estado', 'agente_asignado'];

const SELECT_BASE = `
  SELECT i.id, i.tipo, i.equipo, i.prioridad, i.estado,
         i.creado_por, u.nombre AS creado_por_nombre, u.correo AS creado_por_correo,
         i.agente_asignado, a.nombre AS agente_nombre,
         i.fecha, i.actualizado_en
  FROM incidencias i
  JOIN usuarios u ON u.id = i.creado_por
  LEFT JOIN usuarios a ON a.id = i.agente_asignado`;

async function buscarPorId(id) {
  const { rows } = await db.query(`${SELECT_BASE} WHERE i.id = $1`, [id]);
  return rows[0] || null;
}

/**
 * Crea la incidencia en UNA sola sentencia (antes: INSERT + SELECT = 2 viajes a la BD).
 * Con `clave` (Idempotency-Key), un reintento con la misma clave del mismo usuario no inserta
 * otra fila: devuelve la existente (`nueva = false`). Sin clave se comporta como antes.
 */
async function crear({ tipo, equipo, prioridad, creadoPor, clave = null }) {
  const { rows } = await db.query(
    `WITH ins AS (
       INSERT INTO incidencias (tipo, equipo, prioridad, creado_por, clave_idempotencia)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (creado_por, clave_idempotencia) DO NOTHING
       RETURNING *),
     fila AS (
       SELECT *, true AS nueva FROM ins
       UNION ALL
       SELECT *, false FROM incidencias
       WHERE $5::uuid IS NOT NULL AND creado_por = $4 AND clave_idempotencia = $5 AND NOT EXISTS (SELECT 1 FROM ins))
     SELECT i.id, i.tipo, i.equipo, i.prioridad, i.estado,
            i.creado_por, u.nombre AS creado_por_nombre, u.correo AS creado_por_correo,
            i.agente_asignado, a.nombre AS agente_nombre, i.fecha, i.actualizado_en, i.nueva
     FROM fila i JOIN usuarios u ON u.id = i.creado_por LEFT JOIN usuarios a ON a.id = i.agente_asignado`,
    [tipo, equipo, prioridad, creadoPor, clave]
  );
  const { nueva, ...incidencia } = rows[0];
  return { incidencia, nueva };
}

// Paginación: el índice (creado_por, fecha DESC, id DESC) entrega las filas ya ordenadas y el LIMIT
// corta temprano (antes se ordenaban y enviaban TODAS las filas del usuario).
async function listarDeUsuario(usuarioId, limite = 50) {
  const { rows } = await db.query(
    `${SELECT_BASE} WHERE i.creado_por = $1 ORDER BY i.fecha DESC, i.id DESC LIMIT $2`,
    [usuarioId, limite]
  );
  return rows;
}

async function listarTodas(limite = 50) {
  const { rows } = await db.query(`${SELECT_BASE} ORDER BY i.fecha DESC, i.id DESC LIMIT $1`, [limite]);
  return rows;
}

/** Actualiza solo los campos presentes en `cambios` (lista blanca). */
async function actualizar(id, cambios) {
  const columnas = Object.keys(cambios).filter((c) => COLUMNAS_EDITABLES.includes(c));
  if (columnas.length === 0) return buscarPorId(id);
  const sets = columnas.map((c, i) => `${c} = $${i + 2}`);
  await db.query(
    `UPDATE incidencias SET ${sets.join(', ')}, actualizado_en = now() WHERE id = $1`,
    [id, ...columnas.map((c) => cambios[c])]
  );
  return buscarPorId(id);
}

async function eliminarTodas() {
  const { rowCount } = await db.query('DELETE FROM incidencias');
  return rowCount;
}

async function listarAgentes() {
  const { rows } = await db.query(
    `SELECT id, nombre, tipo FROM usuarios WHERE tipo IN ('agente', 'admin') ORDER BY nombre`
  );
  return rows;
}

async function contarPorEstado() {
  const { rows } = await db.query(
    'SELECT estado, COUNT(*)::int AS total FROM incidencias GROUP BY estado'
  );
  const conteo = Object.fromEntries(ESTADOS.map((e) => [e, 0]));
  rows.forEach((r) => { conteo[r.estado] = r.total; });
  return conteo;
}

module.exports = {
  TIPOS, EQUIPOS, PRIORIDADES, ESTADOS,
  crear, buscarPorId, listarDeUsuario, listarTodas, actualizar,
  eliminarTodas, listarAgentes, contarPorEstado,
};
