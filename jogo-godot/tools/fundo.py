"""Tira o fundo preto de uma arte (o fundo é o preto ligado à borda da imagem; preto
dentro do desenho, como pneu e roupa escura, fica).

Uso: python3 tools/fundo.py entrada.png saida.png
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

LIMIAR = 4           # o fundo das artes é preto puro (0-2); cabelo escuro fica acima disso


def tirar_fundo(img):
    a = np.asarray(img.convert('RGB')).astype(np.int16)
    brilho = a.max(axis=2)
    escuro = brilho <= LIMIAR
    rot, _ = ndimage.label(escuro)
    borda = np.unique(np.concatenate([rot[0], rot[-1], rot[:, 0], rot[:, -1]]))
    fundo = np.isin(rot, borda[borda > 0])
    fundo = ndimage.binary_opening(fundo, iterations=1)
    # borda macia: perto do fundo, a transparência acompanha o brilho
    perto = ndimage.binary_dilation(fundo, iterations=2) & ~fundo
    alfa = np.where(fundo, 0, 255).astype(np.float32)
    alfa[perto] = np.clip((brilho[perto] - LIMIAR) / 36.0, 0, 1) * 255
    alfa = ndimage.gaussian_filter(alfa, 0.6)
    alfa[fundo & ~ndimage.binary_dilation(~fundo, iterations=1)] = 0
    out = np.dstack([a.astype(np.uint8), alfa.clip(0, 255).astype(np.uint8)])
    return Image.fromarray(out, 'RGBA')


if __name__ == '__main__':
    tirar_fundo(Image.open(sys.argv[1])).save(sys.argv[2])
