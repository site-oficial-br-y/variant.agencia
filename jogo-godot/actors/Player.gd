extends Node2D
class_name Player
## Segway com o boneco montado (a arte inteira dirigindo) que, ao capotar / pular
## fora / pousar forte, vira um ragdoll feito das PRÓPRIAS peças recortadas da
## imagem. Impacto -> sangue; impacto muito forte -> membro arrancado esguichando.

# --- tuning ---
@export var drive_power: float = 90000.0
@export var max_speed: float = 900.0
@export var balance_stiffness: float = 55.0
@export var balance_damping: float = 14.0
@export var chao_y: float = 1000.0
@export var spawn_x: float = 600.0
@export var limiar_sangue: float = 420.0       # Δv (px/s) num passo que conta como pancada
@export var limiar_arranca: float = 1750.0     # Δv que arranca o membro
@export var limiar_queda_montado: float = 1500.0

const TOPO_CHASSI := 200.0                     # y da arte onde o "mastro" começa (ombro)
const CORPOS := ["perna", "cabeca", "tronco", "braco"]
# junta: membro -> [pivô (nome no tronco), limite em graus, direção do esguicho no membro]
const JUNTAS := {
	"cabeca": ["pescoco", 40.0],
	"braco": ["ombro", 75.0],
	"perna": ["quadril", 55.0],
}
const MASSA := {"chassi": 5.0, "roda": 2.0, "perna": 1.4, "tronco": 2.0, "braco": 0.5, "cabeca": 0.8}
# forma de colisão por peça, em coords da arte: [tipo, a, b, raio]
const FORMAS := {
	"cabeca": ["circ", Vector2(238, 112), Vector2.ZERO, 92.0],
	"tronco": ["caps", Vector2(190, 250), Vector2(140, 585), 82.0],
	"braco": ["caps", Vector2(178, 384), Vector2(345, 590), 30.0],
	"perna": ["caps", Vector2(140, 630), Vector2(120, 1075), 52.0],
}

var META: Dictionary = {}
var ORDEM: Array = []
var ANCORA := Vector2.ZERO
var RODA_C := Vector2.ZERO
var RODA_R := 150.0

var chassi: RigidBody2D
var inercia_chassi := 1.0
var roda: RigidBody2D
var boneco: Node2D
var sprites: Dictionary = {}
var corpos: Dictionary = {}
var juntas: Dictionary = {}       # membro -> PinJoint2D
var v_ant: Dictionary = {}        # corpo -> velocidade do passo anterior
var v_roda_ant := Vector2.ZERO
var montado := true
var morto := false
var sangue: Sangue
var _mat: PhysicsMaterial

signal morreu

func _ready() -> void:
	var f := FileAccess.open("res://assets/seg/parts.json", FileAccess.READ)
	var dados: Dictionary = JSON.parse_string(f.get_as_text())
	META = dados["pecas"]
	ORDEM = dados["ordem"]
	var r: Dictionary = META["roda"]
	RODA_C = Vector2(r["x"] + r["piv"]["centro"][0], r["y"] + r["piv"]["centro"][1])
	RODA_R = r["r"]
	ANCORA = Vector2(165.0, (TOPO_CHASSI + RODA_C.y) / 2.0)
	_mat = PhysicsMaterial.new()
	_mat.friction = 1.0
	_mat.bounce = 0.05
	_montar()

# ---------- geometria da arte ----------
func centro_arte(k: String) -> Vector2:
	var p: Dictionary = META[k]
	return Vector2(p["x"] + p["w"] / 2.0, p["y"] + p["h"] / 2.0)

func piv_arte(k: String, nome: String) -> Vector2:
	var p: Dictionary = META[k]
	var pv: Array = p["piv"][nome]
	return Vector2(p["x"] + pv[0], p["y"] + pv[1])

func _sprite(k: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/seg/%s.png" % k)
	s.z_index = ORDEM.find(k)
	return s

# ---------- montagem ----------
func _montar() -> void:
	var altura := RODA_C.y - TOPO_CHASSI
	var chassi_pos := Vector2(spawn_x, chao_y - RODA_R - (RODA_C.y - ANCORA.y))
	var roda_pos := Vector2(spawn_x + (RODA_C.x - ANCORA.x), chao_y - RODA_R)

	chassi = RigidBody2D.new()
	chassi.position = chassi_pos
	chassi.mass = MASSA["chassi"]
	chassi.collision_layer = 0
	chassi.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, altura)
	cs.shape = rect
	chassi.add_child(cs)
	add_child(chassi)
	inercia_chassi = chassi.mass * (100.0 * 100.0 + altura * altura) / 12.0

	roda = RigidBody2D.new()
	roda.position = roda_pos
	roda.mass = MASSA["roda"]
	roda.physics_material_override = _mat
	roda.collision_layer = 0b010
	roda.collision_mask = 0b001
	roda.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	var cr := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = RODA_R
	cr.shape = circ
	roda.add_child(cr)
	var sr := _sprite("roda")
	sr.position = centro_arte("roda") - RODA_C
	roda.add_child(sr)
	add_child(roda)

	var eixo := PinJoint2D.new()
	add_child(eixo)
	eixo.global_position = roda_pos
	eixo.node_a = roda.get_path()
	eixo.node_b = chassi.get_path()
	eixo.disable_collision = true

	var sp := _sprite("poste")
	sp.position = centro_arte("poste") - ANCORA
	chassi.add_child(sp)

	boneco = Node2D.new()
	chassi.add_child(boneco)
	for k in ORDEM:
		if k == "roda" or k == "poste":
			continue
		var s := _sprite(k)
		s.position = centro_arte(k) - ANCORA
		boneco.add_child(s)
		sprites[k] = s
	# sensor no formato do corpo: encostou no mundo montado -> voa do veículo
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 0b001
	for k in CORPOS:
		sensor.add_child(_forma_cs(k, ANCORA))
	chassi.add_child(sensor)
	sensor.body_entered.connect(_on_corpo_bateu)
	montado = true

