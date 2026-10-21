---
name: ragdoll-physics-game
description: >-
  Desenvolve e VALIDA JOGANDO jogos 2D de física caótica no Godot 4 (GDScript),
  inspirados na jogabilidade de Happy Wheels (sem copiar código, assets, mapas ou
  personagens dele): ragdolls com segmentos físicos e juntas, veículos com rodas e
  suspensão, armadilhas, fases com checkpoints e vitória/derrota, personagens
  próprios do usuário (inclusive recortados de UMA imagem estática), tela de
  seleção, controles de teclado e toque, e playtest automatizado que tenta
  concluir cada fase com relatório honesto (APROVADO / FALHOU / NÃO TESTADO).
  Use quando o pedido envolver: jogo de física 2D, ragdoll, "boneco que capota",
  Happy Wheels, veículo com física, armadilha/serra/espinho, fase/nível de jogo de
  física, checkpoint, playtest/zerar/testar fase, Godot + RigidBody2D/PinJoint2D,
  ou colocar os personagens do usuário num jogo desse tipo.
---

# Jogos 2D de física com ragdoll (Godot 4) — desenvolver e jogar

Esta skill cobre o ciclo inteiro: **inspecionar → planejar → implementar →
executar → JOGAR → achar falhas → corrigir → testar de novo**, até existir
evidência verificável de que cada fase pode ser concluída.

Referências (consulte a que for relevante antes de implementar):

| Arquivo | Quando abrir |
|---|---|
| [references/physics-system.md](references/physics-system.md) | corpos, juntas, ragdoll, veículos, armadilhas, dano, estabilidade numérica |
| [references/character-system.md](references/character-system.md) | personagens do usuário, recorte de imagem estática, registro, seleção |
| [references/level-design.md](references/level-design.md) | fases, peças de cenário, checkpoints, validação de mapa |
| [references/architecture.md](references/architecture.md) | pastas, componentes, sinais, como adicionar personagem/veículo/fase |
| [references/testing.md](references/testing.md) | testes de física, regressão, **playtest automatizado**, relatório |
| [assets/README.md](assets/README.md) | organização de sprites/sons, pipeline de recorte, licenças |

## Quando ativar

- Criar, continuar ou depurar um jogo 2D baseado em física com personagem que cai,
  gira, é arremessado ou se desmonta.
- Montar ragdoll, veículo, armadilha, plataforma móvel ou objeto destrutível.
- Colocar personagens próprios do usuário no jogo (sprites, fotos, desenhos).
- Criar ou validar fases, checkpoints, vitória e derrota.
- **Testar jogando**: "testa a fase", "consegue zerar?", "joga e me diz o que quebra".

Não ative para jogos sem física rígida (cartas, puzzle de grade, visual novel)
nem para engines diferentes sem justificativa técnica concreta.

## Responsabilidades

1. **Física consistente.** Movimento de corpo físico = força/impulso/torque em
   `RigidBody2D`, nunca `position +=`. Ragdoll = segmentos físicos com juntas, não
   animação que imita queda.
2. **Personagens do usuário primeiro.** Procure os assets dele antes de criar
   qualquer coisa; nunca troque por genérico nem invente personagem.
3. **Original, não cópia.** Inspire-se na *experiência* de Happy Wheels; não use
   código, sprites, sons, nomes, mapas ou layouts dele.
