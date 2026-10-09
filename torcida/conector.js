/* Conector da live do TikTok para o jogo.
 *
 * Ele entra na sua live, escuta presente e comentário, e repassa pro jogo por
 * WebSocket na porta 21213. O jogo (index.html) se conecta sozinho e reconecta
 * se cair, então a ordem de abrir um e outro não importa.
 *
 * Como rodar:
 *   npm install
 *   node conector.js SEU_USUARIO_DO_TIKTOK
 *
 * Precisa estar ao vivo no momento, senão ele não acha a live.
 */

const { WebSocketServer } = require('ws')
const fs = require('fs')
const http = require('http')
const path = require('path')

// A biblioteca mudou de nome entre versões: nas antigas é WebcastPushConnection,
// nas novas é TikTokLiveConnection. Aceita as duas pra não quebrar na atualização.
const lib = require('tiktok-live-connector')
const Conexao = lib.TikTokLiveConnection || lib.WebcastPushConnection

/* Chave do serviço que assina a conexão com o TikTok. Sem ela a conexão é
   recusada com 403 quando o limite gratuito compartilhado estoura. Pega a sua
   em eulerstream.com, cola no arquivo chave.txt ao lado deste, e pronto.
   O arquivo fica fora do repositório de propósito: é segredo seu. */
let chave = process.env.EULER_API_KEY || ''
// Procura na pasta do script e na de cima: a extração do zip costuma deixar
// uma pasta dentro da outra, e o arquivo acaba caindo na de fora.
for (const lugar of [__dirname, path.join(__dirname, '..')]) {
  try {
    const lido = (fs.readFileSync(path.join(lugar, 'chave.txt'), 'utf8') || '').trim()
    if (lido) { chave = lido; break }
  } catch {}
}
if (chave) {
  // Cada versão da biblioteca recebe a chave num lugar. Na 1.2.x ela vai nos
  // parâmetros extras do assinador; nas novas existe um SignConfig. Define as
  // duas, assim funciona sem depender da versão instalada.
  if (lib.signatureProvider && lib.signatureProvider.config) {
    lib.signatureProvider.config.extraParams =
      Object.assign({}, lib.signatureProvider.config.extraParams, { apiKey: chave })
  }
  if (lib.SignConfig) lib.SignConfig.apiKey = chave
  console.log('Chave de assinatura carregada.')
} else {
  console.log('Sem chave de assinatura. Se der erro 403, crie o arquivo chave.txt')
  console.log('com a chave de eulerstream.com dentro.')
}
if (!Conexao) {
  console.error('Não achei a classe de conexão na biblioteca. Rode: npm install tiktok-live-connector')
  process.exit(1)
}

const usuario = (process.argv[2] || '').replace('@', '')
if (!usuario) {
  console.error('Faltou o usuário. Exemplo: node conector.js honkponk')
  process.exit(1)
}

const PORTA = 21213
const servidor = new WebSocketServer({ port: PORTA })
const abertos = new Set()

servidor.on('connection', ws => {
  abertos.add(ws)
  console.log('Jogo conectado. Telas abertas:', abertos.size)
  ws.on('close', () => abertos.delete(ws))
})

function mandar(objeto) {
  const texto = JSON.stringify(objeto)
  for (const ws of abertos) {
    if (ws.readyState === 1) ws.send(texto)
  }
}

/* ---------- servidor do jogo ----------
   O TikTok LIVE Studio só aceita endereço de internet na fonte de link, não
   aceita caminho de arquivo. Então o conector também serve a pasta por HTTP:
   assim dá pra apontar a fonte pra http://localhost:8080 e o jogo é desenhado
   direto em 1080x1920, sem captura de janela e sem zoom borrando. */
const PORTA_SITE = 8080
const TIPOS = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css',
  '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
}

http.createServer((req, res) => {
  let pedido = decodeURIComponent((req.url || '/').split('?')[0])
  if (pedido === '/') pedido = '/index.html'
  // impede sair da pasta com ../
  const arquivo = path.join(__dirname, path.normalize(pedido).replace(/^(\.\.[\/\\])+/, ''))
  if (!arquivo.startsWith(__dirname)) { res.writeHead(403); return res.end('fora da pasta') }
  fs.readFile(arquivo, (erro, dados) => {
    if (erro) { res.writeHead(404); return res.end('não achei ' + pedido) }
    res.writeHead(200, { 'Content-Type': TIPOS[path.extname(arquivo).toLowerCase()] || 'application/octet-stream' })
    res.end(dados)
  })
}).listen(PORTA_SITE, () => {
  console.log('Jogo servido em http://localhost:' + PORTA_SITE)
  console.log('Cole esse endereço na fonte de link do LIVE Studio, com resolução 1080x1920.')
})

console.log('Servidor pronto em ws://localhost:' + PORTA)
console.log('Procurando a live de @' + usuario + '...')

const live = new Conexao(usuario, chave ? { signApiKey: chave } : {})

live.connect()
  .then(info => console.log('Conectado à live. ID da sala:', info.roomId))
  .catch(err => {
    console.error('Não consegui conectar:', err && err.message ? err.message : err)
    console.error('Confira se o perfil está ao vivo agora e se o nome está certo.')
  })

live.on('chat', d => {
  mandar({
    tipo: 'comentario',
    id: d.userId || d.uniqueId,
    apelido: d.nickname || d.uniqueId,
    texto: d.comment || '',
  })
})

live.on('gift', d => {
  // Presente que pode ser segurado chega em várias partes enquanto a pessoa
  // segura o botão. Só vale quando ela solta (repeatEnd), senão conta repetido.
  const segurável = d.giftType === 1
  if (segurável && !d.repeatEnd) return

  // diamondCount é o valor do presente em moedas. É ele que vira ponto no jogo,
  // então presente caro empurra mais porque custou mais.
  const moedas = d.diamondCount || 1

  mandar({
    tipo: 'presente',
    id: d.userId || d.uniqueId,
    apelido: d.nickname || d.uniqueId,
    presente: (d.giftName || '').toLowerCase(),
    quantidade: d.repeatCount || 1,
    moedas,
  })

  // Imprime e guarda o nome exato que o TikTok manda. É esse texto que vai na
  // lista `presentes` do time, dentro do index.html. Fica em arquivo porque o
  // terminal rola e some, e depois de uma live cheia não dá pra achar de novo.
  const nome = (d.giftName || '').toLowerCase()
  console.log('presente:', JSON.stringify(nome), '| moedas:', moedas,
              '| x' + (d.repeatCount || 1), '|', d.nickname)
  anotar(nome, moedas)
})

/* Catálogo dos presentes vistos, um por linha, sem repetir. */
const vistos = new Map()
function anotar(nome, moedas) {
  if (!nome || vistos.has(nome)) return
  vistos.set(nome, moedas)
  const linhas = [...vistos.entries()]
    .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
    .map(([n, m]) => String(m).padStart(6) + ' moedas   ' + n)
  fs.writeFileSync('presentes-vistos.txt',
    'Presentes que apareceram na live, do mais barato pro mais caro.\n' +
    'Copie o nome pra lista `presentes` do time, no index.html.\n\n' +
    linhas.join('\n') + '\n')
}

live.on('disconnected', () => console.log('A live caiu ou terminou.'))
live.on('streamEnd', () => console.log('A transmissão foi encerrada.'))
