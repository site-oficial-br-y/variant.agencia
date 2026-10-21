extends Node2D
class_name Player
## Veículo + piloto montados a partir de res://assets/<personagem>/parts.json.
## Montado: a arte inteira presa ao chassi. Bateu / capotou / pulou fora: o piloto
## vira ragdoll feito das PRÓPRIAS peças recortadas. Pancada -> sangue; pancada
## muito forte -> membro arrancado esguichando.

signal morreu

@export var personagem: String = "segway"
@export var chao_y: float = 1000.0
@export var spawn_x: float = 600.0
@export var balance_stiffness: float = 55.0
@export var balance_damping: float = 14.0
@export var limiar_sangue: float = 750.0       # Δv (px/s) num passo que conta como pancada
@export var limiar_arranca: float = 2700.0     # Δv que arranca o membro
@export var limiar_queda_montado: float = 2400.0

var D: Dictionary = {}
var origem := Vector2.ZERO         # ponto da arte que é a origem do corpo do chassi
var desloc := Vector2.ZERO         # arte -> mundo no spawn
var chassi: RigidBody2D
var inercia_chassi := 1.0
var rodas: Array = []
var roda_motriz: RigidBody2D
var boneco: Node2D
var sprites: Dictionary = {}       # peça -> Sprite2D
var corpos: Dictionary = {}        # corpo do piloto -> RigidBody2D
var juntas: Dictionary = {}        # corpo filho -> PinJoint2D
var v_ant: Dictionary = {}
var v_roda_ant := Vector2.ZERO
var montado := true
var morto := false
var sangue: Sangue
var _mat: PhysicsMaterial

func _ready() -> void:
	var f := FileAccess.open("res://assets/%s/parts.json" % personagem, FileAccess.READ)
	D = JSON.parse_string(f.get_as_text())
	_mat = PhysicsMaterial.new()
	_mat.friction = 1.0
	_mat.bounce = 0.05
	_montar()

# ---------- helpers ----------
func v2(a: Array) -> Vector2:
	return Vector2(a[0], a[1])

func centro_peca(k: String) -> Vector2:
	var p: Dictionary = D["pecas"][k]
	return Vector2(p["x"] + p["w"] / 2.0, p["y"] + p["h"] / 2.0)

