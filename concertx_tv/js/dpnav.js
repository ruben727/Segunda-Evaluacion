// ============================================================
// D-pad navigation — required for SA.2.C evaluation
// Navegación completa por flechas/OK entre los elementos [data-focusable],
// con anillo de foco dorado y sin "wrap-around" en los bordes.
// ============================================================

const FOCUSABLE = '[data-focusable]';

function getFocusableItems() {
  return Array.from(document.querySelectorAll(FOCUSABLE)).filter((el) => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  });
}

function getCurrentFocused(items) {
  return items.find((el) => el.classList.contains('focused')) || null;
}

function setFocus(newEl, oldEl) {
  if (oldEl) oldEl.classList.remove('focused');
  newEl.classList.add('focused');
  newEl.focus({ preventScroll: true });
}

function moveFocus(direction) {
  const items = getFocusableItems();
  if (items.length === 0) return;

  const current = getCurrentFocused(items);
  if (!current) {
    setFocus(items[0]);
    return;
  }

  const currentRect = current.getBoundingClientRect();
  const cx = currentRect.left + currentRect.width / 2;
  const cy = currentRect.top + currentRect.height / 2;

  let best = null;
  let bestScore = Infinity;

  items.forEach((el) => {
    if (el === current) return;
    const rect = el.getBoundingClientRect();
    const ex = rect.left + rect.width / 2;
    const ey = rect.top + rect.height / 2;
    const dx = ex - cx;
    const dy = ey - cy;

    let valid = false;
    let primary = 0;
    let perpendicular = 0;

    switch (direction) {
      case 'up':
        valid = dy < -1;
        primary = -dy;
        perpendicular = Math.abs(dx);
        break;
      case 'down':
        valid = dy > 1;
        primary = dy;
        perpendicular = Math.abs(dx);
        break;
      case 'left':
        valid = dx < -1;
        primary = -dx;
        perpendicular = Math.abs(dy);
        break;
      case 'right':
        valid = dx > 1;
        primary = dx;
        perpendicular = Math.abs(dy);
        break;
      default:
        valid = false;
    }

    if (!valid) return;

    // Favorece elementos alineados (poco desvío perpendicular) y cercanos.
    const score = primary + perpendicular * 2;
    if (score < bestScore) {
      bestScore = score;
      best = el;
    }
  });

  // Si no hay candidato válido en esa dirección, NO se mueve el foco
  // (clamp en los bordes — sin wrap-around, como pide la rúbrica).
  if (best) {
    setFocus(best, current);
  }
}

function activateFocused() {
  const items = getFocusableItems();
  const current = getCurrentFocused(items);
  if (!current) return;

  // Botones de navegación entre pantallas.
  if (current.tagName === 'A' && current.hasAttribute('href')) {
    window.location.href = current.getAttribute('href');
    return;
  }

  // Tarjetas del dashboard: cada una refresca/cicla su propio dato.
  const card = current.dataset.card;
  if (!card || !window.ConcertxTV) return;

  switch (card) {
    case 'users':
      window.ConcertxTV.refreshUsers();
      break;
    case 'song':
      window.ConcertxTV.nextSongDemo();
      break;
    case 'effect':
      window.ConcertxTV.cycleEffect();
      break;
    default:
      break;
  }
}

document.addEventListener('keydown', (e) => {
  switch (e.key) {
    case 'ArrowUp':
      e.preventDefault();
      moveFocus('up');
      break;
    case 'ArrowDown':
      e.preventDefault();
      moveFocus('down');
      break;
    case 'ArrowLeft':
      e.preventDefault();
      moveFocus('left');
      break;
    case 'ArrowRight':
      e.preventDefault();
      moveFocus('right');
      break;
    case 'Enter':
      e.preventDefault();
      activateFocused();
      break;
    case ' ':
      e.preventDefault();
      activateFocused();
      break;
    default:
      break;
  }
});

// Foco inicial: el primer elemento focusable de la pantalla.
document.addEventListener('DOMContentLoaded', () => {
  const items = getFocusableItems();
  if (items.length > 0) setFocus(items[0]);
});
