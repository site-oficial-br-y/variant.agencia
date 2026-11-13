// EHNPOSTOR: telas, modo presencial (um celular) e modo online (servidor no Supabase).
'use strict';
const SB = 'https://yowwwtstwdeudbgzddcf.supabase.co/rest/v1/rpc/';
const CHAVE = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlvd3d3dHN0d2RldWRiZ3pkZGNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4Njc1NDIsImV4cCI6MjEwODQ0MzU0Mn0.w_kpeJlJCk84kA7ejQpY0zd_wBjLOwGOmIkZ2Yecd_w';
const EMOS = ['😂', '🤨', '😱', '👀', '🤡', '🔥', '🤫', '💀'];
const $ = s => document.querySelector(s);
const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html !== undefined) e.innerHTML = html; return e; };
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const rosto = b => 'bonecos/r' + b + '.webp';
const guarda = {
  ler(k, pad) { try { const v = localStorage.getItem('ehn_' + k); return v === null ? pad : JSON.parse(v); } catch { return pad; } },
  pôr(k, v) { try { localStorage.setItem('ehn_' + k, JSON.stringify(v)); } catch { } }
};
const embaralhar = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

// ---------- som e vibração ----------
let actx = null;
function som(tipo) {
  try {
    actx = actx || new (window.AudioContext || window.webkitAudioContext)();
    const notas = { vez: [[660, .09], [880, .14]], pop: [[520, .06]], voto: [[330, .08], [262, .12]], fala: [[740, .07]],
      ruim: [[220, .18], [165, .3]], bom: [[523, .1], [659, .1], [784, .22]], vitoria: [[523, .1], [659, .1], [784, .1], [1047, .35]], tique: [[1200, .03]] }[tipo];
    if (!notas) return;
    let t = actx.currentTime;
    for (const [f, d] of notas) {
      const o = actx.createOscillator(), g = actx.createGain();
      o.type = tipo === 'ruim' ? 'sawtooth' : 'triangle'; o.frequency.value = f;
      g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(.16, t + .015); g.gain.exponentialRampToValueAtTime(.0001, t + d);
      o.connect(g).connect(actx.destination); o.start(t); o.stop(t + d + .02); t += d * .85;
    }
  } catch { }
}
const vibrar = p => { try { navigator.vibrate && navigator.vibrate(p); } catch { } };

// ---------- navegação ----------
const pilha = [];
function ir(id, empilhar = true) {
  document.querySelectorAll('.tela').forEach(t => t.hidden = t.id !== id);
  if (empilhar && pilha[pilha.length - 1] !== id) pilha.push(id);
}
function voltar() { pilha.pop(); ir(pilha[pilha.length - 1] || 'inicio', false); }
document.querySelectorAll('[data-voltar]').forEach(b => b.onclick = () => { som('pop'); voltar(); });
function toast(txt, ms = 2200) {
  const t = el('div', 'toast', esc(txt)); $('#jogo').hidden ? document.body.appendChild(t) : $('#jogo').appendChild(t);
  if (!$('#jogo').hidden) t.style.position = 'absolute'; else { t.style.position = 'fixed'; }
  setTimeout(() => t.remove(), ms);
}

// ---------- perfil ----------
let perfil = guarda.ler('perfil', null);
if (!perfil) { perfil = { nome: '', boneco: Math.floor(Math.random() * 16) }; }
function mostrarPerfil() {
  $('#perfil-rosto').src = rosto(perfil.boneco);
  $('#perfil-nome').textContent = perfil.nome || 'Escolhe seu nome';
}
mostrarPerfil();
let aoEscolherBoneco = null, bonecoTemp = 0, ocupados = [];
function abrirPicker({ titulo, comNome, atual, nome, bloqueados = [], ok }) {
  $('#perfil-titulo').textContent = titulo;
  $('#perfil-nome-cartao').hidden = !comNome;
  $('#perfil-input').value = nome || '';
  bonecoTemp = atual; ocupados = bloqueados; aoEscolherBoneco = ok;
  const g = $('#grade-bonecos'); g.innerHTML = '';
  for (let i = 0; i < 16; i++) {
    const b = el('button', (i === atual ? 'on ' : '') + (bloqueados.includes(i) ? 'ocupado' : ''), `<img src="bonecos/${i}.webp" alt=""><span>${NOMES_BONECO[i]}</span>`);
    b.onclick = () => { bonecoTemp = i; som('pop'); g.querySelectorAll('button').forEach((x, k) => x.classList.toggle('on', k === i)); };
    g.appendChild(b);
  }
  ir('perfil');
}
$('#perfil-ok').onclick = () => {
  const nome = $('#perfil-input').value.trim();
  if (!$('#perfil-nome-cartao').hidden && !nome) { $('#perfil-input').focus(); toast('Coloca um nome'); return; }
  som('bom'); const f = aoEscolherBoneco; voltar(); f && f(bonecoTemp, nome);
};
$('#perfil-chip').onclick = () => abrirPicker({ titulo: 'Seu boneco', comNome: true, atual: perfil.boneco, nome: perfil.nome,
  ok: (b, n) => { perfil = { nome: n, boneco: b }; guarda.pôr('perfil', perfil); mostrarPerfil(); } });
function garantirPerfil(depois) {
  if (perfil.nome) return depois();
  abrirPicker({ titulo: 'Quem é você?', comNome: true, atual: perfil.boneco, nome: '',
    ok: (b, n) => { perfil = { nome: n, boneco: b }; guarda.pôr('perfil', perfil); mostrarPerfil(); depois(); } });
}
$('#b-ajuda').onclick = () => { som('pop'); ir('ajuda'); };

// ---------- mesa (compartilhada) ----------
const mesa = new Mesa($('#cv'));
mesa.topo = 0.17; mesa.baixo = 0.24;
let modoToque = null, emoSel = null;   // 'voto' | 'emote'
function montarEmotes(ativo) {
  const box = $('#j-emotes'); box.hidden = !ativo; if (!ativo) { box.classList.remove('aberto'); return; }
  if (box.childElementCount) return;
  const abre = el('button', 'abre', '😀'); abre.setAttribute('aria-label', 'Emotes');
  abre.onclick = () => { som('pop'); const ab = box.classList.toggle('aberto'); abre.textContent = ab ? '✕' : '😀';
    if (!ab && modoToque === 'emote') { emoSel = null; modoToque = modoAnterior; modoAnterior = null; atualizarSelecao(); } };
  box.appendChild(abre);
  for (const e of EMOS) {
    const b = el('button', '', e);
    b.onclick = () => {
      if (emoSel === e) { emoSel = null; modoToque = modoAnterior; atualizarSelecao(); return; }
      emoSel = e; modoAnterior = modoToque === 'emote' ? modoAnterior : modoToque; modoToque = 'emote'; som('pop'); atualizarSelecao();
    };
    box.appendChild(b);
  }
}
let modoAnterior = null;
function atualizarSelecao() {
  const box = $('#j-emotes');
  box.querySelectorAll('button').forEach(b => b.classList.toggle('on', b.textContent === emoSel));
  box.querySelector('.dica')?.remove();
  if (modoToque === 'emote') box.appendChild(el('div', 'dica', 'Toca em alguém'));
  mesa.selecionavel = modoToque === 'emote' ? (i => On.ativo && On.assentoMeu !== i)
    : modoToque === 'voto' ? (i => votoPermitido(i)) : null;
}
mesa.aoTocar = i => {
  if (modoToque === 'emote' && emoSel) { mandarEmote(i, emoSel); emoSel = null; modoToque = modoAnterior; modoAnterior = null; atualizarSelecao();
    const box = $('#j-emotes'); box.classList.remove('aberto'); box.querySelector('.abre').textContent = '😀'; return; }
  if (modoToque === 'voto') { escolherVoto(i); }
};
function votoPermitido(i) { return Pres.ativo ? Pres.votavel(i) : On.votavel(i); }
function escolherVoto(i) { som('pop'); mesa.selecionado = i; (Pres.ativo ? Pres : On).painel(); }

