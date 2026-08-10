const disenoModel = require('../models/diseno.model');

async function crear(req, res, next) {
  try {
    const { concierto_id, nombre, configuraciones } = req.body;

    if (!concierto_id || !nombre) {
      return res.status(400).json({ error: 'concierto_id y nombre son obligatorios' });
    }

    // Regla de negocio: un solo diseño por concierto.
    const existente = await disenoModel.existeDisenoParaConcierto(concierto_id);
    if (existente) {
      return res.status(409).json({
        error: 'Este concierto ya tiene un diseño creado. Únete con su código en vez de crear otro.',
      });
    }

    const diseno = await disenoModel.crear({
      usuarioId: req.usuario.id,
      concierto_id,
      nombre,
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

module.exports = { crear, obtenerPorCodigo, misDisenos };