4. **Jogar de verdade.** Compilar, passar sintaxe ou simular física isolada não é
   playtest. Veja [testing.md](references/testing.md#niveis-de-evidencia).
5. **Honestidade.** Nunca afirme ter recortado, animado, jogado ou zerado algo sem
   evidência (log, screenshot, sinal de vitória registrado). Métricas só medidas.
6. **Não destruir.** Preserve assets e projetos do usuário; não mexa em arquivos
   fora do escopo; não faça commit/publicação sem autorização.

## Ferramentas recomendadas

- **Godot 4.3+** (binário oficial). Headless para testes:
  `godot --headless --path <projeto> res://cena.tscn -- <args do usuário>`.
- **Xvfb + `--rendering-driver opengl3`** para rodar renderizado sem monitor e
  capturar tela: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path P --rendering-driver opengl3 ...`.
- **Entrada real** (opcional): XTest via `python-xlib` (`pip install python-xlib`)
  ou `xdotool`, mandando teclas para a janela do jogo sob Xvfb.
- **Python 3 + Pillow/numpy/scipy** para recorte de imagens e folhas de contato.
- Exportação web: templates oficiais, preset **sem threads** para hospedagem
  estática (GitHub Pages não envia COOP/COEP).

Verifique o que existe antes de prometer: `command -v godot xvfb-run xdotool`,
`python3 -c "import Xlib"`.

## Fluxo de trabalho

### 1. Inspecionar
- Liste o repositório; ache projetos Godot (`project.godot`), personagens
  (imagens, `parts.json`, `.tres`), fases e testes existentes. Leia o `CLAUDE.md`.
- Identifique ferramentas disponíveis (acima) e registre o que **não** existe.

### 2. Planejar
- Defina: personagens e veículos, mecânicas, fases (objetivo, obstáculos, rota
  viável), critérios de aprovação de cada fase (ver
  [testing.md](references/testing.md#criterios-por-fase)).
- Escolha a estrutura de pastas de [architecture.md](references/architecture.md).

### 3. Implementar em etapas pequenas, testando entre elas
1. Projeto + Input Map + camadas de física nomeadas.
2. Fase mínima (chão + 1 rampa + meta) e o veículo estável (spawn sem afundar).
3. Personagem montado → ragdoll (transição sem teleporte).
4. Dano por impacto, sangue/partículas, morte, reinício rápido.
5. Armadilhas, checkpoints, mais fases.
6. Seleção de personagem, HUD, toque.

### 4. Executar e JOGAR
- Rode o teste de física headless e o **playtest** de cada fase
  ([testing.md](references/testing.md#playtest-automatizado)).
- Capture screenshots/folha de contato e **olhe**. Registre tentativas em JSONL.

### 5. Corrigir e repetir
- Classifique cada falha: execução, estratégia do bot, bug, ou design.
- Corrija a causa real; **não** facilite a fase só para o teste passar.
- Rode de novo tudo que a mudança pode ter afetado (regressão).

### 6. Entregar
- Como rodar, o que foi testado, relatório com APROVADO / FALHOU / NÃO TESTADO e
  limitações do ambiente ([modelo do relatório](references/testing.md#relatorio-de-playtest)).

## Regras de código (GDScript 2.0 / Godot 4)

- Física em `_physics_process` ou `_integrate_forces`; nunca em `_process`.
- Tipos explícitos quando o valor vem de `Dictionary`/JSON: `var ok: bool = ...`
  (`:=` não infere de `Variant` e é **erro de parse**).
- Criar/remover corpos ou juntas dentro de callback de física (`body_entered`,
  `_integrate_forces`) dá *"Can't change this state while flushing queries"*:
  use `metodo.call_deferred(...)`.
- `RigidBody2D.inertia` vale `0` no modo automático — não use como inércia real;
  calcule pela forma (ver [physics-system.md](references/physics-system.md#inercia)).
- Ajuste fino sempre em `@export`; nada de número mágico espalhado.
- APIs de Godot 3 proibidas: `KinematicBody2D`, `instance()`, `extents`,
  `HingeJoint2D` em 2D, `deg2rad`, `yield`.

## Armadilhas de ambiente já vividas

- `--test` é argumento reservado do Godot (aborta o binário oficial). Passe
  argumentos próprios depois de `--` e leia com `OS.get_cmdline_user_args()`.
- Rode o Godot com `--path <projeto>`: se o diretório corrente estiver errado, ele
  trata a pasta atual como projeto e espalha `.import` pelo repositório.
- Exportar para uma pasta que você acabou de apagar pode falhar com
  `Parameter "fd" is null`: crie a pasta (`mkdir -p`) e confira os arquivos.
- `pkill -f <padrão>` casa com a própria linha de comando do shell e mata o seu
  teste (código 144). Mate pelo PID.
- Botão comum (`Button`) no celular aceita **um dedo**: use `TouchScreenButton`
  (multitoque, aciona a ação direto).
- Tela: `canvas_items` + `aspect=expand` preenche celulares 20:9; `keep` deixa
  faixas pretas. Posicione UI pelas bordas do `get_visible_rect()`.

## Critério de "pronto"

Só declare uma fase concluída com evidência de vitória registrada pelo playtest
(sinal de vitória + log + screenshot). Sem interface/automação disponível, diga
explicitamente que o playtest real está **NÃO TESTADO** e entregue o resto.