// relógio do topo
function relogio(fimMs) {
  const r = $('#j-relogio');
  if (!fimMs) { r.hidden = true; return; }
  const s = Math.max(0, Math.ceil((fimMs - agoraServ()) / 1000));
  r.hidden = false; r.textContent = s + 's'; r.classList.toggle('pouco', s <= 5);
  if (s <= 5 && s > 0 && r.dataset.ult != s) { som('tique'); r.dataset.ult = s; }
}
let deltaServ = 0;
const agoraServ = () => Date.now() + deltaServ;

// histórico de palavras
$('#j-hist').onclick = () => { som('pop'); desenharHistorico(); $('#j-historico').hidden = false; };
$('#hist-fechar').onclick = () => { $('#j-historico').hidden = true; };
function desenharHistorico() {
  const L = $('#hist-lista'); L.innerHTML = '';
  const js = Pres.ativo ? Pres.jogadoresHist() : On.jogadoresHist();
  for (const j of js) {
    const d = el('div', 'hist-j' + (j.vivo === false ? ' morto' : ''));
    d.innerHTML = `<img src="${rosto(j.boneco)}" alt=""><div><b>${esc(j.nome)}${j.impostor === true ? '<span class="tag-imp">IMPOSTOR</span>' : ''}${j.vivo === false && j.impostor !== true ? ' 💀' : ''}</b>${
      j.falas.length ? j.falas.map(f => `<span class="pal${f === '—' ? ' vazio' : ''}">${esc(f === '—' ? 'não falou' : f)}</span>`).join('') : '<span class="pal vazio">ainda não falou</span>'}</div>`;
    L.appendChild(d);
  }
}

// modal
function modal(html, botoes = []) {
  const m = $('#j-modal'); m.innerHTML = '';
  if (!html) return;
  const fundo = el('div', 'modal'), cx = el('div', 'caixa', html);
  if (botoes.length) {
    const ac = el('div', 'acoes'); ac.style.flexDirection = botoes.length > 2 ? 'column' : 'row';
    for (const [txt, cls, fn] of botoes) { const b = el('button', 'btn ' + (cls || ''), txt); b.onclick = () => { som('pop'); fn(); }; ac.appendChild(b); }
    cx.appendChild(ac);
  }
  fundo.appendChild(cx); m.appendChild(fundo);
}

// confete
function confete() {
  const cv = $('#confete'), g = cv.getContext('2d'), W = cv.width = innerWidth, H = cv.height = innerHeight;
  const cores = ['#ffc21a', '#ff5a4f', '#4ade80', '#fbe9d0', '#7ab8ff', '#c084fc'];
  const ps = Array.from({ length: 140 }, () => ({ x: W / 2 + (Math.random() - .5) * 80, y: H * .35, vx: (Math.random() - .5) * 14, vy: -Math.random() * 15 - 4,
    r: Math.random() * 6 + 4, c: cores[Math.floor(Math.random() * cores.length)], a: Math.random() * 6, va: (Math.random() - .5) * .4 }));
  let n = 0;
  (function q() {
    g.clearRect(0, 0, W, H);
    for (const p of ps) { p.vy += .35; p.vx *= .99; p.x += p.vx; p.y += p.vy; p.a += p.va;
      g.save(); g.translate(p.x, p.y); g.rotate(p.a); g.fillStyle = p.c; g.fillRect(-p.r, -p.r * .4, p.r * 2, p.r * .8); g.restore(); }
    if (++n < 200) requestAnimationFrame(q); else g.clearRect(0, 0, W, H);
  })();
}

