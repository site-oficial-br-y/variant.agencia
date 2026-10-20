# Física 2D no Godot 4 — guia técnico

Referência de gravidade, corpos rígidos, forças/torque/impulso, colisões,
materiais, **juntas**, ragdoll e estabilidade numérica. Tudo conferido para
Godot 4.x (GDScript 2.0). Unidades: pixels, segundos, radianos; y cresce para
baixo.

---

## 1. Tipos de corpo

| Nó | Uso |
|---|---|
| `StaticBody2D` | Chão, paredes, rampas, obstáculos imóveis. |
| `RigidBody2D` | Simulado pela física: veículo, rodas, peças do ragdoll, caixas. |
| `CharacterBody2D` | Personagem controlado "na mão" (sem ser corpo rígido). Em jogo ragdoll quase não se usa; útil pra NPC/menu. |
| `Area2D` | Detecção (checkpoint, zona de morte, gatilho). Não resolve colisão. |

Formas de colisão: `CollisionShape2D` (com `CircleShape2D`, `RectangleShape2D`,
`CapsuleShape2D`, `SegmentShape2D`) ou `CollisionPolygon2D` (contorno arbitrário —
ideal para peça de corpo recortada).

> Godot 4: `RectangleShape2D.size` é a dimensão **cheia** (Godot 3 usava
> `extents`, que era a metade). `CircleShape2D.radius`.

---

## 2. Gravidade

- Projeto: `ProjectSettings → physics/2d/default_gravity` = `980`,
  `physics/2d/default_gravity_vector` = `(0, 1)`.
- Por corpo: `RigidBody2D.gravity_scale` (1.0 = normal; 0 = sem gravidade;
  >1 "mais pesado" na queda).
- Áreas podem sobrescrever gravidade local (`Area2D.gravity_space_override`,
  `gravity`, `gravity_direction`) — útil para água/vento.

```gdscript
@export var gravity_scale_jump: float = 0.7   # flutua mais no auge do pulo
func _physics_process(_d):
    gravity_scale = gravity_scale_jump if linear_velocity.y < 0 else 1.0
```

---

## 3. Mover corpo rígido: força, torque, impulso

Nunca escreva `global_position` de um `RigidBody2D` dinâmico. Use:

| Método | Efeito | Quando |
|---|---|---|
| `apply_central_force(f)` | Força no centro de massa (sem girar) | empurrão contínuo |
| `apply_force(f, pos)` | Força num ponto `pos` **relativo ao CM** (gera torque) | tração num ponto baixo, vento |
| `apply_torque(t)` | Torque puro (gira) | inclinar, equilibrar |
| `apply_central_impulse(j)` | Mudança instantânea de velocidade linear | pulo, explosão |
| `apply_impulse(j, pos)` | Impulso num ponto (gira + translada) | chute, pancada |
| `apply_torque_impulse(t)` | Chute de rotação instantâneo | girar de repente |

- **Força** é contínua (por segundo); aplique **todo frame** de física enquanto
  dura. **Impulso** é único (aplique uma vez).
- `apply_force`/`apply_impulse`: `pos` é **relativo ao centro de massa**, em
  coordenadas globais de direção (não local do nó). Para ponto local, rotacione:
  `transform.basis_xform(local_offset)` ou `local_offset.rotated(rotation)`.

```gdscript
# tração num ponto baixo do chassi (evita empinar)
apply_force(Vector2(dir * power, 0.0), Vector2(0, 24).rotated(rotation))
```

Limite a velocidade checando antes de aplicar:
```gdscript
if linear_velocity.length() < max_speed:
    apply_central_force(Vector2(dir * power, 0))
```

---

## 4. `_integrate_forces` e `PhysicsDirectBodyState2D`

Para ler/escrever velocidade e inspecionar contatos no passo da física:

```gdscript
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    # ler
    var v := state.linear_velocity
    var w := state.angular_velocity
    var dt := state.step
    # escrever diretamente (ex.: travar velocidade máxima)
    if v.length() > max_speed:
        state.linear_velocity = v.normalized() * max_speed
    # aplicar esforço a partir do state (equivalente aos métodos do nó)
    state.apply_central_force(Vector2(0, -100))
    # contatos (exige contact_monitor = true e max_contacts_reported > 0)
    for i in state.get_contact_count():
        var normal := state.get_contact_local_normal(i)
        var impulse := state.get_contact_impulse(i)   # Vector2 — magnitude do baque
        var other := state.get_contact_collider_object(i)
```

