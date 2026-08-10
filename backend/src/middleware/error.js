/* eslint-disable no-unused-vars */

function notFound(req, res, next) {
  res.status(404).json({ error: `Ruta no encontrada: ${req.method} ${req.originalUrl}` });
}

// Manejador de errores global. Debe registrarse al final de la cadena de middlewares.
function errorHandler(err, req, res, next) {
  // eslint-disable-next-line no-console
  console.error('[error]', err);

  if (err.code === '23505') {
    // Violación de restricción UNIQUE en Postgres
    return res.status(409).json({ error: 'El registro ya existe' });
  }

  const status = err.status || 500;
  res.status(status).json({ error: err.message || 'Error interno del servidor' });
}

module.exports = { notFound, errorHandler };
