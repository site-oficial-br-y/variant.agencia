# Recursos (assets): sprites, recorte em peças, áudio

Como criar e organizar os recursos de um jogo 2D de física no Godot 4, com foco no
pipeline de transformar **uma ilustração única** em peças de ragdoll.

---

## 1. Organização de pastas

```
assets/
  characters/
    <nome>/
      full.png          # ilustração original (perfil), fundo removido
      parts/            # peças recortadas p/ ragdoll
        cabeca.png
        tronco.png
        braco.png
        perna.png
        ...
      parts.json        # offsets + pivôs de cada peça (fonte do parts.tres)
  vehicles/
    <nome>/ roda.png, chassi.png, ...
  tiles/                # tilesets de nível
  audio/
    sfx/ batida.ogg, motor.ogg, osso.ogg
    music/ tema.ogg
```

Converta `parts.json` num `Resource` do Godot (`parts.tres`) ou carregue o JSON
em runtime com `FileAccess` + `JSON.parse_string`.

---

## 2. Importação no Godot 4

- **Pixel art**: no `.import` do sprite, Filter = **Nearest** (sem desfoque).
- **Arte vetorial/ilustração** (como fotos estilizadas): Filter = **Linear**,
  Mipmaps ligados se houver muito zoom-out.
- Mantenha os PNGs com **alfa** (transparência). Não "achate" fundo em branco.
- Um atlas (`AtlasTexture` / `SpriteFrames`) economiza draw calls quando há muitas
  peças pequenas; para um protótipo, PNGs soltos bastam.

---

## 3. Remover o fundo de uma ilustração

Para fundo claro e uniforme, **flood-fill a partir das bordas** (não apague por cor
global — isso come as partes claras internas, tipo tênis/toalha brancos).

```python
# requer: pillow, numpy, scipy
import numpy as np
from PIL import Image
from scipy import ndimage

im = Image.open("full_raw.png").convert("RGB")
a = np.asarray(im).astype(np.int16)
claro = (a[:,:,0] > 228) & (a[:,:,1] > 228) & (a[:,:,2] > 228)
lbl, _ = ndimage.label(claro)
borda = set(lbl[0]) | set(lbl[-1]) | set(lbl[:,0]) | set(lbl[:,-1]); borda.discard(0)
fundo = np.isin(lbl, list(borda))                 # só o claro ligado à borda
alpha = np.where(fundo, 0, 255).astype(np.uint8)
Image.fromarray(np.dstack([np.asarray(im), alpha]), "RGBA").save("full.png")
```

---

## 4. Recortar a ilustração em peças de ragdoll

A técnica que evita "recorte mal feito": cada peça é cortada por **polígono** que
segue o membro, com **sobreposição** nas articulações, e a máscara **multiplica o
alfa original** (borda externa suave, corte interno limpo).

Para cada peça registre: `offset` (canto da bbox na arte) e os **pivôs** nomeados
(pescoço, ombro, quadril, mão, pé…) em coordenadas da imagem. Os pivôs viram:
- a posição das `PinJoint2D` entre peças;
- a origem de rotação do `Sprite2D` (ajuste `offset`).

```python
import json, numpy as np, os
from PIL import Image, ImageDraw, ImageFilter

SRC, OUT = "full.png", "parts"; os.makedirs(OUT, exist_ok=True)
im = Image.open(SRC).convert("RGBA"); W, H = im.size
alpha = np.asarray(im)[:, :, 3].astype(np.float32) / 255.0

# polígono (segue o membro, com folga) + pivôs em coords da arte
PECAS = {
  "cabeca": {"poly": [...], "piv": {"pescoco": (212, 226)}},
  "tronco": {"poly": [...], "piv": {"pescoco": (208,230), "ombro": (218,252),
                                     "quadril": (176,440)}},
  "braco":  {"poly": [...], "piv": {"ombro": (216,252), "mao": (400,600)}},
  "perna":  {"poly": [...], "piv": {"quadril": (178,442), "pe": (150,1068)}},
}

meta = {"src_w": W, "src_h": H, "pecas": {}}
for nome, spec in PECAS.items():
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(spec["poly"], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(1.2))            # suaviza o corte interno
    mask = np.asarray(m).astype(np.float32) / 255.0
    rgba = np.dstack([np.asarray(im)[:, :, :3],
                      (alpha * mask * 255).astype(np.uint8)])
    part = Image.fromarray(rgba, "RGBA"); bbox = part.getbbox()
    part = part.crop(bbox); part.save(f"{OUT}/{nome}.png")
    meta["pecas"][nome] = {
        "file": f"parts/{nome}.png", "x": bbox[0], "y": bbox[1],
        "w": part.width, "h": part.height,
        "piv": {k: [vx - bbox[0], vy - bbox[1]] for k, (vx, vy) in spec["piv"].items()},
    }
json.dump(meta, open(f"{OUT}/parts.json", "w"), indent=1)
```

**Sempre valide**: recomponha todas as peças nas posições originais
(`alpha_composite` em `(x, y)`) e confira que remonta o personagem **sem buraco**
antes de usar no jogo. Se faltar um pedaço no meio (ex.: antebraço diagonal), o
polígono passou por fora do membro — corrija os vértices.

Dicas de recorte:
- Membro diagonal: siga o eixo real do membro; não use caixa reta.
- Nas juntas, estenda a peça ~10–20 px dentro da vizinha (sobreposição) para não
  abrir vão quando articular.
- Áreas onde um membro tampa o tronco ficam "vazias" no tronco; isso é aceitável
  (o membro cobre quando montado); some só no ragdoll separado, no meio do caos.

---

## 5. Levar as peças pro Godot

Cada peça vira uma cena `BodyPart.tscn`:
- `RigidBody2D` (raiz) com `mass` coerente (tronco > coxa > cabeça > braço).
- `Sprite2D` com a textura da peça; ajuste `offset` para que a **origem do nó caia
  no pivô principal** da peça (ex.: o quadril, no tronco).
- `CollisionPolygon2D` com o **mesmo polígono** do recorte (ou uma cápsula/retângulo
  aproximado, mais barato e estável).

As `PinJoint2D` entre peças são criadas por código, posicionadas no pivô global
correspondente (ex.: ombro do tronco == ombro do braço). Ver
`references/physics.md` §7–8.

Escala: a arte costuma ser grande (p.ex. 1379 px de altura). Defina um fator
`ESC` para que a roda/altura fique num tamanho jogável e aplique o **mesmo** fator
ao desenho e às formas de colisão, para sprite e física baterem.

---

## 6. Áudio

- `AudioStreamPlayer2D` para sons posicionais (motor, batida, osso quebrando);
  `AudioStreamPlayer` para música/UI.
- Formatos: `.ogg` (Vorbis) para música/efeitos longos; `.wav` para efeitos curtos
  de baixa latência.
- Buses: crie `Master → Música`, `Master → SFX` (Audio tab) para controlar volume
  por categoria. Loop: marque no `.import` do stream.
- Dispare som no evento, não todo frame: no `Events.bateu_forte`, escolha o som
  pela força do impacto; adicione leve variação de `pitch_scale` para não repetir.

---

## 7. Checklist de assets

- [ ] `full.png` com fundo transparente (flood-fill, partes claras preservadas).
- [ ] Peças recortadas por polígono, validadas recompondo sem buraco.
- [ ] `parts.json` com offset + pivôs por peça.
- [ ] Import Filter correto (Nearest pixel / Linear ilustração).
- [ ] Massas e colisões por peça definidas; mesmo `ESC` em sprite e colisão.
- [ ] SFX em buses, disparados por evento com variação de pitch.
