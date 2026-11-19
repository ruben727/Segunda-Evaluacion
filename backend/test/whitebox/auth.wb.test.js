// Práctica 11 — Caja blanca del endpoint de autenticación
//   POST /api/auth/register y POST /api/auth/login (src/controllers/auth.controller.js)
//   + middleware/auth.js (verificarToken) y middleware/error.js.
// El modelo de usuarios se simula: no se toca la BD real.
process.env.JWT_SECRET = require('./helpers').SECRETO;
jest.mock('../../src/config/db', () => ({ query: jest.fn(), pool: { connect: jest.fn() } }));
jest.mock('../../src/models/usuario.model');

const request = require('supertest');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const app = require('../../src/app');
const usuarioModel = require('../../src/models/usuario.model');
const { SECRETO, bearer, pgError } = require('./helpers');

const valido = { nombre: 'Prueba WB', correo: 'prueba_wb_01@test.com', telefono: '5512345678', password: 'Segura123' };
const sinSecretos = (body) => {
  const texto = JSON.stringify(body);
  expect(texto).not.toMatch(/password_hash|\$2[aby]\$/);
};

beforeEach(() => jest.resetAllMocks());

describe('AUTH register: ramas de validación (L36-60)', () => {
  test.each([
    ['WB-AUTH-R01 falta nombre', { ...valido, nombre: undefined }, 'nombre, correo y password son obligatorios'],
    ['WB-AUTH-R02 nombre solo espacios (tieneTexto=F)', { ...valido, nombre: '   ' }, 'nombre, correo y password son obligatorios'],
    ['WB-AUTH-R03 password no-string (número)', { ...valido, password: 12345678 }, 'nombre, correo y password son obligatorios'],
    ['WB-AUTH-R04 nombre 2 caracteres (límite mín−1)', { ...valido, nombre: 'Al' }, 'El nombre debe tener al menos 3 caracteres'],
    ['WB-AUTH-R05 correo inválido', { ...valido, correo: 'no-es-correo' }, 'Correo inválido'],
    ['WB-AUTH-R06 password 65 (máx+1)', { ...valido, password: 'A1' + 'a'.repeat(63) }, 'La contraseña no puede superar 64 caracteres'],
    ['WB-AUTH-R07 password sin mayúscula/número', { ...valido, password: 'abcdefgh' }, 'La contraseña debe tener al menos 8 caracteres, una mayúscula y un número'],
    ['WB-AUTH-R08 password 7 (mín−1)', { ...valido, password: 'Abcde12' }, 'La contraseña debe tener al menos 8 caracteres, una mayúscula y un número'],
    ['WB-AUTH-R09 teléfono 9 dígitos', { ...valido, telefono: '551234567' }, 'El teléfono debe tener entre 10 y 13 dígitos'],
    ['WB-AUTH-R10 teléfono 14 dígitos', { ...valido, telefono: '12345678901234' }, 'El teléfono debe tener entre 10 y 13 dígitos'],
  ])('%s → 400', async (_n, body, error) => {
    const r = await request(app).post('/api/auth/register').send(body);
    expect(r.status).toBe(400);
    expect(r.body).toEqual({ error });
    expect(usuarioModel.crear).not.toHaveBeenCalled();
  });

  test('WB-AUTH-R11 password 64 (máx) y nombre 3 (mín) y sin teléfono (rama telefono=F) → 201', async () => {
    usuarioModel.buscarPorCorreo.mockResolvedValue(null);
    usuarioModel.crear.mockImplementation(async (u) => ({ id: 1, nombre: u.nombre, correo: u.correo, telefono: null, tipo: 'usuario' }));
    const r = await request(app).post('/api/auth/register').send({ nombre: 'Ana', correo: valido.correo, password: 'A1' + 'a'.repeat(62) });
    expect(r.status).toBe(201);
  });
});

