const http = require('http');
const env = require('./src/config/env');
const app = require('./src/app');
const { attachWebSocketServer } = require('./src/ws');

// Se usa un servidor HTTP explícito (en vez de app.listen) para poder
// adjuntarle el servidor WebSocket que usa concertx_tv para recibir
// actualizaciones en tiempo real (efecto activo, canción, usuarios).
// Este archivo solo se usa para desarrollo local; en Vercel el
// entrypoint es api/index.js, que expone `app` sin WebSocket (Vercel no
// soporta conexiones persistentes en funciones serverless).
const server = http.createServer(app);
attachWebSocketServer(server);

server.listen(env.port, () => {
  // eslint-disable-next-line no-console
  console.log(`Concertx API escuchando en http://localhost:${env.port}`);
  // eslint-disable-next-line no-console
  console.log(`WebSocket escuchando en ws://localhost:${env.port}`);
});

module.exports = app;