// ======================================================================
//                          MODO PRESENCIAL
// ======================================================================
const Pres = {
  ativo: false,
  cfg: guarda.ler('pres_cfg', null) || { jogs: [], cats: [], impostores: 1, dica: true, chute: true, tempo: 0 },
  usadas: new Set(),
  abrir() {
    if (!this.cfg.jogs.length) this.cfg.jogs = [{ nome: perfil.nome || 'Jogador 1', boneco: perfil.boneco }];
    while (this.cfg.jogs.length < 3) this.addJog(false);
    this.desenharConfig(); ir('pres');
  },
  addJog(redesenha = true) {
    if (this.cfg.jogs.length >= 8) { toast('Máximo de 8 na mesa'); return; }
    const usados = this.cfg.jogs.map(j => j.boneco), livres = [...Array(16).keys()].filter(i => !usados.includes(i));
    const b = livres[Math.floor(Math.random() * livres.length)];
    this.cfg.jogs.push({ nome: NOMES_BONECO[b], boneco: b });
    if (redesenha) { som('pop'); this.desenharConfig(); }
  },
  maxImp() { return Math.max(1, Math.floor((this.cfg.jogs.length - 1) / 2)); },
  salvar() { guarda.pôr('pres_cfg', this.cfg); },
  desenharConfig() {
    const c = this.cfg;
    c.impostores = Math.min(c.impostores, this.maxImp());
    const L = $('#pres-jogs'); L.innerHTML = '';
    c.jogs.forEach((j, k) => {
      const r = el('div', 'jog');
      r.innerHTML = `<img src="${rosto(j.boneco)}" alt="trocar boneco"><input class="campo" maxlength="14" value="${esc(j.nome)}"><button class="x" aria-label="remover">✕</button>`;
      r.querySelector('img').onclick = () => abrirPicker({ titulo: 'Boneco de ' + (j.nome || 'jogador'), comNome: false, atual: j.boneco,
        bloqueados: c.jogs.filter((_, q) => q !== k).map(q => q.boneco), ok: b => { j.boneco = b; this.salvar(); this.desenharConfig(); } });
      r.querySelector('input').oninput = e => { j.nome = e.target.value; this.salvar(); };
      r.querySelector('.x').onclick = () => { if (c.jogs.length <= 3) { toast('Precisa de pelo menos 3'); return; } c.jogs.splice(k, 1); som('pop'); this.salvar(); this.desenharConfig(); };
      L.appendChild(r);
    });
    $('#pres-n').textContent = c.jogs.length + ' de 8';
    $('#pres-add').hidden = c.jogs.length >= 8;
    const C = $('#pres-cats'); C.innerHTML = '';
    const todas = el('span', 'chip' + (c.cats.length === 0 ? ' on' : ''), '🎲 Todas'); todas.onclick = () => { c.cats = []; som('pop'); this.salvar(); this.desenharConfig(); }; C.appendChild(todas);
    for (const cat of CATEGORIAS) {
      const ch = el('span', 'chip' + (c.cats.includes(cat.nome) ? ' on' : ''), cat.emoji + ' ' + esc(cat.nome));
      ch.onclick = () => { const i = c.cats.indexOf(cat.nome); i >= 0 ? c.cats.splice(i, 1) : c.cats.push(cat.nome); som('pop'); this.salvar(); this.desenharConfig(); };
      C.appendChild(ch);
    }
    $('#imp-n').textContent = c.impostores;
    $('#pres-imp-info').textContent = `Com ${c.jogs.length} jogadores dá até ${this.maxImp()}.`;
    $('#pres-dica').classList.toggle('on', c.dica);
    $('#pres-chute').classList.toggle('on', c.chute);
    const T = $('#pres-tempo'); T.innerHTML = '';
    for (const [v, txt] of [[0, 'Sem limite'], [20, '20s'], [30, '30s'], [45, '45s']]) {
      const ch = el('span', 'chip' + (c.tempo === v ? ' on' : ''), txt); ch.onclick = () => { c.tempo = v; som('pop'); this.salvar(); this.desenharConfig(); }; T.appendChild(ch);
    }
  },
  sortear() {
    const cats = CATEGORIAS.filter(c => !this.cfg.cats.length || this.cfg.cats.includes(c.nome));
    let pool = [];
    for (const c of cats) for (const [p, d] of c.itens) pool.push({ p, d, cat: c.nome });
    let livres = pool.filter(x => !this.usadas.has(x.p));
    if (!livres.length) { this.usadas.clear(); livres = pool; }
    const w = livres[Math.floor(Math.random() * livres.length)]; this.usadas.add(w.p); return w;
  },
  iniciar() {
    const c = this.cfg;
    for (const j of c.jogs) if (!j.nome.trim()) { toast('Tem jogador sem nome'); return; }
    const nomes = c.jogs.map(j => j.nome.trim().toLowerCase());
    if (new Set(nomes).size !== nomes.length) { toast('Tem nome repetido'); return; }
    const w = this.sortear();
    const imps = embaralhar([...c.jogs.keys()]).slice(0, Math.min(c.impostores, this.maxImp()));
    this.G = { palavra: w.p, dica: w.d, cat: w.cat, rodada: 1, vez: -1, fase: 'revelar', falou: 0,
      jog: c.jogs.map((j, k) => ({ nome: j.nome.trim(), boneco: j.boneco, imp: imps.includes(k), vivo: true, falas: [] })),
      primeiro: Math.floor(Math.random() * c.jogs.length) };
    this.revIdx = 0; this.mostrarRevelar(); ir('revelar');
  },
  mostrarRevelar() {
    const G = this.G, j = G.jog[this.revIdx];
    $('#rev-cont').textContent = `${this.revIdx + 1} de ${G.jog.length}`;
    $('#rev-rosto').src = rosto(j.boneco); $('#rev-nome').textContent = j.nome.toUpperCase();
    const v = $('#rev-verso');
    v.innerHTML = j.imp
      ? `<div class="cat">${esc(j.nome)}, você é...</div><div class="imp">O IMPOSTOR</div>${this.cfg.dica ? `<div class="cat" style="margin-top:8px">sua dica</div><div class="palavra" style="font-size:30px">${esc(G.dica)}</div>` : '<p class="aviso">Sem dica. Se vira!</p>'}<p class="aviso">Finge que sabe a palavra e não deixa ninguém desconfiar.</p>`
      : `<div class="cat">${esc(j.nome)}, a palavra é</div><div class="palavra">${esc(G.palavra)}</div><div class="cat">categoria: ${esc(G.cat)}</div><p class="aviso">Fala algo ligado, mas não entrega fácil pro impostor.</p>`;
    $('#carta').classList.toggle('imp', j.imp); $('#carta').classList.remove('aberta');
    $('#rev-prox').disabled = true;
    $('#rev-prox').textContent = this.revIdx === G.jog.length - 1 ? 'COMEÇAR A RODADA ›' : 'PASSA PRO ' + G.jog[this.revIdx + 1].nome.toUpperCase() + ' ›';
  },
  proximoRevelar() {
    som('pop');
    if (this.revIdx < this.G.jog.length - 1) { this.revIdx++; this.mostrarRevelar(); return; }
    this.comecarJogo();
  },
  comecarJogo() {
    this.ativo = true; On.ativo = false;
    const G = this.G; G.fase = 'falando';
    mesa.definir(G.jog.map((j, i) => ({ id: 'p' + i, boneco: j.boneco, nome: j.nome, vivo: true })));
    mesa.calar(); mesa.saindo = {}; mesa.marcas = {}; mesa.selecionado = null;
    modoToque = null; atualizarSelecao(); montarEmotes(false);
    $('#j-minha').hidden = true; $('#j-chat').classList.remove('on'); modal('');
    $('#j-chatbtn') && ($('#j-chatbtn').hidden = true);
    ir('jogo');
    G.vez = this.proxVivo(G.primeiro - 1); mesa.girarPara(G.vez, true); this.iniciarVez();
  },
  proxVivo(de) { const G = this.G, N = G.jog.length; for (let k = 1; k <= N; k++) { const i = ((de + k) % N + N) % N; if (G.jog[i].vivo) return i; } return -1; },
  iniciarVez() {
    const G = this.G; mesa.girarPara(G.vez); som('vez');
    G.fimVez = this.cfg.tempo ? Date.now() + this.cfg.tempo * 1000 + 900 : null;
    this.painel();
  },
  falou(texto) {
    const G = this.G, j = G.jog[G.vez], t = (texto || '').trim();
    if (t) {
      const n = Pres.norm(t);
      if (!j.imp && n === Pres.norm(G.palavra)) { toast('Não pode falar a palavra secreta!'); return; }
      if (G.jog.some(q => q.falas.some(f => Pres.norm(f) === n))) { toast('Essa já falaram!'); return; }
      mesa.falar(G.vez, t); som('fala');
    } else mesa.pular(G.vez);
    j.falas.push(t || '✓');
    G.falou++;
    const vivos = G.jog.filter(q => q.vivo).length;
    if (G.falou >= vivos) { G.fase = 'fimRodada'; G.vez = -1; G.fimVez = null; this.painel(); return; }
    G.vez = this.proxVivo(G.vez); setTimeout(() => this.iniciarVez(), t ? 700 : 150);
  },
  norm: s => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]/g, ''),
  votavel(i) { return this.G && this.G.fase === 'votacao' && this.G.jog[i].vivo; },
  painel() {
    const G = this.G, P = $('#j-painel'); P.innerHTML = '';
    const vivos = G.jog.filter(q => q.vivo).length;
    $('#j-fase').textContent = { falando: 'RODADA ' + G.rodada, fimRodada: 'TODO MUNDO FALOU', votacao: 'VOTAÇÃO', fim: 'FIM' }[G.fase] || '';
    $('#j-sub').textContent = `${vivos} na mesa · categoria: ${G.cat}`;
    const cx = el('div', 'caixa'); P.appendChild(cx);
    if (G.fase === 'falando') {
      const j = G.jog[G.vez];
      mesa.vezAtiva = true;
      cx.innerHTML = `<div class="tit">Vez de ${esc(j.nome)}</div><div class="sub">Fala UMA palavra em voz alta. Se quiser, anota aqui pra ficar no histórico.</div>
        <div class="envio"><input class="campo" id="p-fala" maxlength="18" placeholder="anotar (opcional)" autocomplete="off"><button class="btn verde" id="p-falou">FALOU ✓</button></div>
        <div class="acoes"><button class="btn escuro peq" id="p-emerg">🚨 VOTAR AGORA</button></div>`;
      const ir2 = () => this.falou($('#p-fala').value);
      $('#p-falou').onclick = ir2; $('#p-fala').onkeydown = e => { if (e.key === 'Enter') ir2(); };
      $('#p-emerg').onclick = () => { som('ruim'); this.irVotacao(); };
    } else if (G.fase === 'fimRodada') {
      cx.innerHTML = `<div class="tit">Discutam! Quem tá estranho?</div><div class="sub">Abre o 📜 pra ver o que cada um falou.</div>
        <div class="acoes"><button class="btn creme" id="p-mais">OUTRA RODADA</button><button class="btn vermelho" id="p-votar">VOTAR</button></div>`;
      $('#p-mais').onclick = () => { som('pop'); G.rodada++; G.falou = 0; G.fase = 'falando'; G.primeiro = this.proxVivo(G.primeiro); G.vez = G.primeiro; mesa.calar(); this.iniciarVez(); };
      $('#p-votar').onclick = () => { som('ruim'); this.irVotacao(); };
    } else if (G.fase === 'votacao') {
      const s = mesa.selecionado;
      cx.innerHTML = s === null || s === undefined
        ? `<div class="tit">Quem é o impostor?</div><div class="sub">Decidam juntos e toquem no boneco na mesa.</div><div class="acoes"><button class="btn creme peq" id="p-pular">NINGUÉM, OUTRA RODADA</button></div>`
        : `<div class="tit">Eliminar ${esc(G.jog[s].nome)}?</div><div class="acoes"><button class="btn creme peq" id="p-cancelar">TROCAR</button><button class="btn vermelho" id="p-elim">ELIMINAR</button></div>`;
      if ($('#p-pular')) $('#p-pular').onclick = () => { modoToque = null; atualizarSelecao(); G.rodada++; G.falou = 0; G.fase = 'falando'; G.primeiro = this.proxVivo(G.primeiro); G.vez = G.primeiro; mesa.calar(); this.iniciarVez(); };
      if ($('#p-cancelar')) $('#p-cancelar').onclick = () => { mesa.selecionado = null; this.painel(); };
      if ($('#p-elim')) $('#p-elim').onclick = () => this.eliminar(s);
    } else cx.remove();
  },
  irVotacao() { const G = this.G; G.fase = 'votacao'; G.vez = -1; G.fimVez = null; mesa.calar(); mesa.vezAtiva = false; mesa.selecionado = null; modoToque = 'voto'; atualizarSelecao(); this.painel(); },
  eliminar(i) {
    const G = this.G, j = G.jog[i];
    j.vivo = false; modoToque = null; atualizarSelecao(); mesa.selecionado = null;
    mesa.girarPara(i); mesa.eliminar(i);
    mesa.assentos[i].vivo = false;
    $('#j-painel').innerHTML = '';
    som(j.imp ? 'bom' : 'ruim'); vibrar(j.imp ? [60, 40, 60] : 200);
    setTimeout(() => {
      modal(`<img class="rosto-g cinza" src="${rosto(j.boneco)}" alt=""><div class="grande">${esc(j.nome)}</div>
        <div class="carimbo ${j.imp ? 'vermelho' : 'verde'}">${j.imp ? 'ERA IMPOSTOR!' : 'ERA INOCENTE'}</div>
        <p class="sub" style="margin-top:8px">${j.imp ? (G.jog.some(q => q.vivo && q.imp) ? 'Mas ainda tem impostor na mesa...' : 'Pegaram o impostor!') : 'Vocês eliminaram um inocente...'}</p>`,
        [['CONTINUAR', '', () => { modal(''); this.depoisEliminar(i); }]]);
    }, 1000);
  },
  depoisEliminar(i) {
    const G = this.G, j = G.jog[i];
    if (j.imp && this.cfg.chute) {
      modal(`<img class="rosto-g" src="${rosto(j.boneco)}" alt=""><div class="grande">Última chance!</div><p class="sub">${esc(j.nome)}, fala em voz alta qual você acha que era a palavra.</p>`,
        [['MOSTRAR A PALAVRA', '', () => modal(`<div class="sub">A palavra era</div><div class="grande">${esc(G.palavra)}</div><p class="sub">${esc(j.nome)} acertou?</p>`,
          [['ERROU', 'creme', () => { modal(''); this.checarFim(); }], ['ACERTOU', 'vermelho', () => { modal(''); this.fim('impostores', j.nome + ' acertou a palavra!'); }]])]]);
      return;
    }
    this.checarFim();
  },
  checarFim() {
    const G = this.G, imp = G.jog.filter(q => q.vivo && q.imp).length, ino = G.jog.filter(q => q.vivo && !q.imp).length;
    if (imp === 0) return this.fim('inocentes');
    if (imp >= ino) return this.fim('impostores');
    G.rodada++; G.falou = 0; G.fase = 'falando'; G.primeiro = this.proxVivo(G.primeiro); G.vez = G.primeiro; mesa.calar(); this.iniciarVez();
  },
  fim(quem, motivo) {
    const G = this.G; G.fase = 'fim'; mesa.vezAtiva = false; $('#j-painel').innerHTML = ''; relogio(null);
    G.jog.forEach((j, i) => { mesa.assentos[i].vivo = j.vivo; });
    som('vitoria'); confete();
    const imps = G.jog.filter(q => q.imp);
    modal(`<div class="grande">${quem === 'inocentes' ? 'OS INOCENTES VENCERAM!' : 'OS IMPOSTORES VENCERAM!'}</div>
      ${motivo ? `<p class="sub">${esc(motivo)}</p>` : ''}
      <div class="sub" style="margin-top:6px">A palavra era <b>${esc(G.palavra)}</b></div>
      <div class="sub">${imps.length > 1 ? 'Os impostores eram' : 'O impostor era'}</div>
      <div class="lista-imp">${imps.map(q => `<figure><img src="${rosto(q.boneco)}" alt="">${esc(q.nome)}</figure>`).join('')}</div>`,
      [['JOGAR DE NOVO', 'verde', () => { modal(''); this.iniciar(); }], ['MENU', 'creme', () => { modal(''); this.sair(); }]]);
  },
  sair() { this.ativo = false; mesa.definir([]); modal(''); relogio(null); pilha.length = 0; ir('inicio'); },
  jogadoresHist() { return this.G.jog.map(j => ({ nome: j.nome, boneco: j.boneco, vivo: j.vivo, impostor: !j.vivo || this.G.fase === 'fim' ? j.imp : null, falas: j.falas })); },
  tick() {
    const G = this.G; if (!this.ativo || !G) return;
    if (G.fase === 'falando' && G.fimVez) {
      relogio(G.fimVez + deltaServ);
      if (Date.now() > G.fimVez) { toast('Acabou o tempo de ' + G.jog[G.vez].nome); this.falou(''); }
    } else relogio(null);
  }
};
$('#b-presencial').onclick = () => { som('pop'); Pres.abrir(); };
$('#pres-add').onclick = () => { Pres.addJog(); Pres.salvar(); };
$('#imp-menos').onclick = () => { Pres.cfg.impostores = Math.max(1, Pres.cfg.impostores - 1); som('pop'); Pres.salvar(); Pres.desenharConfig(); };
$('#imp-mais').onclick = () => { if (Pres.cfg.impostores >= Pres.maxImp()) { toast('Precisa de mais gente pra isso'); return; } Pres.cfg.impostores++; som('pop'); Pres.salvar(); Pres.desenharConfig(); };
$('#pres-dica').onclick = () => { Pres.cfg.dica = !Pres.cfg.dica; som('pop'); Pres.salvar(); Pres.desenharConfig(); };
$('#pres-chute').onclick = () => { Pres.cfg.chute = !Pres.cfg.chute; som('pop'); Pres.salvar(); Pres.desenharConfig(); };
$('#pres-iniciar').onclick = () => { som('bom'); Pres.iniciar(); };
$('#rev-prox').onclick = () => Pres.proximoRevelar();
(function cartaSegura() {
  const c = $('#carta');
  const abre = e => { e.preventDefault(); c.classList.add('aberta'); vibrar(30); $('#rev-prox').disabled = false; };
  const fecha = () => c.classList.remove('aberta');
  c.addEventListener('pointerdown', abre); c.addEventListener('pointerup', fecha); c.addEventListener('pointerleave', fecha); c.addEventListener('pointercancel', fecha);
  c.addEventListener('contextmenu', e => e.preventDefault());
})();

