const disenoModel = require('../models/diseno.model');

// Mismo límite que la columna disenos.nombre VARCHAR(160).
const NOMBRE_MAX = 160;

function validarNombre(nombre) {
  if (typeof nombre !== 'string' || !nombre.trim()) {
    return 'El nombre del diseño es obligatorio';
  }
  if (nombre.trim().length > NOMBRE_MAX) {
    return `El nombre del diseño no puede superar ${NOMBRE_MAX} caracteres`;
  }
  return null;
}

async function crear(req, res, next) {
  try {
    const { concierto_id, nombre, configuraciones } = req.body;

    if (!concierto_id || !nombre) {
      return res.status(400).json({ error: 'concierto_id y nombre son obligatorios' });
    }
    const errorNombre = validarNombre(nombre);
    if (errorNombre) {
      return res.status(400).json({ error: errorNombre });
    }

    // Cualquier usuario puede crear todos los diseños que quiera para
    // cualquier concierto, aunque ese concierto ya tenga otros diseños.
    const diseno = await disenoModel.crear({
      usuarioId: req.usuario.id,
      concierto_id,
      nombre: nombre.trim(),
      configuraciones,
    });

    res.status(201).json({ diseno, codigo: diseno.codigo });
  } catch (err) {
    next(err);
  }
}

async function misDisenos(req, res, next) {
  try {
    const disenos = await disenoModel.misDisenos(req.usuario.id);
    res.json(disenos);
  } catch (err) {
    next(err);
  }
}

async function obtenerPorCodigo(req, res, next) {
  try {
    const diseno = await disenoModel.buscarPorCodigo(req.params.codigo);
    if (!diseno) {
      return res.status(404).json({ error: 'Código de evento no válido' });
    }
    res.json(diseno);
  } catch (err) {
    next(err);
  }
}

/**
 * Busca el diseño y comprueba que pertenezca al usuario autenticado.
 * Responde 404/403 y devuelve null si no se puede continuar.
 */
async function obtenerPropio(req, res) {
  const diseno = await disenoModel.buscarPorId(req.params.id);
  if (!diseno) {
    res.status(404).json({ error: 'Diseño no encontrado' });
    return null;
  }
  if (String(diseno.usuario_id) !== String(req.usuario.id)) {
    res.status(403).json({ error: 'Solo el creador del diseño puede modificarlo o eliminarlo' });
    return null;
  }
  return diseno;
}

async function actualizar(req, res, next) {
  try {
    const errorNombre = validarNombre(req.body.nombre);
    if (errorNombre) {
      return res.status(400).json({ error: errorNombre });
    }

    if (!(await obtenerPropio(req, res))) return;

    const diseno = await disenoModel.actualizarNombre(req.params.id, req.body.nombre.trim());
    res.json({ diseno });
  } catch (err) {
    next(err);
  }
}

async function eliminar(req, res, next) {
  try {
    if (!(await obtenerPropio(req, res))) return;

    await disenoModel.eliminar(req.params.id);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

module.exports = { crear, obtenerPorCodigo, misDisenos, actualizar, eliminar };
