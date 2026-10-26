"""Gera o rosto (150x150, colorido e cinza) e a foto do menu de uma skin, recortando no
mesmo lugar do rosto do personagem base (a arte da skin tem a mesma pose).

Uso: python3 tools/rostos.py gamer:militar monociclo:folhas ...
     (gamer:militar:base = grava por cima do visual base do gamer)
"""
import os, sys
import numpy as np
from PIL import Image, ImageOps

AQUI = os.path.dirname(os.path.abspath(__file__))
FONTE = os.path.join(AQUI, 'fonte')
ASSETS = os.path.join(AQUI, '..', 'assets')


def caixa_rosto(pers):
    """onde o rosto_<pers>.png foi recortado da arte base: busca escala e posição"""
    full = Image.open(os.path.join(FONTE, f'{pers}_full.png')).convert('RGBA')
    fundo = Image.new('RGBA', full.size, (0, 0, 0, 255)); fundo.alpha_composite(full)
    g = np.asarray(fundo.convert('L')).astype(np.float32)
    r = np.asarray(Image.open(os.path.join(ASSETS, 'ui', f'rosto_{pers}.png')).convert('RGBA'))
    rg = np.asarray(Image.fromarray(r).convert('L')).astype(np.float32)
    ra = r[..., 3] > 200
    melhor = None
    f = 0.25
    gp = np.asarray(Image.fromarray(g).resize((int(g.shape[1] * f), int(g.shape[0] * f)))).astype(np.float32)
    for lado in range(150, 520, 6):
        t = max(4, int(round(lado * f)))
        rp = np.asarray(Image.fromarray(rg).resize((t, t))).astype(np.float32)
        mp = np.asarray(Image.fromarray(ra.astype(np.uint8) * 255).resize((t, t))) > 128
        for y in range(0, gp.shape[0] - t, 2):
            for x in range(0, gp.shape[1] - t, 2):
                d = np.abs(gp[y:y + t, x:x + t] - rp)[mp].mean()
                if melhor is None or d < melhor[0]:
                    melhor = (d, x / f, y / f, lado)
    d, x, y, lado = melhor
    # refina em resolução cheia perto do achado
    melhor = None
    for l2 in range(lado - 8, lado + 9, 2):
        rp = np.asarray(Image.fromarray(rg).resize((l2, l2))).astype(np.float32)
        mp = np.asarray(Image.fromarray(ra.astype(np.uint8) * 255).resize((l2, l2))) > 128
        for yy in range(int(y) - 8, int(y) + 9, 2):
            for xx in range(int(x) - 8, int(x) + 9, 2):
                if yy < 0 or xx < 0 or yy + l2 > g.shape[0] or xx + l2 > g.shape[1]:
                    continue
                dd = np.abs(g[yy:yy + l2, xx:xx + l2] - rp)[mp].mean()
                if melhor is None or dd < melhor[0]:
                    melhor = (dd, xx, yy, l2)
    print(f'  rosto de {pers}: erro {melhor[0]:.1f} caixa {melhor[1:]}')
    return melhor[1:]


def gerar(pers, skin, por_cima=False):
    pasta = pers if por_cima else f'{pers}_{skin}'
    arte = Image.open(os.path.join(FONTE, f'{pers}_{skin}_full.png')).convert('RGBA')
    x, y, lado = caixa_rosto(pers)
    rosto = arte.crop((x, y, x + lado, y + lado)).resize((150, 150), Image.LANCZOS)
    rosto.save(os.path.join(ASSETS, 'ui', f'rosto_{pasta}.png'))
    cinza = ImageOps.grayscale(rosto.convert('RGB')).convert('RGBA'); cinza.putalpha(rosto.getchannel('A'))
    cinza.save(os.path.join(ASSETS, 'ui', f'rosto_{pasta}_cinza.png'))
    menu = arte.crop(arte.getbbox())
    alvo = Image.open(os.path.join(ASSETS, 'menu', f'{pers}.png')) if not por_cima else None
    esc = 440 / menu.height if menu.width / menu.height < 560 / 440 else 560 / menu.width
    menu.resize((round(menu.width * esc), round(menu.height * esc)), Image.LANCZOS).save(os.path.join(ASSETS, 'menu', f'{pasta}.png'))
    print('  ok', pasta)


if __name__ == '__main__':
    for arg in sys.argv[1:]:
        p = arg.split(':')
        gerar(p[0], p[1], len(p) > 2 and p[2] == 'base')
