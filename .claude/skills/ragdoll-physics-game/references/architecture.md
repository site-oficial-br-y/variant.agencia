# Arquitetura do projeto (Godot 4)

Sistemas pequenos, cada um com uma responsabilidade, falando por **sinais**. Dados
(personagens, fases) separados de lógica e de arte.

Volte para o [SKILL.md](../SKILL.md) · física em
[physics-system.md](physics-system.md) · personagens em
[character-system.md](character-system.md) · fases em
[level-design.md](level-design.md) · testes em [testing.md](testing.md).

---

## 1. Pastas

```
res://
  project.godot
  autoload/
    Game.gd               # estado global, personagem escolhido, checkpoint por fase
    CharacterRegistry.gd  # descobre characters/*/character.tres
    AudioManager.gd       # buses e sons de evento
    PlaytestController.gd # só age com "-- playtest" / "-- observar"
  characters/<id>/character.tres      # CharacterDefinition
  assets/<id>/*.png + parts.json      # peças recortadas (geradas)
  assets/ui/ assets/fonts/ assets/audio/
  actors/
    Player.gd             # monta veículo + piloto a partir dos dados
    VehicleController.gd  RagdollBuilder.gd
  systems/
    PhysicsDamageSystem.gd  Sangue.gd  CameraController.gd
  levels/
    LevelManager.gd  Checkpoint.gd  fase01.tscn ...  lista_fases.tres
    traps/ SawTrap.gd  MovingPlatform.gd  Destructible.gd
  ui/ Menu.tscn  HUD.gd
  tools/                 # NÃO vai no build (exclude_filter="tools/*")
    segmenta.py  validar_fases.gd  testes_fisica.gd  playtest_xtest.py  fonte/
```

## 2. Componentes (nomes de referência → implementação Godot)

| Papel | Implementação | Responsabilidade | Fala com |
|---|---|---|---|
| CharacterRegistry | autoload `Node` | lista/carrega `CharacterDefinition` | Menu, Player |
| CharacterController | `Player.gd` (`Node2D`) | monta veículo+piloto do `parts.json`, transição montado→ragdoll | VehicleController, RagdollBuilder |
| RagdollController | `RagdollBuilder` | cria corpos/juntas, arranca membro | PhysicsDamageSystem |
| VehicleController | `RigidBody2D` do chassi | tração, freio, inclinação, equilíbrio, pancada no eixo | Input Map |
| PhysicsDamageSystem | `Node` | Δv por passo → `pancada`/`fatal`/`arrancar` | Sangue, AudioManager, LevelManager |
| TrapSystem | cenas em `levels/traps/` (`AnimatableBody2D`/`Area2D`) | perigo, empurrar, matar | LevelManager |
| LevelManager | raiz da fase | spawn, meta, limites, morte, reinício | HUD, PlaytestController |
| CheckpointSystem | `Checkpoint` (`Area2D`) + `Game` | ponto de reinício que sobrevive ao reload | LevelManager |
| CameraController | `Camera2D` fora do veículo | seguir com suavização, olhar à frente | foco do Player |
| UIManager | `CanvasLayer` HUD + Menu | botões de toque, distância, morte/vitória | sinais do LevelManager |
| AudioManager | autoload | tocar som por evento com variação de pitch | sinais de dano/fase |
| PlaytestController | autoload | bot de teste, telemetria, relatório | LevelManager, Input |

Não crie classes só para preencher a tabela: um projeto pequeno pode juntar
VehicleController e CharacterController no mesmo `Player.gd` (como no projeto
real), desde que o código continue separado por função.

## 3. Fluxo de sinais

```
Input Map ─▶ VehicleController ─(pancada_forte)─▶ Player.soltar_ragdoll()
Player ─(cria)─▶ RagdollBuilder ─(corpos)─▶ PhysicsDamageSystem.vigiar()
PhysicsDamageSystem ─(pancada)─▶ Sangue.jorrar / AudioManager
PhysicsDamageSystem ─(fatal)─▶ LevelManager.matar("cabeca")
PhysicsDamageSystem ─(arrancar)─▶ RagdollBuilder.arrancar() ─▶ Sangue.esguichar
Meta/Area2D ─▶ LevelManager ─(venceu|morreu)─▶ HUD, PlaytestController
Checkpoint ─(ativado)─▶ LevelManager ─▶ Game.checkpoint_da_fase
```

## 4. Câmera

