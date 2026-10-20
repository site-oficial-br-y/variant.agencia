---
name: 2d-physics-game
description: >-
  Usar ao criar, depurar ou evoluir jogos 2D baseados em física no Godot 4 com
  GDScript — em especial ragdolls no estilo Happy Wheels: veículos com rodas,
  personagens articulados por juntas (PinJoint2D), aplicação de forças/torque/
  impulso, colisões e camadas, câmera que segue o jogador, níveis, checkpoints,
  sangue/desmembramento e transição "montado → ragdoll". Também cobre o pipeline
  de recortar UMA ilustração em peças de corpo (com pivôs nas articulações) para
  montar o ragdoll a partir da própria arte. Gatilhos: "jogo de física 2D",
  "ragdoll", "Happy Wheels", "Godot", "RigidBody2D", "PinJoint2D", "veículo com
  física", "boneco que capota", "física na imagem".
---

# Jogos 2D de física (Godot 4 / GDScript)

Especialidade: jogos 2D de física com corpos rígidos e **ragdoll estilo Happy
Wheels** — um veículo com rodas motorizadas carregando um boneco articulado que,
ao bater, vira um ragdoll que esparrama, sangra e perde membros.

## Quando usar esta skill

Ative quando o pedido envolver qualquer um:
- Criar/continuar um **jogo 2D de física** no Godot 4 (corre-e-capota, destruição,
  veículo, boneco de pano).
- **Ragdoll**: montar o esqueleto físico, pose "viva", quebra de juntas,
  desmembramento, sangue.
- **Veículo com física**: chassi + rodas, aceleração, equilíbrio, salto, capotagem.
- Transformar **uma ilustração única** (foto/desenho de perfil) em peças de corpo
  para ragdoll.
- Câmera, níveis, checkpoints, HUD e tuning de "game feel" num jogo físico 2D.
- Depurar física: tunneling (atravessar o chão), instabilidade, tombamento,
  juntas que esticam, rodas que patinam.

NÃO use para jogos sem física rígida (puzzle de grade, visual novel, cartas),
nem para engines fora do Godot sem o usuário pedir.

## Princípios (pensar como dev de jogos)

1. **Física primeiro, arte depois — mas a arte manda na silhueta.** A imagem do
   personagem define o tamanho e os pivôs dos corpos físicos, não o contrário.
2. **Determinismo.** Toda lógica de física vive em `_physics_process(delta)` ou
   `_integrate_forces(state)`, nunca em `_process`. Tick fixo (60 Hz).
3. **Corpo rígido de verdade, não sprite andando.** Movimento = força/torque/
   impulso em `RigidBody2D`. Nada de `position += velocity` em quem tem física.
4. **Tuning por `@export`.** Todo número que afeta o feel é `@export` para iterar
   no inspetor sem recompilar a cabeça.
5. **Testar renderizando.** Rode a cena, use *Debug → Visible Collision Shapes*,
   confira spawn/queda/capotagem antes de dizer "pronto".
6. **Sem recorte mal feito.** Peça de corpo recortada segue o contorno do membro
   (polígono), com sobreposição nas juntas pra não abrir buraco.

## Stack e versões

- **Godot 4.x** (4.2+ recomendado; `Node.reparent()` exige 4.1+).
- **GDScript 2.0**: `@export`, `@onready`, `@export_range`, tipos estáticos,
  `preload`/`instantiate()`, sinais com `.connect(Callable)`.
- Física 2D nativa (Godot Physics). Gravidade 2D padrão: **980 px/s²**,
  vetor `(0, 1)` (y cresce pra baixo).

Diferenças de Godot 3 que você DEVE respeitar (erros comuns):
- `KinematicBody2D` → **`CharacterBody2D`**; `move_and_slide()` **sem argumentos**
  (usa a propriedade `velocity`).
- `instance()` → **`instantiate()`**.
- `RectangleShape2D.extents` → **`size`** (agora é a dimensão cheia, não a metade).
- Juntas 2D: só existem **`PinJoint2D`**, `GrooveJoint2D`, `DampedSpringJoint2D`.
  **Não existe `HingeJoint2D` em 2D** (isso é 3D).
- Câmera: `current` → **`enabled`** / `make_current()`; `smoothing_enabled` →
  **`position_smoothing_enabled`**.
- `deg2rad`/`rad2deg` → **`deg_to_rad`/`rad_to_deg`**.

## Arquitetura de projeto (resumo)

Detalhes em `references/architecture.md`. Estrutura mínima:

```
res://
  project.godot
  autoload/
    Game.gd            # estado global, score, checkpoint atual (singleton)
  actors/
    vehicles/
      Segway.tscn/.gd  # chassi + roda(s) + pontos de montagem
    ragdoll/
      Ragdoll.tscn/.gd # monta as peças e as juntas
      BodyPart.tscn/.gd# RigidBody2D genérico de uma peça
  levels/
    Level01.tscn/.gd
  systems/
    Camera.gd          # câmera que segue com lerp/limites
    Blood.gd           # partículas de sangue
  ui/
    HUD.tscn/.gd
  assets/              # ver assets/README.md
```

