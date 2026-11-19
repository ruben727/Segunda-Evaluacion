/**
 * Buscador con Elasticsearch (API REST con fetch, sin dependencias: sirve
 * para Elasticsearch 8/9, Elastic Cloud y también OpenSearch/Bonsai).
 *
 * Variables de entorno:
 *   ELASTICSEARCH_URL      ej. http://localhost:9200 o https://usuario:clave@xxx.bonsaisearch.net
 *   ELASTICSEARCH_API_KEY  (opcional) API key de Elastic Cloud
 *   ELASTICSEARCH_INDEX    (opcional) nombre del índice, por defecto "concertx"
 *
 * Si ELASTICSEARCH_URL no está definida, estaConfigurado() devuelve false y
 * el controlador usa el respaldo con PostgreSQL (pg_trgm).
 */
const db = require('../config/db');

const INDICE = process.env.ELASTICSEARCH_INDEX || 'concertx';
const TIMEOUT_MS = 3000;

// Campos donde se busca y su peso. El orden también define qué campo se
// reporta como "coincidencia" cuando hay varios.
const CAMPOS = ['artista', 'cancion', 'tour', 'estadio', 'ciudad'];
const PESOS = { artista: 3, cancion: 2, tour: 2, estadio: 1.5, ciudad: 1 };

function configuracion() {
  const crudo = process.env.ELASTICSEARCH_URL;
  if (!crudo) return null;
  const url = new URL(crudo);
  const headers = { 'Content-Type': 'application/json' };
  // fetch no acepta usuario:clave dentro de la URL (formato de Bonsai):
  // se pasan a un header Basic.
  if (url.username) {
    const credenciales = `${decodeURIComponent(url.username)}:${decodeURIComponent(url.password)}`;
    headers.Authorization = `Basic ${Buffer.from(credenciales).toString('base64')}`;
    url.username = '';
    url.password = '';
  }
  if (process.env.ELASTICSEARCH_API_KEY) {
    headers.Authorization = `ApiKey ${process.env.ELASTICSEARCH_API_KEY}`;
  }
  return { base: url.toString().replace(/\/$/, ''), headers };
}

const estaConfigurado = () => configuracion() !== null;

async function es(metodo, ruta, body, { ndjson = false } = {}) {
  const cfg = configuracion();
  if (!cfg) throw new Error('Elasticsearch no está configurado');
  const headers = { ...cfg.headers };
  if (ndjson) headers['Content-Type'] = 'application/x-ndjson';
  const res = await fetch(`${cfg.base}${ruta}`, {
    method: metodo,
    headers,
    body: body === undefined ? undefined : ndjson ? body : JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS * (ndjson ? 5 : 1)),
  });
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const err = new Error(`Elasticsearch respondió ${res.status}`);
    err.detalle = data;
    throw err;
  }
  return data;
}

/** Índice con analizador en español sin acentos y campos de autocompletado. */
const DEFINICION_INDICE = {
  settings: {
    number_of_shards: 1,
    number_of_replicas: 0,
    analysis: {
      analyzer: {
        es_sin_acentos: { type: 'custom', tokenizer: 'standard', filter: ['lowercase', 'asciifolding'] },
      },
    },
  },
  mappings: {
    properties: {
      tipo: { type: 'keyword' },
      id: { type: 'keyword' },
      concierto_id: { type: 'keyword' },
      titulo: { type: 'text', analyzer: 'es_sin_acentos' },
      subtitulo: { type: 'text', index: false },
      fecha_inicio: { type: 'date' },
      // search_as_you_type crea subcampos _2gram/_3gram/_index_prefix para
      // sugerir mientras se escribe ("kar" → Karol G).
      ...Object.fromEntries(CAMPOS.map((c) => [c, { type: 'search_as_you_type', analyzer: 'es_sin_acentos' }])),
    },
  },
};

/** Lee conciertos y canciones de PostgreSQL y arma los documentos. */
async function documentosDesdeBD() {
  const { rows: conciertos } = await db.query(
    `SELECT c.id, c.artista, c.nombre_tour, c.fecha_inicio, e.nombre AS estadio, e.ciudad
     FROM conciertos c LEFT JOIN estadios e ON e.id = c.estadio_id`
  );
  const { rows: canciones } = await db.query(
    `SELECT ca.id, ca.titulo, ca.concierto_id, c.artista, c.fecha_inicio
     FROM canciones ca JOIN conciertos c ON c.id = ca.concierto_id`
  );
  const docs = conciertos.map((c) => ({
    _id: `concierto-${c.id}`,
    tipo: 'concierto',
    id: String(c.id),
    concierto_id: String(c.id),
    artista: c.artista,
    tour: c.nombre_tour,
    estadio: c.estadio,
    ciudad: c.ciudad,
    titulo: c.artista,
    subtitulo: [c.nombre_tour, c.estadio].filter(Boolean).join(' · '),
    fecha_inicio: c.fecha_inicio,
  }));
  canciones.forEach((ca) => docs.push({
    _id: `cancion-${ca.id}`,
    tipo: 'cancion',
    id: String(ca.id),
    concierto_id: String(ca.concierto_id),
    cancion: ca.titulo,
    titulo: ca.titulo,
    subtitulo: `Canción de ${ca.artista}`,
    fecha_inicio: ca.fecha_inicio,
  }));
  return docs;
}

