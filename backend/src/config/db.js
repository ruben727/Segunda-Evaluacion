const { Pool } = require('pg');
const env = require('./env');

// Conexión a PostgreSQL (compatible con Supabase Postgres).
const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: env.databaseUrl && env.databaseUrl.includes('supabase')
    ? { rejectUnauthorized: false }
    : false,
});

pool.on('error', (err) => {
  // eslint-disable-next-line no-console
  console.error('[db] Error inesperado en el pool de conexiones', err);
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
