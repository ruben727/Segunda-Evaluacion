// Práctica 11 — Caja blanca del CRUD de incidencias
//   src/routes/incidencias.routes.js + middleware/roles.js (cargarRol, requiereRol)
//   + src/controllers/incidencias.controller.js
// db.query se simula para cargarRol (rol leído de la BD) y el modelo se simula.
process.env.JWT_SECRET = require('./helpers').SECRETO;
jest.mock('../../src/config/db', () => ({ query: jest.fn(), pool: { connect: jest.fn() } }));
jest.mock('../../src/models/incidencia.model', () => {
  const real = jest.requireActual('../../src/models/incidencia.model');
  return {
    TIPOS: real.TIPOS, EQUIPOS: real.EQUIPOS, PRIORIDADES: real.PRIORIDADES, ESTADOS: real.ESTADOS,
    crear: jest.fn(), buscarPorId: jest.fn(), listarDeUsuario: jest.fn(), listarTodas: jest.fn(),
    actualizar: jest.fn(), eliminarTodas: jest.fn(), listarAgentes: jest.fn(), contarPorEstado: jest.fn(),
  };
});

const request = require('supertest');
const app = require('../../src/app');
const db = require('../../src/config/db');
const modelo = require('../../src/models/incidencia.model');
const { bearer, pgError } = require('./helpers');

const USUARIO = { id: 10, tipo: 'usuario' };
const OTRO = { id: 11, tipo: 'usuario' };
const AGENTE = { id: 20, tipo: 'agente' };
const ADMIN = { id: 30, tipo: 'admin' };
const valida = { tipo: 'Falla de equipo', equipo: 'Teléfono', prioridad: 'Media' };
const inc = (o = {}) => ({ id: 5, ...valida, estado: 'Pendiente', creado_por: USUARIO.id, agente_asignado: null, ...o });

/** El rol que devuelve la BD en cargarRol (puede diferir del JWT). */
const rolEnBd = (tipo) => db.query.mockResolvedValue({ rows: tipo ? [{ tipo }] : [] });
const como = (u, metodo, ruta) => request(app)[metodo](ruta).set('Authorization', bearer({ id: u.id, tipo: u.tipo }));