func _sprite(k: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/%s/%s.png" % [personagem, k])
	s.z_index = D["ordem"].find(k)
	return s

func _pecas_do(corpo: String) -> Array:
	var r: Array = []
	for k in D["ordem"]:
		if D["corpo_de"].get(k, "") == corpo:
			r.append(k)
	return r

func arte_para_mundo(p: Vector2) -> Vector2:
	return chassi.global_transform * (p - origem)

## forma de colisão de um corpo, posicionada relativa ao ponto `c` da arte
func _forma_cs(corpo: String, c: Vector2) -> CollisionShape2D:
	var fm: Array = D["corpos"][corpo]["forma"]
	var cs := CollisionShape2D.new()
	if fm[0] == "circ":
		var sh := CircleShape2D.new()
		sh.radius = fm[2]
		cs.shape = sh
		cs.position = v2(fm[1]) - c
	else:
		var a := v2(fm[1])
		var b := v2(fm[2])
		var sh := CapsuleShape2D.new()
		sh.radius = fm[3]
		sh.height = a.distance_to(b) + 2.0 * fm[3]
		cs.shape = sh
		cs.position = (a + b) / 2.0 - c
		cs.rotation = (b - a).angle() - PI / 2.0
	return cs

# ---------- montagem ----------
func _montar() -> void:
	var ch: Dictionary = D["chassi"]
	var fundo := 0.0
	for r in D["rodas"]:
		fundo = maxf(fundo, r["c"][1] + r["r"])

	chassi = RigidBody2D.new()
	chassi.mass = ch["massa"]
	if ch.has("mastro"):
		# segway: mastro rígido do ombro ao eixo, sem colisão (só a roda toca o chão)
		var m: Dictionary = ch["mastro"]
		origem = Vector2(m["x"], (m["y0"] + m["y1"]) / 2.0)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(m["w"], m["y1"] - m["y0"])
		cs.shape = rect
		chassi.add_child(cs)
		chassi.collision_layer = 0
		chassi.collision_mask = 0
		inercia_chassi = chassi.mass * (rect.size.x * rect.size.x + rect.size.y * rect.size.y) / 12.0
	else:
		var pts := PackedVector2Array()
		for p in ch["poly"]:
			pts.append(v2(p))
		origem = _centroide(pts)
		var poly := CollisionPolygon2D.new()
		var rel := PackedVector2Array()
		for p in pts:
			rel.append(p - origem)
		poly.polygon = rel
		chassi.add_child(poly)
		chassi.collision_layer = 0b010
		chassi.collision_mask = 0b1001          # mundo + objetos
		chassi.physics_material_override = _mat
		var bb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			bb = bb.expand(p)
		inercia_chassi = chassi.mass * (bb.size.x * bb.size.x + bb.size.y * bb.size.y) / 12.0
	desloc = Vector2(spawn_x - origem.x, chao_y - fundo)
	chassi.position = origem + desloc
	chassi.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	add_child(chassi)
	chassi.add_to_group("veiculo")

	for r in D["rodas"]:
		var c := v2(r["c"])
		var rb := RigidBody2D.new()
		rb.position = c + desloc
		rb.mass = r["massa"]
		rb.physics_material_override = _mat
		rb.collision_layer = 0b010
		rb.collision_mask = 0b1001              # mundo + objetos
		rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = r["r"]
		cs.shape = circ
		rb.add_child(cs)
		for k in _pecas_do(r["corpo"]):
			var s := _sprite(k)
			s.position = centro_peca(k) - c
			rb.add_child(s)
		add_child(rb)
		rb.add_to_group("veiculo")
		var eixo := PinJoint2D.new()
		add_child(eixo)
		eixo.global_position = c + desloc
		eixo.node_a = rb.get_path()
		eixo.node_b = chassi.get_path()
		eixo.disable_collision = true
		rodas.append(rb)
		if r["motriz"]:
			roda_motriz = rb

	for k in _pecas_do("chassi"):
		var s := _sprite(k)
		s.position = centro_peca(k) - origem
		chassi.add_child(s)

	boneco = Node2D.new()
	chassi.add_child(boneco)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 0b10001           # mundo + perigo pesado (bola de demolição)
	for corpo in D["piloto"]:
		for k in _pecas_do(corpo):
			var s := _sprite(k)
			s.position = centro_peca(k) - origem
			boneco.add_child(s)
			sprites[k] = s
		sensor.add_child(_forma_cs(corpo, origem))
	chassi.add_child(sensor)
	sensor.body_entered.connect(_on_corpo_bateu)
	montado = true

func _centroide(pts: PackedVector2Array) -> Vector2:
	var area := 0.0
	var c := Vector2.ZERO
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var cr := a.cross(b)
		area += cr
		c += (a + b) * cr
	return c / (3.0 * area)

func _on_corpo_bateu(body: Node) -> void:
	# bola de demolição: esbarrão lento só empurra; pancada rápida derruba
	if body.is_in_group("pendulo"):
		var rel := ((body.get_meta("vel", Vector2.ZERO) as Vector2) - chassi.linear_velocity).length()
		if rel < 300.0:
			return
	if montado:   # dentro do callback de física não pode criar corpos: adia pro fim do passo
		soltar_ragdoll.call_deferred(_vel(), false)

# ---------- controle ----------
func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("eject"):
		soltar_ragdoll(_vel(), true)
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
	if montado:
		_dirigir()
	else:
		_checar_pancadas()

func _vel() -> Vector2:
	return chassi.linear_velocity if is_instance_valid(chassi) else Vector2.ZERO

func _dirigir() -> void:
	var ch: Dictionary = D["chassi"]
	var equilibra: bool = ch["auto_equilibrio"]
	var dir := Input.get_axis("brake", "accelerate")
	if dir != 0.0 and chassi.linear_velocity.length() < ch["vmax"]:
		if equilibra:   # segway: empurra embaixo, o equilíbrio segura
			var baixo: float = (roda_motriz.global_position - chassi.global_position).length() * 0.8
			chassi.apply_force(Vector2(dir * ch["forca"], 0.0), Vector2(0, baixo).rotated(chassi.rotation))
		else:           # 2 rodas: pelo centro de massa, sem empinar sozinho (empinar é no botão)
			chassi.apply_central_force(Vector2(dir * ch["forca"], 0.0))
	var lean := Input.get_axis("lean_back", "lean_fwd")
	if lean != 0.0:
		chassi.apply_torque(lean * inercia_chassi * (8.0 if equilibra else 5.0))
	elif equilibra:
		chassi.apply_torque(inercia_chassi * (-chassi.rotation * balance_stiffness
			- chassi.angular_velocity * balance_damping))
	# pouso/batida forte arremessa o piloto; capotou ou caiu no buraco também
	var dv := (v_roda_ant - roda_motriz.linear_velocity).length()
	v_roda_ant = roda_motriz.linear_velocity
	Audio.motor(true, chassi.linear_velocity.length() / float(ch["vmax"]))
	if dv > 700.0:                       # pouso / batida do veículo
		Audio.tocar("impacto_leve" if dv < 1600.0 else "metal", dv / 2500.0)
	var tomba := deg_to_rad(78.0 if equilibra else 115.0)
	if dv > limiar_queda_montado or absf(chassi.rotation) > tomba \
			or chassi.global_position.y > chao_y + 900.0:
		soltar_ragdoll(_vel(), false)

# ---------- montado -> ragdoll ----------
func soltar_ragdoll(herda_vel: Vector2, pulo: bool = false) -> void:
	if not montado:
		return
	montado = false
	Audio.motor(false)
	var rot := chassi.global_rotation
	for corpo in D["piloto"]:
		var base := centro_peca(corpo)          # origem do corpo = centro da peça de mesmo nome
		var rb := RigidBody2D.new()
		rb.mass = D["corpos"][corpo]["massa"]
		rb.physics_material_override = _mat
		rb.collision_layer = 0b100
		rb.collision_mask = 0b1001              # mundo + objetos
		rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		rb.angular_damp = 0.4
		rb.add_child(_forma_cs(corpo, base))
		add_child(rb)
		rb.global_transform = Transform2D(rot, arte_para_mundo(base))
		for k in _pecas_do(corpo):
			sprites[k].reparent(rb)            # mantém a transform global: zero salto
		rb.linear_velocity = herda_vel + (Vector2(160, -380) if pulo else Vector2.ZERO)
		corpos[corpo] = rb
		rb.add_to_group("piloto")
		v_ant[rb] = rb.linear_velocity
	for j in D["juntas"]:
		var pj := PinJoint2D.new()
		add_child(pj)
		pj.global_position = arte_para_mundo(v2(j["p"]))
		pj.node_a = corpos[j["a"]].get_path()
		pj.node_b = corpos[j["b"]].get_path()
		pj.disable_collision = true
		pj.softness = 0.0
		pj.angular_limit_enabled = true
		pj.angular_limit_lower = -deg_to_rad(j["lim"])
		pj.angular_limit_upper = deg_to_rad(j["lim"])
		juntas[j["b"]] = pj
	boneco.queue_free()

# ---------- pancadas: sangue e desmembramento ----------
func _checar_pancadas() -> void:
	for k in corpos:
		var rb: RigidBody2D = corpos[k]
		var dv: float = (v_ant[rb] - rb.linear_velocity).length()
		v_ant[rb] = rb.linear_velocity
		if dv < limiar_sangue:
			continue
		var n := int(clampf(dv / 70.0, 4.0, 40.0))
		Audio.tocar("impacto_forte" if dv > 1600.0 else "impacto_leve", dv / 2500.0)
		if sangue:
			Audio.tocar("splat", dv / 3000.0)
		if sangue:
			sangue.jorrar(rb.global_position, n, clampf(dv * 0.55, 250.0, 900.0), Vector2.ZERO, rb.linear_velocity * 0.3)
		if k == "cabeca" and dv > limiar_arranca * 0.8 and not morto:
			morto = true
			morreu.emit()
		var lim := limiar_arranca * (1.4 if k == "cabeca" else 1.0)   # pescoço aguenta mais
		if dv > lim and juntas.has(k):
			arrancar(k)

func arrancar(membro: String) -> void:
	if not juntas.has(membro):
		return
	var j: PinJoint2D = juntas[membro]
	var p_global := j.global_position
	var pai: RigidBody2D = j.get_node(j.node_a)
	juntas.erase(membro)
	j.queue_free()
	var lado: RigidBody2D = corpos[membro]
	lado.apply_central_impulse((lado.global_position - p_global).normalized() * 220.0 * lado.mass)
	Audio.tocar("osso")
	if sangue:
		sangue.jorrar(p_global, 40, 700.0)
		var no_pai := pai.to_local(p_global)
		sangue.esguichar(pai, no_pai, no_pai.normalized(), 3.5)
		var no_membro := lado.to_local(p_global)
		sangue.esguichar(lado, no_membro, no_membro.normalized(), 2.0)

func foco() -> Node2D:
	return chassi if montado else corpos.get("tronco", chassi)
