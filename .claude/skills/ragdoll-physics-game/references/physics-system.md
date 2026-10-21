# Sistema de física (Godot 4.3+)

Unidades: pixels, segundos, radianos; y cresce para baixo. Gravidade padrão 2D:
`980 px/s²`. Todos os scripts completos abaixo (os que começam com `extends`)
foram escritos para passar em `godot --check-only`.

Volte para o [SKILL.md](../SKILL.md) · veja também
[character-system.md](character-system.md) e [testing.md](testing.md).

---

## 1. Escolha do tipo de corpo

| Nó | Para quê | Observação |
|---|---|---|
| `StaticBody2D` | chão, paredes, rampas | nunca se move |
| `AnimatableBody2D` | plataforma móvel, serra girando, pistão | movido por código/animação, empurra corpos corretamente; `sync_to_physics = true` |
| `RigidBody2D` | veículo, rodas, peças do ragdoll, caixas, destroços | só força/impulso/torque |
| `CharacterBody2D` | personagem a pé "de controle" (não ragdoll) | `velocity` + `move_and_slide()` sem argumentos |
| `Area2D` | espinho, zona de morte, checkpoint, meta, gatilho | não resolve colisão, só detecta |

Formas: `CircleShape2D` (roda, cabeça), `CapsuleShape2D` (membros), `RectangleShape2D`
(`size` é o tamanho CHEIO), `CollisionPolygon2D` (chassi, terreno).

## 2. Forças, impulso, torque

| Método | Efeito | Uso |
|---|---|---|
| `apply_central_force(f)` | força contínua no centro de massa | acelerar sem girar |
| `apply_force(f, p)` | força em `p` relativo ao CM (gera torque) | tração em ponto baixo |
| `apply_torque(t)` | giro contínuo | inclinar, equilibrar |
| `apply_central_impulse(j)` | Δv instantâneo | pulo, explosão, arremesso |
| `apply_impulse(j, p)` | Δv + giro | pancada num ponto |
| `apply_torque_impulse(t)` | Δω instantâneo | chute de rotação |

Força se aplica **todo passo** enquanto dura; impulso **uma vez**. `p` é relativo
ao centro de massa em orientação global: para um ponto local use
`Vector2(0, 30).rotated(rotation)`.

Atrito/elasticidade: `PhysicsMaterial` (`friction` 0..1, `bounce` 0..1, `rough`,
`absorbent`) em `physics_material_override`. Roda e chão com `friction ≈ 1`.

<a id="inercia"></a>
### Inércia real

`RigidBody2D.inertia` retorna **0** enquanto estiver em modo automático; usar esse
valor para escalar torque zera o controle (bug real: o veículo "tombava sozinho").
Calcule pela forma:

- retângulo `w×h`: `I = m·(w² + h²) / 12`
- círculo raio `r`: `I = m·r² / 2`
- polígono: aproxime pela caixa envolvente ou some triângulos.

Ou leia `1.0 / state.inverse_inertia` dentro de `_integrate_forces`.

## 3. Colisões e camadas

Nomeie as camadas em *Project Settings → Layer Names → 2D Physics*:

| bit | nome | quem está | colide com (mask) |
|---|---|---|---|
| 1 | `mundo` | chão, paredes, armadilhas sólidas | — (estáticos não precisam de mask) |
| 2 | `veiculo` | chassi e rodas | `mundo` |
| 3 | `ragdoll` | peças do piloto solto | `mundo` (+ `veiculo` se quiser que bata no carro) |
| 4 | `objeto` | caixas, destroços | `mundo`, `veiculo`, `ragdoll`, `objeto` |
| 5 | `sensor` | `Area2D` de armadilhas/meta | (as Areas usam mask para detectar 2/3) |

- Peças do mesmo ragdoll **não** colidem entre si: `PinJoint2D.disable_collision =
  true` para pares ligados e tire a camada `ragdoll` da própria mask para os não
  adjacentes. Colisão entre partes adjacentes é a maior fonte de tremedeira.
- Detectar contato em `RigidBody2D`: `contact_monitor = true` +
  `max_contacts_reported ≥ 4`, sinais `body_entered/body_exited`.

