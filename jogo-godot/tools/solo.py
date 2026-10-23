"""Recorta personagem de UMA imagem sem veículo de verdade (Caio na bola, Vini a pé).

Uso: python3 tools/solo.py <caio|vini>

- cada parte do corpo sai de um polígono, na ordem (o primeiro fica com o pixel);
- a bola do Caio é um disco que gira (roda);
- o Vini anda: a perna da frente é recortada inteira e a de trás é a mesma perna
  um pouco mais escura (coxa2/canela2), pra animar o passo.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
FONTE = os.path.join(AQUI, 'fonte')


def poly(W, H, pts):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=1)
    return np.asarray(m).astype(bool)


def salvar(img, nome, out_dir):
    bb = img.getbbox()
    img = img.crop(bb)
    img.save(os.path.join(out_dir, nome + '.png'))
    return {'x': bb[0], 'y': bb[1], 'w': img.width, 'h': img.height}


def rodar(nome, cfg):
    full = np.asarray(Image.open(os.path.join(FONTE, f'{nome}_full.png')).convert('RGBA'))
    H, W = full.shape[:2]
    out_dir = os.path.join(AQUI, '..', 'assets', nome)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith(('.png', '.json', '.import')):
            os.remove(os.path.join(out_dir, f))
    livre = full[..., 3] > 0
    pecas = {}
    yy, xx = np.mgrid[0:H, 0:W]
    for r in cfg['fisica']['rodas']:
        if 'peca' in r:
            cx, cy = r['c']
            disco = ((xx - cx) ** 2 + (yy - cy) ** 2 <= (r['r'] + 2) ** 2) & livre & (yy > cy - r['r'] + 12)
            img = Image.fromarray(np.dstack([full[..., :3], np.where(disco, full[..., 3], 0)]).astype(np.uint8), 'RGBA')
            pecas[r['peca']] = salvar(img, r['peca'], out_dir)
            livre &= ~disco
    for parte in cfg['ordem_recorte']:
        own = poly(W, H, cfg['partes'][parte]) & livre
        livre &= ~own
        cor = full[..., :3].astype(float)
        a = np.where(own, full[..., 3], 0)
        if parte in cfg.get('completar', {}):          # buraco do braço no tronco: preenche com a cor em volta
            n = cfg['completar'][parte]
            dil = ndimage.distance_transform_edt(~own) <= n / 2       # fechamento por distância (leve)
            fechado = ndimage.binary_fill_holes(ndimage.distance_transform_edt(dil) > n / 2)
            buraco = fechado & ~own & (full[..., 3] > 0)
            if buraco.any():
                _, (iy, ix) = ndimage.distance_transform_edt(~own, return_indices=True)
                viz = full[..., :3][iy, ix].astype(float)
                viz = np.stack([ndimage.gaussian_filter(viz[..., c], 3) for c in range(3)], 2)
                cor[buraco] = viz[buraco]
                a = np.where(buraco, 255, a)
        img = Image.fromarray(np.dstack([cor.clip(0, 255), a]).astype(np.uint8), 'RGBA')
        pecas[parte] = salvar(img, parte, out_dir)
        print(f'  {parte:8s} {pecas[parte]}')
    for copia, de in cfg.get('copias', {}).items():      # perna de trás: mesma perna, mais escura
        img = Image.open(os.path.join(out_dir, de + '.png'))
        a = img.getchannel('A')
        img = ImageEnhance.Brightness(img.convert('RGB')).enhance(0.62).convert('RGBA')
        img.putalpha(a)
        img.save(os.path.join(out_dir, copia + '.png'))
        pecas[copia] = dict(pecas[de])
    meta = {'nome': nome, 'src_w': W, 'src_h': H, 'ordem': cfg['ordem_desenho'], 'pecas': pecas}
    meta.update(cfg['fisica'])
    json.dump(meta, open(os.path.join(out_dir, 'parts.json'), 'w'), indent=1)


CAIO = {
    'ordem_recorte': ['cabeca', 'braco', 'perna', 'tronco'],
    'partes': {
        'cabeca': [(395, 30), (670, 30), (670, 300), (560, 300), (540, 315), (450, 290), (395, 220)],
        'braco': [(300, 470), (340, 400), (395, 420), (440, 480), (530, 445), (575, 430), (608, 495), (645, 572),
                  (600, 588), (470, 570), (330, 592), (298, 540)],
        'perna': [(395, 745), (625, 735), (625, 1000), (665, 1210), (665, 1300), (395, 1300), (415, 1000)],
        'tronco': [(280, 280), (720, 280), (720, 770), (380, 770), (280, 600)],
    },
    'ordem_desenho': ['roda', 'perna', 'tronco', 'cabeca', 'braco'],
    'fisica': {
        'corpo_de': {'roda': 'roda0', 'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco', 'perna': 'perna'},
        'piloto': ['tronco', 'cabeca', 'braco', 'perna'],
        'rodas': [{'corpo': 'roda0', 'peca': 'roda', 'c': [522.0, 1396.0], 'r': 124, 'massa': 2.0, 'motriz': True}],
        'chassi': {'massa': 5.0, 'auto_equilibrio': True, 'preciso': True, 'vmax': 900.0, 'forca': 90000.0,
                   'mastro': {'x': 520.0, 'y0': 300.0, 'y1': 1396.0, 'w': 100.0}},
        'corpos': {
            'cabeca': {'massa': 0.8, 'forma': ['circ', [530, 170], 120]},
            'tronco': {'massa': 2.0, 'forma': ['caps', [470, 360], [490, 700], 110]},
            'braco': {'massa': 0.5, 'forma': ['caps', [390, 440], [620, 560], 40]},
            'perna': {'massa': 1.4, 'forma': ['caps', [500, 770], [530, 1250], 75]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [525, 290], 'lim': 40},
            {'a': 'tronco', 'b': 'braco', 'p': [400, 425], 'lim': 75},
            {'a': 'tronco', 'b': 'perna', 'p': [505, 745], 'lim': 55},
        ],
    },
}

VINI = {
    'ordem_recorte': ['cabeca', 'braco', 'tronco', 'coxa', 'canela'],
    'partes': {
        'cabeca': [(60, 80), (370, 80), (370, 330), (300, 348), (230, 352), (150, 320), (70, 260)],
        'braco': [(62, 440), (130, 385), (180, 420), (175, 600), (160, 700), (170, 830), (245, 895), (250, 965),
                  (150, 985), (90, 925), (72, 800), (62, 650)],
        'tronco': [(0, 330), (384, 330), (384, 985), (280, 985), (140, 1005), (30, 1045), (0, 1045)],
        'coxa': [(60, 940), (300, 940), (280, 1080), (250, 1185), (95, 1185), (80, 1080)],
        'canela': [(30, 1185), (260, 1185), (240, 1290), (340, 1380), (340, 1470), (20, 1470), (30, 1380), (70, 1290)],
    },
    'copias': {'coxa2': 'coxa', 'canela2': 'canela'},
    'completar': {'tronco': 45},
    'ordem_desenho': ['coxa2', 'canela2', 'tronco', 'coxa', 'canela', 'braco', 'cabeca'],
    'fisica': {
        'corpo_de': {'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco', 'coxa': 'coxa', 'canela': 'canela',
                     'coxa2': 'coxa2', 'canela2': 'canela2'},
        'piloto': ['tronco', 'cabeca', 'braco', 'coxa', 'canela', 'coxa2', 'canela2'],
        'rodas': [{'corpo': 'roda0', 'c': [185.0, 1350.0], 'r': 100, 'massa': 2.0, 'motriz': True}],
        'chassi': {'massa': 5.0, 'auto_equilibrio': True, 'andar': True, 'preciso': True, 'vmax': 950.0,
                   'forca': 90000.0, 'mastro': {'x': 185.0, 'y0': 300.0, 'y1': 1350.0, 'w': 90.0}},
        'corpos': {
            'cabeca': {'massa': 0.8, 'forma': ['circ', [230, 225], 115]},
            'tronco': {'massa': 2.0, 'forma': ['caps', [180, 450], [170, 900], 105]},
            'braco': {'massa': 0.5, 'forma': ['caps', [150, 440], [190, 930], 40]},
            'coxa': {'massa': 0.9, 'forma': ['caps', [180, 980], [170, 1170], 65]},
            'canela': {'massa': 0.8, 'forma': ['caps', [160, 1195], [180, 1420], 60]},
            'coxa2': {'massa': 0.9, 'forma': ['caps', [180, 980], [170, 1170], 65]},
            'canela2': {'massa': 0.8, 'forma': ['caps', [160, 1195], [180, 1420], 60]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [205, 350], 'lim': 40},
            {'a': 'tronco', 'b': 'braco', 'p': [150, 420], 'lim': 80},
            {'a': 'tronco', 'b': 'coxa', 'p': [180, 960], 'lim': 70},
            {'a': 'coxa', 'b': 'canela', 'p': [170, 1180], 'lim': 75},
            {'a': 'tronco', 'b': 'coxa2', 'p': [180, 960], 'lim': 70},
            {'a': 'coxa2', 'b': 'canela2', 'p': [170, 1180], 'lim': 75},
        ],
    },
}

if __name__ == '__main__':
    for n in sys.argv[1:]:
        print('==', n)
        rodar(n, {'caio': CAIO, 'vini': VINI}[n])