func _on_corpo_bateu(_body: Node) -> void:
	if montado:
		soltar_ragdoll(_vel(), false)

# ---------- controle ----------
func _physics_process(delta: float) -> void:
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
	var dir := Input.get_axis("brake", "accelerate")
	if dir != 0.0 and chassi.linear_velocity.length() < max_speed:
		chassi.apply_force(Vector2(dir * drive_power, 0.0), Vector2(0, 400).rotated(chassi.rotation))
	var lean := Input.get_axis("lean_back", "lean_fwd")
	if lean != 0.0:
		chassi.apply_torque(lean * inercia_chassi * 8.0)
	else:
		chassi.apply_torque(inercia_chassi * (-chassi.rotation * balance_stiffness
			- chassi.angular_velocity * balance_damping))
	# pouso forte arremessa o piloto; capotou ou caiu no buraco também
	var dv_roda := (v_roda_ant - roda.linear_velocity).length()
	v_roda_ant = roda.linear_velocity
	if dv_roda > limiar_queda_montado:
		soltar_ragdoll(_vel(), false)
	elif absf(chassi.rotation) > deg_to_rad(78.0) or chassi.global_position.y > chao_y + 900.0:
		soltar_ragdoll(_vel(), false)

# ---------- montado -> ragdoll ----------
func soltar_ragdoll(herda_vel: Vector2, pulo: bool = false) -> void:
	if not montado:
		return
	montado = false
	for k in CORPOS:
		var s: Sprite2D = sprites[k]
		var gt := s.global_transform
		var rb := RigidBody2D.new()
		rb.mass = MASSA[k]
		rb.physics_material_override = _mat
		rb.collision_layer = 0b100
		rb.collision_mask = 0b001
		rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		rb.angular_damp = 0.4
		_forma(rb, k)
		add_child(rb)
		rb.global_transform = gt
		s.reparent(rb)
		s.position = Vector2.ZERO
		rb.linear_velocity = herda_vel + (Vector2(160, -380) if pulo else Vector2.ZERO)
		corpos[k] = rb
		v_ant[rb] = rb.linear_velocity
	# manga (2ª camada do tronco) acompanha o corpo do tronco
	sprites["tronco_f"].reparent(corpos["tronco"])
	boneco.queue_free()

	for membro in JUNTAS:
		var nome: String = JUNTAS[membro][0]
		var lim: float = JUNTAS[membro][1]
		var j := PinJoint2D.new()
		add_child(j)
		j.global_position = corpos["tronco"].to_global(piv_arte("tronco", nome) - centro_arte("tronco"))
		j.node_a = corpos["tronco"].get_path()
		j.node_b = corpos[membro].get_path()
		j.disable_collision = true
		j.softness = 0.0
		j.angular_limit_enabled = true
		j.angular_limit_lower = -deg_to_rad(lim)
		j.angular_limit_upper = deg_to_rad(lim)
		juntas[membro] = j

func _forma(rb: RigidBody2D, k: String) -> void:
	rb.add_child(_forma_cs(k, centro_arte(k)))

## forma de colisão da peça `k`, posicionada relativa ao ponto `c` da arte
func _forma_cs(k: String, c: Vector2) -> CollisionShape2D:
	var f: Array = FORMAS[k]
	var cs := CollisionShape2D.new()
	if f[0] == "circ":
		var sh := CircleShape2D.new()
		sh.radius = f[3]
		cs.shape = sh
		cs.position = f[1] - c
	else:
		var a: Vector2 = f[1]
		var b: Vector2 = f[2]
		var sh := CapsuleShape2D.new()
		sh.radius = f[3]
		sh.height = a.distance_to(b) + 2.0 * f[3]
		cs.shape = sh
		cs.position = (a + b) / 2.0 - c
		cs.rotation = (b - a).angle() - PI / 2.0
	return cs

# ---------- pancadas: sangue e desmembramento ----------
func _checar_pancadas() -> void:
	for k in corpos:
		var rb: RigidBody2D = corpos[k]
		var dv: float = (v_ant[rb] - rb.linear_velocity).length()
		v_ant[rb] = rb.linear_velocity
		if dv < limiar_sangue:
			continue
		var n := int(clampf(dv / 70.0, 4.0, 40.0))
		if sangue:
			sangue.jorrar(rb.global_position, n, clampf(dv * 0.55, 250.0, 900.0), Vector2.ZERO, rb.linear_velocity * 0.3)
		if k == "cabeca" and dv > limiar_arranca * 0.8 and not morto:
			morto = true
			morreu.emit()
		var lim := limiar_arranca * (1.4 if k == "cabeca" else 1.0)   # pescoço aguenta mais
		if dv > lim and juntas.has(k):
			arrancar(k)

func arrancar(membro: String) -> void:
	var j: PinJoint2D = juntas[membro]
	var p_global := j.global_position
	juntas.erase(membro)
	j.queue_free()
	var tronco: RigidBody2D = corpos["tronco"]
	var lado: RigidBody2D = corpos[membro]
	lado.apply_central_impulse((lado.global_position - p_global).normalized() * 220.0 * lado.mass)
	if sangue:
		sangue.jorrar(p_global, 40, 700.0)
		var no_tronco := tronco.to_local(p_global)
		sangue.esguichar(tronco, no_tronco, no_tronco.normalized(), 3.5)
		var no_membro := lado.to_local(p_global)
		sangue.esguichar(lado, no_membro, no_membro.normalized(), 2.0)

func foco() -> Node2D:
	return chassi if montado else corpos.get("tronco", chassi)
