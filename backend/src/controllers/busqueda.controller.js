const modelo = require('../models/busqueda.model');
const elastic = require('../services/elasticsearch.service');

const LONGITUD_MAX = 80;
const LIMITE_DEFECTO = 10;
const LIMITE_MAX = 25;

/** Quita acentos y pasa a minúsculas, igual que buscar_normalizar() en la BD. */
function normalizar(t) {
  return String(t).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
}

/**
 * GET /api/buscar?q=texto&limite=10  (pública, igual que /conciertos)
 *
 * Motor principal: Elasticsearch (fuzzy + autocompletado). Si no está
 * configurado o no responde, se usa PostgreSQL con pg_trgm, así la
 * búsqueda nunca se cae.
 *
 * Respuesta:
 * {
 *   consulta: "karl g",
 *   motor: "elasticsearch" | "postgres",
 *   resultados: [{ tipo, id, concierto_id, campo, texto, titulo, subtitulo, puntaje }],
 *   sugerencia: "Karol G" | null   // "¿Quisiste decir…?"
 * }
 */
async function buscar(req, res, next) {
  try {
    const consulta = String(req.query.q ?? '').replace(/\s+/g, ' ').trim().slice(0, LONGITUD_MAX);
    if (!consulta) {
      return res.json({ consulta: '', motor: null, resultados: [], sugerencia: null });
    }

    const pedido = Number.parseInt(req.query.limite, 10);
    const limite = Number.isFinite(pedido) && pedido > 0 ? Math.min(pedido, LIMITE_MAX) : LIMITE_DEFECTO;

    let motor = 'postgres';
    let resultados;
    if (elastic.estaConfigurado()) {
      try {
        resultados = await elastic.buscar(consulta, limite);
        motor = 'elasticsearch';
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn('[buscar] Elasticsearch no disponible, se usa PostgreSQL:', err.message);
      }
    }
    if (!resultados) resultados = await modelo.buscar(consulta, limite);

    // Si el mejor resultado no contiene literalmente lo escrito, se ofrece
    // como corrección ("¿Quisiste decir Karol G?").
    const mejor = resultados[0];
    const sugerencia = mejor && mejor.puntaje < 1 && normalizar(mejor.texto) !== normalizar(consulta)
      ? mejor.texto
      : null;

    res.json({ consulta, motor, resultados, sugerencia });
  } catch (err) {
    next(err);
  }
}

/** GET /api/buscar/estado — qué motor está activo y cuántos documentos hay. */
async function estado(req, res, next) {
  try {
    if (!elastic.estaConfigurado()) {
      return res.json({ motor: 'postgres', elasticsearch: 'no configurado' });
    }
    try {
      res.json({ motor: 'elasticsearch', ...(await elastic.estado()) });
    } catch (err) {
      res.json({ motor: 'postgres', elasticsearch: 'sin conexión' });
    }
  } catch (err) {
    next(err);
  }
}

/** POST /api/buscar/reindexar — vuelve a cargar los datos de PostgreSQL al índice (solo admin). */
async function reindexar(req, res, next) {
  try {
    if (!elastic.estaConfigurado()) {
      return res.status(400).json({ error: 'Elasticsearch no está configurado' });
    }
    const documentos = await elastic.reindexar();
    res.json({ indice: elastic.INDICE, documentos });
  } catch (err) {
    next(err);
  }
}

module.exports = { buscar, estado, reindexar };
