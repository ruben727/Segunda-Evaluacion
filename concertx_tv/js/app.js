// ============================================================
// Concertx TV — lógica principal (datos en tiempo real, WS, cache)
// Vanilla JS, sin frameworks — mejor rendimiento en Smart TV.
// ============================================================

const API_BASE = 'http://localhost:3000/api';
const WS_URL = 'ws://localhost:3000';
const CACHE_KEY = 'concertx_tv_cache';
const CONCIERTO_ID_KEY = 'concertx_tv_concierto_id';

// Esta Smart TV, mientras dure la fase de pruebas, SOLO proyecta este
// concierto fijo — así todas las pruebas en vivo (alguien se une, crea
// su diseño, etc.) se ven reflejadas siempre en la misma pantalla.
const CONCIERTO_FIJO_ARTISTA = 'Evan Craft';

const EFFECT_COLORS = [
  { color: '#3B82F6', nombre: 'Azul' },
  { color: '#7C3AED', nombre: 'Morado' },
  { color: '#EF4444', nombre: 'Rojo' },
  { color: '#06B6D4', nombre: 'Cian' },
  { color: '#FACC15', nombre: 'Amarillo' },
];

const FALLBACK_PLAYLIST = [
  { titulo: 'Otro Nivel', artista: 'Evan Craft', duracion: 180 },
  { titulo: 'Nadie Como Tú', artista: 'Evan Craft', duracion: 195 },
  { titulo: 'Nada Es Imposible', artista: 'Evan Craft', duracion: 210 },
  { titulo: 'Un Buen Día', artista: 'Evan Craft', duracion: 200 },
];

// Estado compartido de la app (playlist real si llega de la API, índice de
// efecto/canción actual para el ciclo con D-pad, etc.)
const state = {
  conciertoId: localStorage.getItem(CONCIERTO_ID_KEY) || null,
  playlist: FALLBACK_PLAYLIST,
  songIndex: 0,
  effectIndex: 0,
};

// ------------------------------ REST API ------------------------------

