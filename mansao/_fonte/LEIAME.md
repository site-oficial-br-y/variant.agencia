# Alvorada Residence — como reconstruir

O entregável é `mansao/index.html`, arquivo único com fontes e fotos embutidas em base64.
Para editar, mexa em `template.html` e rode os scripts na ordem:

1. `fonts.py`   baixa Outfit e Cormorant Garamond do Google Fonts e gera `fonts.css` já em base64
2. `cut.py`     separa o céu da render principal e gera `fg.png`, o recorte da casa com transparência
3. `assets.py` e `assets2.py`  geram os webp otimizados em `out/`
4. `build.py`   injeta tudo no template e escreve `../index.html`

`shot.py W H` e `shots.py` tiram print com Chromium para conferir antes de entregar.

## O truque da capa
São duas camadas da mesma foto: o fundo completo embaixo do título e o recorte
sem céu por cima. O texto fica no meio, então aparece só onde havia céu e some
atrás da casa e das palmeiras. As duas camadas ficam no mesmo palco com
`container-type:size`, e o título é medido em `cqw`, então a composição inteira
escala junta em qualquer tela. Telas mais altas que largas trocam para um corte
vertical 3:4 da mesma foto, com a mesma máscara.
