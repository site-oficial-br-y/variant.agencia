# Arquitetura de um jogo 2D de física (Godot 4)

Padrões de organização para um jogo tipo Happy Wheels: cenas, autoloads, máquina
de estados, personagem/veículo, níveis, câmera, checkpoints, HUD e eventos.
Objetivo: cada peça isolada, testável e fácil de replicar para novos personagens
e fases.

---

## 1. Árvore de cenas e pastas

```
res://
  project.godot
  autoload/
    Game.gd            # singleton: estado, score, checkpoint, troca de fase
    Events.gd          # barramento de sinais global (desacopla sistemas)
  actors/
    vehicles/
      Vehicle.gd       # base: chassi RigidBody2D + rodas + pontos de montagem
      Segway.tscn      # 1 roda, auto-equilíbrio
      Scooter.tscn     # 2 rodas
    ragdoll/
      Ragdoll.gd/.tscn # instancia peças + cria juntas + transição montado/solto
      BodyPart.tscn    # RigidBody2D + Sprite2D + CollisionPolygon2D
      parts.tres       # Resource com offsets e pivôs por peça (ver assets)
  levels/
    Level.gd           # base de fase (spawn, meta, limites de câmera)
    Level01.tscn
  systems/
    FollowCamera.gd
    Blood.gd           # GPUParticles2D ou pool de sprites
  ui/
    HUD.tscn/.gd
    DeathScreen.tscn
  assets/              # ver assets/README.md
```

Regra: **uma cena por responsabilidade**, composta por instâncias. O `Level`
instancia o `Vehicle`; o `Vehicle` referencia um `Ragdoll`; o `Ragdoll` instancia
as `BodyPart`.

---

## 2. Autoloads (singletons)

`Game.gd` (Project Settings → Autoload) guarda o que sobrevive à troca de cena:

```gdscript
extends Node                       # Autoload "Game"
signal estado_mudou(novo)

enum Estado { MENU, JOGANDO, MORTO, VITORIA }
var estado: Estado = Estado.MENU
var checkpoint: Vector2 = Vector2.ZERO
var fase_atual: PackedScene

func set_estado(e: Estado) -> void:
    estado = e
    estado_mudou.emit(e)

func reiniciar_fase() -> void:
    get_tree().reload_current_scene()
```

`Events.gd` (barramento) desacopla quem emite de quem ouve:
```gdscript
extends Node                       # Autoload "Events"
signal jogador_morreu(pos)
signal bateu_forte(pos, forca)
signal checkpoint_ativado(pos)
```
Sistemas conectam em `_ready`: `Events.bateu_forte.connect(_on_bateu)`.

---

## 3. Máquina de estados do jogo

Centralize em `Game.estado` e reaja por sinal:
- `MENU` → seleção de personagem/fase.
- `JOGANDO` → input ativo, câmera segue, HUD visível.
- `MORTO` → ragdoll solto, input travado, tela de morte com "de novo".
- `VITORIA` → chegou na meta.

Para IA/estados de um ator, use um nó `StateMachine` simples (cada estado é um
método `tick(delta)`), ou apenas flags claras. Evite super-engenharia num jogo de
ação rápido.

---

## 4. Veículo (base reutilizável)

```gdscript
extends RigidBody2D
class_name Vehicle

@export var drive_power := 9000.0
@export var max_speed := 650.0
@export var self_balancing := false
@onready var wheels: Array = $Wheels.get_children()   # RigidBody2D
@onready var mount_point: Marker2D = $MountPoint       # onde o boneco senta/fica

func _physics_process(_d):
    var dir := Input.get_axis("brake", "accelerate")
    if dir != 0.0 and linear_velocity.length() < max_speed:
        apply_force(Vector2(dir * drive_power, 0.0), Vector2(0, 24).rotated(rotation))
    _lean_ou_equilibrio()

func _lean_ou_equilibrio():
    var lean := Input.get_axis("lean_back", "lean_fwd")
    if lean != 0.0: apply_torque(lean * drive_power * 0.5)
    elif self_balancing:
        apply_torque(-rotation * 16.0 * mass - angular_velocity * 8.0 * mass)
```

- Cada roda: `RigidBody2D` + `CircleShape2D`, presa por `PinJoint2D`
  (`disable_collision = true`). `physics_material_override.friction` alto.
- `Marker2D` "MountPoint" marca onde o personagem monta — o `Ragdoll` lê essa
  transform para a pose montada.
- Especializações (`Segway.tscn`, `Scooter.tscn`) só mudam `@export` e número de
  rodas; o código base é o mesmo.

---

## 5. Personagem / Ragdoll

- `Ragdoll.tscn`: nó raiz `Node2D` que instancia as peças (`BodyPart`) e cria as
  `PinJoint2D` por código, lendo `parts.tres` (offsets + pivôs — ver
  `assets/README.md`).
