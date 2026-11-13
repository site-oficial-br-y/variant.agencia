// Mesa redonda vista de frente: os bonecos sentados em volta, a mesa gira até quem é a vez
// ficar no fundo, de frente pra tela. Desenho em canvas 2D (leve, roda em qualquer celular).
const NOMES_BONECO = ["Tonhão", "Juninho", "Seu Zé", "Pipoca", "Barbudo", "Treinador", "Nerdola", "Gamer",
  "Malandro", "Cunhado", "Nerdão", "Chef", "Vovô", "Craque", "Mestre", "Lelê"];

const Sprites = {
  lista: [], prontos: 0,
  carregar() {
    for (let i = 0; i < 16; i++) {
      const im = new Image();
      im.onload = () => {
        // versões prontas (canvas.filter não existe em todo celular): penumbra (de costas) e cinza (eliminado)
        const feito = f => {
          const c = document.createElement('canvas'); c.width = im.width; c.height = im.height;
          const x = c.getContext('2d'); x.drawImage(im, 0, 0);
          const d = x.getImageData(0, 0, c.width, c.height), p = d.data;
          for (let k = 0; k < p.length; k += 4) f(p, k);
          x.putImageData(d, 0, 0); return c;
        };
        const sil = feito((p, k) => { const l = (p[k] * .3 + p[k + 1] * .59 + p[k + 2] * .11);
          p[k] = 34 + l * .28; p[k + 1] = 20 + l * .2; p[k + 2] = 46 + l * .3; });
        const cinza = feito((p, k) => { const l = (p[k] * .3 + p[k + 1] * .59 + p[k + 2] * .11) * .78; p[k] = p[k + 1] = p[k + 2] = l; });
        this.lista[i] = { im, sil, cinza, w: im.width, h: im.height }; this.prontos++;
      };
      im.src = 'bonecos/' + i + '.webp';
    }
  }
};
Sprites.carregar();

class Mesa {
  constructor(canvas) {
    this.cv = canvas; this.g = canvas.getContext('2d');
    this.assentos = [];        // [{id, boneco, nome, vivo, ...}]
    this.vez = -1; this.rot = 0; this.rotDe = 0; this.rotPara = 0; this.tRot = 1;
    this.t = 0; this.fala = null;   // {i, texto, t}
    this.pulos = {}; this.emotes = []; this.saindo = {}; this.marcas = {};
    this.selecionavel = null; this.selecionado = null; this.aoTocar = null;
    this.destaqueVoto = {};
    this.topo = 0.10;          // fração da altura reservada em cima
    this.baixo = 0.0;          // fração reservada embaixo (painéis)
    this._ant = performance.now(); this._hits = [];
    canvas.addEventListener('pointerup', e => this._toque(e));
    const loop = agora => { this._quadro(agora); requestAnimationFrame(loop); };
    requestAnimationFrame(loop);
  }
  definir(assentos) {
    const mudou = assentos.length !== this.assentos.length || assentos.some((a, i) => !this.assentos[i] || this.assentos[i].id !== a.id);
    this.assentos = assentos;
    if (mudou) { this.vez = Math.min(Math.max(this.vez, 0), assentos.length - 1); this.rot = this.rotPara = this.vez < 0 ? 0 : this.vez; this.tRot = 1; }
  }
  girarPara(i, seco) {
    if (i < 0 || i >= this.assentos.length) return;
    const N = this.assentos.length;
    if (i === this.vez && !seco) return;
    this.vez = i;
    let alvo = i; while (alvo - this.rot > N / 2) alvo -= N; while (alvo - this.rot < -N / 2) alvo += N;
    this.rotDe = this.rot; this.rotPara = alvo; this.tRot = seco ? 1 : 0; if (seco) this.rot = alvo;
  }
  falar(i, texto) { this.fala = { i, texto, t: this.t }; this.pular(i); }
  calar() { this.fala = null; }
  pular(i) { this.pulos[i] = this.t; }
  emote(de, para, emo) { this.emotes.push({ de, para, emo, t: this.t }); }
  eliminar(i) { this.saindo[i] = this.t; }
  get girando() { return this.tRot < 1; }

  _toque(e) {
    if (!this.selecionavel || !this.aoTocar) return;
    const r = this.cv.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
    for (let k = this._hits.length - 1; k >= 0; k--) {
      const h = this._hits[k];
      if (x >= h.x && x <= h.x + h.w && y >= h.y && y <= h.y + h.h && this.selecionavel(h.i)) { this.aoTocar(h.i); return; }
    }
  }
  // posição na tela da cabeça do jogador i (pra pôr coisas em HTML por cima)
  posicao(i) { const h = this._hits.find(q => q.i === i); return h ? { x: h.x + h.w / 2, y: h.y, frente: h.frente } : null; }