Uma **cena por responsabilidade**. O ragdoll é uma cena que instancia N peças
(cenas `BodyPart`) e cria as `PinJoint2D` entre elas por código, lendo os pivôs
de um recurso de dados.

## Regras de programação (GDScript)

- `_physics_process(delta)` para controle/decisões; `_integrate_forces(state)`
  quando precisar ler/alterar velocidade e contatos no passo da física.
- Aplique esforço com os métodos corretos (ver `references/physics.md`):
  `apply_central_force`, `apply_force`, `apply_torque`,
  `apply_central_impulse`, `apply_impulse`, `apply_torque_impulse`.
- Nunca mexa em `global_position`/`rotation` de um `RigidBody2D` dinâmico para
  movê-lo — isso briga com o solver. Use `freeze` + `FREEZE_MODE_KINEMATIC` se
  precisar posicionar via transform.
- Camadas de colisão definem o que colide com o quê. Partes do mesmo boneco não
  colidem entre si (ver abaixo).
- `@export_range` nos parâmetros de feel (torque, velocidade máx, rigidez de junta,
  limiar de dano).

## Receita do veículo (segway / moto / scooter)

```gdscript
extends RigidBody2D          # CHASSI
class_name Vehicle

@export var drive_power: float = 9000.0
@export var max_speed: float = 650.0      # px/s
@export var balance_stiffness: float = 16.0
@export var balance_damping: float = 8.0
@export var self_balancing: bool = true   # true pra segway (1 roda)

@onready var wheel: RigidBody2D = $Wheel

func _physics_process(_delta: float) -> void:
    var dir := Input.get_axis("brake", "accelerate")   # -1..1
    if dir != 0.0 and linear_velocity.length() < max_speed:
        # empurra num ponto BAIXO do chassi: não empina nem capota fácil
        apply_force(Vector2(dir * drive_power, 0.0), Vector2(0, 24))
    var lean := Input.get_axis("lean_back", "lean_fwd")
    if lean != 0.0:
        apply_torque(lean * drive_power * 0.5)
    elif self_balancing:
        # pêndulo invertido: endireita sozinho (como o segway real)
        apply_torque(-rotation * balance_stiffness * mass
                     - angular_velocity * balance_damping * mass)
```

- Roda = `RigidBody2D` com `CircleShape2D`, presa ao chassi por **`PinJoint2D`**
  (`disable_collision = true`) no eixo. A roda gira livre; o atrito com o chão
  gera tração. Dê `physics_material_override` com `friction` alto à roda e ao chão.
- Spawn: posicione a roda **tocando** o chão e o chassi **acima** — nunca sobreposto
  ao terreno (senão o solver ejeta o corpo violentamente). Ver "Armadilhas".

## Receita do ragdoll (coração do Happy Wheels)

Modelo: cada parte é um `RigidBody2D` com sprite e colisão; juntas `PinJoint2D`
com limite angular dão a pose; impacto forte quebra juntas.

Transição **montado → ragdoll** (o segredo do feel):
1. **Montado**: as peças ficam com `freeze = true`
   (`freeze_mode = FREEZE_MODE_KINEMATIC`) e são posicionadas por código seguindo
   a pose do veículo. Visualmente é a arte inteira, colada, dirigindo.
2. **Bateu / pulou fora**: para cada peça, `freeze = false` (vira dinâmica na
   posição/rotação atuais), crie as `PinJoint2D` entre as peças nos pivôs de
   articulação e injete a velocidade do veículo. Pronto: esparrama.

```gdscript
func solta_ragdoll(herda_vel: Vector2) -> void:
    for part in partes:                         # Array[RigidBody2D]
        part.freeze = false
        part.linear_velocity = herda_vel
    for j in juntas_def:                         # dados: {a, b, pivo_global, lim}
        var joint := PinJoint2D.new()
        add_child(joint)
        joint.global_position = j.pivo_global
        joint.node_a = j.a.get_path()
        joint.node_b = j.b.get_path()
        joint.disable_collision = true           # a e b não colidem entre si
        joint.softness = 0.0
        joint.angular_limit_enabled = true       # Godot 4: limite dá rigidez de pose
        joint.angular_limit_lower = deg_to_rad(-j.lim)
        joint.angular_limit_upper = deg_to_rad(j.lim)
        juntas.append(joint)
```

- **Partes do mesmo boneco não colidem entre si**: pares ligados por junta usam
  `disable_collision = true`; pares não-adjacentes resolvem por **camadas**
  (todas as peças na layer `ragdoll`, e tiram `ragdoll` da própria `collision_mask`,
  mantendo a layer do mundo).
- **Desmembrar**: em impacto acima de um limiar, remova a junta daquela peça
  (`joint.queue_free()`), emita sangue, aplique impulso. Ver `references/physics.md`
  (detecção por `get_contact_impulse`).
- **Pose viva** (sem ejetar, imitando os "músculos" do Happy Wheels): em vez de
  `freeze`, mantenha as juntas com `motor_enabled = true` e
  `motor_target_velocity` puxando para o ângulo-alvo; dano reduz/zera o motor.

