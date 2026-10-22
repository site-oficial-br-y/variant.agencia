"""Recorta personagens que vieram com DUAS imagens: piloto no veículo + veículo sozinho.

Uso: python3 tools/novos.py <bicho|wendell>

- o veículo inteiro sai da imagem "veiculo" alinhada (escala + deslocamento) à
  imagem com o piloto: fica completo quando o piloto cai;
- o piloto sai da imagem "full" por polígonos de parte do corpo; no carrinho as
  barras finas de metal que passam na frente dele são removidas e o buraco é
  preenchido com a cor vizinha (casca);
- as rodas que giram são discos recortados do veículo alinhado.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
FONTE = os.path.join(AQUI, 'fonte')


def carregar(arq):
    return np.asarray(Image.open(os.path.join(FONTE, arq)).convert('RGBA')).astype(np.int16)


def poly(W, H, pts):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=1)
    return np.asarray(m).astype(bool)


def alinhar(full, veic):
    """melhor escala/deslocamento do veículo sobre a imagem com piloto (máscaras opacas)"""
    ma = full[..., 3] > 100
    mb = veic[..., 3] > 100
    pa = ndimage.zoom(ma.astype(float), 0.25, order=0) > 0.5
    melhor = None
    for s in np.arange(0.90, 1.06, 0.005):
        pb = ndimage.zoom(mb.astype(float), 0.25 * s, order=0) > 0.5
        for dy in range(-6, 36):
            for dx in range(-14, 16):
                sh = np.zeros_like(pa)
                y0, x0 = max(0, dy), max(0, dx)
                y1 = min(pa.shape[0], pb.shape[0] + dy)
                x1 = min(pa.shape[1], pb.shape[1] + dx)
                if y1 <= y0 or x1 <= x0:
                    continue
                sh[y0:y1, x0:x1] = pb[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
                sc = (sh & pa).sum() / max(sh.sum(), 1)
                if melhor is None or sc > melhor[0]:
                    melhor = (sc, s, dx * 4, dy * 4)
    sc, s, dx, dy = melhor
    H, W = full.shape[:2]
    img = Image.fromarray(veic.astype(np.uint8), 'RGBA')
    img = img.resize((int(img.width * s), int(img.height * s)), Image.LANCZOS)
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.alpha_composite(img, (dx, dy)) if dx >= 0 and dy >= 0 else out.paste(img, (dx, dy), img)
    print('  alinhamento: cobre %.3f escala %.3f dx %d dy %d' % (sc, s, dx, dy))
    return np.asarray(out).astype(np.int16)


def suave(rgb, fonte, sigma=6):
    _, (iy, ix) = ndimage.distance_transform_edt(~fonte, return_indices=True)
    nn = rgb[iy, ix].astype(float)
    return np.stack([ndimage.gaussian_filter(nn[:, :, c], sigma) for c in range(3)], 2)


def salvar(nome, rgb, a, out_dir):
    img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.clip(a, 0, 255).astype(np.uint8)]), 'RGBA')
    bb = img.getbbox()
    img = img.crop(bb)
    img.save(os.path.join(out_dir, nome + '.png'))
    return {'x': bb[0], 'y': bb[1], 'w': img.width, 'h': img.height}


def rodar(nome, cfg, dbg=None):
    full = carregar(f'{nome}_full.png')
    veic = alinhar(full, carregar(f'{nome}_veiculo.png'))
    H, W = full.shape[:2]
    rgb = full[..., :3]
    mx, mn = rgb.max(2), rgb.min(2)
    opaco = full[..., 3] > 100
    out_dir = os.path.join(AQUI, '..', 'assets', nome)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith(('.png', '.json', '.import')):
            os.remove(os.path.join(out_dir, f))
    pecas = {}
    # piloto
    barra = np.zeros((H, W), bool)
    if cfg.get('tirar_barras'):
        yy0, xx0 = np.mgrid[0:H, 0:W]
        tenis = (xx0 > 870) & (yy0 > 690) & (mx > 200)                # tênis branco não é barra
        metal = ((mx - mn) < 30) & (mx > 95) & ~tenis
        grosso = ndimage.binary_opening(metal, structure=np.ones((27, 27)))
        barra = metal & ~grosso
        barra = ndimage.binary_dilation(barra, iterations=3) & ~tenis
        vermelho = (rgb[..., 0] > 140) & (rgb[..., 1] < 90) & (rgb[..., 2] < 90)
        barra |= vermelho
    e_veiculo = None
    if cfg.get('tirar_iguais'):        # pixel igual ao do veículo sozinho = é do veículo (selim, manopla, corrente)
        pele = (rgb[..., 0] > 150) & (rgb[..., 0] - rgb[..., 2] > 40) & (rgb[..., 1] > 90)
        igual = (veic[..., 3] > 150) & (np.abs(rgb - veic[..., :3]).max(2) < 24) & ~pele
        e_veiculo = ndimage.binary_opening(igual, iterations=2)
    else:
        e_veiculo = np.zeros((H, W), bool)
    livre = opaco.copy()
    for parte in cfg['ordem_piloto']:
        area = poly(W, H, cfg['partes'][parte])
        own = area & livre & ~barra & ~e_veiculo
        if parte in cfg.get('so_claro', []):        # pé de trás: só o tênis (pedal e corrente ficam na bike)
            own &= mx > 150
        livre &= ~area
        cor = rgb.copy()
        a = np.where(own, full[..., 3], 0)
        buraco = area & opaco & ~own & ~e_veiculo                     # onde passava barra: completa
        if buraco.any():
            sm = suave(rgb, own & (full[..., 3] > 200), 2)
            cor[buraco] = sm[buraco].astype(np.int16)
            a[buraco] = 255
        pecas[parte] = salvar(parte, cor, a, out_dir)
        print(f'  {parte:8s} {pecas[parte]}')
    # veículo: rodas (discos) e o resto
    va = veic[..., 3].copy()
    yy, xx = np.mgrid[0:H, 0:W]
    for i, r in enumerate(cfg['fisica']['rodas']):
        cx, cy = r['c']
        rr = r.get('r_visual', r['r'])
        disco = (xx - cx) ** 2 + (yy - cy) ** 2 <= rr * rr
        nomep = f'roda{i}'
        if r.get('girar', True):
            pecas[nomep] = salvar(nomep, veic[..., :3], np.where(disco, va, 0), out_dir)
            va = np.where(disco, 0, va)
    pecas['veiculo'] = salvar('veiculo', veic[..., :3], va, out_dir)
    ordem = list(cfg['ordem_desenho'])
    for i, r in enumerate(cfg['fisica']['rodas']):
        if r.get('girar', True) and f'roda{i}' not in ordem:
            ordem.insert(0, f'roda{i}')
    meta = {'nome': nome, 'src_w': W, 'src_h': H, 'ordem': ordem, 'pecas': pecas}
    meta.update(cfg['fisica'])
    corpo_de = dict(meta['corpo_de'])
    for i, r in enumerate(cfg['fisica']['rodas']):
        if r.get('girar', True):
            corpo_de[f'roda{i}'] = r['corpo']
    meta['corpo_de'] = corpo_de
    json.dump(meta, open(os.path.join(out_dir, 'parts.json'), 'w'), indent=1)
    if dbg:
        fundo = Image.new('RGBA', (W, H), (140, 190, 230, 255))
        mont = fundo.copy()
        for k in ordem:
            p = pecas[k]
            mont.alpha_composite(Image.open(os.path.join(out_dir, k + '.png')), (p['x'], p['y']))
        so_v = fundo.copy()
        for k in ordem:
            if meta['corpo_de'].get(k, '') in meta['piloto']:
                continue
            p = pecas[k]
            so_v.alpha_composite(Image.open(os.path.join(out_dir, k + '.png')), (p['x'], p['y']))
        so_p = fundo.copy()
        for k in ordem:
            if meta['corpo_de'].get(k, '') in meta['piloto']:
                p = pecas[k]
                so_p.alpha_composite(Image.open(os.path.join(out_dir, k + '.png')), (p['x'], p['y']))
        orig = fundo.copy()
        orig.alpha_composite(Image.fromarray(full.astype(np.uint8), 'RGBA'))
        lado = Image.new('RGB', (W * 4 + 60, H), (15, 15, 15))
        for k, im_ in enumerate([orig, mont, so_v, so_p]):
            lado.paste(im_.convert('RGB'), (k * (W + 20), 0))
        lado.resize((lado.width * 2 // 5, lado.height * 2 // 5)).save(dbg)


BICHO = {
    'tirar_barras': True,
    'ordem_piloto': ['cabeca', 'braco', 'canela', 'coxa', 'tronco'],
    'partes': {
        'cabeca': [(420, 40), (720, 30), (730, 330), (560, 400), (470, 380), (430, 300)],
        'braco': [(700, 330), (760, 340), (860, 420), (1010, 430), (1010, 520), (900, 560), (830, 545), (740, 470), (650, 430)],
        'canela': [(800, 400), (900, 420), (960, 560), (1010, 690), (1180, 750), (1170, 815), (880, 815), (860, 760), (790, 560)],
        'coxa': [(560, 520), (800, 400), (860, 470), (800, 600), (870, 790), (700, 800), (490, 795), (470, 640)],
        'tronco': [(330, 330), (480, 230), (720, 330), (700, 470), (560, 520), (480, 640), (480, 790), (390, 780), (335, 640)],
    },
    'ordem_desenho': ['tronco', 'coxa', 'canela', 'veiculo', 'braco', 'cabeca'],
    'fisica': {
        'corpo_de': {'veiculo': 'chassi', 'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco',
                     'coxa': 'coxa', 'canela': 'canela'},
        'piloto': ['tronco', 'cabeca', 'braco', 'coxa', 'canela'],
        'rodas': [{'corpo': 'roda0', 'c': [192.0, 1092.0], 'r': 62, 'massa': 1.0, 'motriz': True},
                  {'corpo': 'roda1', 'c': [1065.0, 1110.0], 'r': 62, 'massa': 1.0, 'motriz': False}],
        'chassi': {'massa': 7.0, 'auto_equilibrio': False, 'vmax': 800.0, 'forca': 0.0, 'cesto': True,
                   'poly': [[150, 840], [1160, 820], [1140, 1010], [230, 1010]],
                   'paredes': [[[165, 420], [180, 845]], [[1165, 470], [1150, 830]]]},
        'corpos': {
            'cabeca': {'massa': 0.9, 'forma': ['circ', [580, 190], 135]},
            'tronco': {'massa': 2.2, 'forma': ['caps', [430, 360], [440, 720], 120]},
            'braco': {'massa': 0.5, 'forma': ['caps', [700, 390], [960, 470], 45]},
            'coxa': {'massa': 1.1, 'forma': ['caps', [560, 720], [820, 470], 80]},
            'canela': {'massa': 1.0, 'forma': ['caps', [850, 480], [1040, 760], 70]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [560, 340], 'lim': 40},
            {'a': 'tronco', 'b': 'braco', 'p': [690, 380], 'lim': 80},
            {'a': 'tronco', 'b': 'coxa', 'p': [520, 730], 'lim': 70},
            {'a': 'coxa', 'b': 'canela', 'p': [830, 440], 'lim': 75},
        ],
    },
}

WENDELL = {
    'tirar_iguais': True,
    'so_claro': ['pe2'],
    'ordem_piloto': ['cabeca', 'braco', 'canela', 'pe2', 'coxa', 'tronco'],
    'partes': {
        'cabeca': [(495, 40), (700, 30), (710, 230), (640, 245), (575, 235), (500, 140)],
        'braco': [(560, 300), (640, 300), (720, 360), (880, 395), (900, 470), (840, 480), (700, 430), (560, 400)],
        'tronco': [(340, 230), (560, 190), (690, 250), (700, 330), (560, 400), (520, 552), (350, 552), (330, 400)],
        'coxa': [(350, 500), (560, 460), (720, 540), (730, 640), (640, 650), (470, 600), (360, 552)],
        'canela': [(540, 640), (730, 600), (700, 760), (700, 900), (520, 900), (530, 790), (560, 760)],
        'pe2': [(545, 962), (660, 962), (660, 1036), (545, 1036)],
    },
    'ordem_desenho': ['pe2', 'veiculo', 'tronco', 'coxa', 'canela', 'braco', 'cabeca'],
    'fisica': {
        'corpo_de': {'veiculo': 'chassi', 'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco',
                     'coxa': 'coxa', 'canela': 'canela', 'pe2': 'canela'},
        'piloto': ['tronco', 'cabeca', 'braco', 'coxa', 'canela'],
        'rodas': [{'corpo': 'roda0', 'c': [267.0, 942.0], 'r': 180, 'massa': 2.0, 'motriz': True},
                  {'corpo': 'roda1', 'c': [1033.0, 933.0], 'r': 180, 'massa': 1.6, 'motriz': False}],
        'chassi': {'massa': 8.0, 'auto_equilibrio': False, 'vmax': 860.0, 'forca': 0.0,
                   'poly': [[150, 690], [440, 690], [700, 640], [880, 430], [960, 450], [1000, 700],
                            [1020, 930], [700, 960], [267, 942]]},
        'corpos': {
            'cabeca': {'massa': 0.9, 'forma': ['circ', [600, 140], 100]},
            'tronco': {'massa': 2.2, 'forma': ['caps', [470, 300], [440, 520], 115]},
            'braco': {'massa': 0.5, 'forma': ['caps', [600, 340], [880, 440], 40]},
            'coxa': {'massa': 1.1, 'forma': ['caps', [430, 560], [680, 590], 75]},
            'canela': {'massa': 1.0, 'forma': ['caps', [660, 620], [620, 830], 60]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [585, 225], 'lim': 40},
            {'a': 'tronco', 'b': 'braco', 'p': [585, 320], 'lim': 80},
            {'a': 'tronco', 'b': 'coxa', 'p': [440, 560], 'lim': 70},
            {'a': 'coxa', 'b': 'canela', 'p': [690, 600], 'lim': 75},
        ],
    },
}

if __name__ == '__main__':
    S = '/tmp/claude-0/-home-user-variant-agencia/d602722c-012a-5dc7-9c23-bb5704ae8c56/scratchpad/'
    for n in sys.argv[1:]:
        print('==', n)
        rodar(n, {'bicho': BICHO, 'wendell': WENDELL}[n], S + f'novo-{n}.png')
