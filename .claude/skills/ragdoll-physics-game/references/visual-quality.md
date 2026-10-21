# Qualidade visual — padrão obrigatório

O jogo pode ter física perfeita e ainda parecer protótipo. Esta referência define o
padrão visual mínimo e o **portão de qualidade** que toda fase precisa passar,
além do playtest. Volte para o [SKILL.md](../SKILL.md) · composição de fase em
[level-design.md](level-design.md#7-composição-visual-da-fase).

Causa real que motivou este arquivo (jogo Bicho Ehn): a skill só exigia "o bot
zera a fase". Resultado: tudo em retângulos chapados, o mesmo morro em todas as
fases, bola de demolição com 1/7 da altura do boneco, câmera colada no boneco.

---

## 1. Direção de arte antes de código

Para cada fase, escreva 5 linhas antes de construir:

1. **Tema** (campo, obra, montanha, cidade, fábrica…) — define fundo e materiais.
2. **Paleta**: céu (2 cores de gradiente), terreno (preenchimento + faixa de topo +
   contorno), 1 cor de destaque para perigo (vermelho/amarelo), metais (cinza-azulado).
3. **Momentos**: 3–5 "fotos" memoráveis da fase (ex.: "ponte de madeira sobre
   espinhos", "guindaste com bola de demolição", "salto sobre a água").
4. **Silhueta do terreno**: desenho do perfil (subidas, descidas, penhasco, buraco).
5. **Referência**: se o usuário mandou imagem, liste o que vai aproveitar
   (composição, densidade de detalhes, tipos de estrutura) — **nunca** a imagem como
   fundo estático nem cópia de layout.

## 2. Escala (relativa ao personagem)

Meça a altura do personagem no mundo (`H`, px) e derive `px_por_metro ≈ H / 1,8`.
Tamanhos de referência:

| Objeto | Tamanho real | Em `H` |
|---|---|---|
| bola de demolição (diâmetro) | 1,2–1,6 m | 0,7–0,9 H |
| caixa de madeira | 0,6–0,8 m | 0,35–0,45 H |
| barril/TNT | 0,9 m alt. | 0,5 H |
| bola de futebol | 0,22 m | 0,12 H |
| espinho | 0,3–0,5 m | 0,2–0,3 H |
| serra | 1,2–2 m diâm. | 0,7–1,1 H |
| viga de aço (altura) | 0,4 m | 0,22 H |
| torre de guindaste | 8–15 m | 4–8 H |
| árvore | 4–8 m | 2–4 H |

**Câmera**: personagem ocupando 25–35% da altura da tela (zoom ≈ `0,3 × 720 / H`).
Mostre bastante fase à frente (`offset` à frente do movimento).

## 3. Estilo cartunesco consistente

- **Contorno escuro** em tudo que é jogável (terreno, estruturas, obstáculos):
  `Line2D` fechado/aberto, largura ≈ `H/90` (com H≈1300 → 14 px), cor quase preta
  do material (`terra → #2b1a0e`, `metal → #1c2128`, `madeira → #3a2410`).
- **Materiais distinguíveis**: terra com textura (ruído + pedrinhas), faixa de topo
  (grama ou asfalto) com borda clara, madeira com veios e tábuas, metal com
  rebites/listras e brilho, água animada translúcida.
- **Sombreamento simples**: 1 tom de luz no topo/esquerda, 1 de sombra embaixo.
- **Sem polígono "pelado"**: retângulo sem textura, contorno ou detalhe só é aceito
  para colisão invisível.
- Texturas: gere tiles **emendáveis** (gere em faixa tripla e recorte o miolo; teste
  diferença coluna 0 × última ≈ 0) e aplique em `Polygon2D.texture` com
  `texture_repeat = TEXTURE_REPEAT_ENABLED` e UV por posição.

## 4. Construção coerente de estruturas

- Toda estrutura **apoia em algo**: pilares até o chão, cabos até um ponto fixo.
- Treliças (guindaste, andaime, ponte metálica): dois banzos + diagonais em X.
- Pontes de madeira: tábuas + postes + corrimão; caídas quebram em tábuas.
- Pêndulo: corrente visível de elos (ou cabo grosso) até um gancho num braço de
  guindaste — nunca pendurado no céu.
- Colisão e visual **batem**: o polígono de colisão é o mesmo do desenho (ou a
  forma física é a silhueta simplificada); confira com *Visible Collision Shapes*.

## 5. Biblioteca de obstáculos (padrão mínimo de cada um)

| Obstáculo | Visual | Física/comportamento | Feedback |
|---|---|---|---|
| bola de demolição | esfera sombreada + brilho + gancho + corrente de elos | pêndulo cinemático θ(t); empurra; pancada rápida derruba | som metal, poeira |
| serra | disco com dentes, cubo, borrão de giro | gira; Area2D letal | faíscas, sangue |
| espinhos | cones metálicos com brilho e base | Area2D letal | sangue |
| plataforma móvel | viga com rodas/trilho | `AnimatableBody2D` | — |
| pistão/prensa | cilindro + haste + cabeça | `AnimatableBody2D` periódico | baque, poeira |
| ponte que cai | tábuas + postes | tábua `RigidBody2D freeze` → solta | estalo |
| caixa | madeira com tábuas cruzadas | `RigidBody2D` leve | som madeira |
| TNT/barril | barril vermelho com faixa e símbolo | explode em pancada: impulso radial | flash, partículas, fumaça |
| água | superfície ondulada animada, translúcida | zona de morte (afoga) | respingo |
| rampa/loop | madeira ou metal com suporte | estática | — |

Cada obstáculo é uma função/cena **reutilizável** com parâmetros (tamanho, período,
força) — nunca desenhado à mão dentro da fase.

## 6. Fundo com identidade por tema

- Céu: gradiente numa `CanvasLayer` atrás (independe de zoom).
- 3 camadas de paralaxe (longe → perto) **coerentes com o tema**: campo (morros +
  árvores), obra (silhueta de prédios + guindastes), montanha (picos + pinheiros).
- Camada perto com detalhes (árvores, postes, cercas) e camada longe mais clara e
  dessaturada (perspectiva atmosférica).
- Não repita o mesmo fundo em todas as fases.

## 7. Efeitos

- Poeira ao pousar/bater (`CPUParticles2D`, cor do terreno).
- Faíscas em metal, lascas em madeira, flash + fumaça em explosão.
- Sangue: gotas com física + manchas; quantidade proporcional à pancada; jato no
  membro arrancado. Opção de desligar.

## 8. Portão de qualidade visual (obrigatório antes de "pronto")

Renderize a fase (Xvfb + opengl3), gere **folha de contato** (6–12 quadros ao
longo do percurso) e responda, olhando as imagens:

- [ ] O personagem ocupa 25–35% da altura da tela?
- [ ] Objetos na escala da tabela §2?
- [ ] Nenhum polígono sem textura/contorno visível?
- [ ] Estruturas apoiadas e coerentes (nada flutuando)?
- [ ] Fundo do tema certo, sem emenda visível nem área vazia?
- [ ] Colisão alinhada ao desenho (roda no chão, nada afundando/atravessando)?
- [ ] Cada "momento" da direção de arte aparece e é legível?
- [ ] Nada sobrepõe o HUD de forma ruim?

Registre o resultado no relatório como APROVADO / FALHOU / NÃO TESTADO, igual ao
playtest. Fase só está pronta com **os dois portões** aprovados.

Para gerar a folha: playtest com `fotos_cada=<s>` (captura a cada s segundos de jogo)
sob Xvfb, depois junte os PNGs numa grade. Rode com `tentativas=1` para as fotos
não misturarem tentativas diferentes.

## 9. Lições do piloto (Bicho Ehn, fase 1)

- **Arte por script, não à mão na fase**: `tools/gerar_arte.py` gera texturas
  emendáveis e sprites; `levels/Pecas.gd` (biblioteca de peças) monta terreno,
  ponte, guindaste, água, rampa, passarela, prensa, caixa, TNT, placa e partículas.
  A fase só chama funções com parâmetros. Tema troca material:
  `chao_tex`/`topo_tex`/`contorno_chao`.
- **Escala do mundo vale para efeitos**: gota de sangue de 3–8 px some com zoom
  0,18. Multiplique raio e velocidade das partículas pela escala do boneco
  (`Sangue.escala`). O mesmo vale para poeira e explosão.
- **Câmera afastada abre emenda na paralaxe**: com zoom pequeno, uma cópia da camada
  não cobre a tela. Ponha 2 cópias por ciclo de `motion_mirroring`.
- **HUD de toque cobre o terço de baixo**: suba a pista na tela (`offset.y` menos
  negativo) e confira no print se veículo e buracos não ficam atrás dos botões.
- **Texto de placa**: fonte padrão do PIL falha; desenhe o texto no motor (`Label`
  filho do sprite).