// ======================================================================
//                            MODO ONLINE
// ======================================================================
let token = guarda.ler('token', null);
if (!token) { token = Array.from(crypto.getRandomValues(new Uint8Array(18)), b => b.toString(16).padStart(2, '0')).join(''); guarda.pôr('token', token); }
async function rpc(f, args) {
  const r = await fetch(SB + f, { method: 'POST', headers: { apikey: CHAVE, Authorization: 'Bearer ' + CHAVE, 'Content-Type': 'application/json' }, body: JSON.stringify(args) });
  if (!r.ok) throw new Error('http ' + r.status);
  return r.json();
}
const ERROS = { nao_existe: 'Essa sala não existe', cheia: 'Sala cheia (8 jogadores)', poucos: 'Precisa de pelo menos 3 na sala', so_o_dono: 'Só o dono da sala pode', em_jogo: 'O jogo já começou',
  nao_e_sua_vez: 'Não é sua vez', tamanho: 'Palavra muito curta ou longa', uma_palavra: 'Só UMA palavra, sem espaço', secreta: 'Não pode falar a palavra secreta!',
  repetida: 'Essa já falaram!', agora_nao: 'Agora não dá', alvo: 'Não dá pra votar nesse', chat_fechado: 'O chat abre depois que todo mundo falar', calma: 'Calma aí',
  boneco_em_uso: 'Esse boneco já tá na mesa', fora: 'Você não está nessa sala', sem_palavras: 'Sem palavras no servidor' };

