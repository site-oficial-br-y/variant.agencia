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

// A biblioteca mudou de nome entre versões: nas antigas é WebcastPushConnection,
// nas novas é TikTokLiveConnection. Aceita as duas pra não quebrar na atualização.
const lib = require('tiktok-live-connector')
const Conexao = lib.TikTokLiveConnection || lib.WebcastPushConnection
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

console.log('Servidor pronto em ws://localhost:' + PORTA)
console.log('Procurando a live de @' + usuario + '...')

const live = new Conexao(usuario)

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

  mandar({
    tipo: 'presente',
    id: d.userId || d.uniqueId,
    apelido: d.nickname || d.uniqueId,
    presente: (d.giftName || '').toLowerCase(),
    quantidade: d.repeatCount || 1,
  })
  console.log(d.nickname, 'mandou', d.repeatCount || 1, 'x', d.giftName)
})

live.on('disconnected', () => console.log('A live caiu ou terminou.'))
live.on('streamEnd', () => console.log('A transmissão foi encerrada.'))
