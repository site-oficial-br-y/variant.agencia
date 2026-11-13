// cache pra abrir sem internet (o presencial funciona offline). Muda VERSAO a cada publicação.
const VERSAO = 'ehn-1794540510';
const ARQS = ["./", "index.html", "jogo.js", "mesa.js", "palavras.js", "logo.webp", "LilitaOne.woff2", "icone-192.png", "manifest.json", "bonecos/0.webp", "bonecos/1.webp", "bonecos/2.webp", "bonecos/3.webp", "bonecos/4.webp", "bonecos/5.webp", "bonecos/6.webp", "bonecos/7.webp", "bonecos/8.webp", "bonecos/9.webp", "bonecos/10.webp", "bonecos/11.webp", "bonecos/12.webp", "bonecos/13.webp", "bonecos/14.webp", "bonecos/15.webp", "bonecos/r0.webp", "bonecos/r1.webp", "bonecos/r2.webp", "bonecos/r3.webp", "bonecos/r4.webp", "bonecos/r5.webp", "bonecos/r6.webp", "bonecos/r7.webp", "bonecos/r8.webp", "bonecos/r9.webp", "bonecos/r10.webp", "bonecos/r11.webp", "bonecos/r12.webp", "bonecos/r13.webp", "bonecos/r14.webp", "bonecos/r15.webp"];
self.addEventListener('install', e => { e.waitUntil(caches.open(VERSAO).then(c => c.addAll(ARQS)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== VERSAO).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(VERSAO).then(k => k.put(e.request, c)); return r; }).catch(() => caches.match(e.request, { ignoreSearch: true })));
});
