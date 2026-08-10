const WebSocket = require('ws');

// Tipos de mensaje que el backend reenvía a las TVs suscritas cuando los
// manda el teléfono (o cualquier otro cliente). Mantener esta lista en
// sincronía con lo que espera concertx_tv/js/app.js.
const TIPOS_RETRANSMITIDOS = new Set([
  'effect_update',
  'song_update',
  'users_update',
  'seat_update',
]);

/**
 * Adjunta un servidor WebSocket al servidor HTTP de Express y conecta
 * al mismo "salón" a las apps de teléfono y a las Smart TV: cuando el
 * teléfono manda un cambio de efecto/canción, se retransmite a todas
 * las TVs conectadas.
 */
function attachWebSocketServer(httpServer) {
  const wss = new WebSocket.Server({ server: httpServer });
  const clients = new Map();

  wss.on('connection', (ws) => {
    const clientId = Date.now() + Math.random();
    clients.set(clientId, { ws, type: 'unknown' });
    // eslint-disable-next-line no-console
    console.log(`[ws] cliente conectado (${clientId}), total=${clients.size}`);

    ws.on('message', (data) => {
      let msg;
      try {
        msg = JSON.parse(data);
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error('[ws] mensaje no es JSON válido:', e.message);
        return;
      }

      if (!msg || typeof msg.type !== 'string') return;

      if (msg.type === 'tv_connect') {
        clients.get(clientId).type = 'tv';
        // eslint-disable-next-line no-console
        console.log(`[ws] cliente ${clientId} identificado como TV`);
        return;
      }
      if (msg.type === 'phone_connect') {
        clients.get(clientId).type = 'phone';
        // eslint-disable-next-line no-console
        console.log(`[ws] cliente ${clientId} identificado como phone`);
        return;
      }

      if (TIPOS_RETRANSMITIDOS.has(msg.type)) {
        broadcastToTV(clients, msg);
      }
    });

    ws.on('close', () => {
      clients.delete(clientId);
      // eslint-disable-next-line no-console
      console.log(`[ws] cliente desconectado (${clientId}), total=${clients.size}`);
    });

    ws.on('error', (err) => {
      // eslint-disable-next-line no-console
      console.error('[ws] error de socket:', err.message);
    });
  });

  return wss;
}

function broadcastToTV(clients, msg) {
  const payload = JSON.stringify(msg);
  clients.forEach(({ ws, type }) => {
    if (type === 'tv' && ws.readyState === WebSocket.OPEN) {
      ws.send(payload);
    }
  });
}

module.exports = { attachWebSocketServer };
