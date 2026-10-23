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
    dono_de = {}
    for parte in cfg['ordem_recorte']:
        own = poly(W, H, cfg['partes'][parte]) & livre
        dono_de[parte] = own.copy()
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
        if parte in cfg.get('tapar', {}):              # área atrás de outra peça: cor do vizinho
            area = poly(W, H, cfg['tapar'][parte]) & ~own & (full[..., 3] > 0)
            _, (iy, ix) = ndimage.distance_transform_edt(~own, return_indices=True)
            viz = full[..., :3][iy, ix].astype(float)
            viz = np.stack([ndimage.gaussian_filter(viz[..., c], 3) for c in range(3)], 2)
            cor[area] = viz[area]
            a = np.where(area, 255, a)
        img = Image.fromarray(np.dstack([cor.clip(0, 255), a]).astype(np.uint8), 'RGBA')
        pecas[parte] = salvar(img, parte, out_dir)
        print(f'  {parte:8s} {pecas[parte]}')
    if 'resto' in cfg:                                   # veículo = o que sobrou (gorila); atrás do piloto é preenchido
        own = livre & (full[..., 3] > 0)
        for nome_p, pol in cfg.get('resto_manter', {}).items():   # ombro/quadril ficam no corpo (sem buraco quando a pata mexe)
            own |= poly(W, H, pol) & dono_de[nome_p] & (full[..., 3] > 0)
        lab, n = ndimage.label(own)                          # só o pedaço grande (some farelo do piloto)
        if n > 1:
            tam = ndimage.sum(own, lab, range(1, n + 1))
            own = np.isin(lab, [i + 1 for i in range(n) if tam[i] > 3000])
        cor = full[..., :3].astype(float)
        a = np.where(own, full[..., 3], 0)
        buraco = np.zeros((H, W), bool)
        for pol in cfg['resto_fundo']:
            buraco |= poly(W, H, pol)
        buraco &= ~own
        pelo = own & (full[..., :3].max(2) < 110)                 # copia o pelo vizinho (espelhado pra dentro do buraco)
        _, (iy, ix) = ndimage.distance_transform_edt(~pelo, return_indices=True)
        dy = iy - np.mgrid[0:H, 0:W][0]
        dx = ix - np.mgrid[0:H, 0:W][1]
        ry = np.clip(iy + dy, 0, H - 1)
        rx = np.clip(ix + dx, 0, W - 1)
        espelho = np.where(pelo[ry, rx][..., None], full[..., :3][ry, rx], full[..., :3][iy, ix]).astype(float)
        base = np.array(cfg.get('resto_cor', (45, 38, 35)), float)
        cor[buraco] = np.clip(espelho[buraco] * 0.7 + base * 0.3, 0, 255)
        a = np.where(buraco, 255, a)
        img = Image.fromarray(np.dstack([cor.clip(0, 255), a]).astype(np.uint8), 'RGBA')
        pecas[cfg['resto']] = salvar(img, cfg['resto'], out_dir)
    for copia, de in cfg.get('copias', {}).items():      # perna de trás: mesma perna, mais escura
        img = Image.open(os.path.join(out_dir, de + '.png'))
        a = img.getchannel('A')
        img = ImageEnhance.Brightness(img.convert('RGB')).enhance(0.62).convert('RGBA')
        img.putalpha(a)
        img.save(os.path.join(out_dir, copia + '.png'))
        pecas[copia] = dict(pecas[de])
        dx, dy = cfg.get('copias_desloc', {}).get(copia, (0, 0))     # braço de trás um pouco atrás
        pecas[copia]['x'] += dx
        pecas[copia]['y'] += dy
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

