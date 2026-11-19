// Práctica 11 – Fase 4: casos de caja blanca de la BD (8 casos × 3 tablas)
// SOLO opera sobre registros creados por este guion (correo prueba_wb_db_<run>_*),
// y al final los elimina. No modifica registros existentes.
// Uso: node pruebas/wb_bd_casos.js
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Client } = require('pg');

const RUN = Date.now().toString().slice(-8);
const url = process.env.DATABASE_URL;
const nuevo = () => new Client({ connectionString: url, ssl: url.includes('supabase') ? { rejectUnauthorized: false } : false });
const ms = (t) => (Number(process.hrtime.bigint() - t) / 1e6).toFixed(2);

let c;
async function q(etiqueta, sql, params = [], cli = c) {
  const t = process.hrtime.bigint();
  try {
    const r = await cli.query(sql, params);
    console.log(`  ${etiqueta}\n    SQL: ${sql.replace(/\s+/g, ' ')}  params=${JSON.stringify(params)}\n    → OK ${r.command} filas=${r.rowCount} (${ms(t)} ms) ${r.rows.length ? JSON.stringify(r.rows) : ''}`);
    return r;
  } catch (e) {
    console.log(`  ${etiqueta}\n    SQL: ${sql.replace(/\s+/g, ' ')}  params=${JSON.stringify(params)}\n    → ERROR ${e.code} (${ms(t)} ms): ${e.message}`);
    return { error: e };
  }
}
const titulo = (s) => console.log(`\n### ${s}`);

