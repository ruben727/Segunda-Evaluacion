// Registro del Service Worker — habilita instalación como PWA y modo
// offline (ver sw.js).
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('/sw.js')
      .then((reg) => console.log('Service Worker registrado:', reg.scope))
      .catch((err) => console.error('Error registrando Service Worker:', err));
  });
}
