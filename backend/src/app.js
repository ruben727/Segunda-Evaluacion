const express = require('express');
const cors = require('cors');
const { notFound, errorHandler } = require('./middleware/error');

const authRoutes = require('./routes/auth.routes');
const conciertosRoutes = require('./routes/conciertos.routes');
const disenosRoutes = require('./routes/disenos.routes');
const eventosRoutes = require('./routes/eventos.routes');
const usuariosRoutes = require('./routes/usuarios.routes');
const wearableRoutes = require('./routes/wearable.routes');
const incidenciasRoutes = require('./routes/incidencias.routes');
const busquedaRoutes = require('./routes/busqueda.routes');

// App de Express "pura" (sin http.createServer/listen ni WebSocket), para
// poder reutilizarla tanto en el servidor local (server.js) como en el
// entrypoint serverless de Vercel (api/index.js). El WebSocket de
// concertx_tv solo se adjunta en server.js porque Vercel no soporta
// conexiones persistentes en funciones serverless.
const app = express();

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ nombre: 'Concertx API', estado: 'ok' });
});

app.use('/api/auth', authRoutes);
app.use('/api/conciertos', conciertosRoutes);
app.use('/api/disenos', disenosRoutes);
app.use('/api/eventos', eventosRoutes);
app.use('/api/usuarios', usuariosRoutes);
app.use('/api/wearable', wearableRoutes);
app.use('/api/incidencias', incidenciasRoutes);
app.use('/api/buscar', busquedaRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