beforeEach(() => {
  jest.resetAllMocks();
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

describe('Autenticación (401) vs autorización (403)', () => {
  test('WB-INC-A01 sin token → 401 (no 403)', async () => {
    const r = await request(app).get('/api/incidencias');
    expect(r.status).toBe(401);
  });
  test('WB-INC-A02 token válido de usuario borrado (cargarRol sin filas) → 401', async () => {
    rolEnBd(null);
    const r = await como(USUARIO, 'get', '/api/incidencias/mias');
    expect(r.status).toBe(401);
  });
  test('WB-INC-A03 token válido sin rol staff → 403 en GET / (requiereRol)', async () => {
    rolEnBd('usuario');
    const r = await como(USUARIO, 'get', '/api/incidencias');
    expect(r.status).toBe(403);
    expect(modelo.listarTodas).not.toHaveBeenCalled();
  });
  test('WB-INC-A04 el JWT dice "admin" pero la BD dice "usuario" → 403 (se confía en la BD)', async () => {
    rolEnBd('usuario');
    const r = await request(app).delete('/api/incidencias').set('Authorization', bearer({ id: 10, tipo: 'admin' }));
    expect(r.status).toBe(403);
  });
  test('WB-INC-A05 agente en DELETE / (solo admin) → 403; admin → 200', async () => {
    rolEnBd('agente');
    expect((await como(AGENTE, 'delete', '/api/incidencias')).status).toBe(403);
    rolEnBd('admin');
    modelo.eliminarTodas.mockResolvedValue(3);
    const r = await como(ADMIN, 'delete', '/api/incidencias');
    expect(r.status).toBe(200);
    expect(r.body).toEqual({ eliminadas: 3 });
  });
  test('WB-INC-A06 error de BD al cargar el rol → 500', async () => {
    db.query.mockRejectedValue(new Error('pool agotado'));
    const r = await como(USUARIO, 'get', '/api/incidencias/mias');
    expect(r.status).toBe(500);
    expect(r.body).toEqual({ error: 'Error interno del servidor' });
  });
});

describe('POST /api/incidencias (crear)', () => {
  beforeEach(() => rolEnBd('usuario'));
  test.each([
    ['WB-INC-C01 sin tipo', { ...valida, tipo: undefined }, 'Selecciona tipo'],
    ['WB-INC-C02 tipo vacío', { ...valida, tipo: '' }, 'Selecciona tipo'],
    ['WB-INC-C03 tipo fuera de la lista', { ...valida, tipo: 'Hackeo' }, 'Opción de tipo no válida'],
    ['WB-INC-C04 equipo null', { ...valida, equipo: null }, 'Selecciona equipo'],
    ['WB-INC-C05 prioridad inválida', { ...valida, prioridad: 'Urgente' }, 'Opción de prioridad no válida'],
  ])('%s → 400', async (_n, body, error) => {
    const r = await como(USUARIO, 'post', '/api/incidencias').send(body);
    expect(r.status).toBe(400);
    expect(r.body).toEqual({ error });
  });
  test('WB-INC-C06 válida → 201; creado_por sale del token, se ignora el del body', async () => {
    modelo.crear.mockResolvedValue({ incidencia: inc(), nueva: true });
    const r = await como(USUARIO, 'post', '/api/incidencias').send({ ...valida, creado_por: 999, estado: 'Resuelto' });
    expect(r.status).toBe(201);
    expect(modelo.crear).toHaveBeenCalledWith({ ...valida, creadoPor: USUARIO.id, clave: null });
  });
  test('WB-INC-C08 FK/BD falla al insertar → 500 por next(err)', async () => {
    modelo.crear.mockRejectedValue(new Error('connection terminated'));
    expect((await como(USUARIO, 'post', '/api/incidencias').send(valida)).status).toBe(500);
  });
  test('WB-INC-C07 body vacío (req.body = {}) → 400', async () => {
    const r = await como(USUARIO, 'post', '/api/incidencias');
    expect(r.status).toBe(400);
  });
});

describe('P12 idempotencia y paginación', () => {
  beforeEach(() => rolEnBd('usuario'));
  const CLAVE = '3f1c2b4a-5d6e-4f70-8a9b-0c1d2e3f4a5b';
  test('P12-IDEM-01 Idempotency-Key válida se pasa al modelo; respuesta nueva → 201 sin cabecera de repetición', async () => {
    modelo.crear.mockResolvedValue({ incidencia: inc(), nueva: true });
    const r = await como(USUARIO, 'post', '/api/incidencias').set('Idempotency-Key', CLAVE).send(valida);
    expect(r.status).toBe(201);
    expect(modelo.crear).toHaveBeenCalledWith({ ...valida, creadoPor: USUARIO.id, clave: CLAVE });
    expect(r.headers['idempotent-replayed']).toBeUndefined();
  });
  test('P12-IDEM-02 reintento con la misma clave → 201 con la MISMA fila e Idempotent-Replayed: true', async () => {
    modelo.crear.mockResolvedValue({ incidencia: inc(), nueva: false });
    const r = await como(USUARIO, 'post', '/api/incidencias').set('Idempotency-Key', CLAVE).send(valida);
    expect(r.status).toBe(201);
    expect(r.body.id).toBe(5);
    expect(r.headers['idempotent-replayed']).toBe('true');
  });
  test('P12-IDEM-03 Idempotency-Key que no es UUID → 400 sin tocar la BD', async () => {
    const r = await como(USUARIO, 'post', '/api/incidencias').set('Idempotency-Key', 'abc').send(valida);
    expect(r.status).toBe(400);
    expect(modelo.crear).not.toHaveBeenCalled();
  });
  test.each([['sin parámetro', '', 50], ['limite=10', '?limite=10', 10], ['limite=999 (tope)', '?limite=999', 200], ['limite=abc', '?limite=abc', 50], ['limite=0', '?limite=0', 50]])(
    'P12-PAG %s → listarDeUsuario(id, %s)', async (_n, q, esperado) => {
      modelo.listarDeUsuario.mockResolvedValue([]);
      expect((await como(USUARIO, 'get', `/api/incidencias/mias${q}`)).status).toBe(200);
      expect(modelo.listarDeUsuario).toHaveBeenCalledWith(USUARIO.id, esperado);
    });
});

describe('Listados', () => {
  test('WB-INC-L01 /mias → 200 solo del usuario', async () => {
    rolEnBd('usuario');
    modelo.listarDeUsuario.mockResolvedValue([inc()]);
    const r = await como(USUARIO, 'get', '/api/incidencias/mias');
    expect(r.status).toBe(200);
    expect(modelo.listarDeUsuario).toHaveBeenCalledWith(USUARIO.id, 50);
  });
  test('WB-INC-L02 agente: /, /resumen, /agentes → 200', async () => {
    rolEnBd('agente');
    modelo.listarTodas.mockResolvedValue([]);
    modelo.contarPorEstado.mockResolvedValue({ Pendiente: 0, 'En proceso': 0, Resuelto: 0 });
    modelo.listarAgentes.mockResolvedValue([{ id: 20, nombre: 'Agente', tipo: 'agente' }]);
    for (const ruta of ['/api/incidencias', '/api/incidencias/resumen', '/api/incidencias/agentes']) {
      expect((await como(AGENTE, 'get', ruta)).status).toBe(200);
    }
  });
  test('WB-INC-L03 excepción en el modelo → 500 (las 5 rutas de lectura propagan con next)', async () => {
    rolEnBd('admin');
    for (const [fn, ruta] of [['listarDeUsuario', '/mias'], ['listarTodas', ''], ['contarPorEstado', '/resumen'], ['listarAgentes', '/agentes'], ['eliminarTodas', '']]) {
      modelo[fn].mockRejectedValue(new Error('x'));
      const metodo = fn === 'eliminarTodas' ? 'delete' : 'get';
      expect((await como(ADMIN, metodo, `/api/incidencias${ruta}`)).status).toBe(500);
    }
  });
});

describe('GET /api/incidencias/:id (cargarIncidencia)', () => {
  test('WB-INC-G01 id no numérico → 400 sin consultar', async () => {
    rolEnBd('usuario');
    const r = await como(USUARIO, 'get', '/api/incidencias/abc');
    expect(r.status).toBe(400);
    expect(modelo.buscarPorId).not.toHaveBeenCalled();
  });
  test('WB-INC-G02 inexistente → 404', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockResolvedValue(null);
    expect((await como(USUARIO, 'get', '/api/incidencias/404')).status).toBe(404);
  });
  test('WB-INC-G03 de otro usuario y no staff (propia=F, staff=F) → 403', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockResolvedValue(inc({ creado_por: OTRO.id }));
    expect((await como(USUARIO, 'get', '/api/incidencias/5')).status).toBe(403);
  });
  test('WB-INC-G04 propia (propia=V) → 200', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockResolvedValue(inc());
    expect((await como(USUARIO, 'get', '/api/incidencias/5')).status).toBe(200);
  });
  test('WB-INC-G05 ajena pero staff (propia=F, staff=V) → 200', async () => {
    rolEnBd('agente');
    modelo.buscarPorId.mockResolvedValue(inc());
    expect((await como(AGENTE, 'get', '/api/incidencias/5')).status).toBe(200);
  });
  test('WB-INC-G06 [SA-05] id > INT4 pasa el regex; Postgres lanza 22003 → 500 (no 400/404)', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockRejectedValue(pgError('22003', 'value "99999999999" is out of range for type integer'));
    const r = await como(USUARIO, 'get', '/api/incidencias/99999999999');
    expect(r.status).toBe(500);
  });
});

