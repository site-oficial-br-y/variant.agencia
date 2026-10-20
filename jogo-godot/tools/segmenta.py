"""Recorta UMA ilustração (personagem + veículo) em peças de ragdoll para o Godot.

Uso: python3 segmenta.py <cadeira|scooter>

Regras:
- partição: cada pixel opaco vai para UMA peça (regras em ordem de prioridade);
- casca: cada peça é completada (preenchimento suave) só onde algo DESENHADO NA
  FRENTE dela a tampava — assim montado fica idêntico à arte e, solto, sem buraco;
- rodas tampadas são reconstruídas como círculo completo pelo perfil radial.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
CHARS = os.path.join(AQUI, 'fonte')


def carregar(nome):
    im = np.asarray(Image.open(os.path.join(CHARS, f'{nome}_full.png')).convert('RGBA')).astype(np.int16)
    return im


class Ctx:
    def __init__(self, im):
        self.im = im
        self.H, self.W = im.shape[:2]
        self.rgb = im[:, :, :3]
        self.alpha = im[:, :, 3]
        self.ys, self.xs = np.mgrid[0:self.H, 0:self.W]
        r, g, b = self.rgb[:, :, 0], self.rgb[:, :, 1], self.rgb[:, :, 2]
        self.pele = (r > 150) & (r - b > 45) & (g > 90) & (r > g) & (g > b)
        self.mx, self.mn = self.rgb.max(2), self.rgb.min(2)

    def poly(self, pts):
        m = Image.new('L', (self.W, self.H), 0)
        ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=1)
        return np.asarray(m).astype(bool)

    def disco(self, c, r):
        return (self.xs - c[0]) ** 2 + (self.ys - c[1]) ** 2 <= r * r

    def raio(self, c):
        return np.sqrt((self.xs - c[0]) ** 2 + (self.ys - c[1]) ** 2)

    def acima(self, pts):
        """y acima da polilinha (x crescente), constante fora das pontas"""
        px = [p[0] for p in pts]; py = [p[1] for p in pts]
        return self.ys < np.interp(self.xs, px, py)

    def escuro(self, t=85): return self.mx < t
    def claro(self, t=175): return self.mn > t
    def cinza(self, d=28): return (self.mx - self.mn) < d


def raios_roda(ctx, c, r_in, r_out):
    """Acha os ângulos dos raios: picos claros em vários raios, mantidos se aparecem em >= 2."""
    ang = np.arange(0, 360, 0.5)
    vistos = []
    for rr in np.linspace(r_in + 15, r_out - 15, 5):
        x = (c[0] + rr * np.cos(np.radians(ang))).astype(int)
        y = (c[1] + rr * np.sin(np.radians(ang))).astype(int)
        ok = (x >= 0) & (x < ctx.W) & (y >= 0) & (y < ctx.H)
        luz = np.zeros(len(ang), bool)
        luz[ok] = (ctx.mn[y[ok], x[ok]] > 125) & (ctx.alpha[y[ok], x[ok]] > 150) & ((ctx.mx - ctx.mn)[y[ok], x[ok]] < 30)
        ini = None
        for i, v in enumerate(luz):
            if v and ini is None: ini = i
            if not v and ini is not None:
                vistos.append(ang[(ini + i - 1) // 2]); ini = None
    vistos.sort()
    grupos = []
    for a in vistos:
        if grupos and a - grupos[-1][-1] <= 4: grupos[-1].append(a)
        else: grupos.append([a])
    if len(grupos) > 1 and (grupos[0][0] + 360) - grupos[-1][-1] <= 4:
        grupos[0] = [g - 360 for g in grupos.pop()] + grupos[0]
    return [float(np.mean(g)) for g in grupos if len(g) >= 2]


def mascara_raios(ctx, c, angs, r0, r1, larg=4.5):
    """Para cada raio: ajusta uma reta nos pixels claros perto do ângulo e marca a faixa."""
    m = np.zeros((ctx.H, ctx.W), bool)
    dx, dy = ctx.xs - c[0], ctx.ys - c[1]
    rr = np.sqrt(dx * dx + dy * dy)
    teta = np.degrees(np.arctan2(dy, dx)) % 360
    claro = (ctx.mn > 110) & (ctx.alpha > 120) & ((ctx.mx - ctx.mn) < 32)
    for a in angs:
        da = np.abs(((teta - a + 180) % 360) - 180)
        cand = claro & (da < 6) & (rr > r0) & (rr < r1)
        py, px = np.nonzero(cand)
        if len(px) < 30:
            continue
        pts = np.stack([px, py], 1).astype(float)
        cen = pts.mean(0)
        _, _, vt = np.linalg.svd(pts - cen)
        d = vt[0]                                    # direção do raio
        perp = np.abs((ctx.xs - cen[0]) * d[1] - (ctx.ys - cen[1]) * d[0])
        m |= (perp < larg) & (rr > r0) & (rr < r1) & (da < 12)
    return m & ~ctx.escuro(70)


def suave(ctx, fonte, sigma):
    """Estende a textura da peça: copia o pixel próprio mais próximo e suaviza."""
    _, (iy, ix) = ndimage.distance_transform_edt(~fonte, return_indices=True)
    nn = ctx.rgb[iy, ix].astype(float)
    return np.stack([ndimage.gaussian_filter(nn[:, :, ch], sigma) for ch in range(3)], 2)


def roda_radial(ctx, c, r, visivel):
    """Sprite de roda completo a partir do perfil radial médio dos pixels visíveis."""
    rr = ctx.raio(c)
    bins = np.arange(0, int(r) + 2)
    perfil = np.zeros((len(bins), 3)); tem = np.zeros(len(bins), bool)
    ri = rr.astype(int)
    for b in bins:
        m = visivel & (ri == b)
        if m.sum() >= 3:
            perfil[b] = ctx.rgb[m].mean(0); tem[b] = True
    # interpola raios sem amostra
    for ch in range(3):
        perfil[:, ch] = np.interp(bins, bins[tem], perfil[tem, ch])
    disco = rr <= r + 0.5
    cor = np.zeros(ctx.rgb.shape, np.int16)
    idx = np.clip(ri, 0, len(bins) - 1)
    for ch in range(3):
        cor[:, :, ch] = perfil[idx, ch].astype(np.int16)
    a = np.clip((r + 0.5 - rr) * 255, 0, 255).astype(np.int16) * disco
    # onde a roda aparece na arte, fica o pixel original (detalhe do cubo etc.)
    cor[visivel] = ctx.rgb[visivel]
    a[visivel] = np.maximum(a[visivel], ctx.alpha[visivel])
    return cor, a


def rodar(cfg_nome, cfg):
    ctx = Ctx(carregar(cfg_nome))
    H, W = ctx.H, ctx.W
    opaco = ctx.alpha > 8
    labels = cfg['ordem']                           # ordem de desenho (z)
    lab_id = {n: i + 1 for i, n in enumerate(labels)}
    L = np.zeros((H, W), np.uint8)
    livre = opaco.copy()
    for nome, regra in cfg['regras'](ctx):
        m = regra & livre
        L[m] = lab_id[nome]; livre &= ~m
    # sobra -> peça rotulada mais próxima (exceto rodas)
    alvo = (L > 0) & ~np.isin(L, [lab_id[n] for n in cfg.get('rodas_radiais', {})])
    if livre.any():
        _, (ny, nx) = ndimage.distance_transform_edt(~alvo, return_indices=True)
        L[livre] = L[ny[livre], nx[livre]]
    # migalhas (< 300 px) -> vizinho mais comum
    for _ in range(3):
        mudou = 0
        for n, i in lab_id.items():
            comp, k = ndimage.label(L == i)
            if k <= 1: continue
            tam = ndimage.sum(L == i, comp, range(1, k + 1))
            maior = int(np.argmax(tam)) + 1
            for cc in range(1, k + 1):
                if cc == maior or tam[cc - 1] >= cfg.get('migalha', 300): continue
                ilha = comp == cc
                borda = ndimage.binary_dilation(ilha, iterations=2) & ~ilha
                viz = L[borda]; viz = viz[(viz != 0) & (viz != i)]
                if viz.size:
                    L[ilha] = np.bincount(viz).argmax(); mudou += 1
        if not mudou: break

    out_dir = os.path.join(AQUI, '..', 'assets', cfg_nome)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith(('.png', '.json', '.import')):
            os.remove(os.path.join(out_dir, f))

    pecas = {}
    for n in labels:
        i = lab_id[n]
        own = L == i
        cor = ctx.rgb.copy(); a = np.where(own, ctx.alpha, 0).astype(np.int16)
        if n in cfg.get('rodas_radiais', {}):
            c, r = cfg['rodas_radiais'][n]
            cor, a = roda_radial(ctx, c, r, own)
        else:
            frente = np.isin(L, [lab_id[x] for x in labels[labels.index(n) + 1:]])
            casca = np.zeros((H, W), bool)
            for forma in cfg.get('cascas', {}).get(n, []):
                if forma[0] == 'poly': casca |= ctx.poly(forma[1])
                else: casca |= ctx.disco(forma[1], forma[2])
            enche = casca & frente & ~own
            if enche.any():
                fonte = own & (ctx.alpha > 200)
                if cfg.get('fonte_casca', {}).get(n) == 'pele':
                    fonte &= ctx.pele
                sm = suave(ctx, fonte, cfg.get('sigma', 14))
                cor[enche] = sm[enche].astype(np.int16)
                a[enche] = 255
        img = Image.fromarray(np.dstack([np.clip(cor, 0, 255).astype(np.uint8), np.clip(a, 0, 255).astype(np.uint8)]), 'RGBA')
        bb = img.getbbox()
        img = img.crop(bb)
        img.save(os.path.join(out_dir, f'{n}.png'))
        pecas[n] = {'x': bb[0], 'y': bb[1], 'w': img.width, 'h': img.height}
        print(f'  {n:10s} bbox={bb} px_proprios={int(own.sum())}')

    meta = {'nome': cfg_nome, 'src_w': W, 'src_h': H, 'ordem': labels, 'pecas': pecas}
    meta.update(cfg['fisica'])
    json.dump(meta, open(os.path.join(out_dir, 'parts.json'), 'w'), indent=1)

    # validação: remontagem e pose de ragdoll
    dbg = cfg.get('dbg')
    if dbg:
        fundo = (140, 190, 230, 255)
        orig = Image.new('RGBA', (W, H), fundo)
        orig.alpha_composite(Image.fromarray(ctx.im.astype(np.uint8), 'RGBA'))
        mont = Image.new('RGBA', (W, H), fundo)
        for n in labels:
            p = pecas[n]; mont.alpha_composite(Image.open(os.path.join(out_dir, f'{n}.png')), (p['x'], p['y']))
        d = np.abs(np.asarray(orig).astype(int) - np.asarray(mont).astype(int)).max(2)
        print('  REMONTAGEM: max=%d  pixels>16: %d de %d' % (d.max(), int((d > 16).sum()), int(opaco.sum())))
        # ragdoll de teste: corpos do piloto girados nos pivôs + veículo removido
        rag = Image.new('RGBA', (W, H), fundo)
        juntas = {(j['b']): j for j in cfg['fisica']['juntas']}
        for n in labels:
            corpo = cfg['fisica']['corpo_de'].get(n)
            if corpo not in cfg['fisica']['piloto']:
                continue
            p = pecas[n]
            cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            cv.alpha_composite(Image.open(os.path.join(out_dir, f'{n}.png')), (p['x'], p['y']))
            if corpo in juntas:
                j = juntas[corpo]
                cv = cv.rotate(j['teste'], center=tuple(j['p']), resample=Image.BICUBIC)
            rag.alpha_composite(cv)
        mapa = np.zeros((H, W, 3), np.uint8) + 25
        cores = [(230, 60, 60), (60, 120, 230), (240, 200, 40), (70, 200, 90), (230, 90, 220), (60, 220, 230),
                 (250, 140, 40), (150, 90, 250), (180, 250, 120), (250, 250, 250)]
        for n, i in lab_id.items():
            mapa[L == i] = cores[(i - 1) % len(cores)]
        for j in cfg['fisica']['juntas']:
            x, y = map(int, j['p']); mapa[y - 5:y + 5, x - 5:x + 5] = 255
        lado = Image.new('RGB', (W * 4 + 60, H), (15, 15, 15))
        for k, im_ in enumerate([orig.convert('RGB'), Image.fromarray(mapa), mont.convert('RGB'), rag.convert('RGB')]):
            lado.paste(im_, (k * (W + 20), 0))
        lado.save(dbg)
        legenda = ', '.join(f'{n}={cores[(i - 1) % len(cores)]}' for n, i in lab_id.items())
        print('  cores:', legenda)


# ===================================================================== configs

def cadeira_regras(c):
    RODA = (261.5, 882.0); RR = 262
    RODINHA = (583.5, 1071.5); RR2 = 76
    rr = c.raio(RODA)
    angs = raios_roda(c, RODA, 42, 198)
    print('  raios da roda grande:', len(angs), [round(a) for a in angs])
    raios = mascara_raios(c, RODA, angs, 38, 200)
    garfo = c.poly([(560, 880), (650, 880), (650, 1010), (600, 1080), (570, 1080), (560, 1000)])
    painel = c.poly([(228, 558), (594, 558), (594, 604), (568, 608), (568, 800), (228, 800)])
    manga = c.poly([(198, 268), (255, 258), (300, 280), (345, 385), (405, 465), (470, 485), (505, 502),
                    (500, 540), (445, 556), (380, 562), (320, 535), (255, 450), (215, 360)])
    metal_frente = (c.xs > 430) & (c.xs < 722) & (c.ys > 755) & (c.ys < 1062) & c.cinza(30) & (c.mn > 95)
    return [
        ('roda', (rr >= 198) & (rr <= RR + 1)),
        ('roda', rr <= 42),
        ('roda', raios),
        ('rodinha', c.disco(RODINHA, RR2) & ~garfo & ~(c.ys < RODINHA[1] - 60)),
        ('cabeca', c.acima([(150, 236), (200, 238), (330, 297), (420, 300)]) & (c.ys < 305)),
        ('braco', c.pele & (c.ys > 300)),
        ('braco', manga),
        ('frente', painel),
        ('frente', metal_frente | garfo),
        ('frente', (c.ys > 1028) & (c.xs > 690)),                         # descanso de pé
        ('tras', (c.xs < 186) & (c.ys > 385) & c.escuro(80)),             # encosto (borda visível)
        ('tras', c.poly([(25, 390), (170, 390), (178, 452), (25, 452)])), # manopla
        ('tras', (c.ys > 772) & (c.xs < 562)),                            # assento
        ('tronco', (c.xs < 470) & (c.ys < 800)),
        ('coxa', (c.xs + c.ys) < 1420),
        ('canela', np.ones_like(c.pele)),
    ]


CADEIRA = {
    'ordem': ['tras', 'rodinha', 'cabeca', 'tronco', 'coxa', 'canela', 'braco', 'frente', 'roda'],
    'regras': cadeira_regras,
    'rodas_radiais': {'rodinha': ((583.5, 1071.5), 76)},
    'cascas': {
        'cabeca': [('disco', (282, 268), 30)],
        'tronco': [('poly', [(195, 236), (262, 250), (330, 292), (402, 392), (442, 472), (452, 560),
                             (425, 720), (385, 795), (215, 800), (168, 720), (160, 560), (165, 330), (182, 262)])],
        'coxa': [('poly', [(250, 640), (420, 600), (600, 592), (760, 598), (796, 632), (802, 700), (650, 776),
                           (420, 792), (262, 792), (232, 722)]), ('disco', (725, 705), 55)],
        'canela': [('poly', [(655, 760), (800, 625), (826, 800), (842, 940), (930, 955), (935, 1034), (706, 1034), (690, 900)])],
        'braco': [('poly', [(198, 268), (255, 258), (300, 280), (345, 385), (405, 465), (470, 485), (505, 502),
                            (500, 540), (445, 556), (380, 562), (320, 535), (255, 450), (215, 360)])],
        'tras': [('poly', [(140, 445), (242, 445), (242, 810), (140, 810)]),
                 ('poly', [(140, 770), (652, 770), (652, 836), (140, 836)])],
    },
    'fisica': {
        'corpo_de': {'tras': 'chassi', 'frente': 'chassi', 'roda': 'roda0', 'rodinha': 'roda1',
                     'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco', 'coxa': 'coxa', 'canela': 'canela'},
        'piloto': ['tronco', 'cabeca', 'braco', 'coxa', 'canela'],
        'rodas': [{'corpo': 'roda0', 'c': [261.5, 882.0], 'r': 262, 'massa': 2.5, 'motriz': True},
                  {'corpo': 'roda1', 'c': [583.5, 1071.5], 'r': 76, 'massa': 0.6, 'motriz': False}],
        'chassi': {'massa': 7.0, 'auto_equilibrio': False, 'vmax': 760.0, 'forca': 120000.0,
                   'poly': [[140, 445], [242, 445], [592, 565], [700, 780], [865, 1030], [865, 1068],
                            [600, 1000], [400, 900], [140, 820]]},
        'corpos': {
            'cabeca': {'massa': 0.8, 'forma': ['circ', [297, 118], 108]},
            'tronco': {'massa': 2.0, 'forma': ['caps', [290, 280], [300, 720], 105]},
            'braco': {'massa': 0.5, 'forma': ['caps', [262, 312], [640, 585], 34]},
            'coxa': {'massa': 1.0, 'forma': ['caps', [330, 690], [745, 690], 74]},
            'canela': {'massa': 0.8, 'forma': ['caps', [760, 705], [800, 985], 58]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [282, 268], 'lim': 40, 'teste': 25},
            {'a': 'tronco', 'b': 'braco', 'p': [250, 300], 'lim': 80, 'teste': 50},
            {'a': 'tronco', 'b': 'coxa', 'p': [322, 700], 'lim': 70, 'teste': -35},
            {'a': 'coxa', 'b': 'canela', 'p': [725, 705], 'lim': 75, 'teste': 40},
        ],
    },
}


def scooter_regras(c):
    R0 = (138.0, 942.0); RR0 = 109
    R1 = (757.0, 950.0); RR1 = 100
    braco = c.poly([(298, 330), (362, 322), (405, 338), (462, 366), (522, 378), (578, 392), (582, 446),
                    (522, 456), (470, 455), (402, 468), (345, 482), (300, 466), (284, 400)])
    def roda(cn, r):
        return c.disco(cn, r) & (c.escuro(95) | (c.raio(cn) < 0.55 * r))
    return [
        ('roda0', roda(R0, RR0) & (c.ys > R0[1] - 0.72 * RR0)),
        ('roda1', roda(R1, RR1) & (c.ys > R1[1] - 0.72 * RR1)),
        ('cabeca', c.acima([(180, 282), (300, 300), (420, 312), (520, 330), (640, 340)]) & (c.xs > 150)),
        ('frente', braco & c.escuro(95)),                                  # manopla entre os dedos
        ('braco', braco),
        ('frente', c.poly([(176, 506), (402, 506), (402, 548), (176, 548)]) & c.escuro(95)),  # apoio de braço
        ('tronco', c.pele & (c.ys < 620) & (c.xs < 520) & (c.xs > 160)),
        ('tronco', (c.ys < 720) & (c.xs > 185) & (c.xs < 500) & c.claro(150)),               # fralda
        ('perna', c.pele & (c.ys >= 600) & (c.xs < 520)),
        ('tras', (c.xs < 205) & (c.ys < 770)),                             # encosto + giroflex
        ('tras', (c.ys > 640) & (c.ys < 770) & (c.xs < 490) & c.escuro(95)),                  # assento
        ('frente', np.ones_like(c.pele)),
    ]


SCOOTER = {
    'ordem': ['tras', 'roda0', 'roda1', 'cabeca', 'tronco', 'perna', 'braco', 'frente'],
    'regras': scooter_regras,
    'rodas_radiais': {'roda0': ((138.0, 942.0), 109), 'roda1': ((757.0, 950.0), 100)},
    'migalha': 500,
    'fonte_casca': {'tronco': 'pele'},
    'cascas': {
        'cabeca': [('disco', (372, 312), 40)],
        'tronco': [('poly', [(190, 290), (300, 300), (430, 315), (468, 345), (466, 470), (472, 560),
                             (485, 690), (330, 712), (200, 690), (185, 560), (180, 400)])],
        'braco': [('poly', [(298, 330), (362, 322), (405, 338), (462, 366), (522, 378), (578, 392), (582, 446),
                            (522, 456), (470, 455), (402, 468), (345, 482), (300, 466), (284, 400)])],
        'tras': [('poly', [(30, 350), (205, 350), (205, 770), (30, 770)]),
                 ('poly', [(170, 640), (500, 640), (500, 770), (170, 770)])],
    },
    'fisica': {
        'corpo_de': {'tras': 'chassi', 'frente': 'chassi', 'roda0': 'roda0', 'roda1': 'roda1',
                     'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco', 'perna': 'perna'},
        'piloto': ['tronco', 'cabeca', 'braco', 'perna'],
        'rodas': [{'corpo': 'roda0', 'c': [138.0, 942.0], 'r': 109, 'massa': 2.0, 'motriz': True},
                  {'corpo': 'roda1', 'c': [757.0, 950.0], 'r': 100, 'massa': 1.6, 'motriz': False}],
        'chassi': {'massa': 9.0, 'auto_equilibrio': False, 'vmax': 840.0, 'forca': 140000.0,
                   'poly': [[30, 360], [205, 360], [205, 640], [560, 640], [610, 470], [845, 470],
                            [866, 1000], [0, 1000], [0, 760], [30, 760]]},
        'corpos': {
            'cabeca': {'massa': 1.2, 'forma': ['circ', [378, 152], 158]},
            'tronco': {'massa': 2.4, 'forma': ['caps', [330, 360], [330, 620], 128]},
            'braco': {'massa': 0.5, 'forma': ['caps', [345, 360], [570, 420], 40]},
            'perna': {'massa': 1.2, 'forma': ['caps', [340, 660], [355, 770], 88]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [372, 312], 'lim': 35, 'teste': -25},
            {'a': 'tronco', 'b': 'braco', 'p': [345, 352], 'lim': 80, 'teste': -45},
            {'a': 'tronco', 'b': 'perna', 'p': [335, 640], 'lim': 60, 'teste': 30},
        ],
    },
}

if __name__ == '__main__':
    S = '/tmp/claude-0/-home-user-variant-agencia/d602722c-012a-5dc7-9c23-bb5704ae8c56/scratchpad/'
    for nome in sys.argv[1:]:
        cfg = {'cadeira': CADEIRA, 'scooter': SCOOTER}[nome]
        cfg['dbg'] = S + f'seg-{nome}.png'
        print('==', nome)
        rodar(nome, cfg)