(async () => {
  c = nuevo();
  await c.connect();
  console.log(`# Fase 4 – casos de BD. Corrida ${RUN}  ${new Date().toISOString()}  (host oculto)`);
  const correo = `prueba_wb_db_${RUN}_u1@test.com`;
  const hash = '$2a$10$' + 'x'.repeat(53); // hash ficticio (no corresponde a ninguna contraseña)

  // ---------------- TABLA usuarios ----------------
  titulo('TABLA usuarios');
  const u = await q('DB-01 inserción válida', `INSERT INTO usuarios (nombre, correo, telefono, password_hash) VALUES ($1,$2,$3,$4) RETURNING id, nombre, correo, tipo`, ['Prueba WB BD', correo, '5512345678', hash]);
  const uid = u.rows[0].id;
  await q('DB-02a inserción incompleta (sin password_hash → NOT NULL)', `INSERT INTO usuarios (nombre, correo) VALUES ($1,$2)`, ['X', `prueba_wb_db_${RUN}_nn@test.com`]);
  await q('DB-02b correo duplicado (UNIQUE)', `INSERT INTO usuarios (nombre, correo, password_hash) VALUES ($1,$2,$3)`, ['X', correo, hash]);
  await q('DB-02c tipo inválido (CHECK usuarios_tipo_check)', `INSERT INTO usuarios (nombre, correo, password_hash, tipo) VALUES ($1,$2,$3,$4)`, ['X', `prueba_wb_db_${RUN}_ck@test.com`, hash, 'superadmin']);
  const may = await q('DB-02d [SA-01] mismo correo en MAYÚSCULAS (UNIQUE distingue mayúsculas)', `INSERT INTO usuarios (nombre, correo, password_hash) VALUES ($1,$2,$3) RETURNING id`, ['X', correo.toUpperCase(), hash]);
  await q('DB-02e nombre de 121 caracteres (VARCHAR(120))', `INSERT INTO usuarios (nombre, correo, password_hash) VALUES ($1,$2,$3)`, ['n'.repeat(121), `prueba_wb_db_${RUN}_lg@test.com`, hash]);
  await q('DB-03 consulta por id existente (campos públicos, como buscarPorId)', `SELECT id, nombre, correo, telefono, tipo, created_at FROM usuarios WHERE id = $1`, [uid]);
  await q('DB-03b consulta por id inexistente', `SELECT id FROM usuarios WHERE id = $1`, [2147483646]);
  await q('DB-03c consulta por id fuera de rango INT4 (origen de SA-05)', `SELECT id FROM usuarios WHERE id = $1`, ['99999999999']);
  await q('DB-04 actualización', `UPDATE usuarios SET nombre = $2 WHERE id = $1 RETURNING id, nombre`, [uid, 'Prueba WB BD (editado)']);
  await q('DB-07 persistencia tras UPDATE (nueva conexión)', `SELECT nombre FROM usuarios WHERE id = $1`, [uid], await (async () => { const n = nuevo(); await n.connect(); setTimeout(() => n.end(), 3000); return n; })());

  // ---------------- TABLA disenos + configuraciones_luces ----------------
  titulo('TABLA disenos (+ configuraciones_luces)');
  const codigo = `W${RUN.slice(-5)}`.replace(/[01IO]/g, 'Z');
  const d = await q('DB-01 inserción válida', `INSERT INTO disenos (usuario_id, concierto_id, nombre, codigo) VALUES ($1,3,$2,$3) RETURNING id, codigo`, [uid, 'Diseño WB BD', codigo]);
  const did = d.rows[0].id;
  await q('DB-01b configuración de luz válida (canción 6 del concierto 3)', `INSERT INTO configuraciones_luces (diseno_id, cancion_id, color_hex, vibracion, intensidad) VALUES ($1,6,'#EF4444',true,80) RETURNING id`, [did]);
  await q('DB-02a FK concierto inexistente', `INSERT INTO disenos (usuario_id, concierto_id, nombre, codigo) VALUES ($1,999999,'X','ZZZ999')`, [uid]);
  await q('DB-02b código duplicado (UNIQUE codigo)', `INSERT INTO disenos (usuario_id, concierto_id, nombre, codigo) VALUES ($1,3,'X',$2)`, [uid, codigo]);
  await q('DB-02c código de 7 caracteres (VARCHAR(6) → 22001)', `INSERT INTO disenos (usuario_id, concierto_id, nombre, codigo) VALUES ($1,3,'X','ABCDEFG')`, [uid]);
  await q('DB-02d [SA-04] intensidad 999 y color "zzz" se aceptan (no hay CHECK)', `INSERT INTO configuraciones_luces (diseno_id, cancion_id, color_hex, intensidad) VALUES ($1,7,'zzz',999) RETURNING id, color_hex, intensidad`, [did]);
  console.log('\n  DB-02e transacción con fallo parcial (como diseno.model.crear): BEGIN; INSERT diseño; INSERT config con canción inexistente; ROLLBACK');
  await q('    BEGIN', 'BEGIN');
  const dt = await q('    INSERT diseño dentro de la transacción', `INSERT INTO disenos (usuario_id, concierto_id, nombre, codigo) VALUES ($1,3,'WB transaccion','ZTX${RUN.slice(-3).replace(/[01]/g, 'Z')}') RETURNING id`, [uid]);
  await q('    INSERT config con cancion_id 999999 (FK)', `INSERT INTO configuraciones_luces (diseno_id, cancion_id) VALUES ($1, 999999)`, [dt.rows[0].id]);
  await q('    ROLLBACK', 'ROLLBACK');
  await q('    verificación: el diseño de la transacción NO quedó (atomicidad)', `SELECT count(*)::int AS quedaron FROM disenos WHERE id = $1`, [dt.rows[0].id]);
  await q('DB-03 consulta por id existente', `SELECT id, usuario_id, concierto_id, nombre, codigo FROM disenos WHERE id = $1`, [did]);
  await q('DB-03b consulta por código inexistente', `SELECT id FROM disenos WHERE codigo = $1`, ['000000']);
  await q('DB-04 actualización del nombre', `UPDATE disenos SET nombre = $2 WHERE id = $1 RETURNING id, nombre`, [did, 'Diseño WB BD (editado)']);
  await q('DB-05 eliminación (ON DELETE CASCADE en configuraciones_luces)', `DELETE FROM disenos WHERE id = $1`, [did]);
  await q('DB-07 persistencia: diseño y sus configuraciones ya no existen', `SELECT (SELECT count(*) FROM disenos WHERE id = $1)::int AS disenos, (SELECT count(*) FROM configuraciones_luces WHERE diseno_id = $1)::int AS configuraciones`, [did]);

  // ---------------- TABLA incidencias ----------------
  titulo('TABLA incidencias');
  const i = await q('DB-01 inserción válida (estado por defecto)', `INSERT INTO incidencias (tipo, equipo, prioridad, creado_por) VALUES ('Otro','Teléfono','Baja',$1) RETURNING id, estado, fecha`, [uid]);
  const iid = i.rows[0].id;
  await q('DB-02a estado fuera del CHECK', `INSERT INTO incidencias (tipo, equipo, prioridad, estado, creado_por) VALUES ('Otro','Otro','Baja','Cerrado',$1)`, [uid]);
  await q('DB-02b creado_por inexistente (FK)', `INSERT INTO incidencias (tipo, equipo, prioridad, creado_por) VALUES ('Otro','Otro','Baja',2147483646)`);
  await q('DB-02c falta prioridad (NOT NULL)', `INSERT INTO incidencias (tipo, equipo, creado_por) VALUES ('Otro','Otro',$1)`, [uid]);
  await q('DB-03 consulta por id existente (SELECT_BASE de incidencia.model)', `SELECT i.id, i.estado, u.nombre AS creado_por_nombre FROM incidencias i JOIN usuarios u ON u.id = i.creado_por LEFT JOIN usuarios a ON a.id = i.agente_asignado WHERE i.id = $1`, [iid]);
  await q('DB-03b consulta por id inexistente', `SELECT id FROM incidencias WHERE id = $1`, [2147483646]);
  await q('DB-04 actualización (como incidencia.model.actualizar)', `UPDATE incidencias SET estado = $2, actualizado_en = now() WHERE id = $1 RETURNING id, estado, actualizado_en`, [iid, 'En proceso']);
  await q('DB-07 persistencia tras UPDATE', `SELECT estado FROM incidencias WHERE id = $1`, [iid]);

  // ---------------- DB-06 Concurrencia: dos conexiones, mismo registro ----------------
  titulo('DB-06 Concurrencia: dos UPDATE simultáneos sobre la misma incidencia desde dos conexiones');
  const c1 = nuevo(); const c2 = nuevo();
  await Promise.all([c1.connect(), c2.connect()]);
  await q('C1 BEGIN', 'BEGIN', [], c1);
  await q("C1 UPDATE estado='Resuelto' (toma el candado de la fila)", `UPDATE incidencias SET estado = 'Resuelto', actualizado_en = now() WHERE id = $1`, [iid], c1);
  const t2 = process.hrtime.bigint();
  const p2 = q("C2 UPDATE prioridad='Alta' sobre la MISMA fila (queda bloqueado hasta que C1 termine)", `UPDATE incidencias SET prioridad = 'Alta', estado = 'Pendiente', actualizado_en = now() WHERE id = $1 RETURNING estado, prioridad`, [iid], c2)
    .then((r) => { console.log(`    C2 esperó ${ms(t2)} ms en total`); return r; });
  await new Promise((r) => setTimeout(r, 1500));
  console.log('  (C1 mantiene la transacción abierta 1500 ms)');
  await q('C1 COMMIT', 'COMMIT', [], c1);
  await p2;
  await q("Resultado final: gana la última escritura (C2), el 'Resuelto' de C1 se pierde (lost update)", `SELECT estado, prioridad FROM incidencias WHERE id = $1`, [iid]);
  console.log('\n  DB-06b dos conexiones insertan el MISMO correo a la vez (carrera del registro)');
  const correoCarrera = `prueba_wb_db_${RUN}_race@test.com`;
  const [r1, r2] = await Promise.all([
    q('C1 INSERT', `INSERT INTO usuarios (nombre, correo, password_hash) VALUES ('R1',$1,$2) RETURNING id`, [correoCarrera, hash], c1),
    q('C2 INSERT', `INSERT INTO usuarios (nombre, correo, password_hash) VALUES ('R2',$1,$2) RETURNING id`, [correoCarrera, hash], c2),
  ]);
  console.log(`    → éxitos: ${[r1, r2].filter((r) => !r.error).length}, rechazados por UNIQUE: ${[r1, r2].filter((r) => r.error && r.error.code === '23505').length}`);
  await Promise.all([c1.end(), c2.end()]);

  // ---------------- DB-05 eliminación y limpieza ----------------
  titulo('DB-05 eliminación de incidencia y de usuarios de prueba');
  await q('DB-05 eliminación de incidencia por id', `DELETE FROM incidencias WHERE id = $1`, [iid]);
  await q('DB-07 persistencia: la incidencia ya no existe', `SELECT count(*)::int AS quedan FROM incidencias WHERE id = $1`, [iid]);
  await q('DB-05 eliminación de los usuarios de prueba de ESTA corrida (CASCADE a sus datos)', `DELETE FROM usuarios WHERE correo ILIKE $1 RETURNING id, correo`, [`prueba_wb_db_${RUN}_%`]);
  await q('DB-07 persistencia: no queda ningún registro de la corrida', `SELECT count(*)::int AS quedan FROM usuarios WHERE correo ILIKE $1`, [`prueba_wb_db_${RUN}_%`]);
  if (may.rows) console.log(`  (el usuario en mayúsculas id=${may.rows[0].id} también se eliminó por ILIKE)`);
  await c.end();
})().catch((e) => { console.error('Fallo:', e.code || e.message); process.exit(1); });