/**
 * Borra y vuelve a crear el índice con todos los conciertos y canciones.
 * Devuelve cuántos documentos se indexaron.
 */
async function reindexar() {
  await es('DELETE', `/${INDICE}`).catch(() => {}); // si no existía, no pasa nada
  await es('PUT', `/${INDICE}`, DEFINICION_INDICE);
  const docs = await documentosDesdeBD();
  const ndjson = docs
    .map(({ _id, ...doc }) => `${JSON.stringify({ index: { _index: INDICE, _id } })}\n${JSON.stringify(doc)}`)
    .join('\n') + '\n';
  const r = await es('POST', '/_bulk?refresh=true', ndjson, { ndjson: true });
  if (r.errors) {
    const primero = r.items.find((i) => i.index?.error)?.index?.error;
    throw new Error(`Errores al indexar: ${primero?.reason || 'desconocido'}`);
  }
  return docs.length;
}

/** Quita acentos y pasa a minúsculas (para saber si hubo coincidencia literal). */
function normalizar(t) {
  return String(t ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
}

/**
 * Busca combinando:
 *  - bool_prefix sobre search_as_you_type → autocompletado ("kar" → Karol G)
 *  - multi_match con fuzziness AUTO       → tolera errores ("bad buny")
 * Devuelve resultados con el mismo formato que el respaldo de PostgreSQL.
 */
async function buscar(consulta, limite) {
  const camposPrefijo = CAMPOS.flatMap((c) => [c, `${c}._2gram`, `${c}._3gram`]);
  const r = await es('POST', `/${INDICE}/_search`, {
    size: limite,
    query: {
      bool: {
        should: [
          {
            multi_match: {
              query: consulta,
              type: 'bool_prefix',
              fields: camposPrefijo,
              boost: 2,
              // Autocompletado: TODAS las palabras deben estar (la última
              // como prefijo). Si no, en "karl g" la "g" sola traería
              // "Gracias a Ti". Los errores de escritura los cubre el fuzzy.
              operator: 'and',
            },
          },
          {
            multi_match: {
              query: consulta,
              fields: CAMPOS.map((c) => `${c}^${PESOS[c]}`),
              fuzziness: 'AUTO',
              prefix_length: 0,
              // La mayoría de las palabras deben coincidir: evita que "de"
              // traiga cualquier canción con "de" en el título.
              minimum_should_match: '75%',
            },
          },
        ],
        minimum_should_match: 1,
      },
    },
    highlight: {
      require_field_match: false,
      pre_tags: [''],
      post_tags: [''],
      fields: Object.fromEntries(CAMPOS.map((c) => [c, {}])),
    },
  });

  const hits = r.hits?.hits || [];
  const maximo = hits[0]?._score || 1;
  const q = normalizar(consulta);

  return hits
    // Descarta coincidencias muy débiles respecto a la mejor (ruido de
    // fuzzy). 25 %: un documento que coincide en dos campos puede puntuar
    // ~3 veces más que uno que coincide en uno solo, y ambos son válidos.
    .filter((h) => h._score >= maximo * 0.25)
    .map((h) => {
      const doc = h._source;
      const resaltados = Object.keys(h.highlight || {});
      const campo = CAMPOS.find((c) => resaltados.includes(c)) || CAMPOS.find((c) => doc[c]) || 'artista';
      const texto = doc[campo] || doc.titulo;
      return {
        tipo: doc.tipo,
        id: Number(doc.id),
        concierto_id: Number(doc.concierto_id),
        campo,
        texto,
        titulo: doc.titulo,
        subtitulo: doc.subtitulo,
        fecha_inicio: doc.fecha_inicio,
        // 1 = coincidencia literal; si no, el puntaje relativo a la mejor.
        puntaje: normalizar(texto).includes(q) ? 1 : Math.round((h._score / maximo) * 0.99 * 100) / 100,
      };
    });
}

/** Estado del clúster, para verificar la conexión. */
async function estado() {
  const info = await es('GET', '/');
  const conteo = await es('GET', `/${INDICE}/_count`).catch(() => ({ count: 0 }));
  return {
    version: info.version?.number,
    distribucion: info.version?.distribution || 'elasticsearch',
    indice: INDICE,
    documentos: conteo.count,
  };
}

module.exports = { estaConfigurado, reindexar, buscar, estado, INDICE };
