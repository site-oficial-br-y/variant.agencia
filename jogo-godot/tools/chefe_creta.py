"""Prepara as artes da skin Creta do Vitinho pro separados.py: alinha o carro sozinho e o
Vitinho sem camisa sozinho na arte montada, monta o Vitinho DE camisa sozinho (camisa da
arte montada + pernas da arte sem camisa, que ficam escondidas pela porta) e aumenta tudo
pro carro ficar do tamanho da Ferrari (a física do Vitinho foi feita nessa escala).
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(AQUI, 'fonte')
ESCALA = 1.4


def abrir(n):
    return Image.open(os.path.join(F, f'chefe_creta_{n}_orig.png')).convert('RGBA')


def alinhar_regiao(fixa, movel, regiao, so_params=False, escalas=(0.85, 1.25)):
    """escala/deslocamento de `movel` que melhor cobre a máscara de `fixa` dentro de `regiao`"""
    mf = (np.asarray(fixa)[..., 3] > 100) & regiao
    mm = np.asarray(movel)[..., 3] > 100
    f = 0.25
    pf = ndimage.zoom(mf.astype(float), f, order=0) > 0.5
    pr = ndimage.zoom(regiao.astype(float), f, order=0) > 0.5
    melhor = None
    for s in np.arange(escalas[0], escalas[1], 0.01):
        pm = ndimage.zoom(mm.astype(float), f * s, order=0) > 0.5
        for dy in range(-90, 41):
            for dx in range(-60, 61):
                can = np.zeros_like(pf)
                y0, x0 = max(0, dy), max(0, dx)
                y1, x1 = min(pf.shape[0], dy + pm.shape[0]), min(pf.shape[1], dx + pm.shape[1])
                if y1 <= y0 or x1 <= x0:
                    continue
                can[y0:y1, x0:x1] = pm[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
                can &= pr
                uni = (can | pf).sum()
                iou = (can & pf).sum() / uni if uni else 0
                if melhor is None or iou > melhor[0]:
                    melhor = (iou, s, dx / f, dy / f)
    iou, s, dx, dy = melhor
    print(f'  alinhado: iou {iou:.3f} escala {s:.2f} dx {dx:.0f} dy {dy:.0f}')
    if so_params:
        return s, dx, dy
    out = Image.new('RGBA', fixa.size, (0, 0, 0, 0))
    mv = movel.resize((round(movel.width * s), round(movel.height * s)), Image.LANCZOS)
    out.alpha_composite(mv, (int(round(dx)), int(round(dy)))) if dx >= 0 and dy >= 0 else out.paste(mv, (int(round(dx)), int(round(dy))), mv)
    return out


full = abrir('full')
W, H = full.size
yy, xx = np.mgrid[0:H, 0:W]
veic = alinhar_regiao(full, abrir('veiculo'), (yy > 600) & ((xx < 470) | (xx > 980)))   # partes do carro que o piloto não tapa
ult = alinhar_regiao(full, abrir('ult'), yy < 560)                                    # cabeça e ombros (acima da porta)
# Vitinho de camisa: o que na montada não é carro; o resto (pernas atrás da porta) vem da arte sem camisa
a_full = np.asarray(full).astype(int); a_veic = np.asarray(veic).astype(int); a_ult = np.asarray(ult).astype(int)
dif = np.abs(a_full[..., :3] - a_veic[..., :3]).max(2)
piloto_m = (a_full[..., 3] > 100) & ((a_veic[..., 3] < 60) | (dif > 60))
camisa = piloto_m & (((yy < 480) & (xx < 730)) | ((yy < 625) & (xx < 640)))   # cabeça e camisa da montada; resto da sem camisa
pil = np.zeros_like(a_full)
pil[a_ult[..., 3] > 0] = a_ult[a_ult[..., 3] > 0]
pil[camisa] = a_full[camisa]
r_, g_, b_ = pil[..., 0], pil[..., 1], pil[..., 2]
pele = (r_ > 120) & (r_ - b_ > 40) & (g_ > 70)
barriga = pele & (yy >= 600) & (yy < 720) & (xx < 640) & (pil[..., 3] > 0)   # camisa continua até a bermuda
escuro = pil[camisa & (pil[..., :3].max(2) < 60)][:, :3].mean(0)
pil[barriga, :3] = (escuro * (0.85 + 0.3 * (pil[barriga, :3].mean(1, keepdims=True) / 255.0))).astype(int)
op = pil[..., 3] > 30
lab, n = ndimage.label(op)
if n > 1:                                                  # tira pedaços soltos (banco/volante)
    tam = ndimage.sum(op, lab, range(1, n + 1))
    pil[(lab != int(np.argmax(tam)) + 1)] = 0
piloto = Image.fromarray(pil.clip(0, 255).astype(np.uint8), 'RGBA')
# encaixa no lugar do Vitinho da Ferrari (pelo piloto): reaproveita juntas e partes do corpo
ferrari = Image.open(os.path.join(F, 'chefe_full.png')).convert('RGBA')
FW, FH = ferrari.size
fy, fx = np.mgrid[0:FH, 0:FW]
grande = full.resize((round(W * ESCALA), round(H * ESCALA)), Image.LANCZOS)
gp = piloto.resize(grande.size, Image.LANCZOS)
s_, dx, dy = alinhar_regiao(ferrari, gp, fy < 560, so_params=True, escalas=(0.6, 1.1))
for nome, im in [('full', full), ('veiculo', veic), ('ult', ult), ('piloto', piloto)]:
    g = im.resize((round(W * ESCALA * s_), round(H * ESCALA * s_)), Image.LANCZOS)
    out = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    out.paste(g, (int(round(dx)), int(round(dy))), g)
    out.save(os.path.join(F, f'chefe_creta_{nome}.png'))
print('ok', FW, FH)
