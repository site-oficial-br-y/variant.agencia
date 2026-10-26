"""Recorta uma skin usando as peças do personagem original como molde (pra personagem que
não tem regra de recorte própria, ex.: Périne). A arte da skin precisa estar na mesma pose.

Uso: python3 tools/skin_molde.py <personagem> <skin> <arte_sem_fundo.png>
     -> assets/<personagem>_<skin>/ com as mesmas peças, mesmo parts.json (física e juntas)

- a arte é encaixada (escala + posição) sobre a montagem das peças originais;
- cada pixel da arte vai pra peça original mais perto (a peça de cima ganha onde elas se cobrem);
- onde a peça original tinha pedaço escondido atrás de outra (ex.: tronco atrás do braço), ele é
  preenchido com a cor da própria peça nova, pra não abrir buraco quando o boneco se desmonta;
- a roda é cortada por disco (gira inteira).
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(AQUI, '..', 'assets')


def montar_base(pers):
    pj = json.load(open(os.path.join(ASSETS, pers, 'parts.json')))
    W, H = pj['src_w'], pj['src_h']
    mont = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    masc = {}
    for n in pj['ordem']:
        p = pj['pecas'][n]
        im = Image.open(os.path.join(ASSETS, pers, n + '.png')).convert('RGBA')
        mont.alpha_composite(im, (p['x'], p['y']))
        m = np.zeros((H, W), bool)
        a = np.asarray(im)[..., 3] > 40
        m[p['y']:p['y'] + p['h'], p['x']:p['x'] + p['w']] = a[:H - p['y'], :W - p['x']]
        masc[n] = m
    return pj, mont, masc


def encaixar(base, arte):
    """escala e posição da arte que melhor cobrem a silhueta da base"""
    mb = np.asarray(base)[..., 3] > 100
    bb = arte.getbbox()
    arte = arte.crop(bb)
    ys, xs = np.where(mb)
    s0 = (ys.max() - ys.min() + 1) / arte.height
    f = 0.25
    pb = np.asarray(Image.fromarray(mb.astype(np.uint8) * 255).resize((int(mb.shape[1] * f), int(mb.shape[0] * f)))) > 128
    melhor = None
    for s in np.arange(s0 * 0.94, s0 * 1.06, s0 * 0.005):
        w, h = max(1, int(arte.width * s * f)), max(1, int(arte.height * s * f))
        pa = np.asarray(arte.getchannel('A').resize((w, h))) > 128
        for dy in range(-6, 7):
            for dx in range(-25, 26):
                y0 = int(ys.min() * f) + dy
                x0 = int(xs.min() * f) + dx
                can = np.zeros_like(pb)
                ya, xa = max(0, y0), max(0, x0)
                yb, xb = min(pb.shape[0], y0 + h), min(pb.shape[1], x0 + w)
                if yb <= ya or xb <= xa:
                    continue
                can[ya:yb, xa:xb] = pa[ya - y0:yb - y0, xa - x0:xb - x0]
                iou = (can & pb).sum() / max(1, (can | pb).sum())
                if melhor is None or iou > melhor[0]:
                    melhor = (iou, s, x0 / f, y0 / f)
    iou, s, x0, y0 = melhor
    print(f'  encaixe: iou {iou:.3f} escala {s:.3f} pos ({x0:.0f}, {y0:.0f})')
    out = Image.new('RGBA', base.size, (0, 0, 0, 0))
    g = arte.resize((round(arte.width * s), round(arte.height * s)), Image.LANCZOS)
    out.paste(g, (int(round(x0)), int(round(y0))), g)
    return out


def rodar(pers, skin, arq):
    pj, base, masc = montar_base(pers)
    W, H = pj['src_w'], pj['src_h']
    arte = encaixar(base, Image.open(arq).convert('RGBA'))
    a = np.asarray(arte).astype(np.int16)
    op = a[..., 3] > 0
    ordem = pj['ordem']
    yy, xx = np.mgrid[0:H, 0:W]
    # dono de cada pixel da arte: peça de cima que cobre; fora de todas, a mais perto
    L = np.zeros((H, W), np.int16)
    for i, n in enumerate(ordem):
        L[masc[n]] = i + 1
    rodas = {r['corpo']: r for r in pj['rodas']}
    for i, n in enumerate(ordem):
        r = rodas.get(pj['corpo_de'].get(n))
        if r:                                          # roda: disco inteiro (gira)
            disco = (xx - r['c'][0]) ** 2 + (yy - r['c'][1]) ** 2 <= (r['r'] + 4) ** 2
            L[disco & op] = i + 1
    _, (iy, ix) = ndimage.distance_transform_edt(L == 0, return_indices=True)
    dono = np.where(op, L[iy, ix], 0)
    out_dir = os.path.join(ASSETS, f'{pers}_{skin}')
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith(('.png', '.json', '.import')):
            os.remove(os.path.join(out_dir, f))
    pecas = {}
    for i, n in enumerate(ordem):
        own = dono == i + 1
        cor = a[..., :3].astype(float).copy()
        alfa = np.where(own, a[..., 3], 0)
        escondido = masc[n] & ~own & op & (dono > i + 1)   # atrás de peça da frente: completa com a cor da peça
        if escondido.any() and own.any():
            _, (jy, jx) = ndimage.distance_transform_edt(~own, return_indices=True)
            viz = a[..., :3][jy, jx].astype(float)
            viz = np.stack([ndimage.gaussian_filter(viz[..., c], 4) for c in range(3)], 2)
            cor[escondido] = viz[escondido]
            alfa = np.where(escondido, 255, alfa)
        img = Image.fromarray(np.dstack([cor.clip(0, 255), alfa]).astype(np.uint8), 'RGBA')
        bb = img.getbbox() or (0, 0, 1, 1)
        img = img.crop(bb)
        img.save(os.path.join(out_dir, n + '.png'))
        pecas[n] = {'x': bb[0], 'y': bb[1], 'w': img.width, 'h': img.height}
        print(f'  {n:10s} {pecas[n]}')
    meta = dict(pj)
    meta['nome'] = f'{pers}_{skin}'
    meta['pecas'] = pecas
    json.dump(meta, open(os.path.join(out_dir, 'parts.json'), 'w'), indent=1)
    arte.save(os.path.join(AQUI, 'fonte', f'{pers}_{skin}_full.png'))   # arte encaixada (rostos.py usa)


if __name__ == '__main__':
    rodar(sys.argv[1], sys.argv[2], sys.argv[3])