## 4. Juntas

Em 2D existem **só três**: `PinJoint2D`, `DampedSpringJoint2D`, `GrooveJoint2D`
(`HingeJoint2D` é 3D).

- `PinJoint2D` — articulação. A posição do pino é o `global_position` do próprio
  joint; `node_a`/`node_b` são `NodePath`. Desde o 4.0: `angular_limit_enabled`,
  `angular_limit_lower/upper` (rad), `motor_enabled`, `motor_target_velocity`.
  `softness` 0 = rígida.
- `DampedSpringJoint2D` — mola: `length`, `rest_length`, `stiffness`, `damping`.
  Suspensão e "músculo" elástico.
- `GrooveJoint2D` — trilho: `length`, `initial_offset`. Guia a roda na vertical da
  suspensão.

**Crie a junta depois de posicionar os dois corpos** e defina `global_position`
antes de `node_a/node_b` (o joint ancora no momento em que os paths são
atribuídos com os corpos já na árvore).

## 5. Ragdoll

Segmentos: cabeça, tronco, braço(s), coxa/canela ou perna, (pé). Cada segmento é um
`RigidBody2D` com sprite da peça e forma de colisão **no formato do osso**
(cápsula entre as articulações), não a caixa da imagem inteira — caixa grande faz o
braço "boiar" no chão.

Massas coerentes (proporção, não absolutas): tronco 2.0, coxa 1.0, perna inteira
1.4, cabeça 0.8, canela 0.8, braço 0.5. Diferença extrema de massa entre peças
ligadas causa instabilidade.

Limites angulares de partida (ajuste jogando): pescoço ±40°, ombro ±75–80°,
quadril ±55–70°, joelho ±70–75°.

### Transição montado → ragdoll (sem teleporte)

1. Montado: os sprites do piloto são filhos do chassi (a arte inteira, rígida).
2. Ao bater/pular: para cada segmento crie o `RigidBody2D`, coloque-o na
   `global_transform` atual do sprite, **reparente o sprite mantendo a transform
   global**, herde a velocidade do chassi, crie as juntas nos pivôs.
3. Se isso for disparado por sinal de física, adie com `call_deferred`.

```gdscript
extends Node2D
class_name RagdollBuilder
## Converte sprites montados num ragdoll físico. `defs` vem de dados:
## corpos = {nome: {massa, forma:["caps",a,b,r] | ["circ",c,r]}},
## juntas = [{a, b, p, lim}], pontos em coordenadas da ARTE.

signal soltou

@export var camada_ragdoll: int = 0b100
@export var mascara_ragdoll: int = 0b001

var corpos: Dictionary = {}
var juntas: Dictionary = {}

## sprites: {nome_corpo: Sprite2D montado}; arte_para_mundo: Callable(Vector2)->Vector2
func soltar(sprites: Dictionary, defs: Dictionary, arte_para_mundo: Callable,
		centro_peca: Callable, rot: float, vel: Vector2) -> void:
	for nome in defs["corpos"]:
		var d: Dictionary = defs["corpos"][nome]
		var base: Vector2 = centro_peca.call(nome)
		var rb := RigidBody2D.new()
		rb.mass = d["massa"]
		rb.collision_layer = camada_ragdoll
		rb.collision_mask = mascara_ragdoll
		rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		rb.angular_damp = 0.4
		rb.add_child(_forma(d["forma"], base))
		add_child(rb)
		rb.global_transform = Transform2D(rot, arte_para_mundo.call(base))
		var s: Sprite2D = sprites[nome]
		s.reparent(rb)                       # mantém a transform global
		rb.linear_velocity = vel
		corpos[nome] = rb
	for j in defs["juntas"]:
		var pj := PinJoint2D.new()
		add_child(pj)
		pj.global_position = arte_para_mundo.call(Vector2(j["p"][0], j["p"][1]))
		pj.node_a = corpos[j["a"]].get_path()
		pj.node_b = corpos[j["b"]].get_path()
		pj.disable_collision = true
		pj.angular_limit_enabled = true
		pj.angular_limit_lower = -deg_to_rad(j["lim"])
		pj.angular_limit_upper = deg_to_rad(j["lim"])
		juntas[j["b"]] = pj
	soltou.emit()

func _forma(f: Array, base: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	if f[0] == "circ":
		var c := CircleShape2D.new()
		c.radius = f[2]
		cs.shape = c
		cs.position = Vector2(f[1][0], f[1][1]) - base
	else:
		var a := Vector2(f[1][0], f[1][1])
		var b := Vector2(f[2][0], f[2][1])
		var k := CapsuleShape2D.new()
		k.radius = f[3]
		k.height = a.distance_to(b) + 2.0 * f[3]
		cs.shape = k
		cs.position = (a + b) / 2.0 - base
		cs.rotation = (b - a).angle() - PI / 2.0
	return cs

## arranca um membro: tira a junta e devolve o ponto (para esguicho/partículas)
func arrancar(membro: String) -> Vector2:
	if not juntas.has(membro):
		return Vector2.INF
	var j: PinJoint2D = juntas[membro]
	var p := j.global_position
	juntas.erase(membro)
	j.queue_free()
	return p
```

