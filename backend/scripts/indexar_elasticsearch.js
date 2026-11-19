/* eslint-disable no-console */
/**
 * Crea el índice de Elasticsearch y carga todos los conciertos y canciones
 * desde PostgreSQL. Ejecutar después de configurar ELASTICSEARCH_URL en .env
 * y cada vez que cambien los conciertos:
 *
 *   npm run es:indexar
 */
require('dotenv').config();
const elastic = require('../src/services/elasticsearch.service');
const { pool } = require('../src/config/db');

async function main() {
  if (!elastic.estaConfigurado()) {
    console.error('Falta ELASTICSEARCH_URL en .env');
    process.exitCode = 1;
    return;
  }
  const total = await elastic.reindexar();
  const info = await elastic.estado();
  console.log(`Índice "${info.indice}" listo: ${total} documentos (${info.distribucion} ${info.version}).`);
}

main()
  .catch((err) => {
    console.error('Error al indexar:', err.message, err.detalle ? JSON.stringify(err.detalle).slice(0, 300) : '');
    process.exitCode = 1;
  })
  .finally(() => pool.end());
