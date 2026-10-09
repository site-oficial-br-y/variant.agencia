/* Conector da live do TikTok para o jogo.
 *
 * Faz duas coisas ao mesmo tempo:
 *   1. entra na sua live e escuta presente e comentário
 *   2. serve o jogo em http://localhost:8080
 *
 * O LIVE Studio e o OBS só aceitam endereço de internet na fonte de navegador,
 * por isso o jogo é servido aqui em vez de ser aberto como arquivo. Apontando a
 * fonte pra esse endereço em 1080x1920, o jogo é desenhado no tamanho certo,
 * sem captura de janela e sem zoom borrando.
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

const lib = require('tiktok-live-connector')
// A biblioteca trocou de nome entre gerações: na 1.x é WebcastPushConnection,
// na 2.x é TikTokLiveConnection. Aceita as duas.
const Conexao = lib.TikTokLiveConnection || lib.WebcastPushConnection
if (!Conexao) {
  console.error('Não achei a classe de conexão. Rode: npm install')
  process.exit(1)
}

/* ---------- chave de assinatura ----------
   A conexão com o TikTok passa por um serviço que assina a requisição. Sem
   chave própria ele recusa com 403 quando o limite gratuito compartilhado
   estoura. Pegue a sua em eulerstream.com e salve em chave.txt ao lado deste
   arquivo. O arquivo fica fora do repositório de propósito: é segredo seu. */
let chave = process.env.EULER_API_KEY || process.env.SIGN_API_KEY || ''
// Procura na pasta do script e na de cima: a extração do zip no Windows deixa
// uma pasta dentro da outra, e o chave.txt costuma cair na de fora.
for (const lugar of [__dirname, path.join(__dirname, '..')]) {
  try {
    const lido = (fs.readFileSync(path.join(lugar, 'chave.txt'), 'utf8') || '').trim()
    if (lido) { chave = lido; break }
  } catch {}
}
if (chave) {
  // Cada geração lê a chave de um lugar: a 2.x usa SignConfig.apiKey, a 1.x
  // manda nos parâmetros extras do assinador. Define as duas.
  if (lib.SignConfig) lib.SignConfig.apiKey = chave
  if (lib.signatureProvider && lib.signatureProvider.config) {
    lib.signatureProvider.config.extraParams =
      Object.assign({}, lib.signatureProvider.config.extraParams, { apiKey: chave })
  }
  console.log('Chave de assinatura carregada.')
} else {
  console.log('Sem chave de assinatura. Se der 403, salve a chave de')
  console.log('eulerstream.com num arquivo chamado chave.txt nesta pasta.')
}

const usuario = (process.argv[2] || '').replace('@', '')
if (!usuario) {
  console.error('Faltou o usuário. Exemplo: node conector.js honkponk')
  process.exit(1)
}

/* ---------- canal com o jogo ---------- */
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
  for (const ws of abertos) if (ws.readyState === 1) ws.send(texto)
}

/* ---------- servidor do jogo ---------- */
const PORTA_SITE = 8080
const TIPOS = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css',
  '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
}

http.createServer((req, res) => {
  let pedido = decodeURIComponent((req.url || '/').split('?')[0])
  if (pedido === '/') pedido = '/index.html'
  const arquivo = path.join(__dirname, path.normalize(pedido).replace(/^(\.\.[\/\\])+/, ''))
  if (!arquivo.startsWith(__dirname)) { res.writeHead(403); return res.end('fora da pasta') }
  fs.readFile(arquivo, (erro, dados) => {
    if (erro) { res.writeHead(404); return res.end('não achei ' + pedido) }
    res.writeHead(200, { 'Content-Type': TIPOS[path.extname(arquivo).toLowerCase()] || 'application/octet-stream' })
    res.end(dados)
  })
}).listen(PORTA_SITE, () => {
  console.log('Jogo servido em http://localhost:' + PORTA_SITE)
  console.log('Cole esse endereço na fonte de link do LIVE Studio, em 1080x1920.')
})

console.log('Canal com o jogo em ws://localhost:' + PORTA)
console.log('Procurando a live de @' + usuario + '...')

/* ---------- live ----------
   O formato do evento mudou entre as gerações da biblioteca: na 1.x os campos
   vinham soltos (giftName, nickname), na 2.x vêm aninhados (gift.name,
   user.nickname). Os leitores abaixo tentam os dois, então o conector não
   quebra se a versão instalada mudar. */
const live = new Conexao(usuario, chave ? { signApiKey: chave } : {})

const quemE = d => ({
  id: String((d.user && d.user.id) || d.userId || (d.user && d.user.nickname) || d.uniqueId || ''),
  apelido: (d.user && d.user.nickname) || d.nickname || d.uniqueId || 'alguém',
})
const presenteDe = d => {
  const g = d.gift || d.giftDetails || {}
  return {
    nome: String(g.name || d.giftName || '').toLowerCase(),
    moedas: Number(g.diamondCount || d.diamondCount || 0) || 1,
    seguravel: Number(g.type !== undefined ? g.type : d.giftType) === 1,
  }
}

live.connect()
  .then(info => console.log('Conectado à live. Sala:', (info && info.roomId) || ''))
  .catch(err => {
    console.error('Não consegui conectar:', (err && err.message) || err)
    console.error('Confira se o perfil está ao vivo agora e se o nome está certo.')
  })

live.on('chat', d => {
  const quem = quemE(d)
  mandar({ tipo: 'comentario', id: quem.id, apelido: quem.apelido, texto: d.content || d.comment || '' })
})

live.on('gift', d => {
  // Presente que pode ser segurado chega em várias partes enquanto a pessoa
  // segura o botão. Só vale quando ela solta, senão conta repetido.
  const p = presenteDe(d)
  if (p.seguravel && !d.repeatEnd) return

  const quem = quemE(d)
  const vezes = Number(d.repeatCount) || 1
  mandar({
    tipo: 'presente',
    id: quem.id,
    apelido: quem.apelido,
    presente: p.nome,
    quantidade: vezes,
    moedas: p.moedas,
  })

  console.log('presente:', JSON.stringify(p.nome), '| moedas:', p.moedas,
              '| x' + vezes, '|', quem.apelido)
  anotar(p.nome, p.moedas)
})

/* Catálogo dos presentes vistos, um por linha, sem repetir. Fica em arquivo
   porque o terminal rola e some no meio de uma live cheia. */
const vistos = new Map()
function anotar(nome, moedas) {
  if (!nome || vistos.has(nome)) return
  vistos.set(nome, moedas)
  const linhas = [...vistos.entries()]
    .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
    .map(([n, m]) => String(m).padStart(6) + ' moedas   ' + n)
  fs.writeFileSync(path.join(__dirname, 'presentes-vistos.txt'),
    'Presentes que apareceram na live, do mais barato pro mais caro.\n\n' +
    linhas.join('\n') + '\n')
}

live.on('disconnected', () => console.log('A live caiu ou terminou.'))
live.on('streamEnd', () => console.log('A transmissão foi encerrada.'))