LIMA = {
    'ordem_recorte': ['cabeca', 'braco', 'canela', 'coxa', 'tronco', 'gbraco', 'gperna', 'gperna2'],
    'partes': {
        'gperna': [(150, 920), (230, 868), (330, 848), (402, 900), (402, 962), (335, 1000), (322, 1060), (315, 1182),
                   (95, 1182), (92, 1100), (110, 1000)],
        'gperna2': [(398, 962), (560, 940), (645, 1000), (652, 1182), (398, 1182), (392, 1060)],
        'gbraco': [(830, 620), (960, 600), (1010, 760), (1070, 850), (1100, 880), (1150, 960), (1200, 1100), (1200, 1178),
                   (1005, 1178), (1020, 1080), (950, 1010), (900, 980), (860, 900), (830, 760)],
        'cabeca': [(550, 10), (825, 10), (825, 250), (740, 264), (690, 252), (620, 215), (552, 160)],
        'braco': [(600, 330), (700, 318), (790, 465), (862, 468), (862, 532), (812, 562), (760, 525), (690, 472), (600, 432)],
        'canela': [(600, 655), (765, 655), (748, 760), (683, 858), (722, 900), (722, 995), (505, 995), (505, 905), (560, 828), (600, 752)],
        'coxa': [(478, 525), (765, 515), (775, 650), (742, 702), (610, 702), (560, 722), (478, 640)],
        'tronco': [(450, 195), (722, 195), (795, 330), (805, 500), (765, 540), (478, 562), (450, 400)],
    },
    'resto': 'veiculo',
    'resto_fundo': [[(462, 618), (520, 598), (600, 580), (700, 556), (780, 528), (840, 500), (875, 488), (875, 1010), (462, 1010)],
                    ],
    'resto_manter': {'gbraco': [(820, 590), (1015, 590), (1050, 830), (830, 830)],
                     'gperna': [(190, 850), (410, 850), (410, 965), (190, 965)],
                     'gperna2': [(390, 935), (655, 935), (655, 1015), (390, 1015)]},
    'copias': {'gbraco2': 'gbraco'},
    'copias_desloc': {'gbraco2': (-105, 0)},
    'resto_cor': (42, 35, 32),
    'tapar': {'tronco': [(600, 330), (700, 318), (790, 462), (790, 520), (700, 530), (600, 520)]},
    'ordem_desenho': ['gperna2', 'gbraco2', 'veiculo', 'gperna', 'gbraco', 'tronco', 'coxa', 'canela', 'braco', 'cabeca'],
    'fisica': {
        'bracos_veiculo': {'gbraco': [905, 640], 'gbraco2': [800, 640], 'gperna': [330, 880], 'gperna2': [520, 960]},
        'fases_veiculo': {'gbraco': 0.0, 'gperna2': 0.0, 'gbraco2': 3.14159, 'gperna': 3.14159},
        'pernas_veiculo': ['gperna', 'gperna2'],
        'corpo_de': {'veiculo': 'chassi', 'gbraco': 'braco_veiculo', 'gbraco2': 'braco_veiculo',
                     'gperna': 'braco_veiculo', 'gperna2': 'braco_veiculo', 'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco', 'coxa': 'coxa', 'canela': 'canela'},
        'piloto': ['tronco', 'cabeca', 'braco', 'coxa', 'canela'],
        'rodas': [{'corpo': 'roda0', 'c': [235.0, 1120.0], 'r': 70, 'massa': 2.5, 'motriz': True},
                  {'corpo': 'roda1', 'c': [1100.0, 1120.0], 'r': 70, 'massa': 2.5, 'motriz': False}],
        'chassi': {'massa': 9.0, 'auto_equilibrio': False, 'trote': True, 'vmax': 850.0, 'forca': 0.0,
                   'poly': [[170, 1030], [330, 640], [600, 580], [880, 430], [1080, 470], [1215, 640], [1190, 760], [1130, 1030]]},
        'corpos': {
            'cabeca': {'massa': 0.8, 'forma': ['circ', [700, 140], 115]},
            'tronco': {'massa': 2.0, 'forma': ['caps', [565, 290], [600, 515], 105]},
            'braco': {'massa': 0.5, 'forma': ['caps', [645, 365], [840, 500], 42]},
            'coxa': {'massa': 1.1, 'forma': ['caps', [520, 610], [740, 640], 72]},
            'canela': {'massa': 1.0, 'forma': ['caps', [690, 690], [620, 945], 60]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [680, 252], 'lim': 40},
            {'a': 'tronco', 'b': 'braco', 'p': [640, 350], 'lim': 80},
            {'a': 'tronco', 'b': 'coxa', 'p': [530, 590], 'lim': 70},
            {'a': 'coxa', 'b': 'canela', 'p': [722, 662], 'lim': 75},
        ],
    },
}

if __name__ == '__main__':
    for n in sys.argv[1:]:
        print('==', n)
        rodar(n, {'caio': CAIO, 'vini': VINI, 'lima': LIMA}[n])