> `state.apply_*` toma posições **relativas ao CM** (mesma regra do item 3).
> `state.transform` é a transform do corpo neste passo.

### Detectar impacto forte (dano / sangue)
`contact_monitor = true` e `max_contacts_reported ≥ 4`. A magnitude do baque é
`state.get_contact_impulse(i).length()`:

```gdscript
@export var dano_limiar: float = 450.0
func _integrate_forces(state):
    for i in state.get_contact_count():
        if state.get_contact_impulse(i).length() > dano_limiar:
            emit_signal("bateu_forte", state.get_contact_local_position(i),
                        state.get_contact_impulse(i).length())
```

Alternativa simples (sem contatos): guarde a velocidade do frame anterior; se cair
bruscamente num frame com colisão, foi impacto.

---

## 5. Colisões: camadas e máscaras

- `collision_layer`: em quais camadas **este** corpo está.
- `collision_mask`: quais camadas este corpo **enxerga/colide**.
- A colide com B **se** (`A.mask` contém alguma layer de `B.layer`) **e**
  vice-versa. Use nomes nas camadas (Project Settings → Layer Names → 2D Physics).

```gdscript
# Partes do ragdoll: layer "ragdoll" + "mundo-colide"; NÃO enxergam "ragdoll".
set_collision_layer_value(LAYER_RAGDOLL, true)
set_collision_mask_value(LAYER_WORLD, true)
set_collision_mask_value(LAYER_RAGDOLL, false)   # não colidem entre si
```

Para um **par** específico ligado por junta, prefira `PinJoint2D.disable_collision
= true` (desliga colisão só entre os dois). Camadas resolvem os não-adjacentes.

Consultar colisões de um `RigidBody2D`: `contact_monitor = true`,
`max_contacts_reported > 0`, depois `get_colliding_bodies()` ou os sinais
`body_entered(body)` / `body_exited(body)`.

`Area2D`: sinais `body_entered`, `area_entered` — use para checkpoint e zona de morte.

---

## 6. Materiais físicos (`PhysicsMaterial`)

`RigidBody2D.physics_material_override` (ou material do `StaticBody2D`):
- `friction` (0..1): atrito. Roda e chão com atrito alto = tração.
- `bounce` (0..1): restituição (quica).
- `rough`, `absorbent`: como friction/bounce combinam entre dois materiais.

```gdscript
var m := PhysicsMaterial.new()
m.friction = 1.0
m.bounce = 0.0
$Wheel.physics_material_override = m
```

---

## 7. Juntas 2D (o núcleo do ragdoll e do veículo)

**Só existem três juntas 2D no Godot 4** (não há `HingeJoint2D` em 2D):

### `PinJoint2D` — articulação (pino)
Prende dois corpos num ponto; eles giram em torno dele. É a junta do ragdoll e do
eixo da roda.
- `node_a`, `node_b`: `NodePath` dos dois corpos (um pode ser vazio = preso ao mundo).
- Posição do pino = `global_position` do próprio `PinJoint2D`.
- `disable_collision` (bool): desliga colisão entre A e B.
- `softness`: 0 = rígido; maior = mais frouxo.
- **Godot 4 adicionou** (use para pose e motor):
  - `angular_limit_enabled`, `angular_limit_lower`, `angular_limit_upper` (rad):
    limita o ângulo relativo — dá a rigidez de pose do membro.
  - `motor_enabled`, `motor_target_velocity`: motoriza a junta (músculo ativo /
    roda motorizada).

```gdscript
var j := PinJoint2D.new()
add_child(j)
j.global_position = pivo_ombro_global
j.node_a = torso.get_path()
j.node_b = braco.get_path()
j.disable_collision = true
j.angular_limit_enabled = true
j.angular_limit_lower = deg_to_rad(-30)
j.angular_limit_upper = deg_to_rad(80)
```

### `DampedSpringJoint2D` — mola amortecida
Mantém um comprimento com mola: suspensão de roda, "músculo" elástico.
- `length`, `rest_length`, `stiffness`, `damping`.

