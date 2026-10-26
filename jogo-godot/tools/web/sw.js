// só existe pra o navegador deixar instalar o jogo na tela inicial (não guarda nada em cache)
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
