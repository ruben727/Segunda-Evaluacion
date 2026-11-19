// Práctica 11: ejecuta SQL contra la BD de DATABASE_URL (.env) sin imprimir la
// cadena de conexión. Uso:
//   node pruebas/wb_sql.js "SELECT ..."            (una sentencia)
//   node pruebas/wb_sql.js -f archivo.sql          (varias, separadas por ';' al final de línea)
// Imprime cada sentencia, sus filas (JSON) y el tiempo medido en el cliente.
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const fs = require('fs');
const { Client } = require('pg');

const args = process.argv.slice(2);
const texto = args[0] === '-f' ? fs.readFileSync(args[1], 'utf8') : args.join(' ');
const sentencias = texto
  .split(/;\s*(?:\r?\n|$)/)
  .map((s) => s.replace(/^\s*--.*$/gm, '').trim())
  .filter(Boolean);

(async () => {
  const url = process.env.DATABASE_URL;
  const client = new Client({ connectionString: url, ssl: url.includes('supabase') ? { rejectUnauthorized: false } : false });
  const t0 = process.hrtime.bigint();
  await client.connect();
  console.log(`-- conectado en ${(Number(process.hrtime.bigint() - t0) / 1e6).toFixed(1)} ms (host oculto)`);
  for (const sql of sentencias) {
    console.log(`\n=> ${sql.replace(/\s+/g, ' ')}`);
    const t = process.hrtime.bigint();
    try {
      const r = await client.query(sql);
      const ms = Number(process.hrtime.bigint() - t) / 1e6;
      const res = Array.isArray(r) ? r : [r];
      for (const x of res) {
        if (x.rows && x.rows.length) {
          if (x.rows[0]['QUERY PLAN'] !== undefined) x.rows.forEach((row) => console.log(row['QUERY PLAN']));
          else console.log(JSON.stringify(x.rows, null, 0));
        }
        console.log(`<= ${x.command} filas=${x.rowCount ?? 0}`);
      }
      console.log(`<= tiempo cliente (ida y vuelta): ${ms.toFixed(2)} ms`);
    } catch (e) {
      console.log(`<= ERROR ${e.code || ''}: ${e.message}`);
    }
  }
  await client.end();
})().catch((e) => { console.error('Fallo de conexión:', e.code || e.message); process.exit(1); });