describe('PATCH /api/incidencias/:id (actualizar)', () => {
  test('WB-INC-U01 dueño intenta cambiar estado → 403', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockResolvedValue(inc());
    expect((await como(USUARIO, 'patch', '/api/incidencias/5').send({ estado: 'Resuelto' })).status).toBe(403);
  });
  test('WB-INC-U02 dueño intenta asignar agente → 403', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockResolvedValue(inc());
    expect((await como(USUARIO, 'patch', '/api/incidencias/5').send({ agente_asignado: 20 })).status).toBe(403);
  });
  test('WB-INC-U03 dueño edita incidencia ya "En proceso" → 409', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockResolvedValue(inc({ estado: 'En proceso' }));
    expect((await como(USUARIO, 'patch', '/api/incidencias/5').send({ prioridad: 'Alta' })).status).toBe(409);
  });
  test('WB-INC-U04 dueño cambia prioridad de su pendiente → 200 y solo se manda ese campo', async () => {
    rolEnBd('usuario');
    modelo.buscarPorId.mockResolvedValue(inc());
    modelo.actualizar.mockResolvedValue(inc({ prioridad: 'Alta' }));
    const r = await como(USUARIO, 'patch', '/api/incidencias/5').send({ prioridad: 'Alta' });
    expect(r.status).toBe(200);
    expect(modelo.actualizar).toHaveBeenCalledWith(5, { prioridad: 'Alta' });
  });
  test('WB-INC-U05 valor fuera de lista (estado "Cerrado") → 400', async () => {
    rolEnBd('agente');
    modelo.buscarPorId.mockResolvedValue(inc());
    expect((await como(AGENTE, 'patch', '/api/incidencias/5').send({ estado: 'Cerrado' })).status).toBe(400);
  });
  test('WB-INC-U06 agente_asignado que no es agente → 400', async () => {
    rolEnBd('agente');
    modelo.buscarPorId.mockResolvedValue(inc());
    modelo.listarAgentes.mockResolvedValue([{ id: 20 }]);
    expect((await como(AGENTE, 'patch', '/api/incidencias/5').send({ agente_asignado: 10 })).status).toBe(400);
  });
  test('WB-INC-U07 agente asigna agente válido (string "20" → Number) y estado → 200', async () => {
    rolEnBd('agente');
    modelo.buscarPorId.mockResolvedValue(inc());
    modelo.listarAgentes.mockResolvedValue([{ id: 20 }]);
    modelo.actualizar.mockResolvedValue(inc({ estado: 'En proceso', agente_asignado: 20 }));
    const r = await como(AGENTE, 'patch', '/api/incidencias/5').send({ estado: 'En proceso', agente_asignado: '20' });
    expect(r.status).toBe(200);
    expect(modelo.actualizar).toHaveBeenCalledWith(5, { estado: 'En proceso', agente_asignado: 20 });
  });
  test('WB-INC-U08 agente quita el agente (null) → 200', async () => {
    rolEnBd('admin');
    modelo.buscarPorId.mockResolvedValue(inc({ agente_asignado: 20 }));
    modelo.actualizar.mockResolvedValue(inc());
    const r = await como(ADMIN, 'patch', '/api/incidencias/5').send({ agente_asignado: null });
    expect(r.status).toBe(200);
    expect(modelo.actualizar).toHaveBeenCalledWith(5, { agente_asignado: null });
  });
  test('WB-INC-U09 body sin campos conocidos → 400 "No hay cambios que guardar"', async () => {
    rolEnBd('agente');
    modelo.buscarPorId.mockResolvedValue(inc());
    const r = await como(AGENTE, 'patch', '/api/incidencias/5').send({ creado_por: 1 });
    expect(r.status).toBe(400);
    expect(r.body).toEqual({ error: 'No hay cambios que guardar' });
  });
  test('WB-INC-U10 PATCH a id inexistente → 404 (cargarIncidencia devuelve null)', async () => {
    rolEnBd('agente');
    modelo.buscarPorId.mockResolvedValue(null);
    expect((await como(AGENTE, 'patch', '/api/incidencias/9').send({ estado: 'Resuelto' })).status).toBe(404);
  });
  test('WB-INC-U11 excepción al actualizar → 500', async () => {
    rolEnBd('agente');
    modelo.buscarPorId.mockResolvedValue(inc());
    modelo.actualizar.mockRejectedValue(new Error('deadlock detected'));
    expect((await como(AGENTE, 'patch', '/api/incidencias/5').send({ estado: 'Resuelto' })).status).toBe(500);
  });
});
