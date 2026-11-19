/* eslint-disable no-console */
/**
 * Prácticas 7-10 — Pruebas de caja negra de incidencias, roles y reglas de
 * acceso contra la API REST (solo HTTP: no lee la BD ni el código).
 *
 * Uso (Node 18+):
 *   ADMIN_CORREO=admin@concertx.app ADMIN_PASSWORD=... \
 *   BASE_URL=http://localhost:3000/api node pruebas/incidencias_seguridad.js
 *
 * Crea dos clientes de prueba (A y B) con correos *@test.com. NO ejecuta
 * "limpiar historial" con el admin para no borrar tickets reales; solo
 * comprueba que un usuario normal NO puede hacerlo.
 */
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000/api';
const { ADMIN_CORREO, ADMIN_PASSWORD } = process.env;
const sufijo = Date.now();
const resultados = [];

async function http(metodo, ruta, { body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}${ruta}`, {
    method: metodo,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch (_) { /* sin cuerpo */ }
  return { status: res.status, data };
}

async function caso(id, descripcion, esperado, ejecutar, verificar) {
  let obtenido;
  let ok = false;
  try {
    const r = await ejecutar();
    ok = verificar(r);
    obtenido = `${r.status} ${JSON.stringify(r.data ?? '').slice(0, 80)}`;
  } catch (err) {
    obtenido = `Excepción: ${err.message}`;
  }
  resultados.push({ id, descripcion, esperado, obtenido, ok });
  console.log(`${ok ? 'PASA ' : 'FALLA'} ${id} ${descripcion}`);
  if (!ok) console.log(`       esperado: ${esperado}\n       obtenido: ${obtenido}`);
}

async function registrar(letra) {
  const r = await http('POST', '/auth/register', {
    body: {
      nombre: `Cliente ${letra}`,
      correo: `cliente.${letra.toLowerCase()}.${sufijo}@test.com`,
      telefono: '5512345678',
      password: 'Segura123',
    },
  });
  return { token: r.data?.token, id: r.data?.user?.id };
}

async function main() {
  console.log(`Pruebas de incidencias/seguridad contra ${BASE_URL}\n`);
  const A = await registrar('A');
  const B = await registrar('B');
  let admin = null;
  if (ADMIN_CORREO && ADMIN_PASSWORD) {
    const r = await http('POST', '/auth/login', { body: { correo: ADMIN_CORREO, password: ADMIN_PASSWORD } });
    admin = r.data?.token;
  }
  const valida = { tipo: 'Falla de equipo', equipo: 'Smartwatch', prioridad: 'Alta' };
  let incA;

  // ---------- Seguridad de autenticación (Práctica 5/10) ----------
  await caso('SEG-01', 'Sin token no se accede a incidencias', '401',
    () => http('GET', '/incidencias/mias'), (r) => r.status === 401);
  await caso('SEG-02', 'Token alterado se rechaza', '401',
    () => http('GET', '/incidencias/mias', { token: `${A.token}x` }), (r) => r.status === 401);
  await caso('SEG-03', 'Login con contraseña de 65 caracteres → mensaje genérico', '401 "Correo o contraseña incorrectos"',
    () => http('POST', '/auth/login', { body: { correo: 'x@test.com', password: `A1${'a'.repeat(63)}` } }),
    (r) => r.status === 401 && r.data?.error === 'Correo o contraseña incorrectos');
  await caso('SEG-04', 'Login con campos de solo espacios', '400',
    () => http('POST', '/auth/login', { body: { correo: '   ', password: '        ' } }), (r) => r.status === 400);

  // ---------- Operaciones / validaciones ----------
  await caso('DB-01', 'Cliente A crea incidencia válida (estado Pendiente)', '201 estado=Pendiente',
    () => http('POST', '/incidencias', { body: valida, token: A.token }),
    (r) => { incA = r.data; return r.status === 201 && r.data?.estado === 'Pendiente'; });
  await caso('DB-02', 'creado_por lo fija el servidor (se ignora el del body)', `creado_por=${A.id}`,
    () => http('POST', '/incidencias', { body: { ...valida, creado_por: B.id, estado: 'Resuelto' }, token: A.token }),
    (r) => r.status === 201 && String(r.data?.creado_por) === String(A.id) && r.data?.estado === 'Pendiente');
  await caso('DB-03', 'Incidencia sin prioridad se rechaza', '400',
    () => http('POST', '/incidencias', { body: { tipo: 'Otro', equipo: 'Otro' }, token: A.token }), (r) => r.status === 400);
  await caso('DB-04', 'Opción fuera de la lista se rechaza (texto libre)', '400',
    () => http('POST', '/incidencias', { body: { ...valida, tipo: 'Mi texto libre' }, token: A.token }), (r) => r.status === 400);
  await caso('DB-05', 'Persistencia: la incidencia aparece en /mias de A', 'id presente',
    () => http('GET', '/incidencias/mias', { token: A.token }),
    (r) => r.status === 200 && r.data.some((i) => i.id === incA?.id));

  // ---------- Reglas de acceso (Prácticas 9/10) ----------
  await caso('SEG-05', 'Cliente B NO ve incidencias de A en /mias', 'lista sin la de A',
    () => http('GET', '/incidencias/mias', { token: B.token }),
    (r) => r.status === 200 && !r.data.some((i) => String(i.creado_por) === String(A.id)));
  await caso('SEG-06', 'Cliente B NO puede leer la incidencia de A por id', '403',
    () => http('GET', `/incidencias/${incA?.id}`, { token: B.token }), (r) => r.status === 403);
  await caso('SEG-07', 'Cliente B NO puede editar la incidencia de A', '403',
    () => http('PATCH', `/incidencias/${incA?.id}`, { body: { prioridad: 'Baja' }, token: B.token }), (r) => r.status === 403);
  await caso('SEG-08', 'Cliente NO puede listar todas las incidencias', '403',
    () => http('GET', '/incidencias', { token: A.token }), (r) => r.status === 403);
  await caso('SEG-09', 'Cliente NO puede cambiar el estado de su propia incidencia', '403',
    () => http('PATCH', `/incidencias/${incA?.id}`, { body: { estado: 'Resuelto' }, token: A.token }), (r) => r.status === 403);
  await caso('SEG-10', 'Cliente NO puede limpiar el historial', '403',
    () => http('DELETE', '/incidencias', { token: A.token }), (r) => r.status === 403);
  await caso('DB-06', 'Dueño sí puede cambiar prioridad de su incidencia pendiente', '200 prioridad=Media',
    () => http('PATCH', `/incidencias/${incA?.id}`, { body: { prioridad: 'Media' }, token: A.token }),
    (r) => r.status === 200 && r.data?.prioridad === 'Media');

  if (admin) {
    await caso('DB-07', 'Admin ve todas las incidencias (incluye la de A)', '200 contiene id',
      () => http('GET', '/incidencias', { token: admin }),
      (r) => r.status === 200 && r.data.some((i) => i.id === incA?.id));
    await caso('DB-08', 'Admin cambia estado a "En proceso" y se persiste', '200 + /mias de A refleja el cambio',
      async () => {
        await http('PATCH', `/incidencias/${incA?.id}`, { body: { estado: 'En proceso' }, token: admin });
        return http('GET', '/incidencias/mias', { token: A.token });
      },
      (r) => r.status === 200 && r.data.find((i) => i.id === incA?.id)?.estado === 'En proceso');
    await caso('DB-09', 'Admin no puede poner un estado fuera de la lista', '400',
      () => http('PATCH', `/incidencias/${incA?.id}`, { body: { estado: 'Cerrado' }, token: admin }), (r) => r.status === 400);
  } else {
    console.log('\n(Omitidos DB-07..DB-09: define ADMIN_CORREO y ADMIN_PASSWORD)');
  }

  const pasan = resultados.filter((r) => r.ok).length;
  console.log(`\n${pasan}/${resultados.length} casos pasan`);
  console.log(`Usuarios de prueba creados: ${A.id}, ${B.id}`);
  if (pasan !== resultados.length) process.exitCode = 1;
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
