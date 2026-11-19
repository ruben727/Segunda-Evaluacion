const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const usuarioModel = require('../models/usuario.model');

const SALT_ROUNDS = 10;
const EMAIL_REGEX = /^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$/;
const PASSWORD_REGEX = /^(?=.*[A-Z])(?=.*\d).{8,}$/;
// Práctica 5: mismo rango que validan login_screen y register_screen.
const PASSWORD_MIN = 8;
const PASSWORD_MAX = 64;
const MENSAJE_LOGIN_GENERICO = 'Correo o contraseña incorrectos';

/** true si el valor es string y tiene algo más que espacios. */
function tieneTexto(valor) {
  return typeof valor === 'string' && valor.trim().length > 0;
}

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

const normalizarCorreo = (correo) => String(correo).trim().toLowerCase();

async function register(req, res, next) {
  try {
    const { nombre, correo, telefono, password } = req.body;

    if (!tieneTexto(nombre) || !tieneTexto(correo) || !tieneTexto(password)) {
      return res.status(400).json({ error: 'nombre, correo y password son obligatorios' });
    }

    // Mismas reglas que valida register_screen.dart en la app.
    if (String(nombre).trim().length < 3) {
      return res.status(400).json({ error: 'El nombre debe tener al menos 3 caracteres' });
    }
    // P13 (DEF-02): el correo se guarda y se busca normalizado (sin espacios y en minúsculas).
    const correoNormalizado = normalizarCorreo(correo);
    if (!EMAIL_REGEX.test(correoNormalizado)) {
      return res.status(400).json({ error: 'Correo inválido' });
    }
    if (password.length > PASSWORD_MAX) {
      return res.status(400).json({ error: `La contraseña no puede superar ${PASSWORD_MAX} caracteres` });
    }
    if (!PASSWORD_REGEX.test(password)) {
      return res.status(400).json({
        error: 'La contraseña debe tener al menos 8 caracteres, una mayúscula y un número',
      });
    }
    if (telefono) {
      const digitos = String(telefono).replace(/\D/g, '');
      if (digitos.length < 10 || digitos.length > 13) {
        return res.status(400).json({ error: 'El teléfono debe tener entre 10 y 13 dígitos' });
      }
    }

    const existente = await usuarioModel.buscarPorCorreo(correoNormalizado);
    if (existente) {
      return res.status(409).json({ error: 'Ya existe una cuenta con ese correo' });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const usuario = await usuarioModel.crear({ nombre: String(nombre).trim(), correo: correoNormalizado, telefono, passwordHash });
    const token = firmarToken(usuario);

    res.status(201).json({ token, user: usuario });
  } catch (err) {
    next(err);
  }
}

async function login(req, res, next) {
  try {
    const { correo, password } = req.body;

    if (!tieneTexto(correo) || !tieneTexto(password)) {
      return res.status(400).json({ error: 'correo y password son obligatorios' });
    }

    // Fuera de rango no puede ser una contraseña válida: se responde igual
    // que una contraseña incorrecta para no dar pistas, y se evita pasarle
    // a bcrypt entradas enormes.
    if (password.length < PASSWORD_MIN || password.length > PASSWORD_MAX) {
      return res.status(401).json({ error: MENSAJE_LOGIN_GENERICO });
    }

    const usuario = await usuarioModel.buscarPorCorreo(normalizarCorreo(correo));
    if (!usuario) {
      return res.status(401).json({ error: MENSAJE_LOGIN_GENERICO });
    }

    const passwordValida = await bcrypt.compare(password, usuario.password_hash);
    if (!passwordValida) {
      return res.status(401).json({ error: MENSAJE_LOGIN_GENERICO });
    }

    const token = firmarToken(usuario);
    res.json({ token, user: sinPassword(usuario) });
  } catch (err) {
    next(err);
  }
}

module.exports = { register, login };
