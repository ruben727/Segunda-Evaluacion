/* eslint-disable no-console */
/**
 * Aplica un archivo .sql de esta carpeta contra DATABASE_URL (.env).
 * Uso: node migraciones/aplicar.js 002_incidencias.sql
 */
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/config/db');

async function main() {
  const archivo = process.argv[2];
  if (!archivo) {
    console.error('Uso: node migraciones/aplicar.js <archivo.sql>');
    process.exit(1);
  }
  const sql = fs.readFileSync(path.join(__dirname, archivo), 'utf8');
  await pool.query(sql);
  console.log(`Migración ${archivo} aplicada.`);
}

main()
  .catch((err) => {
    console.error('Error al aplicar la migración:', err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