describe('AUTH register: caminos de persistencia', () => {
  test('WB-AUTH-R12 correo ya registrado → 409 sin crear', async () => {
    usuarioModel.buscarPorCorreo.mockResolvedValue({ id: 5 });
    const r = await request(app).post('/api/auth/register').send(valido);
    expect(r.status).toBe(409);
    expect(usuarioModel.crear).not.toHaveBeenCalled();
  });

  test('WB-AUTH-R13 éxito → 201 {token, user}; password se guarda como hash bcrypt; no se expone', async () => {
    usuarioModel.buscarPorCorreo.mockResolvedValue(null);
    usuarioModel.crear.mockImplementation(async (u) => ({ id: 77, nombre: u.nombre, correo: u.correo, telefono: u.telefono, tipo: 'usuario' }));
    const r = await request(app).post('/api/auth/register').send(valido);
    expect(r.status).toBe(201);
    expect(Object.keys(r.body).sort()).toEqual(['token', 'user']);
    expect(jwt.verify(r.body.token, SECRETO)).toMatchObject({ id: 77, correo: valido.correo, tipo: 'usuario' });
    const { passwordHash } = usuarioModel.crear.mock.calls[0][0];
    expect(passwordHash).toMatch(/^\$2[aby]\$10\$/);
    expect(await bcrypt.compare(valido.password, passwordHash)).toBe(true);
    sinSecretos(r.body.user);
  });

  test('WB-AUTH-R14 carrera: UNIQUE violado en el INSERT (23505) → 409 por el errorHandler', async () => {
    usuarioModel.buscarPorCorreo.mockResolvedValue(null);
    usuarioModel.crear.mockRejectedValue(pgError('23505', 'duplicate key value violates unique constraint "usuarios_correo_key"'));
    const r = await request(app).post('/api/auth/register').send(valido);
    expect(r.status).toBe(409);
    expect(r.body).toEqual({ error: 'El registro ya existe' });
  });

  test('WB-AUTH-R15 excepción inesperada de BD → 500 genérico (sin SQL en la respuesta)', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => {});
    usuarioModel.buscarPorCorreo.mockRejectedValue(new Error('connect ECONNREFUSED / relation "usuarios"'));
    const r = await request(app).post('/api/auth/register').send(valido);
    expect(r.status).toBe(500);
    expect(r.body).toEqual({ error: 'Error interno del servidor' });
  });

  // SA-01 / DEF-02 corregido en la P13: ahora la prueba exige el correo normalizado (regresión).
  test('WB-AUTH-R16 [SA-01 corregido en P13] el correo se busca y se guarda sin espacios y en minúsculas', async () => {
    usuarioModel.buscarPorCorreo.mockResolvedValue(null);
    usuarioModel.crear.mockImplementation(async (u) => ({ id: 78, nombre: u.nombre, correo: u.correo, tipo: 'usuario' }));
    const r = await request(app).post('/api/auth/register').send({ ...valido, correo: '  Prueba_WB_01@Test.com ' });
    expect(r.status).toBe(201); // pasa la validación porque el regex se prueba con trim()
    expect(usuarioModel.buscarPorCorreo).toHaveBeenCalledWith('prueba_wb_01@test.com');
    expect(usuarioModel.crear.mock.calls[0][0].correo).toBe('prueba_wb_01@test.com');
  });

  test('WB-AUTH-R17 JSON mal formado → 400 (entity.parse.failed)', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => {});
    const r = await request(app).post('/api/auth/register').set('Content-Type', 'application/json').send('{"nombre": ');
    expect(r.status).toBe(400);
    expect(r.body).toEqual({ error: 'El cuerpo de la petición no es JSON válido' });
  });
});

