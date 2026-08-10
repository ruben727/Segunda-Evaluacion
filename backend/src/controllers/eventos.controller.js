const disenoModel = require('../models/diseno.model');

// Capacidad usada solo para calcular el % de sincronización que muestra
// la Smart TV (no es la capacidad real del recinto, es una referencia
// de demo para la barra de progreso).
const CAPACIDAD_DEMO = 4200;

async function unirse(req, res, next) {
  try {
    const { codigo, zona, fila, asiento } = req.body;

    if (!codigo) {
      return res.status(400).json({ error: 'El código del evento es obligatorio' });
    }

    const diseno = await disenoModel.buscarPorCodigo(codigo);
    if (!diseno) {
      return res.status(404).json({ error: 'Código de evento no válido' });
    }

    await disenoModel.registrarAsistente({
      diseno_id: diseno.id,
      usuarioId: req.usuario.id,
      zona,
      fila,
      asiento,
    });

    res.status(201).json({ success: true, diseno });
  } catch (err) {
    next(err);
  }
}

// GET público: usado por la Smart TV para el contador "Usuarios conectados".
async function conectados(req, res, next) {
  try {
    const total = await disenoModel.contarConectados();
    res.json({
      total,
      capacidad: CAPACIDAD_DEMO,
      porcentaje: Math.round((total / CAPACIDAD_DEMO) * 100),
    });
  } catch (err) {
    next(err);
  }
}

// Eventos a los que el usuario autenticado se ha unido ("Mis conciertos").
async function misEventos(req, res, next) {
  try {
    const eventos = await disenoModel.misEventos(req.usuario.id);
    res.json(eventos);
  } catch (err) {
    next(err);
  }
}

module.exports = { unirse, conectados, misEventos };
