const jwt = require('jsonwebtoken');
const env = require('../config/env');

/**
 * Verifica el JWT enviado en el header Authorization: Bearer <token>
 * y adjunta el payload decodificado en req.usuario.
 */
function verificarToken(req, res, next) {
  const header = req.headers.authorization || '';
  const [tipo, token] = header.split(' ');

  if (tipo !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Token no proporcionado' });
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret);
    req.usuario = payload;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token inválido o expirado' });
  }
}

module.exports = { verificarToken };