## 6. Dano por impacto

Métrica robusta: **Δv por passo de física** de cada segmento,
`(v_anterior - v_atual).length()`. Queda livre muda ~16 px/s por passo (980/60);
batida real muda centenas/milhares. Faixas que funcionaram jogando (piloto de
~1000 px de altura, gravidade 980):

| Δv (px/s) | efeito |
|---|---|
| < 750 | nada (pulo, tombo leve) |
| ≥ 750 | sangue proporcional (`n = clamp(dv/70, 4, 40)`) |
| ≥ 2160 na cabeça | morte (`0.8 ×` limiar de arrancar) |
| ≥ 2700 | arranca membro (cabeça: `×1.4` = 3780) |
| ≥ 2400 no eixo da roda, montado | arremessa o piloto (pouso/colisão forte) |

Escale os limiares com o tamanho do personagem. Alternativa mais "física":
`state.get_contact_impulse(i).length()` em `_integrate_forces` (exige
`contact_monitor`).

```gdscript
extends Node
class_name PhysicsDamageSystem
## Observa corpos e emite pancadas pela variação de velocidade por passo.

signal pancada(corpo: RigidBody2D, dv: float)
signal fatal(corpo: RigidBody2D, dv: float)
signal arrancar(corpo: RigidBody2D, dv: float)

@export var limiar_sangue: float = 750.0
@export var limiar_arranca: float = 2700.0
@export var fator_cabeca: float = 1.4

var _vigiados: Dictionary = {}     # RigidBody2D -> {ant: Vector2, cabeca: bool}

func vigiar(rb: RigidBody2D, eh_cabeca: bool = false) -> void:
	_vigiados[rb] = {"ant": rb.linear_velocity, "cabeca": eh_cabeca}

func _physics_process(_delta: float) -> void:
	for rb in _vigiados.keys():
		if not is_instance_valid(rb):
			_vigiados.erase(rb)
			continue
		var info: Dictionary = _vigiados[rb]
		var dv: float = (info["ant"] - rb.linear_velocity).length()
		info["ant"] = rb.linear_velocity
		if dv < limiar_sangue:
			continue
		pancada.emit(rb, dv)
		var lim := limiar_arranca * (fator_cabeca if info["cabeca"] else 1.0)
		if info["cabeca"] and dv > limiar_arranca * 0.8:
			fatal.emit(rb, dv)
		if dv > lim:
			arrancar.emit(rb, dv)
```

## 7. Veículos

Modelo: chassi `RigidBody2D` + rodas `RigidBody2D` (`CircleShape2D`, atrito alto,
CCD) presas por eixo `PinJoint2D` (roda gira livre). Suspensão opcional:
`GrooveJoint2D` (trilho vertical) + `DampedSpringJoint2D` (mola) no lugar do pino.

Regras aprendidas:

- **Spawn**: a roda encostando no chão, o resto acima. Corpo nascendo dentro do
  terreno é ejetado violentamente (parece "afundar" ou "voar").