```gdscript
extends Camera2D
class_name CameraController
## Segue o foco sem herdar rotação, olhando para a frente do movimento.

@export var alvo: Node2D
@export var suavidade: float = 0.12
@export var olhar_frente: float = 260.0
@export var olhar_cima: float = 170.0

func _ready() -> void:
	make_current()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(alvo):
		return
	var frente := olhar_frente
	if alvo is RigidBody2D:
		frente *= clampf((alvo as RigidBody2D).linear_velocity.x / 600.0, -1.0, 1.0)
	var destino := alvo.global_position + Vector2(frente, -olhar_cima)
	global_position = global_position.lerp(destino, suavidade)
```

Não deixe a câmera como filha do veículo (gira junto e enjoa). Troque o alvo do
chassi para o tronco quando o piloto vira ragdoll.

## 5. Controles remapeáveis e toque

- Ações: `accelerate`, `brake`, `lean_fwd`, `lean_back`, `eject`, `reset`.
  Registre por código no autoload (`InputMap.add_action` +
  `InputMap.action_add_event`) para não depender do formato de `InputEvent` no
  `project.godot`.
- Remapear: salve os eventos em `user://controles.cfg` com `ConfigFile` e
  recarregue no `_ready`.
- Toque: `TouchScreenButton` com `action` = nome da ação (multitoque real).
  `Button` comum aceita um dedo só — acelerar e inclinar ao mesmo tempo falha.
- Projeto: `pointing/emulate_touch_from_mouse=true` para testar toque com mouse.

```gdscript
extends Node
class_name InputRemap
## Salva e carrega o mapeamento de teclas do jogador.

const ARQ := "user://controles.cfg"
const ACOES := ["accelerate", "brake", "lean_fwd", "lean_back", "eject", "reset"]

func salvar() -> void:
	var cfg := ConfigFile.new()
	for a in ACOES:
		var teclas: Array = []
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				teclas.append((ev as InputEventKey).physical_keycode)
		cfg.set_value("teclas", a, teclas)
	cfg.save(ARQ)

func carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQ) != OK:
		return
	for a in ACOES:
		if not cfg.has_section_key("teclas", a):
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				InputMap.action_erase_event(a, ev)
		for k in cfg.get_value("teclas", a):
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
```

## 6. Tela e exportação

- `display/window/stretch/mode="canvas_items"`, `aspect="expand"`, base 1280×720:
  preenche celular 20:9 sem faixas. UI ancorada nas bordas de
  `get_visible_rect()`.
- Retrato (celular em pé): aviso "gira o celular" num `CanvasLayer` do autoload
  quando `DisplayServer.window_get_size()` tiver `y > x`.
- Web: preset sem threads (`variant/thread_support=false`) para hospedagem
  estática. Tela cheia: injete no `html/head_include` um `requestFullscreen()` no
  primeiro `pointerdown` (+ `screen.orientation.lock('landscape')`) — o navegador
  só permite em gesto do usuário. No iPhone o Safari não oferece tela cheia para
  páginas.
- Fonte própria no tema do projeto (`gui/theme/custom_font`) — a padrão "parece
  genérica".

## 7. Como adicionar

**Personagem**: ver [character-system.md §7](character-system.md#7-adicionar-um-personagem-checklist).

**Veículo** (separado do personagem):
1. Cena `vehicles/<id>.tscn`: chassi `RigidBody2D` com `VehicleController`, rodas
   `RigidBody2D` + `PinJoint2D` (ou `WheelSuspension`), `Marker2D` "Assento".
2. Defina `forca`, `vmax`, `auto_equilibrio`, `inercia` (calculada).
3. Teste N1: spawn estável e 2,5 s de aceleração ([testing.md](testing.md#3-testes-de-física-e-regressão-n1)).
4. Adicione o id em `veiculos_compativeis` dos personagens que podem usá-lo.

**Fase**: ver [level-design.md §6](level-design.md#6-organização-para-crescer) —
cena na convenção, entrada na lista, validador, playtest.

## 8. Mapa do projeto real `jogo-godot` (estado conhecido)

O projeto existente neste repositório (jogo "Bicho Ehn") já tem: `Player.gd`
guiado por `parts.json` (3 personagens recortados da arte do usuário: segway,
cadeira, scooter), `Sangue.gd`, `FollowCamera.gd`, `Menu.gd` com seleção,
`Main.gd` com fase de teste e modos `autoteste`/`screenshot`, `tools/segmenta.py`.

Ainda **não** tem (preencha seguindo esta skill): `LevelManager` com `Meta` e
condição de vitória, checkpoints, armadilhas, várias fases, `PlaytestController`
e relatório. Antes de evoluí-lo, leia os arquivos atuais — não reescreva o que
funciona.
