// ============================================================
// Concertx TV — mapa de asientos (seats.html)
// Grilla generada con una semilla fija para que se vea igual en cada
// carga (no completamente aleatoria en cada render), como pide la
// especificación.
// ============================================================

// PRNG determinista (mulberry32) — misma semilla => misma distribución.
function mulberry32(seed) {
  let a = seed;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const SEED = 20250712; // fecha del evento, cualquier constante fija sirve
const random = mulberry32(SEED);

const ROW_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R'];

// Filas del medio más anchas, del frente/fondo más angostas (leve curva oval).
const ROW_WIDTHS = [20, 22, 24, 26, 28, 30, 32, 32, 32, 32, 32, 32, 30, 28, 26, 24, 22, 20];

function porcentajeConectadoPorFila(rowIndex) {
  if (rowIndex <= 2) return 0.88; // A-C
  if (rowIndex <= 7) return 0.75; // D-H
  if (rowIndex <= 12) return 0.6; // I-M
  return 0.4; // N-R
}

function renderSeatGrid() {
  const grid = document.getElementById('seat-grid');
  if (!grid) return;
  grid.innerHTML = '';

  ROW_LETTERS.forEach((letra, rowIndex) => {
    const row = document.createElement('div');
    row.className = 'seat-row';

    const label = document.createElement('span');
    label.className = 'seat-row-label';
    label.textContent = letra;
    row.appendChild(label);

    const width = ROW_WIDTHS[rowIndex];
    const pctConectado = porcentajeConectadoPorFila(rowIndex);

    for (let i = 1; i <= width; i++) {
      const seat = document.createElement('div');
      const conectado = random() < pctConectado;
      seat.className = `seat ${conectado ? 'taken' : 'empty'}`;
      seat.dataset.row = letra;
      seat.dataset.index = String(i);
      row.appendChild(seat);
    }

    grid.appendChild(row);
  });
}

// Actualiza un asiento puntual cuando llega un mensaje seat_update por
// WebSocket/BroadcastChannel. Best-effort: si el asiento indicado no
// existe en esta grilla decorativa, no hace nada.
function updateSeat(zona, fila, asiento, conectado) {
  const el = document.querySelector(`.seat[data-row="${fila}"][data-index="${asiento}"]`);
  if (!el) return;
  el.classList.toggle('taken', !!conectado);
  el.classList.toggle('empty', !conectado);
}

window.ConcertxSeats = { updateSeat };

document.addEventListener('DOMContentLoaded', renderSeatGrid);