- **Tração**: força no chassi. Em veículo de 2 rodas aplique pelo centro de massa
  (`apply_central_force`) — força num ponto baixo faz empinar sozinho ao acelerar;
  empinar fica para o botão de inclinar. No monociclo/segway, força num ponto
  baixo + equilíbrio ativo.
- **Monociclo/segway**: pêndulo invertido. O chassi deve ser um corpo comprido de
  verdade (do ombro ao eixo) com a roda presa **na base**; uma junta longa fazendo
  papel de haste vira alavanca e tomba. Equilíbrio:
  `apply_torque(I * (-rotation * k - angular_velocity * c))`, `k≈55`, `c≈14`.
- **Velocidade máxima**: só aplique força se `linear_velocity.length() < vmax`.
- **Colisão do piloto montado**: um `Area2D` com as formas do corpo, filho do
  chassi; `body_entered` com o mundo → soltar o ragdoll (`call_deferred`).
- **Rodas e sprite**: o sprite da roda é filho da roda; ele gira pela física.

```gdscript
extends RigidBody2D
class_name VehicleController
## Chassi genérico: tração, freio/ré, inclinação, equilíbrio opcional e
## detecção de pancada no eixo motriz.

signal pancada_forte(dv: float)

@export var forca: float = 120000.0
@export var vmax: float = 800.0
@export var auto_equilibrio: bool = false
@export var rigidez_equilibrio: float = 55.0
@export var amortecimento_equilibrio: float = 14.0
@export var torque_inclinar: float = 5.0
@export var limiar_pancada: float = 2400.0
@export var roda_motriz: RigidBody2D
@export var inercia: float = 1.0          # calcule pela forma (ver "Inércia real")

var _v_roda := Vector2.ZERO

func _physics_process(_delta: float) -> void:
	var dir := Input.get_axis("brake", "accelerate")
	if dir != 0.0 and linear_velocity.length() < vmax:
		if auto_equilibrio and roda_motriz:
			var baixo := (roda_motriz.global_position - global_position).length() * 0.8
			apply_force(Vector2(dir * forca, 0.0), Vector2(0, baixo).rotated(rotation))
		else:
			apply_central_force(Vector2(dir * forca, 0.0))
	var lean := Input.get_axis("lean_back", "lean_fwd")
	if lean != 0.0:
		apply_torque(lean * inercia * torque_inclinar)
	elif auto_equilibrio:
		apply_torque(inercia * (-rotation * rigidez_equilibrio - angular_velocity * amortecimento_equilibrio))
	if roda_motriz:
		var dv := (_v_roda - roda_motriz.linear_velocity).length()
		_v_roda = roda_motriz.linear_velocity
		if dv > limiar_pancada:
			pancada_forte.emit(dv)
```

Suspensão por roda (crie depois de chassi e roda estarem na árvore):

```gdscript
extends Node2D
class_name WheelSuspension
## Trilho vertical + mola entre chassi e roda.

@export var curso: float = 60.0
@export var rigidez: float = 40.0
@export var amortecimento: float = 1.2

func montar(chassi: RigidBody2D, roda: RigidBody2D) -> void:
	var trilho := GrooveJoint2D.new()
	add_child(trilho)
	trilho.global_position = roda.global_position - Vector2(0, curso)
	trilho.length = curso * 2.0
	trilho.initial_offset = curso
	trilho.node_a = chassi.get_path()
	trilho.node_b = roda.get_path()
	trilho.disable_collision = true
	var mola := DampedSpringJoint2D.new()
	add_child(mola)
	mola.global_position = roda.global_position - Vector2(0, curso)
	mola.length = curso                   # âncora B = joint + (0, length) = centro da roda
	mola.rest_length = curso
	mola.stiffness = rigidez
	mola.damping = amortecimento
	mola.node_a = chassi.get_path()
	mola.node_b = roda.get_path()
	mola.disable_collision = true
```

## 8. Armadilhas e objetos