## Pipeline: 1 ilustração → peças de ragdoll

Quando o personagem é uma única imagem de perfil (foto ou desenho):
1. Recorte o fundo (flood-fill a partir das bordas, preservando áreas claras
   internas). Ver `assets/README.md`.
2. Para cada parte (cabeça, tronco, braço[s], coxa, canela, pé, + roda/chassi do
   veículo): recorte por **polígono** que segue o membro, com **sobreposição** nas
   articulações; a máscara multiplica o alfa original (borda externa suave, corte
   interno limpo).
3. Salve cada peça como PNG autocropado e registre, por peça: `offset` (canto na
   arte) e os **pivôs** nomeados (pescoço, ombro, quadril, mão, pé…) em coords da
   imagem — eles viram a posição das `PinJoint2D` e o centro de rotação do sprite.
4. **Valide**: recomponha todas as peças nas posições originais e confira que
   remonta o personagem sem buraco antes de levar pro jogo.
5. No Godot: cada peça vira uma cena `BodyPart` (Sprite2D + CollisionPolygon2D
   com o mesmo polígono). O pivô vira a origem do nó (ajuste `Sprite2D.offset`).

Há um script Python de referência do recorte em `assets/README.md`.

## Fluxo de trabalho

1. **Criar/abrir projeto** Godot 4; definir `project.godot` (tick físico 60,
   gravidade, input actions: `accelerate`, `brake`, `lean_fwd`, `lean_back`,
   `eject`, `reset`).
2. Montar **um nível de teste** mínimo: chão plano longo + 1 rampa.
3. **Veículo** dirigível e estável (spawn correto, equilíbrio, tração).
4. **Ragdoll**: pose montada → transição → esparrama. Ajustar massas e limites.
5. **Dano/sangue/desmembramento**; **câmera**; **checkpoints**; **HUD**.
6. **Testar e depurar** (seção abaixo) renderizando de verdade.
7. Só então replicar para outros personagens/níveis.

## Testes de mecânica e depuração

- **Veja as formas**: *Debug → Visible Collision Shapes* e *Visible Paths*.
- **Câmera lenta** pra inspecionar impacto: `Engine.time_scale = 0.2`.
- **Spawn estável**: rode 3 s parado; o veículo não pode tombar nem afundar.
  Logue `rotation` e `global_position.y` do chassi.
- **Tunneling** (atravessou o chão): ative CCD —
  `continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY` nas rodas e projéteis rápidos;
  aumente o tick físico se preciso.
- **Capotagem previsível**: force `rotation` inicial e confira que o ragdoll
  solta e esparrama sem explodir (velocidades finitas; se "explodir", baixe
  rigidez das juntas e aumente `softness`, ou reduza massas).
- **Testes automatizados**: use **GUT** (Godot Unit Test). Ex.: instanciar o
  veículo, rodar N passos de física via `await get_tree().physics_frame`, e
  asserir que `global_position.x` aumentou e `rotation` ficou perto de 0.
- **Print de sanidade**: `print(name, linear_velocity, rotation)` dentro de
  `_integrate_forces` com um contador pra não poluir.

Checklist antes de "pronto":
- [ ] Spawn não afunda nem capota.
- [ ] Dirige pra frente e freia/ré.
- [ ] Sobe rampa e salta sem atravessar o chão.
- [ ] Pular fora solta o ragdoll na posição certa (sem teleporte).
- [ ] Impacto forte: sangue + (opcional) desmembramento, sem explosão numérica.
- [ ] Câmera segue suave; checkpoint reposiciona.

## Armadilhas já pagas (não repetir)

- **Spawn sobreposto ao terreno** → o solver ejeta o corpo (afunda/voa). Spawne a
  roda tocando a superfície e o resto acima.
- **Centro de massa alto** → tomba. Chassi baixo e denso; aplique a força de
  tração num ponto baixo; equilíbrio ativo no segway.
- **Junta longa fazendo de "haste"** → alavanca instável. O corpo que serve de
  mastro deve ser um `RigidBody2D` comprido de verdade, com a roda presa na base.
- **Peça do corpo colidindo com o próprio corpo/veículo** → tranco e jitter. Use
  `disable_collision` nas juntas e camadas pros não-adjacentes.
- **Mover `RigidBody2D` por `position`** → atravessa paredes e ignora colisão.
  Use força/impulso, ou `freeze` kinematic.
- **`RectangleShape2D.extents`** (API de Godot 3) → em Godot 4 é `size` (dobro).
- **Recorte reto no membro** → buraco na junta. Recorte por polígono com folga.

## Referências

- `references/physics.md` — gravidade, corpos rígidos, forças/torque/impulso,
  `_integrate_forces`, colisões/camadas, materiais, **juntas**, ragdoll, CCD.
- `references/architecture.md` — organização de cenas/autoloads, máquina de
  estados, personagem, veículo, nível, câmera, checkpoints, HUD, eventos.
- `assets/README.md` — sprites (recorte por parte, pivôs, importação), áudio,
  organização e licenças.
