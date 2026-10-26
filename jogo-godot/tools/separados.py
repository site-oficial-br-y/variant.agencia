"""Recorta personagem que veio com imagens SEPARADAS: montado, piloto sozinho e
veículo sozinho (e, se tiver, o piloto da habilidade, ex.: Chefe sem camisa).

Uso: python3 tools/separados.py <lima|chefe>

- cada parte do piloto sai da imagem do piloto sozinho (nada escondido atrás do veículo);
- o veículo (ou bicho) sai da imagem dele sozinho: patas articuladas recortadas inteiras
  e o corpo fica com ombro/quadril (sem buraco quando a pata mexe);
- imagens que não batem com a montada são alinhadas (escala + deslocamento).
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageEnhance
from scipy import ndimage
from solo import poly, salvar, FONTE, AQUI
from novos import alinhar


def carregar(arq):
    return np.asarray(Image.open(os.path.join(FONTE, arq)).convert('RGBA')).astype(np.int16)


def recortar(img, own, nome, out_dir, tapar=None, livre_total=None):
    H, W = own.shape
    cor = img[..., :3].astype(float)
    a = np.where(own, img[..., 3], 0)
    if tapar is not None:                                   # atrás de outra peça: cor do vizinho
        area = poly(W, H, tapar) & ~own & (img[..., 3] > 0)
        _, (iy, ix) = ndimage.distance_transform_edt(~own, return_indices=True)
        viz = img[..., :3][iy, ix].astype(float)
        viz = np.stack([ndimage.gaussian_filter(viz[..., c], 3) for c in range(3)], 2)
        cor[area] = viz[area]
        a = np.where(area, 255, a)
    out = Image.fromarray(np.dstack([cor.clip(0, 255), a]).astype(np.uint8), 'RGBA')
    return salvar(out, nome, out_dir)


def rodar(nome, cfg, skin=''):
    base = f'{nome}_{skin}' if skin else nome           # skin: mesma divisão, artes da skin
    arte = lambda arq: arq.replace(nome + '_', base + '_', 1) if skin else arq
    full = carregar(f'{base}_full.png')
    H, W = full.shape[:2]
    piloto = carregar(arte(cfg['img_piloto']))
    veic = carregar(arte(cfg['img_veiculo']))
    if cfg.get('alinhar_veiculo'):
        veic = alinhar(full, veic)
    if cfg.get('alinhar_piloto'):
        piloto = alinhar(full, piloto)
    out_dir = os.path.join(AQUI, '..', 'assets', base)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith(('.png', '.json', '.import')):
            os.remove(os.path.join(out_dir, f))
    pecas = {}
    yy, xx = np.mgrid[0:H, 0:W]
    livre_v = veic[..., 3] > 0
    for r in cfg['fisica']['rodas']:
        if 'peca' in r:
            cx, cy = r['c']
            disco = ((xx - cx) ** 2 + (yy - cy) ** 2 <= (r['r'] + 3) ** 2) & livre_v
            pecas[r['peca']] = recortar(veic, disco, r['peca'], out_dir)
            livre_v &= ~disco
    livre_p = piloto[..., 3] > 0
    total_p = livre_p.sum()
    for parte in cfg['ordem_piloto']:
        own = poly(W, H, cfg['partes'][parte]) & livre_p
        livre_p &= ~own
        pecas[parte] = recortar(piloto, own, parte, out_dir, cfg.get('tapar', {}).get(parte))
    print('  piloto: %.1f%% dos pixels fora das partes' % (100.0 * (livre_p & (piloto[..., 3] > 128)).sum() / max(total_p, 1)))
    for parte, pol in cfg.get('frente_veiculo', {}).items():   # pedaço do veículo na frente do piloto (porta)
        own = poly(W, H, pol) & livre_v
        livre_v &= ~own
        pecas[parte] = recortar(veic, own, parte, out_dir)
    dono = {}
    for parte in cfg.get('ordem_veiculo', []):
        own = poly(W, H, cfg['partes'][parte]) & livre_v
        dono[parte] = own.copy()
        livre_v &= ~own
        pecas[parte] = recortar(veic, own, parte, out_dir)
    corpo = livre_v.copy()
    for parte, pol in cfg.get('manter', {}).items():        # ombro/quadril ficam no corpo
        corpo |= poly(W, H, pol) & dono[parte]
    lab, n = ndimage.label(corpo)
    if n > 1:
        tam = ndimage.sum(corpo, lab, range(1, n + 1))
        corpo = np.isin(lab, [i + 1 for i in range(n) if tam[i] > 3000])
    img_corpo = veic.copy()
    if cfg.get('fundo_corpo'):                           # atrás da pata (quando ela sai do lugar): pelo espelhado
        buraco = np.zeros((H, W), bool)
        for pol in cfg['fundo_corpo']:
            buraco |= poly(W, H, pol)
        buraco &= ~corpo
        pelo = corpo if cfg.get('pelo_todo') else corpo & (veic[..., :3].max(2) < 110)   # gorila dourado: pelo é claro
        _, (iy, ix) = ndimage.distance_transform_edt(~pelo, return_indices=True)
        ry = np.clip(2 * iy - yy, 0, H - 1)
        rx = np.clip(2 * ix - xx, 0, W - 1)
        esp = np.where(pelo[ry, rx][..., None], veic[..., :3][ry, rx], veic[..., :3][iy, ix])
        img_corpo[..., :3][buraco] = esp[buraco]
        img_corpo[..., 3][buraco] = 255
        corpo |= buraco
    pecas['veiculo'] = recortar(img_corpo, corpo, 'veiculo', out_dir)
    for copia, de in cfg.get('copias', {}).items():
        img = Image.open(os.path.join(out_dir, de + '.png'))
        a = img.getchannel('A')
        img = ImageEnhance.Brightness(img.convert('RGB')).enhance(cfg.get('escurecer', 0.62)).convert('RGBA')
        if cfg.get('escurecer_quente'):                  # dourado escurecido sem puxar pro verde
            img = Image.merge('RGBA', [c.point(lambda v, k=k: min(255, int(v * k))) for c, k in
                                       zip(img.split()[:3], (1.08, 0.95, 0.75))] + [img.split()[3]])
        img.putalpha(a)
        img.save(os.path.join(out_dir, copia + '.png'))
        pecas[copia] = dict(pecas[de])
        dx, dy = cfg.get('copias_desloc', {}).get(copia, (0, 0))
        pecas[copia]['x'] += dx
        pecas[copia]['y'] += dy
    if 'ult' in cfg:                                        # visual da habilidade (ex.: sem camisa)
        u = cfg['ult']
        img = alinhar(piloto, carregar(arte(u['img'])))
        livre_u = img[..., 3] > 0
        for parte in u['ordem']:
            own = poly(W, H, u['partes'][parte]) & livre_u
            livre_u &= ~own
            pecas[parte + '_ult'] = recortar(img, own, parte + '_ult', out_dir)
    meta = {'nome': nome, 'src_w': W, 'src_h': H, 'ordem': cfg['ordem_desenho'], 'pecas': pecas}
    meta.update(cfg['fisica'])
    json.dump(meta, open(os.path.join(out_dir, 'parts.json'), 'w'), indent=1)
    for k, p in pecas.items():
        print(f'  {k:10s} {p}')


def zig(x0, x1, y, amp=22, passo=26):
    pts, x, k = [], x1, 0
    while x > x0:
        pts.append((x, y + (amp if k % 2 else 0)))
        x -= passo
        k += 1
    pts.append((x0, y))
    return pts


LIMA = {
    'img_piloto': 'lima_piloto.png',
    'img_veiculo': 'lima_gorila.png',
    'alinhar_veiculo': True,
    'alinhar_piloto': True,
    'ordem_piloto': ['cabeca', 'braco', 'canela', 'coxa', 'tronco'],
    'ordem_veiculo': ['gbraco', 'gperna', 'gperna2'],
    'partes': {
        'cabeca': [(540, 0), (840, 0), (840, 250), (740, 264), (690, 252), (620, 215), (540, 160)],
        'braco': [(600, 330), (700, 318), (790, 465), (880, 455), (880, 545), (812, 570), (760, 525), (690, 472), (600, 432)],
        'canela': [(600, 655), (775, 655), (758, 760), (690, 858), (812, 900), (812, 1010), (495, 1010), (495, 905), (560, 828), (600, 752)],
        'coxa': [(470, 515), (790, 505), (790, 650), (742, 702), (610, 702), (560, 722), (470, 640)],
        'tronco': [(420, 190), (722, 190), (800, 330), (815, 500), (790, 540), (470, 570), (420, 400)],
        'gbraco': [(830, 620), (960, 600), (1010, 760), (1070, 850), (1100, 880), (1150, 960), (1200, 1100), (1200, 1178),
                   (1005, 1178), (1020, 1080), (950, 1010), (900, 980), (860, 900), (830, 760)],
        'gperna': [(150, 920), (230, 840), (330, 800), (420, 830), (420, 962), (335, 1000), (322, 1060), (315, 1182),
                   (95, 1182), (92, 1100), (110, 1000)],
        'gperna2': [(392, 880), (735, 880), (735, 1182), (398, 1182), (392, 1060)],
    },
    'tapar': {'tronco': [(600, 330), (700, 318), (790, 462), (790, 520), (700, 530), (600, 520)]},
    'fundo_corpo': [[(840, 690), (1000, 690), (1030, 800), (1010, 880), (900, 900), (850, 820)]],
    'manter': {'gbraco': [(820, 590), (1015, 590), (1030, 700), (830, 700)],
               'gperna': [(140, 780), (430, 780), (430, 965), (140, 965)],
               'gperna2': [(385, 870), (740, 870)] + zig(385, 740, 1000)},
    'copias': {'gbraco2': 'gbraco'},
    'copias_desloc': {'gbraco2': (-105, 0)},
    'ordem_desenho': ['gperna2', 'gbraco2', 'veiculo', 'gperna', 'gbraco', 'tronco', 'coxa', 'canela', 'braco', 'cabeca'],
    'fisica': {
        'bracos_veiculo': {'gbraco': [905, 640], 'gbraco2': [800, 640], 'gperna': [340, 860], 'gperna2': [520, 930]},
        'fases_veiculo': {'gbraco': 0.0, 'gperna2': 0.0, 'gbraco2': 3.14159, 'gperna': 3.14159},
        'pernas_veiculo': ['gperna', 'gperna2'],
        'corpo_de': {'veiculo': 'chassi', 'gbraco': 'braco_veiculo', 'gbraco2': 'braco_veiculo',
                     'gperna': 'braco_veiculo', 'gperna2': 'braco_veiculo',
                     'cabeca': 'cabeca', 'tronco': 'tronco', 'braco': 'braco', 'coxa': 'coxa', 'canela': 'canela'},
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

CHEFE = {
    'img_piloto': 'chefe_piloto.png',
    'img_veiculo': 'chefe_veiculo.png',
    'alinhar_veiculo': True,
    'ordem_piloto': ['cabeca', 'braco', 'canela', 'coxa', 'tronco'],
    'partes': {
        'cabeca': [(360, 30), (720, 30), (720, 335), (600, 350), (520, 345), (430, 300), (360, 220)],
        'braco': [(415, 365), (520, 375), (625, 465), (700, 488), (780, 476), (860, 445), (925, 462), (925, 550),
                  (860, 570), (780, 565), (720, 565), (620, 550), (500, 505), (415, 475)],
        'canela': [(690, 535), (785, 545), (870, 630), (975, 622), (1000, 700), (975, 800), (750, 800), (750, 695), (680, 640)],
        'coxa': [(445, 600), (560, 555), (695, 530), (745, 575), (750, 800), (480, 800), (435, 665)],
        'tronco': [(340, 320), (630, 320), (705, 475), (650, 560), (560, 625), (450, 700), (340, 610)],
    },
    'tapar': {'tronco': [(430, 380), (520, 380), (625, 470), (700, 500), (690, 545), (560, 560), (430, 480)]},
    'frente_veiculo': {'porta': [(440, 668), (700, 688), (995, 712), (1010, 830), (440, 830)]},
    'ult': {
        'img': 'chefe_ult.png',
        'ordem': ['braco', 'tronco'],
        'partes': {
            'braco': [(400, 360), (520, 380), (640, 470), (760, 470), (880, 440), (990, 470), (990, 600), (880, 610),
                      (760, 600), (640, 580), (500, 530), (400, 490)],
            'tronco': [(330, 310), (640, 310), (720, 480), (660, 600), (560, 660), (450, 720), (330, 640)],
        },
    },
    'ordem_desenho': ['veiculo', 'roda0', 'roda1', 'tronco', 'coxa', 'canela', 'porta', 'braco', 'cabeca'],
    'fisica': {
        'corpo_de': {'veiculo': 'chassi', 'porta': 'chassi', 'roda0': 'roda0', 'roda1': 'roda1', 'cabeca': 'cabeca', 'tronco': 'tronco',
                     'braco': 'braco', 'coxa': 'coxa', 'canela': 'canela'},
        'piloto': ['tronco', 'cabeca', 'braco', 'coxa', 'canela'],
        'rodas': [{'corpo': 'roda0', 'peca': 'roda0', 'c': [283.0, 853.0], 'r': 132, 'massa': 2.5, 'motriz': True},
                  {'corpo': 'roda1', 'peca': 'roda1', 'c': [1148.0, 868.0], 'r': 130, 'massa': 2.0, 'motriz': False}],
        'chassi': {'massa': 9.0, 'auto_equilibrio': False, 'vmax': 1300.0, 'forca': 0.0,
                   'poly': [[50, 660], [300, 580], [460, 650], [930, 660], [1100, 650], [1300, 700], [1490, 820],
                            [1490, 850], [1270, 880], [990, 875], [450, 870], [130, 870], [45, 760]]},
        'corpos': {
            'cabeca': {'massa': 0.8, 'forma': ['circ', [540, 190], 140]},
            'tronco': {'massa': 2.0, 'forma': ['caps', [480, 400], [500, 610], 110]},
            'braco': {'massa': 0.5, 'forma': ['caps', [450, 400], [890, 500], 45]},
            'coxa': {'massa': 1.1, 'forma': ['caps', [490, 650], [720, 580], 70]},
            'canela': {'massa': 1.0, 'forma': ['caps', [745, 585], [905, 690], 60]},
        },
        'juntas': [
            {'a': 'tronco', 'b': 'cabeca', 'p': [570, 330], 'lim': 40},
            {'a': 'tronco', 'b': 'braco', 'p': [460, 400], 'lim': 80},
            {'a': 'tronco', 'b': 'coxa', 'p': [480, 650], 'lim': 70},
            {'a': 'coxa', 'b': 'canela', 'p': [730, 570], 'lim': 75},
        ],
    },
}

# Vitinho no Creta: mesmo corpo (artes encaixadas no lugar do da Ferrari por tools/chefe_creta.py),
# carro com outras rodas, porta e formato
CHEFE_CRETA = json.loads(json.dumps(CHEFE))
CHEFE_CRETA['alinhar_veiculo'] = False                 # já vem encaixado
CHEFE_CRETA['frente_veiculo'] = {'porta': [(380, 640), (640, 660), (1000, 700), (1010, 830), (380, 830)]}
CHEFE_CRETA['fisica']['rodas'] = [
    {'corpo': 'roda0', 'peca': 'roda0', 'c': [335.0, 830.0], 'r': 107, 'massa': 2.5, 'motriz': True},
    {'corpo': 'roda1', 'peca': 'roda1', 'c': [1157.0, 845.0], 'r': 108, 'massa': 2.0, 'motriz': False}]
CHEFE_CRETA['fisica']['chassi']['poly'] = [[130, 700], [210, 600], [380, 600], [480, 640], [930, 680], [1150, 640],
    [1350, 660], [1480, 720], [1480, 850], [1270, 880], [990, 880], [450, 880], [140, 860], [125, 760]]

if __name__ == '__main__':
    for arg in sys.argv[1:]:
        n, _, skin = arg.partition(':')
        print('==', arg)
        cfg = dict({'lima': LIMA, 'chefe': CHEFE}[n])
        if (n, skin) == ('lima', 'dourado'):
            cfg['pelo_todo'] = True
            cfg['escurecer'] = 0.72
            cfg['escurecer_quente'] = True
            cfg['partes'] = dict(cfg['partes'])
            cfg['partes']['gperna2'] = [(470, 880), (705, 880), (735, 1000), (735, 1182), (470, 1182), (452, 1000)]   # sem pedaço da barriga
        if (n, skin) == ('chefe', 'creta'):
            cfg = CHEFE_CRETA
        rodar(n, cfg, skin)
