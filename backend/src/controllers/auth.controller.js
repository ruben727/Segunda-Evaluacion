const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const usuarioModel = require('../models/usuario.model');

const SALT_ROUNDS = 10;

function firmarToken(usuario) {
  return jwt.sign(
    { id: usuario.id, correo: usuario.correo, tipo: usuario.tipo },
    env.jwtSecret,
    { expiresIn: '7d' }
  );
}

function sinPassword(usuario) {
  const { password_hash, ...resto } = usuario;
  return resto;
}

async function register(req, res, next) {
  try {
    const { nombre, correo, telefono, password } = req.body;

    if (!nombre || !correo || !password) {
      return res.status(400).json({ error: 'nombre, correo y password son obligatorios' });
    }

    const existente = await usuarioModel.buscarPorCorreo(correo);
    if (existente) {
      return res.status(409).json({ error: 'Ya existe una cuenta con ese correo' });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const usuario = await usuarioModel.crear({ nombre, correo, telefono, passwordHash });
    const token = firmarToken(usuario);

    res.status(201).json({ token, user: usuario });
  } catch (err) {
    next(err);
  }
}

async function login(req, res, next) {
  try {
    const { correo, password } = req.body;

    if (!correo || !password) {
      return res.status(400).json({ error: 'correo y password son obligatorios' });
    }

    const usuario = await usuarioModel.buscarPorCorreo(correo);
    if (!usuario) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }

    const passwordValida = await bcrypt.compare(password, usuario.password_hash);
    if (!passwordValida) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }

    const token = firmarToken(usuario);
    res.json({ token, user: sinPassword(usuario) });
  } catch (err) {
    next(err);
  }
}

module.exports = { register, login };
