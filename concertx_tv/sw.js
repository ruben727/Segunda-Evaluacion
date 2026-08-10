// ============================================================
// Concertx TV — Service Worker
// Cache First para estáticos, Network First para /api/*, y
// offline.html como último recurso para navegación sin red.
// ============================================================

const CACHE_NAME = 'concertx-tv-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/seats.html',
  '/offline.html',
  '/css/styles.css',
  '/css/tv.css',
  '/js/app.js',
  '/js/seats.js',
  '/js/dpnav.js',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  if (request.method !== 'GET') return; // no cachear POST/PUT, etc.

  const esApi = url.pathname.startsWith('/api/');

  if (esApi) {
    event.respondWith(networkFirst(request));
    return;
  }

  event.respondWith(cacheFirst(request));
});

// Estáticos: sirve del cache de inmediato y actualiza en segundo plano.
async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  const fetchAndUpdate = fetch(request)
    .then((response) => {
      if (response && response.ok) cache.put(request, response.clone());
      return response;
    })
    .catch(() => null);

  if (cached) {
    fetchAndUpdate; // actualiza el cache sin bloquear la respuesta
    return cached;
  }

  const network = await fetchAndUpdate;
  if (network) return network;

  if (request.mode === 'navigate') {
    return (await cache.match('/offline.html')) || Response.error();
  }
  return Response.error();
}

// API: intenta red primero (datos frescos), cae al cache si no hay red.
async function networkFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(request);
    if (response && response.ok) cache.put(request, response.clone());
    return response;
  } catch (err) {
    const cached = await cache.match(request);
    if (cached) return cached;
    return new Response(JSON.stringify({ error: 'Sin conexión y sin datos en cache' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
