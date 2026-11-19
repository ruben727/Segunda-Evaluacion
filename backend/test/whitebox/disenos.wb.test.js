// Práctica 11 — Caja blanca del CRUD de diseños
//   src/routes/disenos.routes.js + src/controllers/disenos.controller.js
//   + middleware/error.js (mapeo de códigos de Postgres)
process.env.JWT_SECRET = require('./helpers').SECRETO;
jest.mock('../../src/config/db', () => ({ query: jest.fn(), pool: { connect: jest.fn() } }));
jest.mock('../../src/models/diseno.model');

const request = require('supertest');
const app = require('../../src/app');
const modelo = require('../../src/models/diseno.model');
const { bearer, pgError } = require('./helpers');

const DUENO = { id: 10 };
const OTRO = { id: 11 };
const como = (u, metodo, ruta) => request(app)[metodo](ruta).set('Authorization', bearer(u));
const disenoBd = { id: 3, usuario_id: DUENO.id, concierto_id: 3, nombre: 'Diseño WB', codigo: 'ABC234' };
const cuerpo = { concierto_id: 3, nombre: '  Diseño WB  ', configuraciones: [{ cancion_id: 10, color_hex: '#EF4444', vibracion: true, intensidad: 80 }] };

beforeEach(() => {
  jest.resetAllMocks();
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

describe('POST /api/disenos (crear)', () => {
  test('WB-DIS-C01 sin token → 401', async () => {
    expect((await request(app).post('/api/disenos').send(cuerpo)).status).toBe(401);
  });
  test.each([
    ['WB-DIS-C02 sin concierto_id', { ...cuerpo, concierto_id: undefined }, 'concierto_id y nombre son obligatorios'],
    ['WB-DIS-C03 sin nombre', { ...cuerpo, nombre: '' }, 'concierto_id y nombre son obligatorios'],
    ['WB-DIS-C04 nombre solo espacios', { ...cuerpo, nombre: '   ' }, 'El nombre del diseño es obligatorio'],
    ['WB-DIS-C05 nombre numérico (typeof≠string)', { ...cuerpo, nombre: 12345 }, 'El nombre del diseño es obligatorio'],
    ['WB-DIS-C06 nombre de 161 caracteres (máx+1)', { ...cuerpo, nombre: 'n'.repeat(161) }, 'El nombre del diseño no puede superar 160 caracteres'],
  ])('%s → 400', async (_n, body, error) => {
    const r = await como(DUENO, 'post', '/api/disenos').send(body);
    expect(r.status).toBe(400);
    expect(r.body).toEqual({ error });
    expect(modelo.crear).not.toHaveBeenCalled();
  });
  test('WB-DIS-C07 nombre de 160 (máx) → 201; nombre recortado; usuario del token', async () => {
    modelo.crear.mockResolvedValue({ ...disenoBd, configuraciones: [] });
    const r = await como(DUENO, 'post', '/api/disenos').send({ ...cuerpo, nombre: 'n'.repeat(160) });
    expect(r.status).toBe(201);
    expect(modelo.crear.mock.calls[0][0]).toMatchObject({ usuarioId: DUENO.id, nombre: 'n'.repeat(160) });
  });
  test('WB-DIS-C08 válido → 201 {diseno, codigo} y trim del nombre', async () => {
    modelo.crear.mockResolvedValue({ ...disenoBd, configuraciones: [] });
    const r = await como(DUENO, 'post', '/api/disenos').send(cuerpo);
    expect(r.status).toBe(201);
    expect(Object.keys(r.body).sort()).toEqual(['codigo', 'diseno']);
    expect(modelo.crear.mock.calls[0][0].nombre).toBe('Diseño WB');
  });
  test('WB-DIS-C09 concierto o canción inexistente (FK 23503) → 400', async () => {
    modelo.crear.mockRejectedValue(pgError('23503'));
    const r = await como(DUENO, 'post', '/api/disenos').send(cuerpo);
    expect(r.status).toBe(400);
    expect(r.body).toEqual({ error: 'El registro relacionado no existe' });
  });
  test('WB-DIS-C10 concierto_id "abc" (22P02) → 400', async () => {
    modelo.crear.mockRejectedValue(pgError('22P02'));
    expect((await como(DUENO, 'post', '/api/disenos').send({ ...cuerpo, concierto_id: 'abc' })).status).toBe(400);
  });
  test('WB-DIS-C11 [SA-04] configuraciones no se validan en el controlador: intensidad 999 llega al modelo', async () => {
    modelo.crear.mockResolvedValue({ ...disenoBd, configuraciones: [] });
    const conf = [{ cancion_id: 10, color_hex: 'no-es-color', intensidad: 999 }];
    const r = await como(DUENO, 'post', '/api/disenos').send({ ...cuerpo, configuraciones: conf });
    expect(r.status).toBe(201);
    expect(modelo.crear.mock.calls[0][0].configuraciones).toEqual(conf);
  });
  test('WB-DIS-C12 [SA-04] color_hex > VARCHAR(7): Postgres 22001 no está mapeado → 500', async () => {
    modelo.crear.mockRejectedValue(pgError('22001', 'value too long for type character varying(7)'));
    const r = await como(DUENO, 'post', '/api/disenos').send(cuerpo);
    expect(r.status).toBe(500);
    expect(r.body).toEqual({ error: 'Error interno del servidor' });
  });
  test('WB-DIS-C13 no se pudo generar código único (Error sin status) → 500', async () => {
    modelo.crear.mockRejectedValue(new Error('No se pudo generar un código único, intenta de nuevo'));
    expect((await como(DUENO, 'post', '/api/disenos').send(cuerpo)).status).toBe(500);
  });
});

describe('GET /api/disenos/codigo/:codigo (pública) y /mios', () => {
  test('WB-DIS-G01 código existente → 200 sin auth', async () => {
    modelo.buscarPorCodigo.mockResolvedValue({ ...disenoBd, configuraciones: [] });
    expect((await request(app).get('/api/disenos/codigo/abc234')).status).toBe(200);
  });
  test('WB-DIS-G02 código inexistente → 404', async () => {
    modelo.buscarPorCodigo.mockResolvedValue(null);
    const r = await request(app).get('/api/disenos/codigo/ZZZZZZ');
    expect(r.status).toBe(404);
    expect(r.body).toEqual({ error: 'Código de evento no válido' });
  });
  test('WB-DIS-G03 excepción → 500', async () => {
    modelo.buscarPorCodigo.mockRejectedValue(new Error('x'));
    expect((await request(app).get('/api/disenos/codigo/ABC234')).status).toBe(500);
  });
  test('WB-DIS-G04 /mios → 200 del usuario; error → 500', async () => {
    modelo.misDisenos.mockResolvedValueOnce([]).mockRejectedValueOnce(new Error('x'));
    expect((await como(DUENO, 'get', '/api/disenos/mios')).status).toBe(200);
    expect(modelo.misDisenos).toHaveBeenCalledWith(DUENO.id);
    expect((await como(DUENO, 'get', '/api/disenos/mios')).status).toBe(500);
  });
});

describe('PUT y DELETE /api/disenos/:id (obtenerPropio)', () => {
  test('WB-DIS-U01 nombre inválido → 400 antes de consultar', async () => {
    const r = await como(DUENO, 'put', '/api/disenos/3').send({ nombre: '' });
    expect(r.status).toBe(400);
    expect(modelo.buscarPorId).not.toHaveBeenCalled();
  });
  test('WB-DIS-U02 inexistente → 404', async () => {
    modelo.buscarPorId.mockResolvedValue(null);
    expect((await como(DUENO, 'put', '/api/disenos/99').send({ nombre: 'X' })).status).toBe(404);
  });
  test('WB-DIS-U03 de otro usuario → 403 (token válido, sin permiso sobre el recurso)', async () => {
    modelo.buscarPorId.mockResolvedValue(disenoBd);
    const r = await como(OTRO, 'put', '/api/disenos/3').send({ nombre: 'Robado' });
    expect(r.status).toBe(403);
    expect(modelo.actualizarNombre).not.toHaveBeenCalled();
  });
  test('WB-DIS-U04 dueño → 200 {diseno}', async () => {
    modelo.buscarPorId.mockResolvedValue(disenoBd);
    modelo.actualizarNombre.mockResolvedValue({ ...disenoBd, nombre: 'Nuevo' });
    const r = await como(DUENO, 'put', '/api/disenos/3').send({ nombre: ' Nuevo ' });
    expect(r.status).toBe(200);
    expect(modelo.actualizarNombre).toHaveBeenCalledWith('3', 'Nuevo');
  });
  test('WB-DIS-U05 PUT con id "abc" → 22P02 → 400', async () => {
    modelo.buscarPorId.mockRejectedValue(pgError('22P02'));
    expect((await como(DUENO, 'put', '/api/disenos/abc').send({ nombre: 'X' })).status).toBe(400);
  });
  test('WB-DIS-D01 DELETE de otro → 403; inexistente → 404', async () => {
    modelo.buscarPorId.mockResolvedValueOnce(disenoBd).mockResolvedValueOnce(null);
    expect((await como(OTRO, 'delete', '/api/disenos/3')).status).toBe(403);
    expect((await como(DUENO, 'delete', '/api/disenos/3')).status).toBe(404);
  });
  test('WB-DIS-D02 DELETE del dueño → 200 {success:true} (la API no usa 204)', async () => {
    modelo.buscarPorId.mockResolvedValue(disenoBd);
    modelo.eliminar.mockResolvedValue(true);
    const r = await como(DUENO, 'delete', '/api/disenos/3');
    expect(r.status).toBe(200);
    expect(r.body).toEqual({ success: true });
  });
  test('WB-DIS-D03 DELETE con excepción → 500', async () => {
    modelo.buscarPorId.mockResolvedValue(disenoBd);
    modelo.eliminar.mockRejectedValue(new Error('x'));
    expect((await como(DUENO, 'delete', '/api/disenos/3')).status).toBe(500);
  });
});

describe('errorHandler: err.status 4xx conserva su mensaje', () => {
  test('WB-ERR-01 error con status 422 lanzado por el modelo → 422 con su mensaje', async () => {
    modelo.buscarPorCodigo.mockRejectedValue(Object.assign(new Error('Validación semántica simulada'), { status: 422 }));
    const r = await request(app).get('/api/disenos/codigo/ABC234');
    expect(r.status).toBe(422);
    expect(r.body).toEqual({ error: 'Validación semántica simulada' });
  });
});
