/* eslint-disable no-console */
/**
 * Práctica 8 — Pruebas de caja negra automatizadas contra la API REST.
 *
 * Solo usa entradas y salidas HTTP (no lee la BD ni el código interno):
 * para cada caso manda una petición y compara el código de estado y el
 * cuerpo con el resultado esperado del requisito.
 *
 * Uso (Node 18+, sin dependencias extra):
 *   npm run dev                         # en otra terminal, backend local
 *   node pruebas/caja_negra.js          # contra http://localhost:3000/api
 *   BASE_URL=https://.../api node pruebas/caja_negra.js
 *
 * Genera ../Practica8_CajaNegra/resultados_pruebas.md con la tabla de
 * resultados para usarla como evidencia.
 */
const fs = require('fs');
const path = require('path');

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000/api';
const SALIDA = path.join(__dirname, '..', '..', 'Practica8_CajaNegra', 'resultados_pruebas.md');

const resultados = [];
const sufijo = Date.now();

async function http(metodo, ruta, { body, token, raw } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}${ruta}`, {
    method: metodo,
    headers,
    body: raw !== undefined ? raw : body !== undefined ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch (_) {
    // respuesta sin cuerpo JSON
  }
  return { status: res.status, data };
}

/**
 * Ejecuta un caso. `verificar` recibe la respuesta y devuelve true/false.
 */
async function caso(id, requisito, descripcion, entrada, esperado, ejecutar, verificar) {
  let obtenido;
  let ok = false;
  try {
    const res = await ejecutar();
    ok = verificar(res);
    obtenido = `${res.status} ${JSON.stringify(res.data ?? '').slice(0, 90)}`;
  } catch (err) {
    obtenido = `Excepción: ${err.message}`;
  }
  resultados.push({ id, requisito, descripcion, entrada, esperado, obtenido, ok });
  console.log(`${ok ? 'PASA' : 'FALLA'}  ${id} [${requisito}] ${descripcion}`);
  if (!ok) console.log(`       esperado: ${esperado}\n       obtenido: ${obtenido}`);
}

async function main() {
  console.log(`Ejecutando pruebas de caja negra contra ${BASE_URL}\n`);

  const usuarioA = { nombre: 'Prueba A', correo: `prueba.a.${sufijo}@test.com`, telefono: '5512345678', password: 'Segura123' };
  const usuarioB = { nombre: 'Prueba B', correo: `prueba.b.${sufijo}@test.com`, telefono: '5587654321', password: 'Segura123' };
  let tokenA;
  let tokenB;
  let idUsuarioA;
  let idUsuarioB;
  let diseno;

  // ---------- RF-01 / RV-01: Registro ----------
  await caso('CP-01', 'RF-01', 'Registro con datos válidos', JSON.stringify(usuarioA), '201 + token + user sin password_hash',
    () => http('POST', '/auth/register', { body: usuarioA }),
    (r) => {
      tokenA = r.data?.token;
      idUsuarioA = r.data?.user?.id;
      return r.status === 201 && !!tokenA && r.data.user && !('password_hash' in r.data.user);
    });
  await caso('CP-02', 'RV-01', 'Registro sin campos obligatorios', '{correo}', '400',
    () => http('POST', '/auth/register', { body: { correo: 'x@test.com' } }), (r) => r.status === 400);
  await caso('CP-03', 'RV-01', 'Registro con correo mal formado', 'correo="usuario@@mal"', '400 "Correo inválido"',
    () => http('POST', '/auth/register', { body: { ...usuarioB, correo: 'usuario@@mal' } }), (r) => r.status === 400);
  await caso('CP-04', 'RV-01', 'Registro con contraseña débil', 'password="abc123"', '400 (mín. 8, 1 mayúscula, 1 número)',
    () => http('POST', '/auth/register', { body: { ...usuarioB, password: 'abc123' } }), (r) => r.status === 400);
  await caso('CP-05', 'RV-01', 'Registro con teléfono de 5 dígitos', 'telefono="12345"', '400',
    () => http('POST', '/auth/register', { body: { ...usuarioB, telefono: '12345' } }), (r) => r.status === 400);
  await caso('CP-06', 'RP-02', 'Registro con correo ya existente', usuarioA.correo, '409 "Ya existe una cuenta con ese correo"',
    () => http('POST', '/auth/register', { body: usuarioA }), (r) => r.status === 409);
  await caso('CP-07', 'RF-01', 'Registro de segundo usuario (B)', JSON.stringify(usuarioB), '201',
    () => http('POST', '/auth/register', { body: usuarioB }),
    (r) => {
      tokenB = r.data?.token;
      idUsuarioB = r.data?.user?.id;
      return r.status === 201 && !!tokenB;
    });

  // ---------- RF-02: Login ----------
  await caso('CP-08', 'RF-02', 'Login con credenciales correctas', usuarioA.correo, '200 + token',
    () => http('POST', '/auth/login', { body: { correo: usuarioA.correo, password: usuarioA.password } }),
    (r) => r.status === 200 && !!r.data?.token);
  await caso('CP-09', 'RF-02', 'Login con contraseña incorrecta', 'password="Incorrecta1"', '401 mensaje genérico',
    () => http('POST', '/auth/login', { body: { correo: usuarioA.correo, password: 'Incorrecta1' } }),
    (r) => r.status === 401 && r.data?.error === 'Correo o contraseña incorrectos');
  await caso('CP-10', 'RF-02', 'Login con correo no registrado', 'noexiste@test.com', '401 mismo mensaje genérico',
    () => http('POST', '/auth/login', { body: { correo: `noexiste.${sufijo}@test.com`, password: 'Segura123' } }),
    (r) => r.status === 401 && r.data?.error === 'Correo o contraseña incorrectos');
  await caso('CP-11', 'RV-01', 'Login sin contraseña', '{correo}', '400',
    () => http('POST', '/auth/login', { body: { correo: usuarioA.correo } }), (r) => r.status === 400);

  // ---------- RF-05: Consulta de conciertos ----------
  let concierto;
  await caso('CP-12', 'RF-05', 'Listar conciertos', 'GET /conciertos', '200 + arreglo no vacío',
    () => http('GET', '/conciertos'), (r) => r.status === 200 && Array.isArray(r.data) && r.data.length > 0);
  await caso('CP-13', 'RF-05', 'Detalle de concierto con setlist', 'GET /conciertos/1', '200 + canciones[]',
    () => http('GET', '/conciertos/1'),
    (r) => {
      concierto = r.data;
      return r.status === 200 && Array.isArray(r.data?.canciones);
    });
  await caso('CP-14', 'RE-01', 'Detalle de concierto inexistente', 'GET /conciertos/999999', '404 "Concierto no encontrado"',
    () => http('GET', '/conciertos/999999'), (r) => r.status === 404);
  await caso('CP-15', 'RE-01', 'Detalle con id no numérico', 'GET /conciertos/abc', '400 (no 500)',
    () => http('GET', '/conciertos/abc'), (r) => r.status === 400);

  // ---------- RN-02 / RV-02 / RF-03: Crear diseño ----------
  const configuraciones = (concierto?.canciones || []).map((c, i) => ({
    cancion_id: c.id,
    color_hex: ['#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF'][i % 5],
    vibracion: i % 2 === 0,
    intensidad: 80,
  }));
  const nuevoDiseno = { concierto_id: 1, nombre: 'Diseño de prueba caja negra', configuraciones };

  await caso('CP-16', 'RN-02', 'Crear diseño sin token', 'sin Authorization', '401 "Token no proporcionado"',
    () => http('POST', '/disenos', { body: nuevoDiseno }), (r) => r.status === 401);
  await caso('CP-17', 'RN-02', 'Crear diseño con token alterado', 'Bearer abc.def.ghi', '401 "Token inválido o expirado"',
    () => http('POST', '/disenos', { body: nuevoDiseno, token: 'abc.def.ghi' }), (r) => r.status === 401);
  await caso('CP-18', 'RV-02', 'Crear diseño con nombre vacío', 'nombre="   "', '400',
    () => http('POST', '/disenos', { body: { ...nuevoDiseno, nombre: '   ' }, token: tokenA }), (r) => r.status === 400);
  await caso('CP-19', 'RV-02', 'Crear diseño con nombre de 161 caracteres', 'nombre="x"*161', '400',
    () => http('POST', '/disenos', { body: { ...nuevoDiseno, nombre: 'x'.repeat(161) }, token: tokenA }), (r) => r.status === 400);
  await caso('CP-20', 'RV-02', 'Crear diseño para concierto inexistente', 'concierto_id=999999', '400 (no 500)',
    () => http('POST', '/disenos', { body: { ...nuevoDiseno, concierto_id: 999999 }, token: tokenA }), (r) => r.status === 400);
  await caso('CP-21', 'RF-03', 'Crear diseño válido', `concierto 1, ${configuraciones.length} canciones`, '201 + código de 6 caracteres',
    () => http('POST', '/disenos', { body: nuevoDiseno, token: tokenA }),
    (r) => {
      diseno = r.data?.diseno;
      return r.status === 201 && typeof r.data?.codigo === 'string' && r.data.codigo.length === 6;
    });
  await caso('CP-22', 'RF-03', 'Código usa solo caracteres sin ambigüedad', diseno?.codigo ?? '-', '/^[A-HJ-NP-Z2-9]{6}$/ (sin 0, O, 1, I)',
    async () => ({ status: 200, data: diseno?.codigo }), (r) => /^[A-HJ-NP-Z2-9]{6}$/.test(r.data || ''));

  // ---------- RF-04: Consultar / unirse con código ----------
  await caso('CP-23', 'RF-04', 'Consultar diseño por código', `GET /disenos/codigo/${diseno?.codigo}`, '200 + configuraciones en orden',
    () => http('GET', `/disenos/codigo/${diseno?.codigo}`),
    (r) => r.status === 200 && r.data?.configuraciones?.length === configuraciones.length);
  await caso('CP-24', 'RF-04', 'Consultar código en minúsculas', diseno?.codigo?.toLowerCase() ?? '-', '200 (no distingue mayúsculas)',
    () => http('GET', `/disenos/codigo/${diseno?.codigo?.toLowerCase()}`), (r) => r.status === 200);
  await caso('CP-25', 'RV-03', 'Consultar código inexistente', 'ZZZZZZ', '404 "Código de evento no válido"',
    () => http('GET', '/disenos/codigo/ZZZZZZ'), (r) => r.status === 404);
  await caso('CP-26', 'RV-03', 'Unirse sin código', '{zona, fila, asiento}', '400',
    () => http('POST', '/eventos/unirse', { body: { zona: 'A' }, token: tokenB }), (r) => r.status === 400);
  await caso('CP-27', 'RV-03', 'Unirse con código inexistente', 'codigo="ZZZZZZ"', '404',
    () => http('POST', '/eventos/unirse', { body: { codigo: 'ZZZZZZ' }, token: tokenB }), (r) => r.status === 404);
  await caso('CP-28', 'RF-04', 'Usuario B se une con el código', `codigo=${diseno?.codigo}, zona A, fila 3, asiento 12`, '201 success',
    () => http('POST', '/eventos/unirse', { body: { codigo: diseno?.codigo, zona: 'A', fila: '3', asiento: '12' }, token: tokenB }),
    (r) => r.status === 201 && r.data?.success === true);
  await caso('CP-29', 'RP-02', 'Usuario B se une dos veces (cambia asiento)', 'mismo código, asiento 15', '201 y una sola fila en "Mis conciertos" con asiento 15',
    async () => {
      await http('POST', '/eventos/unirse', { body: { codigo: diseno?.codigo, zona: 'A', fila: '3', asiento: '15' }, token: tokenB });
      return http('GET', '/eventos/mios', { token: tokenB });
    },
    (r) => {
      const propios = (r.data || []).filter((e) => e.diseno?.codigo === diseno?.codigo);
      return r.status === 200 && propios.length === 1 && propios[0].asiento === '15';
    });

  // ---------- RP-01: Persistencia / RF-06 Modificar ----------
  await caso('CP-30', 'RP-01', '"Mis diseños" de A contiene el diseño creado', 'GET /disenos/mios (A)', '200 + incluye el código',
    () => http('GET', '/disenos/mios', { token: tokenA }),
    (r) => r.status === 200 && r.data.some((d) => d.codigo === diseno?.codigo));
  await caso('CP-31', 'RN-02', '"Mis diseños" de B no muestra diseños de A', 'GET /disenos/mios (B)', '200 + no incluye el código',
    () => http('GET', '/disenos/mios', { token: tokenB }),
    (r) => r.status === 200 && !r.data.some((d) => d.codigo === diseno?.codigo));
  await caso('CP-32', 'RN-02', 'B intenta renombrar diseño de A', `PUT /disenos/${diseno?.id}`, '403',
    () => http('PUT', `/disenos/${diseno?.id}`, { body: { nombre: 'Hackeado' }, token: tokenB }), (r) => r.status === 403);
  await caso('CP-33', 'RN-02', 'B intenta eliminar diseño de A', `DELETE /disenos/${diseno?.id}`, '403',
    () => http('DELETE', `/disenos/${diseno?.id}`, { token: tokenB }), (r) => r.status === 403);
  await caso('CP-34', 'RV-02', 'A renombra con nombre vacío', 'nombre=""', '400',
    () => http('PUT', `/disenos/${diseno?.id}`, { body: { nombre: '' }, token: tokenA }), (r) => r.status === 400);
  await caso('CP-35', 'RF-06', 'A renombra su diseño', 'nombre="Diseño editado"', '200 y el nuevo nombre se ve en "Mis diseños"',
    async () => {
      await http('PUT', `/disenos/${diseno?.id}`, { body: { nombre: 'Diseño editado' }, token: tokenA });
      return http('GET', '/disenos/mios', { token: tokenA });
    },
    (r) => r.status === 200 && r.data.find((d) => d.codigo === diseno?.codigo)?.nombre === 'Diseño editado');
  await caso('CP-36', 'RP-01', 'Código y colores se conservan tras editar', `GET /disenos/codigo/${diseno?.codigo}`, 'mismo código y mismas configuraciones',
    () => http('GET', `/disenos/codigo/${diseno?.codigo}`),
    (r) => r.status === 200 && r.data?.nombre === 'Diseño editado' && r.data.configuraciones.length === configuraciones.length);

  // ---------- RN-02: otros permisos ----------
  await caso('CP-37', 'RN-02', 'Perfil sin token', 'GET /usuarios/perfil', '401',
    () => http('GET', '/usuarios/perfil'), (r) => r.status === 401);
  await caso('CP-38', 'RN-02', 'Perfil con token no expone password_hash', 'GET /usuarios/perfil (A)', '200 sin password_hash',
    () => http('GET', '/usuarios/perfil', { token: tokenA }),
    (r) => r.status === 200 && r.data?.id === idUsuarioA && !('password_hash' in r.data));
  await caso('CP-39', 'RN-02', 'A consulta datos del reloj de B', `GET /wearable/ultimos/${idUsuarioB}`, '403',
    () => http('GET', `/wearable/ultimos/${idUsuarioB}`, { token: tokenA }), (r) => r.status === 403);

  // ---------- RE-01: Manejo de errores ----------
  await caso('CP-40', 'RE-01', 'Ruta inexistente', 'GET /no-existe', '404 JSON {error}',
    () => http('GET', '/no-existe'), (r) => r.status === 404 && !!r.data?.error);
  await caso('CP-41', 'RE-01', 'JSON mal formado', 'body="{correo:"', '400 (no 500)',
    () => http('POST', '/auth/login', { raw: '{correo:' }), (r) => r.status === 400);
  await caso('CP-42', 'RE-01', 'Editar diseño con id no numérico', 'PUT /disenos/abc', '400 (no 500)',
    () => http('PUT', '/disenos/abc', { body: { nombre: 'X' }, token: tokenA }), (r) => r.status === 400);

  // ---------- RF-06 / RP-01: Eliminar y consistencia ----------
  await caso('CP-43', 'RF-06', 'A elimina su diseño', `DELETE /disenos/${diseno?.id}`, '200 success',
    () => http('DELETE', `/disenos/${diseno?.id}`, { token: tokenA }), (r) => r.status === 200 && r.data?.success === true);
  await caso('CP-44', 'RP-01', 'El código eliminado deja de ser válido', `GET /disenos/codigo/${diseno?.codigo}`, '404',
    () => http('GET', `/disenos/codigo/${diseno?.codigo}`), (r) => r.status === 404);
  await caso('CP-45', 'RP-01', 'Se borra en cascada de "Mis conciertos" de B', 'GET /eventos/mios (B)', '200 sin el código eliminado',
    () => http('GET', '/eventos/mios', { token: tokenB }),
    (r) => r.status === 200 && !r.data.some((e) => e.diseno?.codigo === diseno?.codigo));
  await caso('CP-46', 'RE-01', 'Eliminar un diseño ya eliminado', `DELETE /disenos/${diseno?.id}`, '404',
    () => http('DELETE', `/disenos/${diseno?.id}`, { token: tokenA }), (r) => r.status === 404);

  escribirReporte();
}

function escribirReporte() {
  const pasan = resultados.filter((r) => r.ok).length;
  const esc = (s) => String(s).replace(/\|/g, '\\|').replace(/\n/g, ' ');
  const filas = resultados
    .map((r) => `| ${r.id} | ${r.requisito} | ${esc(r.descripcion)} | ${esc(r.entrada)} | ${esc(r.esperado)} | ${esc(r.obtenido)} | ${r.ok ? 'PASA' : '**FALLA**'} |`)
    .join('\n');

  const md = `# Resultados de pruebas de caja negra — API Concertx

- Fecha de ejecución: ${new Date().toLocaleString('es-MX')}
- URL probada: \`${BASE_URL}\`
- Total: ${resultados.length} casos — **${pasan} pasan**, **${resultados.length - pasan} fallan**

| ID | Requisito | Caso | Entrada | Resultado esperado | Resultado obtenido | Veredicto |
|----|-----------|------|---------|--------------------|--------------------|-----------|
${filas}
`;
  fs.mkdirSync(path.dirname(SALIDA), { recursive: true });
  fs.writeFileSync(SALIDA, md, 'utf8');
  console.log(`\n${pasan}/${resultados.length} casos pasan. Reporte: ${SALIDA}`);
}

main().catch((err) => {
  console.error('No se pudo ejecutar la suite:', err.message);
  console.error('¿Está corriendo el backend? (npm run dev)');
  process.exit(1);
});
