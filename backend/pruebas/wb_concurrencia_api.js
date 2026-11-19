// Práctica 11 – DB-06 vía API (localhost): solicitudes paralelas sobre el MISMO registro.
// Usa solo usuarios/registros creados por la prueba. Uso:
//   node pruebas/wb_concurrencia_api.js <run>   (run = la corrida de ejecutar_newman.sh)
const BASE = 'http://localhost:3000/api';
const RUN = process.argv[2];
const P = 'Segura123';
const post = (ruta, body, token, metodo = 'POST') => fetch(BASE + ruta, {
  method: metodo,
  headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  body: JSON.stringify(body),
}).then(async (r) => ({ status: r.status, body: await r.json() }));
const ocultar = (o) => JSON.stringify(o).replace(/(eyJ[A-Za-z0-9_-]{6})[A-Za-z0-9_\-.]+/g, '$1…[oculto]');

(async () => {
  console.log(`# DB-06 concurrencia vía API — ${new Date().toISOString()} — corrida ${RUN}`);
  const login = async (n) => (await post('/auth/login', { correo: `prueba_wb_${RUN}_${n}@test.com`, password: P })).body.token;
  const [tA, tB, tAg] = await Promise.all([login('01'), login('02'), login('ag')]);

  console.log('\n## C1: 2 registros simultáneos con el MISMO correo nuevo');
  const correo = `prueba_wb_${RUN}_par@test.com`;
  const regs = await Promise.all([1, 2].map(() => post('/auth/register', { nombre: 'Prueba WB Par', correo, password: P })));
  regs.forEach((r, i) => console.log(`  solicitud ${i + 1}: HTTP ${r.status} ${ocultar(r.body).slice(0, 120)}`));

  console.log('\n## C2: 2 PATCH simultáneos del agente sobre la MISMA incidencia (estado distinto)');
  const inc = await post('/incidencias', { tipo: 'Otro', equipo: 'Otro', prioridad: 'Baja' }, tA);
  console.log(`  incidencia creada id=${inc.body.id} estado=${inc.body.estado}`);
  const pats = await Promise.all(['En proceso', 'Resuelto'].map((estado) => post(`/incidencias/${inc.body.id}`, { estado }, tAg, 'PATCH')));
  pats.forEach((r, i) => console.log(`  PATCH ${i + 1} (${['En proceso', 'Resuelto'][i]}): HTTP ${r.status} → estado devuelto=${r.body.estado}`));
  const fin = await fetch(`${BASE}/incidencias/${inc.body.id}`, { headers: { Authorization: `Bearer ${tAg}` } }).then((r) => r.json());
  console.log(`  estado final en BD: ${fin.estado} (las dos respuestas fueron 200; la que terminó última gana, sin aviso de conflicto)`);

  console.log('\n## C3: 5 solicitudes simultáneas de B para unirse al MISMO evento (ON CONFLICT)');
  const dis = await post('/disenos', { concierto_id: 3, nombre: 'WB concurrencia', configuraciones: [] }, tA);
  const unir = await Promise.all([1, 2, 3, 4, 5].map((n) => post('/eventos/unirse', { codigo: dis.body.codigo, zona: 'Z', fila: String(n), asiento: String(n) }, tB)));
  console.log(`  códigos: ${unir.map((r) => r.status).join(', ')}`);
  require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
  const { Client } = require('pg');
  const cli = new Client({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
  await cli.connect();
  const { rows } = await cli.query('SELECT count(*)::int AS filas, max(fila) AS fila_final FROM asistentes_evento WHERE diseno_id = $1', [dis.body.diseno.id]);
  await cli.end();
  console.log(`  filas en asistentes_evento para ese diseño: ${rows[0].filas} (fila guardada: ${rows[0].fila_final}) → UNIQUE(diseno_id, usuario_id) + ON CONFLICT evita duplicados`);
  const del = await post(`/disenos/${dis.body.diseno.id}`, {}, tA, 'DELETE');
  console.log(`  diseño de prueba eliminado: HTTP ${del.status}`);
})().catch((e) => { console.error(e); process.exit(1); });