```gdscript
extends AnimatableBody2D
class_name SawTrap
## Serra girando (corpo cinemático que empurra) + Area2D letal na borda.

signal matou(corpo: Node2D)

@export var velocidade_angular: float = 9.0     # rad/s
@export var raio: float = 90.0

func _ready() -> void:
	sync_to_physics = false                       # rotação própria por código
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 0b110                   # veículo + ragdoll
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = raio + 4.0
	cs.shape = c
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b: Node2D) -> void: matou.emit(b))

func _physics_process(delta: float) -> void:
	rotation += velocidade_angular * delta
```

```gdscript
extends AnimatableBody2D
class_name MovingPlatform
## Plataforma que vai e volta entre dois pontos; empurra corpos corretamente.

@export var deslocamento: Vector2 = Vector2(400, 0)
@export var periodo: float = 3.0

var _origem := Vector2.ZERO
var _t := 0.0

func _ready() -> void:
	sync_to_physics = true
	_origem = position

func _physics_process(delta: float) -> void:
	_t += delta
	var f := 0.5 - 0.5 * cos(TAU * _t / periodo)
	position = _origem + deslocamento * f
```

```gdscript
extends RigidBody2D
class_name Destructible
## Caixa que quebra em pedaços quando leva pancada acima do limiar.

@export var limiar_quebra: float = 900.0
@export var pedacos: int = 4
@export var tamanho: Vector2 = Vector2(80, 80)

var _ant := Vector2.ZERO
var _quebrou := false

func _physics_process(_delta: float) -> void:
	var dv := (_ant - linear_velocity).length()
	_ant = linear_velocity
	if dv > limiar_quebra and not _quebrou:
		_quebrou = true
		_quebrar.call_deferred()

func _quebrar() -> void:
	var lado := tamanho / 2.0
	for i in pedacos:
		var p := RigidBody2D.new()
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = lado
		cs.shape = r
		p.add_child(cs)
		p.collision_layer = collision_layer
		p.collision_mask = collision_mask
		get_parent().add_child(p)
		var off := Vector2((i % 2) - 0.5, (i / 2) - 0.5) * lado
		p.global_position = global_position + off.rotated(rotation)
		p.linear_velocity = linear_velocity + off * 4.0
	queue_free()
```

Espinhos/zona de morte: `Area2D` com `collision_mask` de veículo e ragdoll,
`body_entered` → `PhysicsDamageSystem`/`LevelManager`. Projéteis: `RigidBody2D`
pequeno com `continuous_cd = CCD_MODE_CAST_RAY` e `apply_central_impulse` no
disparo.

## 9. Sangue e partículas (cartunesco, opcional)

Gotas balísticas próprias (barato e com física de verdade): para cada gota
`v.y += g·dt; v *= (1 - arrasto·dt)`, raycast de `p` até `p + v·dt` com
`PhysicsRayQueryParameters2D.create(de, para, mascara_mundo)` em
`get_world_2d().direct_space_state.intersect_ray(q)`; ao bater vira mancha
achatada no ângulo da normal. Limite (≈450 gotas, ≈700 manchas). Esguicho pulsante
preso ao toco: emissor com `sin(t·2π·2.2)`. Para fumaça/faísca use
`CPUParticles2D` (funciona no renderizador Compatibility/web).

Ofereça **opção de desligar sangue** (configuração) — o jogo pode precisar de
versão sem gore.

## 10. Estabilidade numérica — checklist

- [ ] Nada nasce sobreposto ao terreno ou a outro corpo.
- [ ] Massas entre peças ligadas na proporção de no máximo ~4:1.
- [ ] Juntas com limite angular; `disable_collision` entre os pares ligados.
- [ ] CCD (`CCD_MODE_CAST_RAY`) em rodas, peças do ragdoll e projéteis.
- [ ] Chão grosso (retângulo/polígono), não segmento fino, onde há alta velocidade.
- [ ] `physics_ticks_per_second` 60 (subir para 120 se ainda houver túnel).
- [ ] Velocidade limitada (`vmax`) e torque de controle escalado pela inércia **real**.
- [ ] Criar/remover corpos fora de callbacks de física (`call_deferred`).
- [ ] Se "explodir": aumente `softness`, reduza diferença de massa, revise pivôs
      sobrepostos, confira se partes não-adjacentes colidem.
