const db = require('../config/db');

const ROLES_STAFF = ['agente', 'admin'];

/**
 * Carga el rol ACTUAL del usuario desde la BD (no se confía en el campo
 * "tipo" del JWT: podría estar desactualizado si se cambió el rol después
 * del login). Debe ir después de verificarToken. Deja req.rol.
 */
async function cargarRol(req, res, next) {
  try {
    const { rows } = await db.query('SELECT tipo FROM usuarios WHERE id = $1', [req.usuario.id]);
    if (!rows[0]) {
      return res.status(401).json({ error: 'Token inválido o expirado' });
    }
    req.rol = rows[0].tipo;
    next();
  } catch (err) {
    next(err);
  }
}

/** Permite solo los roles indicados; responde 403 al resto. */
function requiereRol(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.rol)) {
      return res.status(403).json({ error: 'No tienes permisos para esta acción' });
    }
    next();
  };
}

const esStaff = (rol) => ROLES_STAFF.includes(rol);

module.exports = { cargarRol, requiereRol, esStaff, ROLES_STAFF };