  _quadro(agora) {
    const dt = Math.min(0.05, (agora - this._ant) / 1000); this._ant = agora; this.t += dt;
    const cv = this.cv, g = this.g, D = Math.min(devicePixelRatio || 1, 2);
    const W = cv.clientWidth, H = cv.clientHeight;
    if (!W || !H) return;
    if (cv.width !== Math.round(W * D) || cv.height !== Math.round(H * D)) { cv.width = Math.round(W * D); cv.height = Math.round(H * D); }
    const N = this.assentos.length, t = this.t;
    if (this.tRot < 1) {
      this.tRot = Math.min(1, this.tRot + dt / 0.9);
      const q = this.tRot, e = q < .5 ? 4 * q * q * q : 1 - Math.pow(-2 * q + 2, 3) / 2;
      this.rot = this.rotDe + (this.rotPara - this.rotDe) * e;
      if (this.tRot >= 1 && N) this.rot = this.rotPara = ((this.rotPara % N) + N) % N;
    }
    g.setTransform(D, 0, 0, D, 0, 0);
    // sala
    const bg = g.createLinearGradient(0, 0, 0, H); bg.addColorStop(0, '#24142f'); bg.addColorStop(.6, '#2f1b3a'); bg.addColorStop(1, '#140b1a');
    g.fillStyle = bg; g.fillRect(0, 0, W, H);
    const areaY0 = H * this.topo, areaH = H * (1 - this.topo - this.baixo);
    const retrato = areaH > W * 0.9;
    const cx = W / 2, cy = areaY0 + areaH * (retrato ? 0.50 : 0.48);
    const Rx = Math.min(W * (retrato ? .36 : .30), areaH * .50), Ry = Rx * .52, esc = Rx / 215;
    g.globalAlpha = .06; g.fillStyle = '#fff';
    for (let x = (W / 2) % 46 - 46; x < W; x += 46) g.fillRect(x, 0, 18, cy - Ry * .2);
    g.globalAlpha = 1;
    const luz = g.createRadialGradient(cx, cy - Ry * .2, 10, cx, cy, Rx * 2.1);
    luz.addColorStop(0, 'rgba(255,214,140,.42)'); luz.addColorStop(.45, 'rgba(255,170,90,.13)'); luz.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = luz; g.fillRect(0, 0, W, H);
    g.fillStyle = 'rgba(0,0,0,.45)'; this._el(cx, cy + Ry * 1.05 + 26 * esc, Rx * .86, Ry * .62); g.fill();
    if (!N) { this._mesa(cx, cy, Rx, Ry, esc, 0); return; }
    const lista = [];
    for (let i = 0; i < N; i++) {
      const a = (i - this.rot) * 2 * Math.PI / N, z = Math.cos(a);
      lista.push({ i, a, z, x: cx + Rx * 1.08 * Math.sin(a), y: cy - Ry * 1.10 * z });
    }
    lista.sort((p, q) => q.z - p.z);
    this._hits = [];
    lista.filter(o => o.z >= 0).forEach(o => this._boneco(o, esc));
    this._mesa(cx, cy, Rx, Ry, esc, N);
    lista.filter(o => o.z < 0).forEach(o => this._boneco(o, esc));
    // nomes, marcas, emotes
    g.textAlign = 'center'; g.textBaseline = 'middle';
    for (const o of lista) {
      if (o.topo === undefined) continue;
      const a = this.assentos[o.i];
      const sel = this.selecionavel && this.selecionavel(o.i);
      {
        const fs = Math.max(11, 13 * esc); g.font = '400 ' + fs + 'px Lilita, system-ui, sans-serif';
        const nm = a.nome; const tw = g.measureText(nm).width + 16, ny = o.topo - 12 * esc;
        const ativo = o.i === this.vez && !this.girando && this.vezAtiva !== false;
        g.globalAlpha = a.vivo === false ? .6 : 1;
        g.fillStyle = this.selecionado === o.i ? '#ff5a4f' : ativo ? '#ffc21a' : 'rgba(30,16,10,.82)';
        this._rr(o.x - tw / 2, ny - fs * .82, tw, fs * 1.64, fs * .82); g.fill();
        if (sel && this.selecionado !== o.i) { g.strokeStyle = '#ffc21a'; g.lineWidth = 2; g.stroke(); }
        g.fillStyle = ativo || this.selecionado === o.i ? '#2a160b' : '#fbe9d0'; g.fillText(nm, o.x, ny + 1);
        const m = this.marcas[o.i];
        if (m) { g.font = (18 * esc) + 'px system-ui'; g.fillText(m, o.x + tw / 2 + 8 * esc, ny); }
        g.globalAlpha = 1;
      }
    }
    // emotes voando de quem mandou até o alvo
    this.emotes = this.emotes.filter(e => t - e.t < 2.2);
    for (const e of this.emotes) {
      const de = lista.find(o => o.i === e.de), pa = lista.find(o => o.i === e.para);
      if (!pa || pa.topo === undefined) continue;
      const q = (t - e.t);
      const ox = de && de.topo !== undefined ? de.x : cx, oy = de && de.topo !== undefined ? de.topo : cy;
      let x, y, s, al = 1;
      if (q < .55) { const k = q / .55, ke = 1 - Math.pow(1 - k, 3); x = ox + (pa.x - ox) * ke; y = oy + (pa.topo - oy) * ke - Math.sin(k * Math.PI) * 70 * esc; s = .6 + .4 * k; }
      else { const k = (q - .55) / 1.65; x = pa.x + Math.sin(q * 7) * 4; y = pa.topo - 26 * esc - k * 40 * esc; s = 1 + .25 * Math.sin(Math.min(1, k * 3) * Math.PI); al = 1 - Math.pow(k, 3); }
      g.globalAlpha = al; g.font = (40 * esc * s) + 'px system-ui'; g.fillText(e.emo, x, y); g.globalAlpha = 1;
      if (q >= .55 && q - dt < .55) this.pular(e.para);
    }
    // balão da fala
    const at = this.fala && lista.find(o => o.i === this.fala.i);
    if (at && at.topo !== undefined) {
      const q = Math.min(1, (t - this.fala.t) / .35), c1 = 1.70158, c3 = c1 + 1, s = 1 + c3 * Math.pow(q - 1, 3) + c1 * Math.pow(q - 1, 2);
      const fs = Math.max(18, 25 * esc); g.font = '400 ' + fs + 'px Lilita, system-ui, sans-serif';
      const tw = g.measureText(this.fala.texto).width + 36, bh = fs * 1.9, by = at.topo - 42 * esc - bh / 2;
      g.save(); g.translate(at.x, by + bh / 2); g.scale(s, s); g.translate(0, -bh / 2);
      g.fillStyle = 'rgba(0,0,0,.35)'; this._rr(-tw / 2 + 3, -bh / 2 + 5, tw, bh, bh * .32); g.fill();
      g.fillStyle = '#fffaf0'; this._rr(-tw / 2, -bh / 2, tw, bh, bh * .32); g.fill();
      g.strokeStyle = '#4a2a17'; g.lineWidth = 3; g.stroke();
      g.beginPath(); g.moveTo(-10, bh / 2 - 1); g.lineTo(0, bh / 2 + 13); g.lineTo(12, bh / 2 - 1); g.closePath(); g.fillStyle = '#fffaf0'; g.fill();
      g.fillStyle = '#2a160b'; g.fillText(this.fala.texto, 0, 2); g.restore();
    }
    const vi = g.createRadialGradient(cx, cy, Rx * .9, cx, cy, Math.max(W, H) * .85);
    vi.addColorStop(0, 'rgba(0,0,0,0)'); vi.addColorStop(1, 'rgba(0,0,0,.5)'); g.fillStyle = vi; g.fillRect(0, 0, W, H);
  }

