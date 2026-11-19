// Utilidades comunes: JWT de prueba firmado con el secreto de prueba.
const jwt = require('jsonwebtoken');
const SECRETO = 'secreto-de-prueba-wb';
const token = (payload, opts = { expiresIn: '1h' }) => jwt.sign(payload, SECRETO, opts);
const bearer = (payload, opts) => `Bearer ${token(payload, opts)}`;
const pgError = (code, message = `error simulado ${code}`) => Object.assign(new Error(message), { code });
module.exports = { SECRETO, token, bearer, pgError };
