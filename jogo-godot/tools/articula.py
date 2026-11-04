"""Dá cotovelo e joelho aos bonecos: corta a peça do braço (e a da perna inteira, de quem não tem
coxa/canela) em duas na metade da cápsula, com uma faixa de sobra embaixo da emenda pra não abrir
buraco quando dobra. Cria o corpo novo (antebraco / pe / pe2), a junta e atualiza o parts.json.

Uso: python3.13 tools/articula.py            (todas as pastas com parts.json; pula quem já tem)
"""
import glob, json, os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(AQUI, '..', 'assets')
CORTES = {'braco': ('antebraco', 0.5, 70), 'perna': ('pe', 0.5, 75), 'perna2': ('pe2', 0.5, 75)}
SEM_COTOVELO = {'sartori'}      # braço troca de desenho na raquetada: fica inteiro
SOBRA = 16                      # px da peça de baixo que entram embaixo da de cima


def cortar(pasta, d, corpo, novo, t, lim):
    pecas = [k for k, v in d['corpo_de'].items() if v == corpo]
    if len(pecas) != 1 or corpo not in d['corpos'] or d['corpos'][corpo]['forma'][0] != 'caps':
        return False
    k = pecas[0]
    junta = next((j for j in d['juntas'] if j['b'] == corpo), None)
    if junta is None:
        return False
    _, a, b, r = d['corpos'][corpo]['forma']
    a, b = np.array(a, float), np.array(b, float)
    if np.linalg.norm(a - np.array(junta['p'])) > np.linalg.norm(b - np.array(junta['p'])):
        a, b = b, a                                   # a = ponta presa no pai
    j = a + (b - a) * t
    eixo = (b - a) / np.linalg.norm(b - a)
    pc = d['pecas'][k]
    img = np.asarray(Image.open(os.path.join(pasta, k + '.png')).convert('RGBA')).copy()
    h, w = img.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    proj = (xs + pc['x'] - j[0]) * eixo[0] + (ys + pc['y'] - j[1]) * eixo[1]
    cima = img.copy()
    cima[proj >= 0, 3] = 0
    baixo = img.copy()
    baixo[proj < -SOBRA, 3] = 0
    for arr, nome in ((cima, k), (baixo, novo)):
        im = Image.fromarray(arr)
        bb = im.getbbox()
        if bb is None:
            return False
        im.crop(bb).save(os.path.join(pasta, nome + '.png'))
        d['pecas'][nome] = {'x': pc['x'] + bb[0], 'y': pc['y'] + bb[1], 'w': bb[2] - bb[0], 'h': bb[3] - bb[1]}
    m = float(d['corpos'][corpo].get('massa', 1.0))
    d['corpos'][corpo] = {'massa': round(m * 0.55, 3), 'forma': ['caps', [round(a[0]), round(a[1])], [round(j[0]), round(j[1])], r]}
    d['corpos'][novo] = {'massa': round(m * 0.45, 3), 'forma': ['caps', [round(j[0]), round(j[1])], [round(b[0]), round(b[1])], round(r * 0.9)]}
    d['corpo_de'][novo] = novo
    d['ordem'].insert(d['ordem'].index(k), novo)        # canela/antebraço por baixo da emenda
    if novo not in d['piloto']:
        d['piloto'].append(novo)
    i = d['juntas'].index(junta)
    d['juntas'].insert(i + 1, {'a': corpo, 'b': novo, 'p': [round(j[0]), round(j[1])], 'lim': lim})
    return True


for arq in sorted(glob.glob(os.path.join(ASSETS, '*', 'parts.json'))):
    pasta = os.path.dirname(arq)
    nome = os.path.basename(pasta)
    d = json.load(open(arq))
    if 'corpos' not in d:
        continue
    feitos = []
    for corpo, (novo, t, lim) in CORTES.items():
        if novo in d['corpos'] or (corpo == 'braco' and nome.split('_')[0] in SEM_COTOVELO):
            continue
        if cortar(pasta, d, corpo, novo, t, lim):
            feitos.append(novo)
    if feitos:
        json.dump(d, open(arq, 'w'), indent=1, ensure_ascii=False)
        print(nome, feitos)