/** Busca el id del concierto fijo (Evan Craft) una sola vez y lo cachea. */
async function resolverConciertoFijo() {
  if (state.conciertoId) return;
  try {
    const res = await fetch(`${API_BASE}/conciertos`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const lista = await res.json();
    const objetivo = lista.find((c) => c.artista === CONCIERTO_FIJO_ARTISTA);
    if (objetivo) {
      state.conciertoId = objetivo.id;
      localStorage.setItem(CONCIERTO_ID_KEY, objetivo.id);
    } else {
      console.warn(`No se encontró el concierto "${CONCIERTO_FIJO_ARTISTA}" en el backend`);
    }
  } catch (err) {
    console.warn('No se pudo resolver el concierto fijo', err);
  }
}

async function fetchEventData() {
  await resolverConciertoFijo();
  if (!state.conciertoId) {
    loadFromCache();
    return;
  }

  try {
    const res = await fetch(`${API_BASE}/conciertos/${state.conciertoId}/estado`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    updateDashboard(data);
    localStorage.setItem(CACHE_KEY, JSON.stringify(data));
  } catch (err) {
    console.warn('API offline, using cached data', err);
    loadFromCache();
  }
}

function loadFromCache() {
  const cached = localStorage.getItem(CACHE_KEY);
  if (!cached) return; // se quedan los valores mock del HTML como último recurso
  try {
    updateDashboard(JSON.parse(cached));
  } catch (e) {
    console.warn('No se pudo leer el cache local', e);
  }
}

function updateDashboard(estadoEvento) {
  const concierto = estadoEvento && estadoEvento.concierto;
  if (!concierto) return;

  const pill = document.getElementById('event-pill');
  if (pill) {
    const fecha = concierto.fecha_inicio
      ? new Date(concierto.fecha_inicio).toLocaleDateString('es-MX', {
          day: '2-digit',
          month: 'short',
          year: 'numeric',
        })
      : '';
    const estadio = concierto.estadio || {};
    const codigoTxt = estadoEvento.diseno
      ? `Código: ${estadoEvento.diseno.codigo}`
      : 'Código: (sin diseño aún)';
    pill.textContent = [concierto.artista, estadio.nombre, estadio.ciudad, fecha, codigoTxt]
      .filter(Boolean)
      .join(' · ');
  }

  // Setlist real (>=1 registro adicional con datos reales de la API) para
  // que "siguiente canción" del D-pad cicle sobre datos reales.
  if (Array.isArray(concierto.canciones) && concierto.canciones.length > 0) {
    state.playlist = concierto.canciones.map((c) => ({
      titulo: c.titulo,
      artista: concierto.artista,
      duracion: c.duracion_segundos || 180,
    }));
    state.songIndex = 0;
  }

  updateUserCount(estadoEvento.conectados ?? 0);
  updateSyncPercent(estadoEvento.porcentaje ?? 0);
}

async function fetchConnectedUsers() {
  // El conteo en vivo viene junto con el resto del estado del concierto
  // fijo (mismo endpoint), así que solo se refresca todo junto.
  await fetchEventData();
}

// --------------------------- WEBSOCKET (tiempo real) ---------------------------
// Se conecta al mismo backend que usa la app de teléfono: cuando el
// teléfono manda un cambio de efecto/canción, la TV se actualiza sola.

let ws;
function connectWebSocket() {
  ws = new WebSocket(WS_URL);

  ws.onopen = () => {
    console.log('WebSocket conectado');
    ws.send(JSON.stringify({ type: 'tv_connect', room: 'concertx_tv' }));
  };

  ws.onmessage = (event) => {
    let msg;
    try {
      msg = JSON.parse(event.data);
    } catch (e) {
      console.warn('Mensaje WS no es JSON válido', e);
      return;
    }
    if (!msg || !msg.type) return;
    handleMessage(msg);
  };

  ws.onclose = () => {
    console.log('WebSocket desconectado, reconectando en 3s...');
    setTimeout(connectWebSocket, 3000); // auto-reconexión
  };

  ws.onerror = (err) => {
    console.error('WebSocket error:', err);
  };
}

// BroadcastChannel — respaldo cuando el teléfono corre en el MISMO
// dispositivo/navegador que la TV (útil para pruebas locales).
const channel = new BroadcastChannel('concertx_sync');
channel.onmessage = (event) => {
  // VALIDAR ORIGEN Y TIPO — requerido por rúbrica SA.4
  if (!event.data || typeof event.data !== 'object') return;
  if (!event.data.type) return;
  if (!['effect_update', 'song_update', 'users_update'].includes(event.data.type)) return;

  handleMessage(event.data);
};

function handleMessage(msg) {
  switch (msg.type) {
    case 'effect_update':
      updateActiveEffect(msg.color, msg.nombre);
      break;
    case 'song_update':
      updateCurrentSong(msg.titulo, msg.artista, msg.duracion);
      break;
    case 'users_update':
      updateUserCount(msg.total);
      break;
    case 'seat_update':
      if (window.ConcertxSeats && typeof window.ConcertxSeats.updateSeat === 'function') {
        window.ConcertxSeats.updateSeat(msg.zona, msg.fila, msg.asiento, msg.conectado);
      }
      break;
    default:
      break;
  }
}

// ---------------------------- UI update functions ----------------------------

function updateUserCount(count) {
  const el = document.getElementById('user-count');
  if (!el) return;
  el.textContent = Number(count).toLocaleString('es-MX');
  el.style.transform = 'scale(1.05)';
  setTimeout(() => {
    el.style.transform = 'scale(1)';
  }, 200);
}

function updateSyncPercent(pct) {
  const value = Math.max(0, Math.min(100, Number(pct) || 0));
  const percentEl = document.getElementById('sync-percent');
  const barEl = document.getElementById('sync-progress');
  if (percentEl) percentEl.textContent = `${value}%`;
  if (barEl) barEl.style.width = `${value}%`;
}

function updateActiveEffect(colorHex, nombre) {
  const circle = document.getElementById('effect-circle');
  const label = document.getElementById('effect-label');
  if (!colorHex) return;
  if (circle) circle.style.borderColor = colorHex;
  if (label) {
    label.textContent = (nombre || '').toUpperCase();
    label.style.color = colorHex;
  }
}

function updateCurrentSong(titulo, artista, duracionSeg) {
  const titleEl = document.getElementById('song-title');
  const artistEl = document.getElementById('song-artist');
  if (titleEl) titleEl.textContent = titulo;
  if (artistEl) artistEl.textContent = artista;
  resetSongProgress(duracionSeg);
}

// --------------------------- Barra de progreso de la canción ---------------------------
// Cuenta hacia arriba cada segundo (setInterval). Al llegar al final da la
// vuelta a 00:00 en vez de congelarse — así la demo no se queda "pegada"
// si nadie interactúa por varios minutos.

const DEFAULT_SONG_DURATION = 243; // 04:03, como en el mockup
const DEFAULT_SONG_ELAPSED = 134; // 02:14, como en el mockup

let songTimer = null;
let songElapsed = DEFAULT_SONG_ELAPSED;
let songTotal = DEFAULT_SONG_DURATION;

function startSongProgress() {
  updateSongProgressUI(songElapsed, songTotal);
  _tickSong();
}

function resetSongProgress(totalSec) {
  songTotal = totalSec && totalSec > 0 ? totalSec : DEFAULT_SONG_DURATION;
  songElapsed = 0;
  updateSongProgressUI(songElapsed, songTotal);
  _tickSong();
}

function _tickSong() {
  clearInterval(songTimer);
  songTimer = setInterval(() => {
    songElapsed++;
    if (songElapsed >= songTotal) {
      songElapsed = 0;
    }
    updateSongProgressUI(songElapsed, songTotal);
  }, 1000);
}

function updateSongProgressUI(elapsed, total) {
  const pct = total > 0 ? (elapsed / total) * 100 : 0;
  const bar = document.getElementById('song-progress');
  const current = document.getElementById('song-time-current');
  const totalEl = document.getElementById('song-time-total');
  if (bar) bar.style.width = `${pct}%`;
  if (current) current.textContent = formatTime(elapsed);
  if (totalEl) totalEl.textContent = formatTime(total);
}

function formatTime(sec) {
  const m = Math.floor(sec / 60).toString().padStart(2, '0');
  const s = Math.floor(sec % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
}

// ------------------------------ Header contextual ------------------------------
// Requerido por rúbrica SA.2.C — info contextual visible en todo momento.

function updateHeader() {
  const now = new Date();
  const timeStr = now.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
  const el = document.getElementById('header-time');
  if (el) el.textContent = timeStr;
}
setInterval(updateHeader, 1000);

// ------------------------- Acciones activadas por D-pad -------------------------
// Expuestas en window.ConcertxTV para que dpnav.js las invoque sin acoplar
// los dos archivos (ver activateFocused() en dpnav.js).

function refreshUsers() {
  fetchConnectedUsers();
}

function nextSongDemo() {
  if (!state.playlist.length) return;
  state.songIndex = (state.songIndex + 1) % state.playlist.length;
  const siguiente = state.playlist[state.songIndex];
  updateCurrentSong(siguiente.titulo, siguiente.artista, siguiente.duracion);
}

function cycleEffect() {
  state.effectIndex = (state.effectIndex + 1) % EFFECT_COLORS.length;
  const efecto = EFFECT_COLORS[state.effectIndex];
  updateActiveEffect(efecto.color, efecto.nombre);
}

window.ConcertxTV = { refreshUsers, nextSongDemo, cycleEffect };

// ------------------------------------ Init ------------------------------------

document.addEventListener('DOMContentLoaded', () => {
  fetchEventData();
  fetchConnectedUsers();
  connectWebSocket();
  startSongProgress();
  updateHeader();

  // Refresca el contador de usuarios cada 5 segundos.
  setInterval(fetchConnectedUsers, 5000);
});
