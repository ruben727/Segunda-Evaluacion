// Prácticas 13 y 14 – AUT-04 (integración API ↔ persistencia de usuarios).
// Previene el defecto DEF-02 de la Práctica 11: el correo no se normalizaba (espacios/mayúsculas),
// lo que permitía cuentas duplicadas y usuarios que no podían iniciar sesión.
// Se prueba la ruta HTTP real de Express (supertest); solo el modelo de BD se simula.
process.env.JWT_SECRET = 'secreto-de-prueba-p13';
jest.mock('../../src/config/db', () => ({ query: jest.fn(), pool: { connect: jest.fn() } }));
jest.mock('../../src/models/usuario.model');

const request = require('supertest');
const bcrypt = require('bcryptjs');
const app = require('../../src/app');
const usuarioModel = require('../../src/models/usuario.model');

const base = { nombre: 'Prueba P13', telefono: '5512345678', password: 'Segura123' };

beforeEach(() => jest.resetAllMocks());

test('AUT-API-01 registro con espacios y mayúsculas → 201 y el correo se busca y guarda normalizado', async () => {
  usuarioModel.buscarPorCorreo.mockResolvedValue(null);
  usuarioModel.crear.mockImplementation(async (u) => ({ id: 1, nombre: u.nombre, correo: u.correo, tipo: 'usuario' }));
  const r = await request(app).post('/api/auth/register').send({ ...base, correo: '  Prueba_P13@Test.COM ' });
  expect(r.status).toBe(201);
  expect(usuarioModel.buscarPorCorreo).toHaveBeenCalledWith('prueba_p13@test.com');
  expect(usuarioModel.crear.mock.calls[0][0].correo).toBe('prueba_p13@test.com');
  expect(r.body.user.correo).toBe('prueba_p13@test.com');
});

test('AUT-API-02 el mismo correo en mayúsculas ya registrado → 409 y no se crea otra cuenta', async () => {
  usuarioModel.buscarPorCorreo.mockImplementation(async (c) => (c === 'prueba_p13@test.com' ? { id: 1 } : null));
  const r = await request(app).post('/api/auth/register').send({ ...base, correo: 'PRUEBA_P13@TEST.COM' });
  expect(r.status).toBe(409);
  expect(usuarioModel.crear).not.toHaveBeenCalled();
});

test('AUT-API-03 login con mayúsculas encuentra la cuenta guardada en minúsculas → 200 con token', async () => {
  const fila = { id: 1, nombre: 'Prueba P13', correo: 'prueba_p13@test.com', tipo: 'usuario', password_hash: await bcrypt.hash('Segura123', 4) };
  usuarioModel.buscarPorCorreo.mockImplementation(async (c) => (c === 'prueba_p13@test.com' ? fila : null));
  const r = await request(app).post('/api/auth/login').send({ correo: ' Prueba_P13@TEST.com', password: 'Segura123' });
  expect(r.status).toBe(200);
  expect(r.body.token).toEqual(expect.any(String));
  expect(JSON.stringify(r.body)).not.toMatch(/password_hash/);
});