const On = {
  ativo: false, codigo: null, est: null, desde: 0, rodando: false, vistoFalas: {}, ultFase: null, ultVez: null, ultUlt: '', naoLidas: 0, assentoMeu: -1, ids: [], partida: -1,
  async entrar(codigo, criar) {
    const err = $('#on-erro'); err.textContent = '';
    try {
      const r = criar ? await rpc('ehn_criar', { p_nome: perfil.nome, p_boneco: perfil.boneco, p_token: token })
        : await rpc('ehn_entrar', { p_codigo: codigo, p_nome: perfil.nome, p_boneco: perfil.boneco, p_token: token });
      if (r.erro) { err.textContent = ERROS[r.erro] || r.erro; som('ruim'); return; }
      this.codigo = r.codigo; guarda.pôr('sala', { codigo: r.codigo, quando: Date.now() });
      this.comecar();
    } catch { err.textContent = 'Sem conexão. Tenta de novo.'; som('ruim'); }
  },
  comecar() {
    Pres.ativo = false; this.ativo = true; this.est = null; this.desde = 0; this.vistoFalas = {}; this.ultFase = null; this.ultVez = null; this.ultUlt = ''; this.partida = -1;
    $('#chat-msgs').innerHTML = ''; this.naoLidas = 0;
    mesa.definir([]); mesa.saindo = {}; mesa.marcas = {}; mesa.selecionado = null; mesa.calar();
    modoToque = null; emoSel = null; montarEmotes(true); atualizarSelecao(); modal('');
    this.botaoChat();
    ir('jogo');
    history.replaceState(null, '', '?sala=' + this.codigo);
    if (!this.rodando) this.laco();
  },
  botaoChat() {
    if ($('#j-chatbtn')) { $('#j-chatbtn').hidden = false; return; }
    const b = el('button', 'ico', '💬<span class="bolinha" hidden>0</span>'); b.id = 'j-chatbtn';
    $('#j-hist').before(b);
    b.onclick = () => { som('pop'); $('#j-chat').classList.add('on'); this.naoLidas = 0; this.bolinha(); setTimeout(() => { const m = $('#chat-msgs'); m.scrollTop = m.scrollHeight; }, 50); };
  },
  bolinha() { const b = $('#j-chatbtn .bolinha'); if (!b) return; b.hidden = !this.naoLidas; b.textContent = this.naoLidas > 9 ? '9+' : this.naoLidas; },
  async laco() {
    this.rodando = true;
    while (this.ativo) {
      try {
        const e = await rpc('ehn_estado', { p_codigo: this.codigo, p_token: token, p_desde: this.desde });
        if (!this.ativo) break;
        if (e.erro) { this.sairLocal('Você saiu da sala'); break; }
        deltaServ = e.agora - Date.now();
        this.aplicar(e);
      } catch { $('#j-sub').textContent = 'reconectando...'; }
      const minhaVez = this.est && this.est.sala.vez === this.est.eu.id;
      await new Promise(r => setTimeout(r, minhaVez ? 1200 : 850));
    }
    this.rodando = false;
  },
  meu() { return this.est && this.est.eu; },
  seat(id) { return this.ids.indexOf(id); },
  jogadorPor(id) { return this.est && this.est.jogadores.find(j => j.id === id); },
  aplicar(e) {
    const ant = this.est; this.est = e;
    const s = e.sala, eu = e.eu;
    const emJogo = !['sala', 'fim'].includes(s.fase);
    const naMesa = e.jogadores.filter(j => emJogo || s.fase === 'fim' ? j.jogando : true);
    const ids = naMesa.map(j => j.id);
    if (s.partida !== this.partida) { this.partida = s.partida; mesa.saindo = {}; this.vistoFalas = {}; this.ultUlt = ''; mesa.calar(); }
    this.ids = ids; this.assentoMeu = ids.indexOf(eu.id);
    mesa.definir(naMesa.map(j => ({ id: j.id, boneco: j.boneco, nome: j.nome + (j.id === eu.id ? ' (você)' : ''), vivo: emJogo || s.fase === 'fim' ? j.vivo : true })));
    // marcas: quem já votou / pediu emergência / caiu
    mesa.marcas = {};
    naMesa.forEach((j, i) => { if (s.fase === 'votacao' && j.votou) mesa.marcas[i] = '✅'; else if (j.emerg && ['falando', 'discussao'].includes(s.fase)) mesa.marcas[i] = '🚨'; else if (!j.on) mesa.marcas[i] = '📵'; else if (j.host && s.fase === 'sala') mesa.marcas[i] = '👑'; });
    // falas novas → balão
    for (const j of naMesa) {
      const n = j.falas.length, v = this.vistoFalas[j.id] ?? n;
      if (ant && n > v) { const f = j.falas[n - 1]; if (f !== '—') { mesa.falar(this.seat(j.id), f); som('fala'); } }
      this.vistoFalas[j.id] = n;
    }
    // vez
    if (s.fase === 'falando' && s.vez) {
      mesa.vezAtiva = true;
      if (s.vez !== this.ultVez) { mesa.girarPara(this.seat(s.vez)); if (s.vez === eu.id) { som('vez'); vibrar([80, 50, 80]); } }
    } else if (s.fase === 'chute' && s.vez) { mesa.vezAtiva = false; if (s.vez !== this.ultVez) mesa.girarPara(this.seat(s.vez)); }
    else mesa.vezAtiva = false;
    this.ultVez = s.vez;
    // chat e emotes
    for (const c of e.chat) {
      this.desde = Math.max(this.desde, c.id);
      if (c.tipo === 'emo') { const a = this.seat(c.de), b = this.seat(c.alvo); if (b >= 0) { mesa.emote(a, b, c.texto); if (c.alvo === eu.id) vibrar(40); } continue; }
      this.addChat(c);
    }
    // mudanças de fase
    const ultStr = JSON.stringify(s.ult || {});
    if (s.fase === 'revelacao' && ultStr !== this.ultUlt) this.revelar(s.ult);
    if (s.fase === 'chute' && this.ultFase !== 'chute') modal('');
    if (s.fase === 'fim' && this.ultFase !== 'fim' && this.ultFase !== null) this.fim();
    if (s.fase === 'fim' && this.ultFase === null) this.fim(true);
    if (s.fase !== 'revelacao' && s.fase !== 'fim' && ['revelacao', 'fim', 'chute'].includes(this.ultFase) && s.fase !== 'chute') modal('');
    if (s.fase === 'sala' && this.ultFase === 'fim') modal('');
    if (s.fase === 'votacao' && this.ultFase !== 'votacao') { som('ruim'); vibrar(120); mesa.selecionado = null; mesa.calar(); }
    if (s.fase === 'discussao' && this.ultFase !== 'discussao') { toast('Todo mundo falou! Discutam no chat 💬'); mesa.calar(); }
    if (s.fase === 'falando' && this.ultFase && this.ultFase !== 'falando' && this.ultFase !== 'sala') toast('Rodada ' + s.rodada + '!');
    if (s.fase === 'falando' && this.ultFase === 'sala') { mesa.calar(); toast('Começou! Sua palavra tá lá em cima 👆', 3000); som('bom'); }
    this.ultUlt = ultStr; this.ultFase = s.fase;
    // modo de toque
    const podeVotar = s.fase === 'votacao' && eu.jogando && eu.vivo && !eu.voto;
    if (modoToque !== 'emote') modoToque = podeVotar ? 'voto' : null;
    else modoAnterior = podeVotar ? 'voto' : null;
    if (!podeVotar && mesa.selecionado !== null && s.fase !== 'votacao') mesa.selecionado = null;
    atualizarSelecao();
    this.minhaPalavra(); this.topo(); this.painel(); this.chatEstado();
    if (!$('#j-historico').hidden) desenharHistorico();
  },
  votavel(i) { const j = this.jogadorPor(this.ids[i]); return j && j.vivo && j.jogando && j.id !== this.est.eu.id && this.est.sala.fase === 'votacao' && !this.est.eu.voto; },
  minhaPalavra() {
    const e = this.est, eu = e.eu, b = $('#j-minha'), s = e.sala;
    if (!eu.jogando || ['sala'].includes(s.fase)) { b.hidden = true; return; }
    if (b.hidden) b.classList.remove('oculta');      // online: cada um no seu celular, já mostra (toca pra esconder)
    b.hidden = false; b.classList.toggle('imp', eu.impostor);
    const html = eu.impostor ? `🤫 IMPOSTOR ${eu.dica ? `· dica <span class="p">${esc(eu.dica)}</span>` : '<span class="p">sem dica</span>'}` : `Palavra <span class="p">${esc(eu.palavra)}</span>`;
    if (b.dataset.h !== html) { b.innerHTML = html + ' <span style="font-size:14px">👁</span>'; b.dataset.h = html; }
  },
  topo() {
    const e = this.est, s = e.sala, eu = e.eu, vivos = e.jogadores.filter(j => j.jogando && j.vivo).length;
    const nome = id => (this.jogadorPor(id) || {}).nome || '?';
    const T = { sala: 'SALA ' + s.codigo, falando: s.vez === eu.id ? 'SUA VEZ!' : 'Vez de ' + nome(s.vez), discussao: 'DISCUSSÃO', votacao: 'VOTAÇÃO',
      revelacao: 'RESULTADO', chute: s.vez === eu.id ? 'ÚLTIMA CHANCE!' : nome(s.vez) + ' vai chutar', fim: 'FIM DE JOGO' }[s.fase];
    $('#j-fase').textContent = T;
    $('#j-sub').textContent = s.fase === 'sala' ? `${e.jogadores.length} de 8 na mesa` : s.fase === 'fim' ? '' : `Rodada ${s.rodada} · ${vivos} vivos` + (!eu.jogando ? ' · assistindo' : !eu.vivo ? ' · você é plateia 👻' : '');
    relogio(['falando', 'discussao', 'votacao', 'chute'].includes(s.fase) ? s.prazo : null);
  },
  painel() {
    const e = this.est, s = e.sala, eu = e.eu, P = $('#j-painel');
    const chave = JSON.stringify([s.fase, s.vez, eu.voto, eu.vivo, eu.host, mesa.selecionado, e.jogadores.length, s.config, eu.jogando,
      s.fase === 'votacao' ? e.jogadores.filter(j => j.votou).length : 0, ['falando', 'discussao'].includes(s.fase) ? e.jogadores.filter(j => j.emerg).length : 0, eu.id && e.jogadores.find(j => j.id === eu.id)?.emerg]);
    if (P.dataset.k === chave) return;
    const foco = document.activeElement && document.activeElement.id, valor = foco && $('#' + foco) ? $('#' + foco).value : null;
    P.dataset.k = chave; P.innerHTML = '';
    const cx = el('div', 'caixa'); P.appendChild(cx);
    const vivosJ = e.jogadores.filter(j => j.jogando && j.vivo), euJ = e.jogadores.find(j => j.id === eu.id) || {};
    const emerg = () => {
      if (!eu.jogando || !eu.vivo) return '';
      const n = vivosJ.filter(j => j.emerg).length, prec = Math.floor(vivosJ.length / 2) + 1;
      return `<div class="acoes"><button class="btn ${euJ.emerg ? 'vermelho' : 'escuro'} peq emerg" id="o-emerg">🚨 ${euJ.emerg ? 'CANCELAR' : 'EMERGÊNCIA'} <span style="font:800 13px system-ui">${n}/${prec}</span></button></div>`;
    };
    if (s.fase === 'sala') {
      const c = s.config;
      const resumo = `${c.impostores} impostor${c.impostores > 1 ? 'es' : ''} · dica ${c.dica ? 'sim' : 'não'} · ${c.tempo_vez ? c.tempo_vez + 's por vez' : 'sem tempo'} · ${c.categorias.length ? c.categorias.length + ' categorias' : 'todas as categorias'}`;
      cx.innerHTML = `<div class="sub" style="margin:0">Código da sala</div><div class="codigo-sala">${esc(s.codigo)}</div><div class="sub">${resumo}</div>
        <div class="acoes"><button class="btn creme peq" id="o-convidar">📲 CONVIDAR</button><button class="btn creme peq" id="o-boneco">🎭 BONECO</button>${eu.host ? '<button class="btn creme peq" id="o-config">⚙️ REGRAS</button>' : ''}</div>
        ${eu.host ? `<div class="acoes"><button class="btn verde" id="o-iniciar" ${e.jogadores.length < 3 ? 'disabled' : ''}>▶ COMEÇAR${e.jogadores.length < 3 ? ' (mín. 3)' : ''}</button></div>` : '<div class="sub" style="margin:10px 0 0">Esperando o dono da sala começar...</div>'}`;
      $('#o-convidar').onclick = () => this.convidar();
      $('#o-boneco').onclick = () => abrirPicker({ titulo: 'Seu boneco', comNome: true, atual: euJ.boneco, nome: euJ.nome, bloqueados: e.jogadores.filter(j => j.id !== eu.id).map(j => j.boneco),
        ok: async (b, n) => { perfil = { nome: n, boneco: b }; guarda.pôr('perfil', perfil); mostrarPerfil(); const r = await rpc('ehn_perfil', { p_codigo: this.codigo, p_token: token, p_nome: n, p_boneco: b }); if (r.erro) toast(ERROS[r.erro]); } });
      if ($('#o-config')) $('#o-config').onclick = () => this.config();
      if ($('#o-iniciar')) $('#o-iniciar').onclick = async () => { som('bom'); const r = await rpc('ehn_iniciar', { p_codigo: this.codigo, p_token: token }); if (r.erro) toast(ERROS[r.erro] || r.erro); };
    } else if (s.fase === 'falando') {
      if (s.vez === eu.id) {
        cx.innerHTML = `<div class="tit">Sua vez! Fala UMA palavra</div><div class="sub">Ligada à palavra secreta, sem entregar demais.</div>
          <div class="envio"><input class="campo" id="o-fala" maxlength="18" placeholder="sua palavra" autocomplete="off" enterkeyhint="send"><button class="btn verde" id="o-falar">➤</button></div><div class="erro-msg" id="o-erro"></div>` + emerg();
        const vai = async () => {
          const v = $('#o-fala').value.trim(); if (!v) return;
          $('#o-falar').disabled = true;
          try { const r = await rpc('ehn_falar', { p_codigo: this.codigo, p_token: token, p_palavra: v }); if (r.erro) { $('#o-erro').textContent = ERROS[r.erro] || r.erro; som('ruim'); $('#o-falar').disabled = false; } }
          catch { $('#o-erro').textContent = 'Falhou, tenta de novo'; $('#o-falar').disabled = false; }
        };
        $('#o-falar').onclick = vai; $('#o-fala').onkeydown = ev => { if (ev.key === 'Enter') vai(); };
        setTimeout(() => $('#o-fala') && $('#o-fala').focus({ preventScroll: true }), 400);
      } else {
        const j = this.jogadorPor(s.vez);
        cx.innerHTML = `<div class="tit">${esc(j ? j.nome : '')} tá pensando...</div><div class="sub">${!eu.jogando ? 'Você entrou no meio: assiste essa partida.' : !eu.vivo ? 'Você é plateia 👻 Conversa com os outros eliminados no chat.' : 'Presta atenção no que cada um fala.'}</div>` + emerg();
      }
    } else if (s.fase === 'discussao') {
      cx.innerHTML = `<div class="tit">Discutam! Quem tá estranho?</div><div class="sub">Abre o 💬 pra conversar e o 📜 pra ver as palavras. A votação abre quando o tempo acabar.</div>` + emerg();
    } else if (s.fase === 'votacao') {
      if (!eu.jogando || !eu.vivo) cx.innerHTML = `<div class="tit">Votação rolando...</div><div class="sub">Você não vota dessa vez.</div>`;
      else if (eu.voto) { const alvo = eu.voto === 'pular' ? 'pular' : (this.jogadorPor(eu.voto) || {}).nome; cx.innerHTML = `<div class="tit">Você votou ${eu.voto === 'pular' ? 'pra pular' : 'em ' + esc(alvo)}</div><div class="sub">Esperando os outros (${e.jogadores.filter(j => j.votou).length}/${vivosJ.length})</div>`; }
      else if (mesa.selecionado !== null && mesa.selecionado !== undefined && this.votavel(mesa.selecionado)) {
        const j = this.jogadorPor(this.ids[mesa.selecionado]);
        cx.innerHTML = `<div class="tit">Votar em ${esc(j.nome)}?</div><div class="acoes"><button class="btn creme peq" id="o-trocar">TROCAR</button><button class="btn vermelho" id="o-votar">VOTAR</button></div>`;
        $('#o-trocar').onclick = () => { mesa.selecionado = null; this.painel(); };
        $('#o-votar').onclick = () => this.votar(j.id);
      } else {
        cx.innerHTML = `<div class="tit">Quem é o impostor?</div><div class="sub">Toca em alguém na mesa pra votar.</div><div class="acoes"><button class="btn creme peq" id="o-pular">PULAR VOTO</button></div>`;
        $('#o-pular').onclick = () => this.votar('pular');
      }
    } else if (s.fase === 'chute') {
      if (s.vez === eu.id) {
        cx.innerHTML = `<div class="tit">Te pegaram! Última chance</div><div class="sub">Acerta a palavra e os impostores ganham.</div>
          <div class="envio"><input class="campo" id="o-chute" maxlength="24" placeholder="qual era a palavra?" autocomplete="off"><button class="btn vermelho" id="o-chutar">➤</button></div>`;
        const vai = async () => { const v = $('#o-chute').value.trim(); if (!v) return; $('#o-chutar').disabled = true; await rpc('ehn_chutar', { p_codigo: this.codigo, p_token: token, p_palavra: v }).catch(() => { }); };
        $('#o-chutar').onclick = vai; $('#o-chute').onkeydown = ev => { if (ev.key === 'Enter') vai(); };
      } else { const j = this.jogadorPor(s.vez); cx.innerHTML = `<div class="tit">${esc(j ? j.nome : '')} era impostor!</div><div class="sub">Agora tá tentando adivinhar a palavra... Se acertar, os impostores ganham.</div>`; }
    } else cx.remove();
    if ($('#o-emerg')) $('#o-emerg').onclick = async () => { som('ruim'); const r = await rpc('ehn_emergencia', { p_codigo: this.codigo, p_token: token }); if (r.erro) toast(ERROS[r.erro] || r.erro); };
    if (foco && $('#' + foco) && valor !== null) { $('#' + foco).value = valor; $('#' + foco).focus({ preventScroll: true }); }
  },
  async votar(alvo) {
    som('voto'); vibrar(30);
    const r = await rpc('ehn_votar', { p_codigo: this.codigo, p_token: token, p_alvo: alvo }).catch(() => ({ erro: 'rede' }));
    if (r.erro) toast(ERROS[r.erro] || 'Falhou, tenta de novo');
    else { this.est.eu.voto = alvo; mesa.selecionado = null; modoToque = null; atualizarSelecao(); this.painel(); }
  },
  revelar(u) {
    const e = this.est;
    if (u.empate || !u.eliminado) {
      som('pop');
      modal(`<div class="grande">${u.empate ? 'EMPATE!' : 'NINGUÉM SAIU'}</div><p class="sub">${u.empate ? 'Ninguém foi eliminado. Vai pra outra rodada.' : 'A maioria pulou o voto. Outra rodada!'}</p>${this.listaVotos(u)}`);
      return;
    }
    const j = this.jogadorPor(u.eliminado) || { nome: '?', boneco: 0 }, i = this.seat(u.eliminado);
    if (i >= 0) { mesa.girarPara(i); mesa.eliminar(i); }
    som(u.impostor ? 'bom' : 'ruim'); vibrar(u.impostor ? [60, 40, 60] : 220);
    const sobra = e.jogadores.some(q => q.jogando && q.vivo && q.impostor === null && q.id !== e.eu.id) || (e.eu.impostor && e.eu.vivo);
    setTimeout(() => modal(`<img class="rosto-g cinza" src="${rosto(j.boneco)}" alt=""><div class="grande">${esc(j.nome)}${u.eliminado === e.eu.id ? ' (você)' : ''}</div>
      <div class="carimbo ${u.impostor ? 'vermelho' : 'verde'}">${u.impostor ? 'ERA IMPOSTOR!' : 'ERA INOCENTE'}</div>${this.listaVotos(u)}`), 900);
  },
  listaVotos(u) {
    const v = u.votos || {}, nome = id => id === 'pular' ? 'pular' : ((this.jogadorPor(id) || {}).nome || '?');
    const ks = Object.keys(v); if (!ks.length) return '';
    return `<div class="votos-lista">${ks.map(k => `${esc(nome(k))} → <b>${esc(nome(v[k]))}</b>`).join('<br>')}</div>`;
  },
  fim(silencioso) {
    const e = this.est, s = e.sala, eu = e.eu;
    const imps = e.jogadores.filter(j => j.jogando && j.impostor);
    const ganhei = eu.jogando && ((s.vencedor === 'impostores') === eu.impostor);
    if (!silencioso) { if (ganhei) { som('vitoria'); confete(); } else som('ruim'); }
    const u = s.ult || {};
    const motivo = u.acertou ? `${(this.jogadorPor(u.eliminado) || {}).nome} acertou a palavra no chute!` : '';
    modal(`<div class="grande">${s.vencedor === 'inocentes' ? 'OS INOCENTES VENCERAM!' : 'OS IMPOSTORES VENCERAM!'}</div>
      ${eu.jogando ? `<div class="carimbo ${ganhei ? 'verde' : 'vermelho'}">${ganhei ? 'VOCÊ GANHOU' : 'VOCÊ PERDEU'}</div>` : ''}
      ${motivo ? `<p class="sub">${esc(motivo)}</p>` : ''}
      <div class="sub" style="margin-top:6px">A palavra era <b>${esc(s.palavra)}</b></div>
      <div class="sub">${imps.length > 1 ? 'Os impostores eram' : 'O impostor era'}</div>
      <div class="lista-imp">${imps.map(q => `<figure><img src="${rosto(q.boneco)}" alt="">${esc(q.nome)}</figure>`).join('')}</div>`,
      eu.host ? [['JOGAR DE NOVO', 'verde', async () => { await rpc('ehn_denovo', { p_codigo: this.codigo, p_token: token }); modal(''); }], ['SAIR', 'creme', () => this.sair()]]
        : [['SAIR', 'creme', () => this.sair()]]);
    if (!eu.host) { const c = $('#j-modal .caixa'); c && c.insertAdjacentHTML('beforeend', '<p class="sub" style="margin-top:10px">O dono da sala decide se tem outra.</p>'); }
  },
  addChat(c) {
    const e = this.est, j = this.jogadorPor(c.de);
    if (c.tipo === 'sis') { this.msgDom(`<div>${esc(c.texto)}</div>`, 'sis'); toast(c.texto); return; }
    const eu = c.de === e.eu.id;
    this.msgDom(`<img src="${rosto(j ? j.boneco : 0)}" alt=""><div><i>${esc(j ? j.nome : '?')}${c.morto ? ' 👻' : ''}</i>${esc(c.texto)}</div>`, (eu ? 'eu ' : '') + (c.morto ? 'morto' : ''));
    if (!eu && !$('#j-chat').classList.contains('on')) { this.naoLidas++; this.bolinha(); som('pop'); }
  },
  msgDom(html, cls) {
    const m = $('#chat-msgs'), perto = m.scrollHeight - m.scrollTop - m.clientHeight < 60;
    m.appendChild(el('div', 'msg ' + (cls || ''), html));
    while (m.childElementCount > 120) m.firstChild.remove();
    if (perto) m.scrollTop = m.scrollHeight;
  },
  chatEstado() {
    const e = this.est, s = e.sala, eu = e.eu;
    const fantasma = !['sala', 'fim'].includes(s.fase) && !(eu.jogando && eu.vivo);
    const fechado = !fantasma && ['falando', 'chute'].includes(s.fase);
    $('#chat-envio').hidden = fechado; $('#chat-fechado').hidden = !fechado;
    $('#chat-fechado').textContent = 'O chat abre depois que todo mundo falar a palavra.';
    $('#chat-input').placeholder = fantasma ? 'só os eliminados veem 👻' : 'Escreve aqui...';
  },
  async mandarChat() {
    const i = $('#chat-input'), v = i.value.trim(); if (!v) return;
    i.value = '';
    const r = await rpc('ehn_dizer', { p_codigo: this.codigo, p_token: token, p_tipo: 'msg', p_texto: v, p_alvo: null }).catch(() => ({ erro: 'rede' }));
    if (r.erro) { toast(ERROS[r.erro] || 'Não foi'); i.value = v; }
  },
  config() {
    const c = JSON.parse(JSON.stringify(this.est.sala.config));
    const n = this.est.jogadores.length, maxImp = Math.max(1, Math.min(3, Math.floor((n - 1) / 2)));
    const desenhar = () => {
      const chips = (arr, atual, campo) => arr.map(([v, t]) => `<span class="chip${atual === v ? ' on' : ''}" data-c="${campo}" data-v="${v}">${t}</span>`).join('');
      modal(`<div class="tit">Regras da sala</div>
        <div style="text-align:left;max-height:58vh;overflow-y:auto">
        <div class="sub" style="text-align:left;margin:6px 0">Impostores (até ${maxImp} com ${n} na sala)</div>${chips([[1, '1'], [2, '2'], [3, '3']], c.impostores, 'impostores')}
        <div class="sub" style="text-align:left;margin:6px 0">Dica pro impostor</div>${chips([[true, 'Sim'], [false, 'Não']], c.dica, 'dica')}
        <div class="sub" style="text-align:left;margin:6px 0">Última chance (impostor chuta a palavra)</div>${chips([[true, 'Sim'], [false, 'Não']], c.chute, 'chute')}
        <div class="sub" style="text-align:left;margin:6px 0">Tempo pra falar a palavra</div>${chips([[20, '20s'], [30, '30s'], [45, '45s'], [60, '60s']], c.tempo_vez, 'tempo_vez')}
        <div class="sub" style="text-align:left;margin:6px 0">Discussão antes de votar</div>${chips([[0, 'Direto'], [30, '30s'], [60, '1 min'], [90, '1:30'], [120, '2 min']], c.tempo_disc, 'tempo_disc')}
        <div class="sub" style="text-align:left;margin:6px 0">Tempo pra votar</div>${chips([[20, '20s'], [30, '30s'], [45, '45s'], [60, '60s']], c.tempo_voto, 'tempo_voto')}
        <div class="sub" style="text-align:left;margin:6px 0">Categorias</div><span class="chip${c.categorias.length ? '' : ' on'}" data-cat="">🎲 Todas</span>${CATEGORIAS.map(k => `<span class="chip${c.categorias.includes(k.nome) ? ' on' : ''}" data-cat="${esc(k.nome)}">${k.emoji} ${esc(k.nome)}</span>`).join('')}
        </div>`, [['CANCELAR', 'creme', () => modal('')], ['SALVAR', 'verde', async () => {
          const r = await rpc('ehn_config', { p_codigo: this.codigo, p_token: token, p_config: c }).catch(() => ({ erro: 'rede' }));
          if (r.erro) toast(ERROS[r.erro] || 'Falhou'); else { modal(''); toast('Regras salvas'); }
        }]]);
      document.querySelectorAll('#j-modal [data-c]').forEach(ch => ch.onclick = () => {
        const k = ch.dataset.c, raw = ch.dataset.v, v = raw === 'true' ? true : raw === 'false' ? false : +raw;
        if (k === 'impostores' && v > maxImp) { toast(`Com ${n} na sala dá até ${maxImp}`); return; }
        c[k] = v; som('pop'); desenhar();
      });
      document.querySelectorAll('#j-modal [data-cat]').forEach(ch => ch.onclick = () => {
        const k = ch.dataset.cat; if (!k) c.categorias = []; else { const i = c.categorias.indexOf(k); i >= 0 ? c.categorias.splice(i, 1) : c.categorias.push(k); }
        som('pop'); desenhar();
      });
    };
    desenhar();
  },
  convidar() {
    const url = location.origin + location.pathname + '?sala=' + this.codigo;
    const texto = `Bora jogar EHNPOSTOR! Sala ${this.codigo}`;
    if (navigator.share) navigator.share({ title: 'Ehnpostor', text: texto, url }).catch(() => { });
    else { navigator.clipboard && navigator.clipboard.writeText(texto + ' ' + url); toast('Link copiado! Cola no grupo'); }
  },
  async sair() {
    modal('');
    const c = this.codigo; this.sairLocal();
    try { await rpc('ehn_sair', { p_codigo: c, p_token: token }); } catch { }
  },
  sairLocal(msg) {
    this.ativo = false; this.codigo = null; guarda.pôr('sala', null);
    history.replaceState(null, '', location.pathname);
    mesa.definir([]); modal(''); relogio(null); $('#j-chat').classList.remove('on'); $('#j-historico').hidden = true; montarEmotes(false);
    pilha.length = 0; ir('inicio'); if (msg) toast(msg);
  },
  jogadoresHist() {
    const e = this.est; if (!e) return [];
    return e.jogadores.filter(j => j.jogando || e.sala.fase === 'sala').map(j => ({ nome: j.nome, boneco: j.boneco, vivo: j.vivo, impostor: j.id === e.eu.id && e.eu.impostor ? true : j.impostor, falas: j.falas }));
  }
};
function mandarEmote(i, emo) {
  if (!On.ativo) return;
  const alvo = On.ids[i]; if (!alvo) return;
  mesa.emote(On.assentoMeu, i, emo); som('pop');
  rpc('ehn_dizer', { p_codigo: On.codigo, p_token: token, p_tipo: 'emo', p_texto: emo, p_alvo: alvo }).then(r => { if (r.erro === 'calma') toast('Calma aí'); }).catch(() => { });
}
$('#chat-mandar').onclick = () => On.mandarChat();
$('#chat-input').onkeydown = e => { if (e.key === 'Enter') On.mandarChat(); };
$('#chat-fechar').onclick = () => $('#j-chat').classList.remove('on');
$('#j-minha').onclick = () => { $('#j-minha').classList.toggle('oculta'); som('pop'); };
$('#j-sair').onclick = () => {
  if (Pres.ativo) { modal('<div class="tit">Sair da partida?</div>', [['FICAR', 'creme', () => modal('')], ['SAIR', 'vermelho', () => Pres.sair()]]); return; }
  modal('<div class="tit">Sair da sala?</div><p class="sub">Se o jogo já começou, você sai da partida.</p>', [['FICAR', 'creme', () => modal('')], ['SAIR', 'vermelho', () => On.sair()]]);
};
$('#b-online').onclick = () => garantirPerfil(() => { som('pop'); abrirOnline(); });
function abrirOnline(codigo) {
  $('#on-erro').textContent = '';
  if (codigo) $('#on-codigo').value = codigo;
  const salva = guarda.ler('sala', null);
  ir('online');
  if (salva && salva.codigo && Date.now() - salva.quando < 3 * 3600e3 && !codigo) {
    $('#on-codigo').value = salva.codigo;
  }
}
$('#on-entrar').onclick = () => { const c = $('#on-codigo').value.trim().toUpperCase(); if (c.length !== 4) { $('#on-erro').textContent = 'O código tem 4 letras'; return; } som('pop'); On.entrar(c, false); };
$('#on-codigo').onkeydown = e => { if (e.key === 'Enter') $('#on-entrar').click(); };
$('#on-criar').onclick = () => { som('pop'); On.entrar(null, true); };

// a tela do jogo nunca rola (foco em campo de texto empurrava tudo pra cima)
for (const id of ['#jogo', '#revelar']) $(id).addEventListener('scroll', e => { e.target.scrollTop = 0; e.target.scrollLeft = 0; });

// laço do presencial (cronômetro)
setInterval(() => Pres.tick(), 250);
// atualiza o relógio do online entre uma consulta e outra
setInterval(() => { if (On.ativo && On.est) { const s = On.est.sala; relogio(['falando', 'discussao', 'votacao', 'chute'].includes(s.fase) ? s.prazo : null); } }, 250);

// link de convite: ?sala=XXXX
(function () {
  const p = new URLSearchParams(location.search).get('sala');
  pilha.push('inicio');
  if (p && /^[A-Z0-9]{4}$/i.test(p)) garantirPerfil(() => { abrirOnline(p.toUpperCase()); On.entrar(p.toUpperCase(), false); });
})();
if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => { });
