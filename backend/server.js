const http = require('http');
const express = require('express');
const cors = require('cors');
const env = require('./src/config/env');
const { notFound, errorHandler } = require('./src/middleware/error');
const { attachWebSocketServer } = require('./src/ws');

const authRoutes = require('./src/routes/auth.routes');
const conciertosRoutes = require('./src/routes/conciertos.routes');
const disenosRoutes = require('./src/routes/disenos.routes');
const eventosRoutes = require('./src/routes/eventos.routes');
const usuariosRoutes = require('./src/routes/usuarios.routes');
const wearableRoutes = require('./src/routes/wearable.routes');

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

app.use(notFound);
app.use(errorHandler);

// Se usa un servidor HTTP explícito (en vez de app.listen) para poder
// adjuntarle el servidor WebSocket que usa concertx_tv para recibir
// actualizaciones en tiempo real (efecto activo, canción, usuarios).
const server = http.createServer(app);
attachWebSocketServer(server);

server.listen(env.port, () => {
  // eslint-disable-next-line no-console
  console.log(`Concertx API escuchando en http://localhost:${env.port}`);
  // eslint-disable-next-line no-console
  console.log(`WebSocket escuchando en ws://localhost:${env.port}`);
});

module.exports = app;