### `GrooveJoint2D` — trilho
Permite deslizar ao longo de um segmento: suspensão vertical, elevador.

> Quebrar uma junta (desmembrar / soltar): `joint.queue_free()` ou
> `joint.node_b = NodePath("")`.

---

## 8. Ragdoll — montagem e transição

Estrutura: N `RigidBody2D` (uma por parte) + `PinJoint2D` nas articulações.

### Pose "montado" (preso ao veículo, parece a arte inteira)
Duas opções:
- **Freeze kinematic**: cada peça com `freeze = true`,
  `freeze_mode = FREEZE_MODE_KINEMATIC`, posicionada por script seguindo o veículo.
  Simples e estável; vira dinâmica ao `freeze = false`.
- **Motor/limites**: peças dinâmicas, juntas com `motor_enabled` puxando ao
  ângulo-alvo (músculos). Mais "vivo", mais difícil de tunar.

### Soltar ragdoll
```gdscript
func soltar(herda_vel: Vector2) -> void:
    for p in partes:
        p.freeze = false
        p.linear_velocity = herda_vel
    for d in juntas_def:                 # {a, b, pivo_global, lim}
        var j := PinJoint2D.new(); add_child(j)
        j.global_position = d.pivo_global
        j.node_a = d.a.get_path(); j.node_b = d.b.get_path()
        j.disable_collision = true
        j.angular_limit_enabled = true
        j.angular_limit_lower = -deg_to_rad(d.lim)
        j.angular_limit_upper =  deg_to_rad(d.lim)
        juntas.append(j)
    partes[IDX_TRONCO].apply_torque_impulse(2000.0)   # empurrãozinho
```

### Massas e estabilidade
- Dê massas coerentes: tronco > coxa > cabeça > braço. `RigidBody2D.mass`.
- Juntas com limite estreito = corpo "duro"; limite largo = mole. Comece
  moderado (±30–60°) e ajuste.
- Se o ragdoll "explode" (velocidades enormes, tremor): baixe rigidez (aumente
  `softness`), reduza diferenças extremas de massa, confira pivôs sobrepostos, e
  limite a velocidade em `_integrate_forces`.

---

## 9. Tunneling e CCD (atravessar o chão)

Corpos rápidos (queda de rampa, projétil) podem pular o chão num passo.
- Ative **Continuous Collision Detection** no corpo rápido:
  `continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY` (ou `CCD_MODE_CAST_SHAPE`,
  mais caro e preciso).
- Aumente o tick físico: `ProjectSettings → physics/common/physics_ticks_per_second`
  (ex.: 120) para colisões mais finas.
- Dê **espessura** ao chão (não use `SegmentShape2D` fino para superfícies de alta
  velocidade; prefira retângulos grossos).

---

## 10. Determinismo e passo fixo

- Física roda em passo fixo (`physics_ticks_per_second`, padrão 60). Lógica de
  física em `_physics_process(delta)` (delta constante) — nunca em `_process`.
- Para interpolação visual suave com física a 60 Hz, ligue
  `physics_interpolation` (ProjectSettings) ou interpole o sprite manualmente.
- `Engine.time_scale` afeta tudo (útil pra câmera lenta e debug).

---

## 11. Erros de API que quebram (Godot 3 → 4)

| Errado (Godot 3) | Certo (Godot 4) |
|---|---|
| `extends KinematicBody2D` + `move_and_slide(vel)` | `extends CharacterBody2D`; set `velocity`; `move_and_slide()` |
| `scene.instance()` | `scene.instantiate()` |
| `RectangleShape2D.extents = Vector2(w/2,h/2)` | `.size = Vector2(w, h)` |
| `HingeJoint2D` | não existe em 2D — use `PinJoint2D` (com limite angular) |
| `deg2rad()/rad2deg()` | `deg_to_rad()/rad_to_deg()` |
| `camera.current = true` | `camera.enabled = true` / `camera.make_current()` |
| `yield(get_tree().create_timer(1),"timeout")` | `await get_tree().create_timer(1.0).timeout` |
| `connect("sig", self, "_m")` | `sig.connect(_m)` (Callable) |
