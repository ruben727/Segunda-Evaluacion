// Práctica 11 – Fase 4: EXPLAIN ANALYZE de consultas reales de la app y comparación
// BD directa vs. misma operación vía API local.
// Uso: node pruebas/wb_explain_vs_api.js <run>   (usuarios de prueba de ejecutar_newman.sh)
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Client } = require('pg');
const RUN = process.argv[2];
const API = 'http://localhost:3000/api';
const N_EXPLAIN = 5, N = 10;
const st = (a) => { const s = [...a].sort((x, y) => x - y); const m = a.reduce((x, y) => x + y, 0) / a.length; return { prom: m, min: s[0], max: s[s.length - 1] }; };
const f = (x) => x.toFixed(2);
const ahora = () => Number(process.hrtime.bigint()) / 1e6;

(async () => {
  const c = new Client({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
  await c.connect();
  const http = (ruta, opt = {}) => fetch(API + ruta, opt).then(async (r) => ({ status: r.status, bytes: (await r.arrayBuffer()).byteLength }));
  const json = (body, token) => ({ method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
  const login = (n) => fetch(`${API}/auth/login`, json({ correo: `prueba_wb_${RUN}_${n}@test.com`, password: 'Segura123' })).then((r) => r.json());
  const A = await login('01');
  const AG = await login('ag');
  const dis = await fetch(`${API}/disenos`, json({ concierto_id: 3, nombre: 'WB explain', configuraciones: [6, 7, 8, 9].map((id) => ({ cancion_id: id, color_hex: '#3B82F6', intensidad: 50 })) }, A.token)).then((r) => r.json());
  const uid = A.user.id, did = dis.diseno.id, cod = dis.codigo;
  console.log(`# EXPLAIN ANALYZE vs API — ${new Date().toISOString()} — usuario de prueba id=${uid}, diseño de prueba id=${did}`);

  const casos = [
    { id: 'Q1', nombre: 'login: usuario.model.buscarPorCorreo', sql: `SELECT * FROM usuarios WHERE correo = $1`, p: [A.user.correo],
      api: () => http('/auth/login', json({ correo: A.user.correo, password: 'Segura123' })), apiDesc: 'POST /api/auth/login (incluye bcrypt.compare)' },
    { id: 'Q2', nombre: 'concierto.model.listar', sql: `SELECT c.id, c.artista, c.nombre_tour, c.fecha_inicio, c.imagen_url, c.descripcion, c.asistentes_registrados, e.id AS estadio_id, e.nombre AS estadio_nombre, e.direccion AS estadio_direccion, e.ciudad AS estadio_ciudad FROM conciertos c LEFT JOIN estadios e ON e.id = c.estadio_id ORDER BY c.fecha_inicio ASC`, p: [],
      api: () => http('/conciertos'), apiDesc: 'GET /api/conciertos' },
    { id: 'Q3', nombre: 'diseno.model.misDisenos (subconsulta array_agg)', sql: `SELECT d.id, d.nombre, d.codigo, d.created_at, c.id AS concierto_id, c.artista, c.nombre_tour, c.fecha_inicio, e.nombre AS estadio_nombre, e.ciudad AS estadio_ciudad, COALESCE((SELECT array_agg(cl.color_hex ORDER BY ca.numero) FROM configuraciones_luces cl JOIN canciones ca ON ca.id = cl.cancion_id WHERE cl.diseno_id = d.id), '{}') AS colores FROM disenos d JOIN conciertos c ON c.id = d.concierto_id LEFT JOIN estadios e ON e.id = c.estadio_id WHERE d.usuario_id = $1 ORDER BY d.created_at DESC`, p: [uid],
      api: () => http('/disenos/mios', { headers: { Authorization: `Bearer ${A.token}` } }), apiDesc: 'GET /api/disenos/mios' },
    { id: 'Q4', nombre: 'diseno.model.buscarPorCodigo (2.ª consulta: configuraciones + canciones)', sql: `SELECT cl.id, cl.cancion_id, cl.color_hex, cl.vibracion, cl.intensidad, c.titulo, c.numero, c.duracion_segundos FROM configuraciones_luces cl JOIN canciones c ON c.id = cl.cancion_id WHERE cl.diseno_id = $1 ORDER BY c.numero ASC`, p: [did],
      api: () => http(`/disenos/codigo/${cod}`), apiDesc: 'GET /api/disenos/codigo/:codigo (2 consultas)' },
    { id: 'Q5', nombre: 'incidencia.model.listarTodas (SELECT_BASE, 2 JOIN)', sql: `SELECT i.id, i.tipo, i.equipo, i.prioridad, i.estado, i.creado_por, u.nombre AS creado_por_nombre, u.correo AS creado_por_correo, i.agente_asignado, a.nombre AS agente_nombre, i.fecha, i.actualizado_en FROM incidencias i JOIN usuarios u ON u.id = i.creado_por LEFT JOIN usuarios a ON a.id = i.agente_asignado ORDER BY i.fecha DESC`, p: [],
      api: () => http('/incidencias', { headers: { Authorization: `Bearer ${AG.token}` } }), apiDesc: 'GET /api/incidencias (agente; + cargarRol)' },
  ];

  const resumen = [];
  for (const k of casos) {
    console.log(`\n================ ${k.id} ${k.nombre}\nSQL: ${k.sql}\nparams: ${JSON.stringify(k.p)}`);
    const ej = [], pl = [];
    for (let i = 0; i < N_EXPLAIN; i++) {
      const { rows } = await c.query(`EXPLAIN (ANALYZE, BUFFERS) ${k.sql}`, k.p);
      const plan = rows.map((r) => r['QUERY PLAN']);
      if (i === 0) console.log(plan.join('\n'));
      pl.push(parseFloat(plan.find((l) => l.startsWith('Planning Time')).split(':')[1]));
      ej.push(parseFloat(plan.find((l) => l.startsWith('Execution Time')).split(':')[1]));
    }
    const rt = [];
    for (let i = 0; i < N; i++) { const t = ahora(); await c.query(k.sql, k.p); rt.push(ahora() - t); }
    const ap = [], codigos = new Set(); let bytes = 0;
    for (let i = 0; i < N; i++) { const t = ahora(); const r = await k.api(); ap.push(ahora() - t); codigos.add(r.status); bytes = r.bytes; }
    const e = st(ej), p = st(pl), r = st(rt), a = st(ap);
    console.log(`Execution Time ×${N_EXPLAIN} (ms): ${ej.map(f).join(', ')} → prom ${f(e.prom)}`);
    console.log(`Planning Time ×${N_EXPLAIN} (ms): ${pl.map(f).join(', ')} → prom ${f(p.prom)}`);
    console.log(`Ida y vuelta cliente→BD ×${N} (ms): ${rt.map(f).join(', ')} → prom ${f(r.prom)} min ${f(r.min)} max ${f(r.max)}`);
    console.log(`API ${k.apiDesc} ×${N} (ms): ${ap.map(f).join(', ')} → prom ${f(a.prom)} min ${f(a.min)} max ${f(a.max)}  códigos ${[...codigos]}  ${bytes} bytes`);
    resumen.push([k.id, k.nombre, f(e.prom), f(p.prom), f(r.prom), f(a.prom), [...codigos].join('/'), bytes]);
  }
  console.log('\n## RESUMEN (ms, promedios)');
  console.log('ID | consulta | ejecución en BD | planificación | ida y vuelta cliente→BD | vía API local | HTTP | bytes');
  resumen.forEach((r) => console.log(r.join(' | ')));
  const del = await fetch(`${API}/disenos/${did}`, { method: 'DELETE', headers: { Authorization: `Bearer ${A.token}` } });
  console.log(`\n(diseño de prueba id=${did} eliminado: HTTP ${del.status})`);
  await c.end();
})().catch((e) => { console.error(e); process.exit(1); });