describe('AUTH login (L77-107)', () => {
  let usuarioBd;
  beforeAll(async () => {
    usuarioBd = { id: 9, nombre: 'Prueba WB', correo: valido.correo, tipo: 'usuario', password_hash: await bcrypt.hash('Segura123', 4) };
  });

  test.each([
    ['WB-AUTH-L01 sin correo', { password: 'Segura123' }, 400],
    ['WB-AUTH-L02 password solo espacios', { correo: valido.correo, password: '        ' }, 400],
    ['WB-AUTH-L03 password 7 (mín−1) → 401 sin consultar BD', { correo: valido.correo, password: 'Segura1' }, 401],
    ['WB-AUTH-L04 password 65 (máx+1) → 401 sin consultar BD', { correo: valido.correo, password: 'S1' + 'a'.repeat(63) }, 401],
  ])('%s', async (_n, body, status) => {
    const r = await request(app).post('/api/auth/login').send(body);
    expect(r.status).toBe(status);
    expect(usuarioModel.buscarPorCorreo).not.toHaveBeenCalled();
  });

  test('WB-AUTH-L05 correo inexistente y L06 password incorrecta → mismo 401 y mismo mensaje (no enumera usuarios)', async () => {
    usuarioModel.buscarPorCorreo.mockResolvedValueOnce(null).mockResolvedValueOnce(usuarioBd);
    const a = await request(app).post('/api/auth/login').send({ correo: 'nadie@test.com', password: 'Segura123' });
    const b = await request(app).post('/api/auth/login').send({ correo: valido.correo, password: 'Incorrecta1' });
    expect([a.status, b.status]).toEqual([401, 401]);
    expect(a.body).toEqual(b.body);
    expect(a.body).toEqual({ error: 'Correo o contraseña incorrectos' });
  });

  test('WB-AUTH-L07 éxito → 200 {token, user} sin password_hash; el correo se busca con trim', async () => {
    usuarioModel.buscarPorCorreo.mockResolvedValue(usuarioBd);
    const r = await request(app).post('/api/auth/login').send({ correo: `  ${valido.correo}  `, password: 'Segura123' });
    expect(r.status).toBe(200);
    expect(usuarioModel.buscarPorCorreo).toHaveBeenCalledWith(valido.correo);
    expect(r.body.user).toEqual({ id: 9, nombre: 'Prueba WB', correo: valido.correo, tipo: 'usuario' });
    sinSecretos(r.body.user);
  });

  test('WB-AUTH-L08 excepción de BD → 500 genérico', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => {});
    usuarioModel.buscarPorCorreo.mockRejectedValue(new Error('timeout'));
    const r = await request(app).post('/api/auth/login').send({ correo: valido.correo, password: 'Segura123' });
    expect(r.status).toBe(500);
    expect(r.body).toEqual({ error: 'Error interno del servidor' });
  });
});

describe('middleware verificarToken (401) — vía GET /api/usuarios/perfil', () => {
  test.each([
    ['WB-MW-01 sin header', undefined, 'Token no proporcionado'],
    ['WB-MW-02 esquema distinto (Basic)', 'Basic abc', 'Token no proporcionado'],
    ['WB-MW-03 "Bearer" sin token', 'Bearer', 'Token no proporcionado'],
    ['WB-MW-04 firma inválida', `Bearer ${jwt.sign({ id: 1 }, 'otro-secreto')}`, 'Token inválido o expirado'],
    ['WB-MW-05 token vencido', bearer({ id: 1 }, { expiresIn: -10 }), 'Token inválido o expirado'],
  ])('%s → 401', async (_n, auth, error) => {
    const req = request(app).get('/api/usuarios/perfil');
    if (auth) req.set('Authorization', auth);
    const r = await req;
    expect(r.status).toBe(401);
    expect(r.body).toEqual({ error });
  });

  test('WB-MW-06 token válido de usuario borrado → 404 en perfil', async () => {
    usuarioModel.buscarPorId.mockResolvedValue(null);
    const r = await request(app).get('/api/usuarios/perfil').set('Authorization', bearer({ id: 123 }));
    expect(r.status).toBe(404);
  });

  test('WB-MW-07 token válido → 200 perfil sin password_hash', async () => {
    usuarioModel.buscarPorId.mockResolvedValue({ id: 9, nombre: 'Prueba WB', correo: valido.correo, telefono: null, tipo: 'usuario' });
    const r = await request(app).get('/api/usuarios/perfil').set('Authorization', bearer({ id: 9 }));
    expect(r.status).toBe(200);
    sinSecretos(r.body);
  });

  test('WB-MW-08 ruta inexistente → 404 JSON', async () => {
    const r = await request(app).get('/api/no-existe');
    expect(r.status).toBe(404);
    expect(r.body).toEqual({ error: 'Ruta no encontrada: GET /api/no-existe' });
  });
});