  _boneco(o, esc) {
    const g = this.g, a = this.assentos[o.i], s = Sprites.lista[a.boneco]; if (!s) return;
    const t = this.t, perto = (1 - o.z) / 2;
    let k = esc * (.62 + .26 * perto);
    const ang = o.a % (2 * Math.PI), af = ang > Math.PI ? ang - 2 * Math.PI : ang < -Math.PI ? ang + 2 * Math.PI : ang;
    if (o.z > 0) k *= 1 + .16 * Math.max(0, 1 - Math.abs(af) / .6);
    const resp = Math.sin(t * 2.1 + o.i * 1.7) * .012;
    let sy = 1 + resp, sx = 1 - resp, dy = 0, alfa = 1, giro = 0;
    const tp = t - (this.pulos[o.i] ?? -9);
    if (tp >= 0 && tp < .6) { const q = tp / .6; dy = -Math.sin(q * Math.PI) * 26 * esc * (1 - q * .3); sy += Math.sin(q * Math.PI * 2) * .07; sx -= Math.sin(q * Math.PI * 2) * .05; }
    if (this.fala && this.fala.i === o.i && t - this.fala.t < 1.6) { const f = Math.sin((t - this.fala.t) * 18) * .022 * (1 - (t - this.fala.t) / 1.6); sy += f; sx -= f; }
    const ts = this.saindo[o.i];
    if (ts !== undefined) { const q = Math.min(1, (t - ts) / 1.1); dy -= Math.sin(q * Math.PI * .5) * 40 * esc; giro = q * .5; alfa = 1 - q * .55; }
    if (a.vivo === false && ts === undefined) alfa = .4;
    const w = s.w * k * sx, h = s.h * k * sy;
    const base = o.y + (o.z > 0 ? h * .46 : h * (.46 + .42 * Math.min(1, -o.z * 1.6)));
    const X = o.x - w / 2, Y = base - h + dy;
    const luzP = Math.max(0, Math.min(1, (o.z + .42) / .5));
    g.fillStyle = 'rgba(0,0,0,' + (.28 * luzP + .1) + ')'; this._el(o.x, base - 4 * esc, w * .36, w * .09); g.fill();
    g.save(); g.globalAlpha = alfa;
    if (giro) { g.translate(o.x, base); g.rotate(giro); g.translate(-o.x, -base); }
    const arte = a.vivo === false ? s.cinza : s.im;
    g.drawImage(arte, X, Y, w, h);
    if (luzP < 1) { g.globalAlpha = alfa * (1 - luzP) * .22; g.drawImage(s.sil, X, Y, w, h); }   // só uma sombra leve: todo mundo aparece normal
    g.restore();
    if (this.selecionado === o.i) { g.strokeStyle = '#ff5a4f'; g.lineWidth = 4; this._el(o.x, base - 4 * esc, w * .45, w * .13); g.stroke(); }
    o.topo = Y; o.luz = luzP;
    this._hits.push({ i: o.i, x: X, y: Y, w, h: h * .9, frente: o.z > 0 });
  }