- Estado **montado**: peças `freeze` kinematic, posicionadas por script relativas
  ao `MountPoint` do veículo (pose rígida = a arte inteira).
- Estado **solto**: `freeze = false`, cria juntas, injeta velocidade do veículo.
- Dano: `Events.bateu_forte` → sangue; acima de um limiar maior, remove junta
  (desmembra).

`BodyPart.gd` genérico:
```gdscript
extends RigidBody2D
class_name BodyPart
@export var nome := ""           # "cabeca", "tronco", ...
func _ready():
    add_to_group("ragdoll")
    contact_monitor = true
    max_contacts_reported = 4
```

---

## 6. Níveis

Duas formas de terreno:
- **Polígonos/retângulos** (`StaticBody2D` + `CollisionPolygon2D`): preciso e leve
  para pistas desenhadas à mão (rampas, lombadas). Bom para começar.
- **`TileMapLayer`** (Godot 4.3+; antes `TileMap`) com colisão no TileSet: para
  níveis grandes/modulares.

`Level.gd` base:
```gdscript
extends Node2D
class_name Level
@export var spawn: NodePath
@export var camera_limits := Rect2(0, -2000, 8000, 4000)

func _ready():
    Game.checkpoint = get_node(spawn).global_position
    spawnar_jogador()
```

Obstáculos letais (espinhos, zona de morte): `Area2D` com
`body_entered.connect(...)` → `Events.jogador_morreu.emit(pos)`.
Meta: `Area2D` que dispara `VITORIA`.

---

## 7. Câmera que segue

Câmera **não** deve ser filha do veículo (herdaria a rotação e embrulharia a
tela). Ponha `Camera2D` no nível e siga por script, ou use `RemoteTransform2D`.

```gdscript
extends Camera2D
class_name FollowCamera
@export var alvo_path: NodePath
@export var lerp_rate := 0.12
@export var zoom_base := Vector2(1, 1)

func _ready():
    enabled = true
    position_smoothing_enabled = true
    position_smoothing_speed = 8.0

func _physics_process(_d):
    var alvo := get_node_or_null(alvo_path)
    if alvo:
        global_position = global_position.lerp(alvo.global_position, lerp_rate)
```

- Limites: `limit_left/right/top/bottom` para não mostrar fora da fase.
- Zoom: `zoom` (em Godot 4, `zoom` maior = **mais perto**; é multiplicador).
- Seguir um ragdoll (vários corpos): mire no tronco, ou na média das posições.

---

## 8. Checkpoints e morte

```gdscript
# Checkpoint (Area2D)
func _on_body_entered(body):
    if body.is_in_group("jogador"):
        Game.checkpoint = global_position
        Events.checkpoint_ativado.emit(global_position)

# Ao morrer: reposiciona no último checkpoint
func respawn():
    get_tree().reload_current_scene()      # simples
    # ou reposicionar o ator em Game.checkpoint sem recarregar a cena
```

Para respawn sem recarregar tudo: guarde o estado mínimo e reposicione o veículo
em `Game.checkpoint`, zere velocidades (`linear_velocity = Vector2.ZERO`,
`angular_velocity = 0`, `rotation = 0`), e recrie o personagem montado.

---

## 9. HUD e UI

- `CanvasLayer` com `Control` para HUD (não escala com a câmera).
- Mostre distância/score, botões de toque (`TouchScreenButton` ou `Button` com
  `Input` sintético) para mobile: GÁS, RÉ, inclinar, PULA FORA.
- Tela de morte/vitória: `Control` com `visible` alternado por `Game.estado`.
- Mapeie input em Project Settings → Input Map (`accelerate`, `brake`,
  `lean_fwd`, `lean_back`, `eject`, `reset`) e use `Input.get_axis` /
  `Input.is_action_just_pressed`.

---

## 10. Eventos vs chamadas diretas

- Use o barramento `Events` para coisas transversais (morte, sangue, som, câmera
  shake) — quem emite não precisa conhecer quem ouve.
- Use referência direta/`@export NodePath` para relações estruturais (veículo ↔
  ragdoll ↔ peças).

---

## 11. Performance

- Reaproveite objetos (pool) para sangue e partículas; não `instantiate()`/
  `queue_free()` a cada frame.
- Prefira `GPUParticles2D` para sangue em volume.
- Limite nós físicos ativos; congele (`freeze`) partes fora da tela se preciso.
- `max_contacts_reported` só o necessário (cada contato custa).

---

## 12. Ordem de construção recomendada

1. `project.godot` + Input Map + camadas de física nomeadas.
2. `Level01` com chão + 1 rampa (polígonos).
3. `Vehicle` dirigível e estável (spawn correto).
4. `Ragdoll` montado → solto.
5. Dano/sangue/desmembramento.
6. `FollowCamera` + checkpoints + HUD.
7. Autoloads `Game`/`Events` amarrando o fluxo.
8. Replicar personagens/fases.
