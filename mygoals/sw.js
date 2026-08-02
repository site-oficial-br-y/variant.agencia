// Service Worker — deixa o app abrir offline
const CACHE = 'mygoals-v1';
const ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icon192.png',
  './icon512.png',
  './iconmaskable.png',
  './appletouchicon.png'
];

// Guarda os arquivos na primeira visita
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(ASSETS))
      .then(() => self.skipWaiting())
  );
});

// Limpa versões antigas do cache
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Network-first: tenta a internet, se falhar usa o cache
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request)
      .then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
        return res;
      })
      .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html')))
  );
});