  _mesa(cx, cy, Rx, Ry, esc, N) {
    const g = this.g, esp = 30 * esc;
    g.fillStyle = '#3d2112'; this._el(cx, cy + esp, Rx * .80, Ry * .80); g.fill(); g.fillRect(cx - Rx * .80, cy, Rx * 1.6, esp);
    g.fillStyle = '#2a160b'; g.beginPath(); g.ellipse(cx, cy + esp, Rx * .80, Ry * .80, 0, 0, Math.PI); g.fill();
    g.save(); g.translate(cx, cy); g.scale(1, Ry / Rx);
    const tm = g.createRadialGradient(0, -Rx * .2, Rx * .05, 0, 0, Rx * .8); tm.addColorStop(0, '#b9743a'); tm.addColorStop(1, '#7a4420');
    g.fillStyle = tm; g.beginPath(); g.arc(0, 0, Rx * .80, 0, Math.PI * 2); g.fill();
    g.save(); g.beginPath(); g.arc(0, 0, Rx * .80, 0, Math.PI * 2); g.clip(); g.rotate(-this.rot * 2 * Math.PI / Math.max(1, N));
    g.strokeStyle = 'rgba(60,28,10,.35)'; g.lineWidth = 2;
    for (let q = 0; q < 12; q++) { g.rotate(Math.PI / 6); g.beginPath(); g.moveTo(Rx * .2, 0); g.lineTo(Rx * .8, 0); g.stroke(); }
    g.fillStyle = '#156b47'; g.beginPath(); g.arc(0, 0, Rx * .56, 0, Math.PI * 2); g.fill();
    g.strokeStyle = '#ffc21a'; g.lineWidth = 4 * esc; g.beginPath(); g.arc(0, 0, Rx * .56, 0, Math.PI * 2); g.stroke();
    g.strokeStyle = 'rgba(255,255,255,.16)'; g.lineWidth = 2; g.beginPath(); g.arc(0, 0, Rx * .36, 0, Math.PI * 2); g.stroke();
    for (let i = 0; i < N; i++) {
      g.save(); g.rotate(i * 2 * Math.PI / N);
      g.fillStyle = i === this.vez ? '#ffc21a' : 'rgba(255,255,255,.22)';
      g.beginPath(); g.moveTo(0, -Rx * .50); g.lineTo(Rx * .035, -Rx * .42); g.lineTo(-Rx * .035, -Rx * .42); g.closePath(); g.fill();
      g.fillStyle = this.assentos[i] && this.assentos[i].vivo === false ? 'rgba(120,110,100,.6)' : 'rgba(250,245,230,.92)';
      this._rr(-Rx * .045, -Rx * .71, Rx * .09, Rx * .11, 3); g.fill(); g.restore();
    }
    g.restore();
    g.strokeStyle = '#e0a05c'; g.lineWidth = 3 * esc; g.beginPath(); g.arc(0, 0, Rx * .795, 0, Math.PI * 2); g.stroke();
    g.restore();
    g.fillStyle = 'rgba(255,230,170,.10)'; this._el(cx, cy - Ry * .25, Rx * .42, Ry * .3); g.fill();
  }
  _el(x, y, rx, ry) { const g = this.g; g.beginPath(); g.ellipse(x, y, Math.max(0, rx), Math.max(0, ry), 0, 0, Math.PI * 2); }
  _rr(x, y, w, h, r) { const g = this.g; g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
}
