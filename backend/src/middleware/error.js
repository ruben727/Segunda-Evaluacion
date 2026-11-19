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

  if (err.code === '22P02') {
    // Valor con formato inválido para el tipo de la columna (ej. id = "abc")
    return res.status(400).json({ error: 'Parámetro con formato inválido' });
  }

  if (err.code === '23503') {
    // Violación de llave foránea (ej. concierto_id o cancion_id inexistente)
    return res.status(400).json({ error: 'El registro relacionado no existe' });
  }

  if (err.type === 'entity.parse.failed') {
    // JSON mal formado en el body
    return res.status(400).json({ error: 'El cuerpo de la petición no es JSON válido' });
  }

  // Práctica 5: un 500 nunca devuelve el mensaje técnico (SQL, stack,
  // nombres de tablas) al cliente; ese detalle solo queda en el log.
  // Los errores lanzados a propósito con err.status (4xx) sí conservan su
  // mensaje, porque ya están redactados para el usuario.
  const status = err.status || 500;
  const mensaje = status >= 500 ? 'Error interno del servidor' : err.message;
  res.status(status).json({ error: mensaje || 'Error interno del servidor' });
}

module.exports = { notFound, errorHandler };
