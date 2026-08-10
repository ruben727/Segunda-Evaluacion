const concierto_model = require('../models/concierto.model');
const disenoModel = require('../models/diseno.model');

async function listar(req, res, next) {
  try {
    const conciertos = await concierto_model.listar();
    res.json(conciertos);
  } catch (err) {
    next(err);
  }
}

async function obtenerPorId(req, res, next) {
  try {
    const concierto = await concierto_model.buscarPorId(req.params.id);
    if (!concierto) {
      return res.status(404).json({ error: 'Concierto no encontrado' });
    }
    res.json(concierto);
  } catch (err) {
    next(err);
  }
}

// Capacidad de referencia para el % de sincronización en las pruebas en
// vivo (pocos asistentes reales, no miles) — así la barra se mueve de
// forma visible cuando alguien más se une, en vez de quedarse en 0%.
const CAPACIDAD_PRUEBA = 20;

// Estado en vivo de un concierto para la Smart TV: datos del concierto,
// el diseño (código) si ya existe, y cuántos asistentes están conectados.
async function estado(req, res, next) {
  try {
    const concierto = await concierto_model.buscarPorId(req.params.id);
    if (!concierto) {
      return res.status(404).json({ error: 'Concierto no encontrado' });
    }

    const diseno = await disenoModel.buscarPorConcierto(req.params.id);
    const conectados = diseno ? await disenoModel.contarConectadosPorDiseno(diseno.id) : 0;

    res.json({
      concierto,
      diseno: diseno ? { id: diseno.id, codigo: diseno.codigo, nombre: diseno.nombre } : null,
      conectados,
      capacidad: CAPACIDAD_PRUEBA,
      porcentaje: Math.min(100, Math.round((conectados / CAPACIDAD_PRUEBA) * 100)),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { listar, obtenerPorId, estado };
