# Recursos (assets)

Como organizar e preparar sprites, peças de ragdoll, sons e fontes — em especial
transformar **a imagem do personagem do usuário** em peças com física.

Volte para o [SKILL.md](../SKILL.md) · formato `parts.json` em
[character-system.md](../references/character-system.md#2-modelo-de-dados).

---

## 1. Organização

```
tools/fonte/<id>_full.png        # cópia de trabalho da imagem original (fundo removido)
assets/<id>/<peca>.png            # peças geradas (não editar à mão)
assets/<id>/parts.json            # geometria + física geradas
assets/ui/                        # fundo do menu, ícones dos botões, rostos, logo
assets/fonts/                     # .woff2/.ttf (Godot 4 importa woff2)
assets/audio/sfx/ assets/audio/musica/
```

- O arquivo que o usuário mandou **nunca** é sobrescrito.
- Peças são **geradas** por script: para mudar, mude a config e rode de novo.
- `tools/` fica fora do build (`exclude_filter="tools/*"`).

## 2. Importação no Godot

- Ilustração/foto: filtro **Linear** (`rendering/textures/canvas_textures/default_texture_filter=1`).
  Pixel art: **Nearest**.
- PNG com alfa; não achatar em fundo branco.
- Fonte: `.woff2` pode ser baixada de pacotes npm `@fontsource/<fonte>` (arquivos
  `files/*-latin-400-normal.woff2`). Ex.: Lilita One.

## 3. Pipeline de recorte

Implementação real: `jogo-godot/tools/segmenta.py` (configs `cadeira`,
`scooter`; o segway foi feito antes com um script dedicado, mesmos princípios).

1. **Fundo**
   - flood-fill a partir das bordas em pixels claros (`min(rgb) > 228`);
   - **ilhas presas**: componentes conexos com `min(rgb) > 238`, tamanho > 400 px
     e **desvio de cor < 4** viram transparentes (fundo liso preso entre perna e
     poste, vãos de raio de roda). Brancos do personagem (fralda, tênis,
     carenagem) têm sombreado e sobrevivem;
   - confira contando pixels quase brancos opacos que sobraram (deve ser 0 nas
     áreas de vão).
2. **Espelhar** se o personagem anda para a esquerda.
3. **Mapear com grade**: gere a imagem com grade de 50 px (e zoom com grade de
   20 px nas juntas) e anote: centro e raio das rodas (meça por perfis de pixel
   em linhas/colunas), linhas de corte (pescoço, barra da camisa, joelho),
   polígonos de membros que a cor não separa.
4. **Partição em ordem de prioridade** (cada pixel em UMA peça): roda → cabeça
   (acima da linha do pescoço) → braço (cor de pele + polígono) → veículo da
   frente → veículo de trás → tronco → perna; sobra → peça rotulada mais próxima
   (`distance_transform_edt` com índices); migalhas < 300–500 px → vizinho.
5. **Casca**: preencha cada peça apenas em `casca ∩ (pixels de peças desenhadas
   DEPOIS dela) ∩ ~própria`, com cor = pixel próprio mais próximo + desfoque
   gaussiano (σ≈14). Fonte da cor restrita quando necessário (ex.: só pele na
   barriga atrás de um apoio de braço, senão mistura com a roupa).
6. **Rodas**: se parcialmente tampadas, perfil radial médio dos pixels visíveis
   para completar o disco + pixels originais onde visíveis. Raios (spokes):
   detectar ângulos claros em vários raios, ajustar uma reta (SVD) por raio.
7. **Pivôs e formas** em coordenadas da arte; formas = cápsulas entre pivôs.
8. **Validação** (sempre mostrar números):
   - remontagem na ordem de desenho vs original → % de pixels com diferença > 16;
   - pose de teste com membros girados nos pivôs, para ver buraco/sobra;
   - mapa colorido das peças, para conferir se nada caiu na peça errada
     (ex.: giroflex laranja classificado como "pele" e indo para a cabeça).

Erros reais já corrigidos com esse processo: faixa branca de fundo entre perna e
poste; roda medida menor que a real (pneu cortado); escudo amarelo virando "pele";
bloco preto na coxa por preenchimento que zerava longe dos pixels visíveis.

## 4. Interface

- Ícones dos botões gerados por script (círculo translúcido + seta/curva), 200×200,
  escalados no `TouchScreenButton`.
- Rostos dos quadros: peça `cabeca` reduzida + versão cinza por luminância.
- Logo do usuário: remova o fundo (flood-fill) e use como `TextureRect`.

## 5. Áudio

- `AudioStreamPlayer2D` para batida/motor (posicional), `AudioStreamPlayer` para
  música/UI. Buses `Musica` e `SFX`.
- `.ogg` para música/loops, `.wav` para efeito curto. Varie `pitch_scale`
  (0,9–1,1) para não repetir igual.
- Dispare por sinal (`pancada`, `venceu`), nunca todo quadro.

## 6. Licenças e originalidade

- Não use sprites, sons, fontes, nomes ou mapas de Happy Wheels nem de outros jogos.
- Fontes: só com licença livre (OFL/Apache) — as do Fontsource/Google Fonts são.
- Sons gerados/gravados pelo usuário ou de bancos livres (CC0), anotando a fonte
  num `assets/audio/CREDITOS.md`.
