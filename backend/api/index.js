// Entrypoint serverless para Vercel. Exporta la app de Express tal cual
// (sin http.createServer/listen ni WebSocket): Vercel envuelve esto como
// función serverless y le da HTTPS automáticamente.
module.exports = require('../src/app');
