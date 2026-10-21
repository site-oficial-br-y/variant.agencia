"""Gera a arte original do jogo (texturas emendáveis e sprites com contorno).

Uso: python3 tools/gerar_arte.py   (escreve em assets/arte/)
Estilo: cartunesco, contorno escuro, 1 luz e 1 sombra, materiais distinguíveis.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(AQUI, '..', 'assets', 'arte')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)


def salvar(img, nome):
    img.save(os.path.join(OUT, nome))
    print('  ', nome, img.size)


def ruido_emendavel(w, h, escala, seed):
    """Ruído suave que emenda nas bordas (gera periódico via FFT de ruído)."""
    r = np.random.default_rng(seed).standard_normal((h, w))
    f = np.fft.fft2(r)
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    filtro = np.exp(-(fx ** 2 + fy ** 2) * (escala ** 2) * 40)
    n = np.real(np.fft.ifft2(f * filtro))
    return (n - n.min()) / (n.max() - n.min())


def textura_terra():
    w = h = 256
    n = 0.6 * ruido_emendavel(w, h, 6, 1) + 0.4 * ruido_emendavel(w, h, 1.5, 2)
    base = np.array([108, 62, 30]); escuro = np.array([74, 40, 18])
    img = base * (0.75 + 0.35 * n[..., None]) * 0.9 + escuro * 0.1
    img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(5)
    for _ in range(26):                                   # pedrinhas
        x, y, s = r.integers(0, w), r.integers(0, h), r.integers(4, 10)
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                d.ellipse([x + dx - s, y + dy - s * 0.7, x + dx + s, y + dy + s * 0.7], fill=(132, 92, 60))
                d.ellipse([x + dx - s * 0.5, y + dy - s * 0.5, x + dx + s * 0.2, y + dy], fill=(160, 118, 82))
    salvar(img, 'terra.png')


def faixa_grama():
    """Faixa horizontal emendável: lâminas de grama em cima, borda escura embaixo."""
    w, h = 256, 96
    img = Image.new('RGBA', (w * 3, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 26, w * 3, 74], fill=(78, 150, 40, 255))
    d.rectangle([0, 26, w * 3, 34], fill=(132, 200, 70, 255))      # luz no topo
    d.rectangle([0, 64, w * 3, 74], fill=(52, 108, 28, 255))       # sombra embaixo
    d.rectangle([0, 74, w * 3, 82], fill=(43, 26, 14, 255))        # contorno com a terra
    r = np.random.default_rng(7)
    for x in range(0, w * 3, 7):                                    # lâminas
        alt = r.integers(10, 26)
        cor = (98 + r.integers(0, 40), 172 + r.integers(0, 30), 52, 255)
        d.polygon([(x, 30), (x + 7, 30), (x + 3 + r.integers(-3, 4), 30 - alt)], fill=cor)
    img = img.crop((w, 0, 2 * w, h))
    salvar(img, 'grama.png')


def textura_madeira():
    w, h = 256, 64
    img = Image.new('RGB', (w, h), (150, 96, 50))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(9)
    for y in range(0, h, 3):                                        # veios
        c = 140 + r.integers(-18, 18)
        d.line([(0, y), (w, y)], fill=(c, int(c * 0.64), int(c * 0.33)), width=2)
    d.rectangle([0, 0, w, 5], fill=(186, 126, 70))                  # luz
    d.rectangle([0, h - 6, w, h], fill=(96, 58, 28))                # sombra
    for x in (0, 128):                                              # emenda das tábuas + pregos
        d.line([(x, 0), (x, h)], fill=(70, 40, 18), width=4)
        for yy in (14, h - 16):
            d.ellipse([x + 8, yy - 3, x + 14, yy + 3], fill=(60, 60, 66))
    salvar(img, 'madeira.png')


def textura_metal():
    w, h = 256, 64
    img = Image.new('RGB', (w, h), (122, 134, 150))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 10], fill=(170, 182, 198))
    d.rectangle([0, h - 12, w, h], fill=(80, 90, 104))
    d.rectangle([0, 26, w, 38], fill=(98, 108, 122))
    for x in range(16, w, 64):                                      # rebites
        for yy in (17, h - 20):
            d.ellipse([x - 5, yy - 5, x + 5, yy + 5], fill=(70, 78, 90))
            d.ellipse([x - 3, yy - 4, x + 2, yy + 1], fill=(190, 200, 214))
    salvar(img, 'metal.png')


def faixa_perigo():
    w, h = 128, 40
    img = Image.new('RGB', (w, h), (240, 190, 30))
    d = ImageDraw.Draw(img)
    for x in range(-h, w + h, 32):
        d.polygon([(x, h), (x + 16, h), (x + 16 + h, 0), (x + h, 0)], fill=(30, 30, 34))
    salvar(img, 'perigo.png')


def elo():
    """Elo de corrente (tile vertical): oval + barra lateral."""
    w, h = 48, 64
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([8, 2, 40, 62], radius=16, outline=(28, 28, 32, 255), width=9)
    d.rounded_rectangle([10, 4, 38, 60], radius=14, outline=(120, 124, 134, 255), width=5)
    d.rectangle([20, 22, 28, 42], fill=(28, 28, 32, 255))
    salvar(img, 'elo.png')


def esfera(nome, r, cor, luz, contorno, extras=None):
    s = 2 * r + 24
    yy, xx = np.mgrid[0:s, 0:s].astype(float)
    cx = cy = s / 2
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    dentro = d <= r
    lx, ly = cx - r * 0.35, cy - r * 0.4
    dl = np.sqrt((xx - lx) ** 2 + (yy - ly) ** 2) / (r * 1.4)
    tom = np.clip(1.15 - dl, 0.35, 1.15)
    rgb = np.array(cor)[None, None, :] * tom[..., None]
    rgb = np.where((np.sqrt((xx - lx) ** 2 + (yy - ly) ** 2) < r * 0.18)[..., None], np.array(luz), rgb)
    a = np.where(dentro, 255, 0)
    borda = (d > r - 10) & dentro
    rgb[borda] = contorno
    img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8), 'RGBA')
    if extras:
        extras(ImageDraw.Draw(img), s, r)
    salvar(img, nome)


def bola_demolicao():
    def gancho(d, s, r):
        c = s / 2
        d.rounded_rectangle([c - 36, 2, c + 36, 40], radius=10, fill=(40, 40, 46, 255))
        d.rounded_rectangle([c - 22, 8, c + 22, 34], radius=8, fill=(110, 114, 124, 255))
    esfera('bola_demolicao.png', 300, (78, 68, 88), (200, 196, 214), (24, 20, 30), gancho)


def serra():
    r = 300
    s = 2 * r + 20
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    pts = []
    for k in range(64):
        ang = 2 * np.pi * k / 64
        rr = r if k % 2 == 0 else r * 0.86
        pts.append((c + rr * np.cos(ang), c + rr * np.sin(ang)))
    d.polygon(pts, fill=(196, 202, 214, 255), outline=(30, 32, 38, 255))
    d.ellipse([c - r * 0.78, c - r * 0.78, c + r * 0.78, c + r * 0.78], fill=(170, 176, 190, 255))
    for k in range(6):                                              # furos de alívio
        ang = 2 * np.pi * k / 6
        x, y = c + r * 0.5 * np.cos(ang), c + r * 0.5 * np.sin(ang)
        d.ellipse([x - 26, y - 26, x + 26, y + 26], fill=(120, 126, 140, 255))
    d.ellipse([c - 60, c - 60, c + 60, c + 60], fill=(60, 64, 72, 255), outline=(20, 20, 24, 255), width=8)
    d.ellipse([c - 20, c - 20, c + 20, c + 20], fill=(200, 200, 210, 255))
    salvar(img, 'serra.png')


def caixa():
    s = 256
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, s - 1, s - 1], fill=(176, 120, 62, 255))
    for y in range(0, s, 5):
        d.line([(0, y), (s, y)], fill=(160, 106, 52, 255), width=1)
    d.rectangle([0, 0, s - 1, s - 1], outline=(58, 34, 14, 255), width=12)
    d.rectangle([12, 12, s - 13, 40], fill=(140, 90, 44, 255))
    d.rectangle([12, s - 41, s - 13, s - 13], fill=(140, 90, 44, 255))
    d.line([(26, 40), (s - 26, s - 40)], fill=(130, 82, 38, 255), width=26)
    d.line([(26, 40), (s - 26, s - 40)], fill=(58, 34, 14, 255), width=4)
    for x, y in [(20, 20), (s - 20, 20), (20, s - 20), (s - 20, s - 20)]:
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(70, 70, 78, 255))
    salvar(img, 'caixa.png')


def tnt():
    w, h = 220, 300
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 10, w - 6, h - 6], radius=26, fill=(196, 40, 34, 255), outline=(40, 10, 10, 255), width=10)
    d.rectangle([16, 14, 44, h - 12], fill=(226, 80, 66, 255))      # luz
    for y in (60, h - 70):
        d.rectangle([6, y, w - 6, y + 22], fill=(60, 60, 66, 255))
    d.rectangle([40, 112, w - 40, 188], fill=(250, 230, 200, 255), outline=(40, 10, 10, 255), width=6)
    d.text((70, 128), "TNT", fill=(160, 20, 20, 255))
    d.polygon([(w / 2 - 30, 150), (w / 2 + 30, 150), (w / 2, 120)], fill=(160, 20, 20, 255))
    d.line([(w / 2, 10), (w / 2 + 20, -4)], fill=(40, 30, 20, 255), width=6)
    salvar(img, 'tnt.png')


def arvore(nome, seed, alt=900):
    r = np.random.default_rng(seed)
    w, h = 760, alt
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = w / 2
    d.polygon([(cx - 34, h), (cx + 34, h), (cx + 22, h * 0.45), (cx - 22, h * 0.45)], fill=(98, 62, 34, 255), outline=(43, 26, 14, 255))
    d.line([(cx - 10, h), (cx - 6, h * 0.5)], fill=(126, 84, 48, 255), width=10)
    copa = Image.new('L', (w, h), 0)
    dc = ImageDraw.Draw(copa)
    for _ in range(9):
        x = cx + r.uniform(-200, 200); y = h * r.uniform(0.18, 0.42); rr = r.uniform(130, 210)
        dc.ellipse([x - rr, y - rr * 0.85, x + rr, y + rr * 0.85], fill=255)
    m = np.asarray(copa) > 0
    yy = np.arange(h)[:, None] * np.ones((1, w))
    tom = np.clip(1.15 - (yy / (h * 0.5)), 0.65, 1.15)
    base = np.array([70, 150, 44])
    rgb = base[None, None, :] * tom[..., None]
    borda = m & ~ndimage.binary_erosion(m, iterations=9)
    arr = np.asarray(img).copy()
    arr[m, :3] = rgb[m]
    arr[m, 3] = 255
    arr[borda, :3] = (28, 70, 22)
    img = Image.fromarray(arr, 'RGBA')
    salvar(img, nome)


def pedra(nome, seed):
    r = np.random.default_rng(seed)
    w, h = 420, 260
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(20, h - 6), (40, 110 + r.integers(-20, 20)), (130, 30 + r.integers(-20, 20)), (260, 20 + r.integers(-10, 30)),
           (370, 90 + r.integers(-20, 20)), (w - 14, h - 6)]
    d.polygon(pts, fill=(140, 140, 150, 255), outline=(40, 40, 48, 255))
    d.polygon([(130, 40), (200, 36), (120, 150), (70, 140)], fill=(176, 176, 188, 255))
    d.line(pts + [pts[0]], fill=(40, 40, 48, 255), width=10)
    salvar(img, nome)


def placa(nome, texto, cor):
    w, h = 900, 1100
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in (140, w - 180):
        d.rectangle([x, 300, x + 40, h], fill=(110, 72, 40, 255), outline=(43, 26, 14, 255), width=8)
    d.rounded_rectangle([20, 20, w - 20, 360], radius=26, fill=cor, outline=(20, 20, 20, 255), width=14)
    d.rounded_rectangle([46, 46, w - 46, 334], radius=18, outline=(255, 255, 255, 255), width=8)
    if nome == 'placa_chegada.png':
        for i in range(0, w - 80, 70):
            for j in range(2):
                if (i // 70 + j) % 2 == 0:
                    d.rectangle([40 + i, 50 + j * 50, 40 + i + 70, 100 + j * 50], fill=(20, 20, 20, 255))
    salvar(img, nome)


def cerca():
    w, h = 400, 260
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in (70, 160):
        d.rectangle([0, y, w, y + 30], fill=(170, 118, 66, 255), outline=(58, 34, 14, 255), width=5)
    for x in (30, w - 70):
        d.polygon([(x, h), (x + 40, h), (x + 40, 20), (x + 20, 0), (x, 20)], fill=(190, 136, 80, 255), outline=(58, 34, 14, 255))
    salvar(img, 'cerca.png')


def fundo_campo():
    """3 camadas emendáveis: montanhas longe, morros com árvores, morros perto."""
    def faixa(w, h, cor_base, cor_luz, amp, seed, arvores=0, contorno=(0, 0, 0, 0), freq=(1, 2, 3)):
        r = np.random.default_rng(seed)
        xs = np.arange(w)
        y = h * 0.42 + sum(amp * h * r.uniform(0.3, 1) * np.sin(2 * np.pi * k * xs / w + r.uniform(0, 6)) for k in freq)
        big = Image.new('RGBA', (w * 3, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        for t in range(3):
            d.polygon([(t * w, h)] + [(t * w + x, yv) for x, yv in zip(xs, y)] + [(t * w + w, h)], fill=cor_base)
            d.line([(t * w + x, yv + 3) for x, yv in zip(xs, y)], fill=cor_luz, width=10)
            if contorno[3]:
                d.line([(t * w + x, yv) for x, yv in zip(xs, y)], fill=contorno, width=4)
            for k in range(arvores):
                x = int((k + r.uniform(0.2, 0.8)) * w / arvores)
                if x >= w:
                    continue
                yt = y[x]
                rr = r.uniform(26, 44)
                cor = tuple(int(c * 0.78) for c in cor_base[:3]) + (255,)
                d.rectangle([t * w + x - 4, yt - rr * 0.4, t * w + x + 4, yt + 8], fill=cor)
                d.ellipse([t * w + x - rr, yt - rr * 2.1, t * w + x + rr, yt - rr * 0.3], fill=cor)
        img = big.crop((w, 0, 2 * w, h)).filter(ImageFilter.GaussianBlur(1.0))
        return img
    salvar(faixa(2048, 512, (150, 184, 206, 255), (190, 214, 230, 255), 0.18, 11, freq=(2, 3, 5)), 'fundo_campo_longe.png')
    salvar(faixa(2048, 512, (110, 168, 82, 255), (150, 200, 110, 255), 0.12, 12, arvores=22), 'fundo_campo_meio.png')
    salvar(faixa(2048, 512, (82, 148, 54, 255), (120, 186, 80, 255), 0.10, 13, arvores=9,
                 contorno=(40, 86, 28, 255)), 'fundo_campo_perto.png')


def textura_concreto():
    w = h = 256
    n = 0.5 * ruido_emendavel(w, h, 5, 21) + 0.5 * ruido_emendavel(w, h, 1.2, 22)
    img = np.array([150, 146, 140]) * (0.82 + 0.25 * n[..., None])
    img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(23)
    for _ in range(40):                                   # brita e furinhos
        x, y, s = r.integers(0, w), r.integers(0, h), r.integers(2, 6)
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                d.ellipse([x + dx - s, y + dy - s, x + dx + s, y + dy + s], fill=(112, 108, 104))
    d.line([(0, h // 2), (w, h // 2)], fill=(120, 116, 110), width=3)       # junta de forma
    d.line([(w // 2, 0), (w // 2, h // 2)], fill=(120, 116, 110), width=3)
    d.line([(0, h // 2), (0, h)], fill=(120, 116, 110), width=3)
    salvar(img, 'concreto.png')


def textura_rocha():
    w = h = 256
    n = 0.55 * ruido_emendavel(w, h, 4, 31) + 0.45 * ruido_emendavel(w, h, 1.0, 32)
    base = np.array([96, 92, 98])
    img = base * (0.7 + 0.45 * n[..., None])
    img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(33)
    for _ in range(14):                                   # fissuras
        x, y = r.integers(0, w), r.integers(0, h)
        pts = [(x, y)]
        for k in range(4):
            x += r.integers(-24, 25); y += r.integers(8, 22); pts.append((x, y))
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                d.line([(a + dx, b + dy) for a, b in pts], fill=(58, 54, 62), width=3)
    salvar(img, 'rocha.png')


def faixa_asfalto():
    """Laje de concreto da obra: topo claro, faixa de perigo na borda, contorno."""
    w, h = 256, 96
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 22, w, 66], fill=(168, 164, 156, 255))
    d.rectangle([0, 22, w, 30], fill=(206, 202, 194, 255))
    d.rectangle([0, 66, w, 80], fill=(36, 34, 32, 255))
    for x in range(-40, w + 40, 40):                       # listra amarela/preta embaixo
        d.polygon([(x, 66), (x + 20, 66), (x + 34, 80), (x + 14, 80)], fill=(240, 180, 30, 255))
    d.rectangle([0, 18, w, 22], fill=(30, 28, 26, 255))
    d.rectangle([0, 80, w, 86], fill=(30, 28, 26, 255))
    salvar(img, 'asfalto.png')


def faixa_grama_alpina():
    w, h = 256, 96
    img = Image.new('RGBA', (w * 3, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 26, w * 3, 74], fill=(70, 120, 54, 255))
    d.rectangle([0, 26, w * 3, 34], fill=(118, 166, 88, 255))
    d.rectangle([0, 64, w * 3, 74], fill=(48, 84, 40, 255))
    d.rectangle([0, 74, w * 3, 82], fill=(34, 30, 36, 255))
    r = np.random.default_rng(17)
    for x in range(0, w * 3, 9):
        alt = r.integers(6, 16)
        d.polygon([(x, 30), (x + 9, 30), (x + 4, 30 - alt)], fill=(88, 140, 66, 255))
    for _ in range(18):                                    # florzinhas
        x = r.integers(0, w * 3)
        d.ellipse([x - 3, 22, x + 3, 28], fill=(240, 236, 220, 255) if r.random() < 0.6 else (230, 196, 60, 255))
    img = img.crop((w, 0, 2 * w, h))
    salvar(img, 'grama_alpina.png')


def pinheiro(nome, seed, alt=1100):
    r = np.random.default_rng(seed)
    w, h = 600, alt
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = w / 2
    d.rectangle([cx - 26, h * 0.8, cx + 26, h], fill=(92, 58, 32, 255), outline=(40, 24, 12, 255), width=6)
    camadas = 4
    for k in range(camadas):
        topo = h * (0.04 + k * 0.17); base = topo + h * 0.34
        larg = w * (0.22 + k * 0.08) + r.uniform(-10, 10)
        tri = [(cx, topo), (cx + larg, base), (cx - larg, base)]
        d.polygon(tri, fill=(40, 98, 62, 255), outline=(18, 46, 30, 255))
        d.line(tri + [tri[0]], fill=(18, 46, 30, 255), width=8)
        d.polygon([(cx, topo + 20), (cx - larg * 0.75, base - 10), (cx - larg * 0.2, base - 10)], fill=(62, 130, 82, 255))
    salvar(img, nome)


def cone():
    w, h = 220, 300
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, h - 40, w - 6, h - 6], radius=8, fill=(230, 90, 20, 255), outline=(40, 20, 10, 255), width=7)
    d.polygon([(w / 2 - 22, 10), (w / 2 + 22, 10), (w - 40, h - 40), (40, h - 40)], fill=(245, 110, 30, 255), outline=(40, 20, 10, 255))
    d.line([(w / 2 - 22, 10), (40, h - 40)], fill=(40, 20, 10, 255), width=7)
    d.line([(w / 2 + 22, 10), (w - 40, h - 40)], fill=(40, 20, 10, 255), width=7)
    for y0, y1 in ((80, 115), (165, 200)):
        f = lambda y: (w / 2 - 22) + (y - 10) / (h - 50) * ((40) - (w / 2 - 22))
        d.polygon([(f(y0), y0), (w - f(y0), y0), (w - f(y1), y1), (f(y1), y1)], fill=(250, 250, 245, 255))
    salvar(img, 'cone.png')


def _faixa_generica(w, h, desenhar, seed):
    """Desenha 3 vezes lado a lado e recorta o miolo: emenda perfeita."""
    big = Image.new('RGBA', (w * 3, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    r = np.random.default_rng(seed)
    elementos = desenhar(r, w, h)
    for t in range(3):
        for el in elementos:
            el(d, t * w)
    return big.crop((w, 0, 2 * w, h))


def fundo_obra():
    """Cidade em obra: prédios longe, prédios em construção com andaime e guindaste, tapume perto."""
    def predios(cor, cor_janela, alt_min, alt_max, n, andaime=False, guindastes=0):
        def desenhar(r, w, h):
            els = []
            x = 0
            while x < w:
                lw = int(r.uniform(90, 200)); alt = int(r.uniform(alt_min, alt_max)) * h // 512
                x0 = x
                def predio(d, ox, x0=x0, lw=lw, alt=alt, temjan=r.random() < 0.8, sem=int(r.integers(0, 1000))):
                    d.rectangle([ox + x0, h - alt, ox + x0 + lw, h], fill=cor)
                    if temjan:
                        rr = np.random.default_rng(sem)
                        for jy in range(h - alt + 16, h - 10, 26):
                            for jx in range(x0 + 10, x0 + lw - 14, 22):
                                if rr.random() < 0.7:
                                    d.rectangle([ox + jx, jy, ox + jx + 10, jy + 14], fill=cor_janela)
                    if andaime:
                        for ay in range(h - alt, h, 34):
                            d.line([(ox + x0 - 6, ay), (ox + x0 + lw + 6, ay)], fill=(70, 66, 60, 255), width=3)
                        for ax in range(x0 - 6, x0 + lw + 8, 30):
                            d.line([(ox + ax, h - alt - 10), (ox + ax, h)], fill=(70, 66, 60, 255), width=3)
                els.append(predio)
                x += lw + int(r.uniform(4, 30))
            for g in range(guindastes):
                gx = int((g + 0.5) * w / guindastes)
                def guind(d, ox, gx=gx):
                    top = int(h * 0.08)
                    d.rectangle([ox + gx - 7, top, ox + gx + 7, h], fill=(70, 64, 56, 255))
                    d.rectangle([ox + gx - 260, top, ox + gx + 120, top + 12], fill=(70, 64, 56, 255))
                    d.rectangle([ox + gx + 80, top + 12, ox + gx + 116, top + 40], fill=(70, 64, 56, 255))
                    d.line([(ox + gx - 240, top + 12), (ox + gx - 240, top + 150)], fill=(70, 64, 56, 255), width=3)
                els.append(guind)
            return els
        return desenhar
    salvar(_faixa_generica(2048, 512, predios((168, 180, 196, 255), (190, 202, 216, 255), 160, 380, 0), 41), 'fundo_obra_longe.png')
    salvar(_faixa_generica(2048, 512, predios((132, 124, 116, 255), (160, 150, 138, 255), 120, 300, 0, True, 2), 42), 'fundo_obra_meio.png')

    def tapume(r, w, h):
        els = []
        def base(d, ox):
            d.rectangle([ox, h - 150, ox + w, h], fill=(120, 108, 92, 255))
            for x in range(0, w, 64):
                d.line([(ox + x, h - 150), (ox + x, h)], fill=(96, 86, 72, 255), width=4)
            d.rectangle([ox, h - 156, ox + w, h - 148], fill=(70, 62, 52, 255))
        els.append(base)
        for k in range(5):                                  # contêineres e pilhas de tubo
            cx = int((k + r.uniform(0.1, 0.6)) * w / 5); cw = int(r.uniform(180, 260)); ch = int(r.uniform(90, 120))
            cor = [(150, 70, 50, 255), (60, 100, 130, 255), (170, 140, 60, 255)][k % 3]
            def cont(d, ox, cx=cx, cw=cw, ch=ch, cor=cor):
                d.rectangle([ox + cx, h - 150 - ch, ox + cx + cw, h - 150], fill=cor)
                for x in range(cx + 10, cx + cw - 6, 18):
                    d.line([(ox + x, h - 146 - ch), (ox + x, h - 154)], fill=tuple(int(c * 0.8) for c in cor[:3]) + (255,), width=4)
            els.append(cont)
        return els
    salvar(_faixa_generica(2048, 512, tapume, 43), 'fundo_obra_perto.png')


def fundo_montanha():
    """Picos pontudos com neve (longe), encostas com pinheiros (meio e perto)."""
    def picos(cor, neve, alt_min, alt_max, n, seed, pinheiros=0, cor_p=(0, 0, 0, 0), vale=0.85):
        def desenhar(r, w, h):
            pts = [(0, h * vale)]
            for k in range(n):
                xp = (k + r.uniform(0.25, 0.75)) * w / n
                yp = h - r.uniform(alt_min, alt_max) * h
                xa, ya = pts[-1]
                pts.append((xa + (xp - xa) * r.uniform(0.35, 0.6), ya + (yp - ya) * r.uniform(0.3, 0.7)))   # ombro
                pts.append((xp, yp))
                if k < n - 1:
                    pts.append(((k + 1) * w / n + r.uniform(-20, 20), h * vale - r.uniform(0, 0.3) * h))
            pts.append((w, h * vale))
            pin = [(r.uniform(0, w), r.uniform(16, 30)) for _ in range(pinheiros)]
            def y_em(x):
                for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                    if x0 <= x <= x1:
                        return y0 + (y1 - y0) * (x - x0) / max(x1 - x0, 1e-6)
                return h * vale
            def monte(d, ox):
                d.polygon([(ox, h)] + [(ox + x, y) for x, y in pts] + [(ox + w, h)], fill=cor)
                if neve[3]:
                    for i in range(1, len(pts) - 1):
                        x, y = pts[i]
                        if y < h * 0.45:
                            xa, ya = pts[i - 1]; xb, yb = pts[i + 1]
                            t = 0.28
                            pa = (x + (xa - x) * t, y + (ya - y) * t); pb = (x + (xb - x) * t, y + (yb - y) * t)
                            meio = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2 + 10)
                            d.polygon([(ox + x, y), (ox + pa[0], pa[1]), (ox + meio[0] - 14, meio[1]), (ox + meio[0] + 6, meio[1] - 14), (ox + pb[0], pb[1])], fill=neve)
                    d.line([(ox + x, y) for x, y in pts], fill=tuple(int(c * 1.12) for c in cor[:3]) + (255,), width=4)
                for px, rr in pin:
                    yt = y_em(px)
                    d.polygon([(ox + px, yt - rr * 2.8), (ox + px + rr, yt + 6), (ox + px - rr, yt + 6)], fill=cor_p)
            return [monte]
        return desenhar
    salvar(_faixa_generica(2048, 512, picos((150, 166, 196, 255), (238, 244, 252, 255), 0.55, 0.85, 7, 51, vale=0.8), 51), 'fundo_montanha_longe.png')
    salvar(_faixa_generica(2048, 512, picos((86, 122, 114, 255), (0, 0, 0, 0), 0.32, 0.5, 9, 52, 70, (54, 90, 72, 255), vale=0.7), 52), 'fundo_montanha_meio.png')
    salvar(_faixa_generica(2048, 512, picos((62, 96, 70, 255), (0, 0, 0, 0), 0.22, 0.32, 6, 53, 30, (36, 66, 46, 255), vale=0.62), 53), 'fundo_montanha_perto.png')


if __name__ == '__main__':
    print('gerando arte em', OUT)
    textura_terra(); faixa_grama(); textura_madeira(); textura_metal(); faixa_perigo(); elo()
    bola_demolicao(); serra(); caixa(); tnt()
    arvore('arvore1.png', 1); arvore('arvore2.png', 2, alt=1100)
    pedra('pedra1.png', 3); pedra('pedra2.png', 4)
    placa('placa_largada.png', 'LARGADA', (40, 150, 60, 255)); placa('placa_chegada.png', 'CHEGADA', (200, 40, 40, 255))
    cerca(); fundo_campo()
    textura_concreto(); textura_rocha(); faixa_asfalto(); faixa_grama_alpina()
    pinheiro('pinheiro1.png', 61); pinheiro('pinheiro2.png', 62, alt=1400); cone()
    fundo_obra(); fundo_montanha()
