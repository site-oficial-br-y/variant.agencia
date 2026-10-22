extends Node2D
class_name Player
## Veículo + piloto montados a partir de res://assets/<personagem>/parts.json.
## Montado: a arte inteira presa ao chassi. Bateu / capotou / pulou fora: o piloto
## vira ragdoll feito das PRÓPRIAS peças recortadas. Pancada -> sangue; pancada
## muito forte -> membro arrancado esguichando.

signal morreu
signal bateu_chao(pos: Vector2, forca: float)

@export var personagem: String = "segway"
@export var chao_y: float = 1000.0
var fundo_y := INF                 # abaixo disso o veículo caiu num buraco (a fase define)
@export var spawn_x: float = 600.0
@export var balance_stiffness: float = 55.0
@export var balance_damping: float = 14.0
@export var velocidade: float = 1.6           # multiplica a velocidade máxima no plano
@export var aceleracao: float = 900.0         # px/s² de jogo: ~0,5 s real até a máxima, e ainda sobe rampa de 27°
@export var equilibrio_mono: float = 6.0      # força dos botões de girar no monociclo
@export var mono_rigidez: float = 30.0           # quanto ele volta sozinho pro prumo (menos que a gravidade: ainda cai)
@export var mono_amortece: float = 9.0
@export var mono_balanco: float = 4.0
@export var mono_pende: float = 0.5             # 1 = força no eixo (tomba bastante), 0 = no centro (não tomba)
var _balanco_mono := 0.0
var delta_fisica := 1.0 / 60.0
@export var arrasto: float = 0.15             # resistência do ar: descida chega num limite em vez de disparar
@export var limiar_sangue: float = 420.0       # Δv (px/s) num passo que já espirra sangue
@export var limiar_arranca: float = 2700.0     # Δv que arranca o membro
@export var limiar_queda_montado: float = 2400.0
@export var limiar_explode: float = 3300.0      # Δv que estoura a parte do corpo (cabeça estoura antes)

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
var massa_total := 1.0
var membros: Dictionary = {}            # corpo -> Node2D articulado (montado: animado por molas)
var _mola: Dictionary = {}              # corpo -> [ângulo, velocidade]
var _v_chassi_ant := Vector2.ZERO
var _t_anim := 0.0
var _ac := Vector2.ZERO                 # aceleração do veículo suavizada (para o corpo reagir)
var fogo: CPUParticles2D                 # jato do turbo (cadeira e scooter)
var _som_turbo := 0.0
const PULO := 1700.0                     # Δv pra cima do salto reforçado (px/s de jogo)
const TURBO := 2600.0                    # aceleração extra do turbo (px/s² de jogo)
## habilidade (botão especial): recarga em s, combustível do turbo 0..1, estado do arpão
var habilidade := ""
var recarga := 0.0
var recarga_total := 1.0
var combustivel := 1.0
var recarga_bomba := 0.0
var _equilibrio_t := 0.0
var _arpao: Dictionary = {}              # preso: {corpo, local, comp}
var _corda: Line2D
var explodir_cb: Callable                # (pos, raio, dv) -> explosão no mundo (bomba do Gian)
## dano por parte do corpo enquanto montado
var vida: Dictionary = {}                # corpo -> 0..100
var perdeu: Dictionary = {}              # corpo -> true (membro arrancado montado)
var _forma_corpo: Array = []             # formas do sensor (meta "corpo")
var sensor_piloto: Area2D
var _ang0: Dictionary = {}               # ângulo de repouso de cada junta (pose da arte)
const MEMBROS := ["braco", "perna", "perna2", "coxa", "canela"]
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
	massa_total = chassi.mass
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
	chassi.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	chassi.linear_damp = arrasto
	add_child(chassi)
	chassi.add_to_group("veiculo")

	for r in D["rodas"]:
		var c := v2(r["c"])
		var rb := RigidBody2D.new()
		rb.position = c + desloc
		rb.mass = r["massa"]
		rb.physics_material_override = _mat
		rb.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE   # amortecimento padrão (1,0) freava a roda o tempo todo
		rb.angular_damp = 0.0
		rb.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		rb.linear_damp = arrasto
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
		massa_total += rb.mass
		if r["motriz"]:
			roda_motriz = rb

	for k in _pecas_do("chassi"):
		var s := _sprite(k)
		s.position = centro_peca(k) - origem
		chassi.add_child(s)

	habilidade = Game.HABILIDADES.get(personagem, "")
	if habilidade == "turbo" and ch.has("poly"):
		_montar_turbo(ch)
	boneco = Node2D.new()
	chassi.add_child(boneco)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 0b10001           # mundo + perigo pesado (bola de demolição)
	_montar_membros()
	for corpo in D["piloto"]:
		var cs := _forma_cs(corpo, origem)
		cs.set_meta("corpo", corpo)
		sensor.add_child(cs)
		_forma_corpo.append(cs)
		vida[corpo] = 100.0
	chassi.add_child(sensor)
	sensor_piloto = sensor
	sensor.body_shape_entered.connect(_on_corpo_bateu)
	montado = true

## piloto montado em articulações: tronco gira no quadril, os outros nas juntas do
## parts.json. Só visual (a colisão do sensor fica fixa no chassi).
func _montar_membros() -> void:
	var raiz := "tronco"
	var piv_raiz := centro_peca(raiz)
	for j in D["juntas"]:
		if j["a"] == raiz and (str(j["b"]).begins_with("perna") or j["b"] == "coxa"):
			piv_raiz = v2(j["p"])
			break
	var pivos := {raiz: piv_raiz}
	membros[raiz] = _membro(raiz, boneco, piv_raiz - origem, piv_raiz)
	for j in D["juntas"]:
		var pai: String = j["a"]
		var filho: String = j["b"]
		if not membros.has(pai):
			continue
		var p := v2(j["p"])
		pivos[filho] = p
		membros[filho] = _membro(filho, membros[pai], p - (pivos[pai] as Vector2), p)
	for c in membros:
		_mola[c] = [0.0, 0.0]

func _membro(corpo: String, pai: Node, pos: Vector2, pivo_arte: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	pai.add_child(n)
	for k in _pecas_do(corpo):
		var s := _sprite(k)
		s.position = centro_peca(k) - pivo_arte
		n.add_child(s)
		sprites[k] = s
	return n

## o boneco montado se mexe: corpo inclina com a aceleração, cabeça chacoalha
## nas pancadas (mola frouxa), braço balança, perna pedala o monociclo e as das
## cadeiras balançam soltas
func _animar(delta: float) -> void:
	_t_anim += delta
	var v := chassi.linear_velocity
	var a := (v - _v_chassi_ant) / maxf(delta, 0.001)
	_v_chassi_ant = v
	_ac = _ac.lerp(a.clamp(Vector2(-9000, -9000), Vector2(9000, 9000)), 0.35)
	var ax := _ac.x * cos(chassi.rotation) + _ac.y * sin(chassi.rotation)
	var ay := -_ac.x * sin(chassi.rotation) + _ac.y * cos(chassi.rotation)
	var vel := clampf(chassi.linear_velocity.length() / 1500.0, 0.0, 1.5)   # chacoalha mais quanto mais rápido
	var corpo_alvo := clampf(-ax * 0.00005, -0.3, 0.3) + (0.035 + 0.03 * vel) * sin(_t_anim * (2.3 + 3.0 * vel))
	var alvos := {"tronco": [corpo_alvo, 45.0, 9.0],
		"cabeca": [corpo_alvo * 0.5 - clampf(ay * 0.00006, -0.4, 0.4) + 0.04 * vel * sin(_t_anim * 7.0), 60.0, 4.5],
		"braco": [clampf(-ax * 0.00005, -0.4, 0.4) + 0.05 * sin(_t_anim * 1.7 + 1.0), 35.0, 5.0]}
	var solto := clampf(-ax * 0.00008, -0.5, 0.5) + (0.07 + 0.08 * vel) * sin(_t_anim * (3.1 + 4.0 * vel))
	for c in ["perna", "perna2", "coxa", "canela"]:
		alvos[c] = [solto * (0.4 if c == "coxa" else 1.0), 22.0, 3.0]
	if D["chassi"].get("monociclo", false) and membros.has("perna"):
		alvos.erase("perna")                       # pedal: segue o giro da roda
		(membros["perna"] as Node2D).rotation = 0.38 * sin(roda_motriz.rotation)
	elif D["chassi"]["auto_equilibrio"] and membros.has("perna"):
		alvos["perna"] = [-corpo_alvo * 0.6, 40.0, 8.0]
	for c in alvos:
		if not membros.has(c):
			continue
		var m: Array = _mola[c]
		var alvo: float = alvos[c][0]
		m[1] += ((alvo - float(m[0])) * float(alvos[c][1]) - float(m[1]) * float(alvos[c][2])) * delta
		m[0] = clampf(float(m[0]) + float(m[1]) * delta, -0.7, 0.7)
		(membros[c] as Node2D).rotation = m[0]

## bocal de jato na traseira + partículas de fogo que só saem com o turbo ligado
func _montar_turbo(ch: Dictionary) -> void:
	var xs: Array = []
	var ys: Array = []
	for p in ch["poly"]:
		xs.append(float(p[0]))
		ys.append(float(p[1]))
	var traseira := Vector2(xs.min() - 30.0, lerpf(ys.min(), ys.max(), 0.62)) - origem
	var bocal := Node2D.new()
	bocal.position = traseira
	bocal.scale = Vector2.ONE * 1.35
	bocal.z_index = 12
	chassi.add_child(bocal)
	var corpo := Polygon2D.new()
	corpo.polygon = PackedVector2Array([Vector2(110, -46), Vector2(-40, -62), Vector2(-40, 62), Vector2(110, 46)])
	corpo.color = Color(0.42, 0.44, 0.48)
	bocal.add_child(corpo)
	var aro := Polygon2D.new()
	aro.polygon = PackedVector2Array([Vector2(-40, -62), Vector2(-62, -70), Vector2(-62, 70), Vector2(-40, 62)])
	aro.color = Color(0.2, 0.2, 0.23)
	bocal.add_child(aro)
	var faixa := Polygon2D.new()
	faixa.polygon = PackedVector2Array([Vector2(30, -52), Vector2(55, -50), Vector2(55, 50), Vector2(30, 52)])
	faixa.color = Color(0.85, 0.2, 0.15)
	bocal.add_child(faixa)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var bolha := GradientTexture2D.new()
	bolha.gradient = g
	bolha.fill = GradientTexture2D.FILL_RADIAL
	bolha.fill_from = Vector2(0.5, 0.5)
	bolha.fill_to = Vector2(1.0, 0.5)
	bolha.width = 64
	bolha.height = 64
	fogo = CPUParticles2D.new()
	fogo.texture = bolha
	fogo.position = Vector2(-66, 0)
	fogo.amount = 220
	fogo.lifetime = 0.4
	fogo.local_coords = false
	fogo.direction = Vector2.LEFT
	fogo.spread = 9.0
	fogo.gravity = Vector2(0, -300)
	fogo.initial_velocity_min = 1500.0
	fogo.initial_velocity_max = 2300.0
	fogo.scale_amount_min = 2.4
	fogo.scale_amount_max = 4.4
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 0.75, 1.0])
	rampa.colors = PackedColorArray([Color(1, 1, 0.85, 1), Color(1, 0.85, 0.2, 1), Color(1, 0.4, 0.05, 0.95),
		Color(0.55, 0.12, 0.05, 0.6), Color(0.25, 0.25, 0.25, 0.0)])
	fogo.color_ramp = rampa
	var tam := Curve.new()
	tam.add_point(Vector2(0, 0.6))
	tam.add_point(Vector2(0.3, 1.0))
	tam.add_point(Vector2(1, 1.6))
	fogo.scale_amount_curve = tam
	fogo.emitting = false
	fogo.z_index = 11
	bocal.add_child(fogo)

func _no_chao() -> bool:
	var r: float = (roda_motriz.get_child(0).shape as CircleShape2D).radius
	var q := PhysicsRayQueryParameters2D.create(roda_motriz.global_position, roda_motriz.global_position + Vector2(0, r + 70.0), 0b0001)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()

## botão especial: cada personagem tem a sua habilidade, com limite
##  salto (Périne): pulo reforçado, recarga 1,2 s, só com a roda no chão
##  turbo (Gabriel): jato enquanto segura; combustível acaba e recarrega
##  bomba (Gian): arremessa uma bomba pra frente, recarga 2,5 s
##  equilibrio (Erick): 3 s de equilíbrio automático, recarga 8 s
##  arpao (Gorisch): dispara pra frente e pra cima, prende e puxa; solta ao largar
func _especial(ch: Dictionary, delta: float) -> void:
	recarga = maxf(0.0, recarga - delta)
	_equilibrio_t = maxf(0.0, _equilibrio_t - delta)
	var apertou := Input.is_action_just_pressed("especial")
	var segura := Input.is_action_pressed("especial")
	match habilidade:
		"salto":
			if apertou and recarga <= 0.0 and _no_chao():
				_usar(1.2)
				for rb in [chassi] + rodas:
					var c := rb as RigidBody2D
					c.apply_central_impulse((Vector2(0, -PULO) + Vector2.RIGHT.rotated(chassi.rotation) * 250.0) * c.mass)
				Audio.tocar("pulo")
		"turbo":
			var ligado := segura and combustivel > (0.0 if _som_turbo > 0.0 else 0.2)
			if fogo:
				fogo.emitting = ligado
			if ligado:
				if not (personagem in Game.TURBO_INFINITO):
					combustivel = maxf(0.0, combustivel - 0.4 * delta)
				if chassi.linear_velocity.length() < float(ch["vmax"]) * velocidade * 1.9:
					chassi.apply_central_force(Vector2.RIGHT.rotated(chassi.rotation) * massa_total * TURBO)
				_som_turbo -= delta
				if _som_turbo <= 0.0:
					_som_turbo = 0.9
					Audio.tocar("turbo", 0.9, 0.04)
			else:
				_som_turbo = 0.0
				combustivel = minf(1.0, combustivel + 0.18 * delta)
		"bomba":
			if apertou and recarga <= 0.0:
				_usar(2.5)
				_lancar_bomba()
		"equilibrio":
			if apertou and recarga <= 0.0:
				_usar(8.0)
				_equilibrio_t = 3.0
				Audio.tocar("pulo", 0.5)
			if _equilibrio_t > 0.0:              # segura em pé sozinho e amortece o giro
				chassi.apply_torque(inercia_chassi * (-chassi.rotation * 45.0 - chassi.angular_velocity * 10.0))
		"arpao":
			_arpoar(apertou, segura, delta)
	if personagem in Game.BOMBA_EXTRA:               # segundo botão: bomba com recarga própria
		recarga_bomba = maxf(0.0, recarga_bomba - delta)
		if Input.is_action_just_pressed("bomba") and recarga_bomba <= 0.0:
			recarga_bomba = 2.5
			_lancar_bomba()

func _usar(tempo: float) -> void:
	recarga = tempo
	recarga_total = tempo

## 0..1 do quanto a habilidade está pronta (HUD)
func pronto() -> float:
	if habilidade == "turbo":
		return 1.0 if personagem in Game.TURBO_INFINITO else combustivel
	if habilidade == "equilibrio" and _equilibrio_t > 0.0:
		return 1.0
	return 1.0 - recarga / maxf(recarga_total, 0.001)

func _lancar_bomba() -> void:
	var b := RigidBody2D.new()
	b.mass = 1.0
	b.collision_layer = 0b1000
	b.collision_mask = 0b1001
	b.contact_monitor = true
	b.max_contacts_reported = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 75.0
	cs.shape = c
	b.add_child(cs)
	var corpo := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 20:
		pts.append(Vector2(75, 0).rotated(TAU * k / 20.0))
	corpo.polygon = pts
	corpo.color = Color(0.12, 0.12, 0.14)
	b.add_child(corpo)
	var pavio := Line2D.new()
	pavio.points = PackedVector2Array([Vector2(0, -70), Vector2(20, -120), Vector2(45, -135)])
	pavio.width = 14.0
	pavio.default_color = Color(0.75, 0.6, 0.35)
	b.add_child(pavio)
	var faisca := CPUParticles2D.new()
	faisca.position = Vector2(45, -135)
	faisca.amount = 16
	faisca.lifetime = 0.3
	faisca.initial_velocity_min = 150.0
	faisca.initial_velocity_max = 400.0
	faisca.spread = 180.0
	faisca.scale_amount_min = 6.0
	faisca.scale_amount_max = 12.0
	faisca.color = Color(1, 0.8, 0.2)
	b.add_child(faisca)
	var frente := Vector2.RIGHT.rotated(chassi.rotation)
	b.position = chassi.global_position + frente * 500.0 + Vector2(0, -350)
	get_parent().add_child(b)
	b.linear_velocity = chassi.linear_velocity + frente.rotated(-0.55) * 1700.0
	b.angular_velocity = 8.0
	Audio.tocar("pulo", 0.6)
	var estoura := func() -> void:
		if is_instance_valid(b) and not b.has_meta("foi"):
			b.set_meta("foi", true)
			var pos := b.global_position
			b.queue_free()
			if explodir_cb.is_valid():
				explodir_cb.call(pos, 1300.0, 1000.0)
	b.body_entered.connect(func(_o: Node) -> void: estoura.call_deferred())
	get_tree().create_timer(2.2).timeout.connect(estoura)

## mira automática: a argola de gancho mais perto à frente (até 5,5 mil px); sem
## argola, varre de 30° a 80° pra cima e prende na primeira estrutura que achar
func _mirar_arpao(de: Vector2) -> Dictionary:
	var melhor: Node2D = null
	var dist := 5500.0
	for g in get_tree().get_nodes_in_group("gancho"):
		var gp := (g as Node2D).global_position
		var d := de.distance_to(gp)
		if gp.x > de.x - 300.0 and gp.y < de.y + 200.0 and d < dist:
			melhor = g
			dist = d
	if melhor:
		return {"corpo": melhor, "ponto": melhor.global_position}
	var espaco := get_world_2d().direct_space_state
	for graus in [30.0, 40.0, 50.0, 60.0, 70.0, 80.0]:
		var direcao := Vector2.RIGHT.rotated(chassi.rotation - deg_to_rad(graus))
		var q := PhysicsRayQueryParameters2D.create(de, de + direcao * 5000.0, 0b1001)
		q.exclude = [chassi.get_rid()]
		var hit := espaco.intersect_ray(q)
		if not hit.is_empty():
			return {"corpo": hit["collider"], "ponto": hit["position"]}
	return {}

## arpão: no toque, procura gancho/estrutura à frente e acima; preso, a
## corda puxa o veículo e vai encurtando enquanto segura; soltar o botão libera
func _arpoar(apertou: bool, segura: bool, delta: float) -> void:
	if _corda == null:
		_corda = Line2D.new()
		_corda.width = 16.0
		_corda.default_color = Color(0.85, 0.82, 0.7)
		_corda.z_index = 15
		get_parent().add_child(_corda)
	if _arpao.is_empty():
		_corda.visible = false
		if apertou and recarga <= 0.0:
			var de := chassi.global_position + Vector2(0, -300)
			_usar(0.6)
			Audio.tocar("metal", 0.6)
			var alvo := _mirar_arpao(de)
			if alvo.is_empty():
				return
			var no: Node2D = alvo["corpo"]
			_arpao = {"corpo": no, "local": no.to_local(alvo["ponto"]),
				"comp": de.distance_to(alvo["ponto"]) * 0.92}
		return
	var corpo: Node2D = _arpao["corpo"]
	if not segura or not is_instance_valid(corpo):
		_arpao.clear()
		_usar(0.8)
		return
	var ponto: Vector2 = corpo.to_global(_arpao["local"])
	var de := chassi.global_position + Vector2(0, -300)
	_corda.visible = true
	_corda.points = PackedVector2Array([de, ponto])
	_arpao["comp"] = maxf(500.0, float(_arpao["comp"]) - 900.0 * delta)     # vai recolhendo
	var d := ponto - de
	var estica := d.length() - float(_arpao["comp"])
	if estica > 0.0:                                     # corda esticada: puxa (mola firme + amortecimento)
		var dir := d.normalized()
		var vrel := chassi.linear_velocity.dot(dir)
		var f := dir * (estica * 22.0 - vrel * 3.0) * massa_total
		chassi.apply_force(f, Vector2(0, -300).rotated(chassi.rotation))

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

func _on_corpo_bateu(_rid: RID, body: Node, _forma_outro: int, forma: int) -> void:
	if not montado:
		return
	var corpo := "tronco"
	var dono := sensor_piloto.shape_find_owner(forma)
	var no_forma := sensor_piloto.shape_owner_get_owner(dono)
	if no_forma:
		corpo = no_forma.get_meta("corpo", "tronco")
	# bola de demolição: esbarrão lento só empurra; pancada rápida derruba
	if body.is_in_group("pendulo"):
		var relp := ((body.get_meta("vel", Vector2.ZERO) as Vector2) - chassi.linear_velocity).length()
		if relp < 300.0:
			return
	var rel := chassi.linear_velocity.length()
	if body is RigidBody2D:
		rel = (chassi.linear_velocity - (body as RigidBody2D).linear_velocity).length()
	# braço/perna raspando: machuca a parte (pode cair) mas ele continua montado
	if corpo in MEMBROS and rel < 2200.0 and not body.is_in_group("pendulo"):
		if rel > 350.0:
			_ferir_membro.call_deferred(corpo, rel)
		return
	# cabeça/tronco ou pancada muito forte: voa do veículo (adiado: callback de física)
	soltar_ragdoll.call_deferred(_vel(), false)

## dano localizado montado: cada parte tem vida; zerou, o membro sai voando
func _ferir_membro(corpo: String, forca: float) -> void:
	if not montado or perdeu.has(corpo) or not membros.has(corpo):
		return
	vida[corpo] = float(vida.get(corpo, 100.0)) - forca / 14.0
	var onde: Vector2 = (membros[corpo] as Node2D).global_position
	if sangue:
		sangue.jorrar(onde, 14, 900.0, Vector2.ZERO, chassi.linear_velocity * 0.3)
	Audio.tocar("splat", 0.6)
	if vida[corpo] <= 0.0:
		if corpo == "braco":
			_amputar_montado(corpo)            # braço pode sair e ele segue montado
		else:
			soltar_ragdoll.call_deferred(_vel(), false)   # perna destruída: cai do veículo
			arrancar.call_deferred(corpo)

func _amputar_montado(corpo: String) -> void:
	var lista: Array = [corpo]
	for j in D["juntas"]:                            # leva junto o que está preso nele (canela na coxa)
		if j["a"] in lista:
			lista.append(j["b"])
	for c in lista:
		perdeu[c] = true
	for cs in _forma_corpo:
		if (cs as Node).get_meta("corpo", "") in lista:
			(cs as CollisionShape2D).set_deferred("disabled", true)
	var no: Node2D = membros[corpo]
	var pivo := no.global_position
	var rb := RigidBody2D.new()
	rb.mass = D["corpos"][corpo]["massa"]
	rb.physics_material_override = _mat
	rb.collision_layer = 0b100
	rb.collision_mask = 0b1001
	var base := centro_peca(corpo)
	rb.add_child(_forma_cs(corpo, base))
	add_child(rb)
	rb.global_transform = Transform2D(no.global_rotation, no.to_global(base - v2(_pivo_arte(corpo))))
	for c in lista:
		for k in _pecas_do(c):
			if sprites.has(k) and is_instance_valid(sprites[k]):
				sprites[k].reparent(rb)
				sprites[k].z_index += 20
		membros.erase(c)
	no.queue_free()
	rb.linear_velocity = chassi.linear_velocity * 0.6 + Vector2(randf_range(-300, 300), -700)
	rb.angular_velocity = randf_range(-8, 8)
	Audio.tocar("osso", 1.0)
	if sangue:
		sangue.jorrar(pivo, 40, 1300.0)
		sangue.esguichar(rb, rb.to_local(pivo), Vector2.ZERO - rb.to_local(pivo).normalized(), 3.0)
		sangue.esguichar(chassi, chassi.to_local(pivo), Vector2(-1, 0.3), 4.0)

func _pivo_arte(corpo: String) -> Array:
	for j in D["juntas"]:
		if j["b"] == corpo:
			return j["p"]
	var c := centro_peca(corpo)
	return [c.x, c.y]

func _sem_perna() -> bool:
	for c in ["perna", "perna2", "coxa", "canela"]:
		if perdeu.has(c):
			return true
	return false

func _sem_braco() -> bool:
	return perdeu.has("braco")

## explosão por perto: montado, machuca os membros (ou derruba se for colado);
## caído, arranca ou estoura as partes mais próximas
func explosao(pos: Vector2, raio: float) -> void:
	if not is_instance_valid(chassi):
		return
	if montado:                    # o empurrão é físico (Pecas._empurrar); aqui só machuca os membros
		for c in MEMBROS:
			if membros.has(c) and not perdeu.has(c):
				var dm := (membros[c] as Node2D).global_position.distance_to(pos)
				if dm < raio * 0.6:
					_ferir_membro.call_deferred(c, 1900.0 * (1.0 - dm / raio))
		return
	for c in corpos.keys():
		var rbc: RigidBody2D = corpos[c]
		var d := rbc.global_position.distance_to(pos)
		if d < raio * 0.22:
			explodir.call_deferred(c)
		elif d < raio * 0.45 and juntas.has(c):
			arrancar.call_deferred(c)

# ---------- controle ----------
func _physics_process(delta: float) -> void:
	delta_fisica = delta
	if Input.is_action_just_pressed("eject"):
		soltar_ragdoll(_vel(), true)
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
	if montado:
		_dirigir()
		_especial(D["chassi"], delta)
		_animar(delta)
	else:
		_checar_pancadas()

func _vel() -> Vector2:
	return chassi.linear_velocity if is_instance_valid(chassi) else Vector2.ZERO

func _dirigir() -> void:
	var ch: Dictionary = D["chassi"]
	var equilibra: bool = ch["auto_equilibrio"]
	var mono: bool = ch.get("monociclo", false)
	var dir := Input.get_axis("brake", "accelerate")
	if dir != 0.0 and chassi.linear_velocity.length() < ch["vmax"] * velocidade:
		var forca := massa_total * aceleracao * (0.8 if _sem_perna() else 1.0)   # sem perna, pedala/empurra pior
		if mono:        # monociclo: pedala perto do eixo; o corpo pende um pouco pra trás ao acelerar
			chassi.apply_force(Vector2(dir * forca, 0.0), (roda_motriz.global_position - chassi.global_position) * mono_pende)
		elif equilibra:   # segway: empurra embaixo, o equilíbrio segura
			var baixo: float = (roda_motriz.global_position - chassi.global_position).length() * 0.8
			chassi.apply_force(Vector2(dir * forca, 0.0), Vector2(0, baixo).rotated(chassi.rotation))
		else:           # 2 rodas: pelo centro de massa, sem empinar sozinho (empinar é no botão)
			chassi.apply_central_force(Vector2(dir * forca, 0.0))
	var lean := Input.get_axis("lean_back", "lean_fwd")
	if mono:        # meio estável: tomba devagar e balança sozinho; o jogador corrige com os botões
		_balanco_mono += delta_fisica * (0.9 + 0.4 * sin(_balanco_mono * 0.37))
		var empurrao := sin(_balanco_mono * 1.3) * mono_balanco                # desequilíbrio que pede correção
		chassi.apply_torque(inercia_chassi * (lean * equilibrio_mono * (0.6 if _sem_perna() else 1.0) * (0.6 if _sem_braco() else 1.0)
			- chassi.rotation * mono_rigidez - chassi.angular_velocity * mono_amortece + empurrao))
	elif equilibra:   # girar muda o ângulo-alvo; o equilíbrio nunca desliga (desligar fazia tombar)
		var alvo := lean * 0.45
		chassi.apply_torque(inercia_chassi * (-(chassi.rotation - alvo) * balance_stiffness
			- chassi.angular_velocity * balance_damping))
	elif lean != 0.0:                # sem braço, controla mal
		chassi.apply_torque(lean * inercia_chassi * (2.2 if _sem_braco() else 5.0))
	else:           # sem botão, se alinha sozinho com o chão embaixo: pousa certo na descida
		var alvo := _angulo_chao_embaixo() if ch.get("nivela_chao", true) else 0.0   # pé comprido na frente: fica reto
		chassi.apply_torque(inercia_chassi * (-wrapf(chassi.rotation - alvo, -PI, PI) * 6.0 - chassi.angular_velocity * 2.5))
	# pouso/batida forte arremessa o piloto; capotou ou caiu no buraco também
	var dv := (v_roda_ant - roda_motriz.linear_velocity).length()
	v_roda_ant = roda_motriz.linear_velocity
	Audio.motor(true, chassi.linear_velocity.length() / (float(ch["vmax"]) * velocidade))
	if dv > 1300.0:                      # pouso / batida do veículo (quique pequeno não faz barulho)
		Audio.tocar("impacto_leve" if dv < 2000.0 else "impacto_forte", dv / 3000.0)
		bateu_chao.emit(roda_motriz.global_position + Vector2(0, (roda_motriz.get_child(0).shape as CircleShape2D).radius), dv / 2000.0)
	var tomba := deg_to_rad(65.0 if mono else (78.0 if equilibra else 115.0))
	if dv > limiar_queda_montado or absf(chassi.rotation) > tomba \
			or chassi.global_position.y > (fundo_y if fundo_y < INF else chao_y + 900.0):
		soltar_ragdoll(_vel(), false)

func _angulo_chao_embaixo() -> float:
	var espaco := get_world_2d().direct_space_state
	var pts: Array = []
	for dx in [-300.0, 300.0]:
		var de := chassi.global_position + Vector2(dx, 0)
		var q := PhysicsRayQueryParameters2D.create(de, de + Vector2(0, 5000), 0b0001)
		var hit := espaco.intersect_ray(q)
		if hit.is_empty():
			return 0.0
		pts.append(hit["position"])
	return ((pts[1] as Vector2) - (pts[0] as Vector2)).angle()

# ---------- montado -> ragdoll ----------
func soltar_ragdoll(herda_vel: Vector2, pulo: bool = false) -> void:
	if not montado:
		return
	montado = false
	for c in membros:                              # volta à pose da arte antes de virar ragdoll
		(membros[c] as Node2D).rotation = 0.0
	Audio.motor(false)
	if fogo:
		fogo.emitting = false
	var rot := chassi.global_rotation
	for corpo in D["piloto"]:
		if perdeu.has(corpo):
			continue
		var base := centro_peca(corpo)          # origem do corpo = centro da peça de mesmo nome
		var rb := RigidBody2D.new()
		rb.mass = D["corpos"][corpo]["massa"]
		rb.physics_material_override = _mat
		rb.collision_layer = 0b100
		rb.collision_mask = 0b1001              # mundo + objetos
		rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		rb.angular_damp = 2.5                    # membro não gira solto feito pano
		rb.add_child(_forma_cs(corpo, base))
		add_child(rb)
		rb.global_transform = Transform2D(rot, arte_para_mundo(base))
		for k in _pecas_do(corpo):
			sprites[k].reparent(rb)            # mantém a transform global: zero salto
			sprites[k].z_index += 20          # caído fica na frente do veículo (perna não some atrás dele)
		rb.linear_velocity = herda_vel + (Vector2(160, -380) if pulo else Vector2.ZERO)
		corpos[corpo] = rb
		rb.add_to_group("piloto")
		v_ant[rb] = rb.linear_velocity
	for j in D["juntas"]:
		if perdeu.has(j["a"]) or perdeu.has(j["b"]):
			continue
		var pj := PinJoint2D.new()
		add_child(pj)
		pj.global_position = arte_para_mundo(v2(j["p"]))
		pj.node_a = corpos[j["a"]].get_path()
		pj.node_b = corpos[j["b"]].get_path()
		pj.disable_collision = true
		pj.softness = 0.0
		pj.angular_limit_enabled = true
		var lim_j := 28.0 if j["b"] == "cabeca" else float(j["lim"]) * 0.55
		pj.angular_limit_lower = -deg_to_rad(lim_j)
		pj.angular_limit_upper = deg_to_rad(lim_j)
		juntas[j["b"]] = pj
		_ang0[j["b"]] = corpos[j["b"]].rotation - corpos[j["a"]].rotation
	boneco.queue_free()

# ---------- pancadas: sangue e desmembramento ----------
## tônus muscular: a junta tende a voltar ao ângulo da arte (mola + amortecimento),
## então o corpo cai como gente e não dobra feito origami. Fraco: pancada vence.
func _musculos() -> void:
	for j in D["juntas"]:
		var a: String = j["a"]
		var b: String = j["b"]
		if not juntas.has(b) or not corpos.has(a) or not corpos.has(b):
			continue
		var ra: RigidBody2D = corpos[a]
		var rb: RigidBody2D = corpos[b]
		var rel := wrapf(rb.rotation - ra.rotation - float(_ang0.get(b, 0.0)), -PI, PI)
		var wrel := rb.angular_velocity - ra.angular_velocity
		var forca := 0.35 if morto else 1.0
		var t := (-rel * 4.0 - wrel * 1.0) * forca
		# limite duro (o do PinJoint2D escapa): passou do ângulo, empurra de volta com força
		# e corta o giro pra fora. Pescoço mais curto: a cabeça não entra no peito.
		var lim := deg_to_rad(28.0 if b == "cabeca" else float(j["lim"]) * 0.6)
		if absf(rel) > lim:
			var passou := rel - signf(rel) * lim
			t += -passou * 120.0 - wrel * 12.0
			if signf(wrel) == signf(rel):
				rb.angular_velocity = ra.angular_velocity + wrel * 0.3
		rb.apply_torque(t * _inercia(rb))
		ra.apply_torque(-t * _inercia(rb) * 0.5)

func _inercia(rb: RigidBody2D) -> float:
	return rb.mass * 9000.0

func _checar_pancadas() -> void:
	_musculos()
	for k in corpos:
		var rb: RigidBody2D = corpos[k]
		var dv: float = (v_ant[rb] - rb.linear_velocity).length()
		v_ant[rb] = rb.linear_velocity
		if dv < limiar_sangue:
			continue
		var n := int(clampf(dv / 45.0, 6.0, 45.0))
		Audio.tocar("impacto_forte" if dv > 1600.0 else "impacto_leve", dv / 2500.0)
		if sangue:
			Audio.tocar("splat", dv / 3000.0)
		if sangue:
			sangue.jorrar(rb.global_position, n, clampf(dv * 0.9, 500.0, 1700.0), Vector2.ZERO, rb.linear_velocity * 0.3)
		if dv < 750.0:                   # pancada leve só suja: não machuca
			continue
		if k == "cabeca" and dv > limiar_arranca * 0.8 and not morto:
			morto = true
			morreu.emit()
		if dv > limiar_explode * (0.85 if k == "cabeca" else 1.25):
			explodir.call_deferred(k)               # não mexe em `corpos` no meio do laço
			continue
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
		sangue.jorrar(p_global, 70, 1500.0)
		var no_pai := pai.to_local(p_global)
		sangue.esguichar(pai, no_pai, no_pai.normalized(), 7.0)
		var no_membro := lado.to_local(p_global)
		sangue.esguichar(lado, no_membro, no_membro.normalized(), 4.0)

## estoura uma parte do corpo: some a peça, voam pedaços (carne, osso, olho) e
## o toco esguicha. Montado, primeiro vira ragdoll.
func explodir(membro: String) -> void:
	if not is_inside_tree():                        # chamada adiada que chegou depois do reinício
		return
	if montado:
		soltar_ragdoll(_vel(), false)
	if not corpos.has(membro):
		return
	var rb: RigidBody2D = corpos[membro]
	var pos := rb.global_position
	var vel := rb.linear_velocity
	for filho in juntas.keys():                     # solta o que estava preso nele
		var j: PinJoint2D = juntas[filho]
		if filho == membro or j.get_node_or_null(j.node_a) == rb:
			var ponta: Node = corpos.get(filho) if filho != membro else j.get_node_or_null(j.node_a)
			if sangue and is_instance_valid(ponta):
				var local := (ponta as Node2D).to_local(j.global_position)
				sangue.esguichar(ponta, local, local.normalized(), 4.0 if filho != membro else 8.0)
			juntas.erase(filho)
			j.queue_free()
	corpos.erase(membro)
	v_ant.erase(rb)
	rb.queue_free()
	Audio.tocar("splat", 1.0)
	Audio.tocar("osso", 1.0)
	Audio.tocar("impacto_forte", 0.9)
	if sangue:
		sangue.jorrar(pos, 110, 2600.0, Vector2.ZERO, vel * 0.3)
	var cabeca := membro == "cabeca"
	var pedacos: Array = [["carne", 5]]              # pedacinhos de carne pequenos (estilo do gênero)
	if cabeca:
		pedacos = [["carne", 6], ["olho", 1]]
	for tipo in pedacos:
		for i in tipo[1]:
			_pedaco(tipo[0], pos, vel)
	if cabeca and not morto:
		morto = true
		morreu.emit()

func _pedaco(tipo: String, pos: Vector2, vel: Vector2) -> void:
	var r: float = {"carne": randf_range(28, 55), "olho": 26.0}[tipo]
	var g := RigidBody2D.new()
	g.mass = 0.3
	g.collision_layer = 0b100
	g.collision_mask = 0b1001
	g.physics_material_override = _mat
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = r * 0.8
	cs.shape = c
	g.add_child(cs)
	var pts := PackedVector2Array()
	var lados := 9
	for k in lados:
		var esc := 1.0 if tipo in ["olho", "dente"] else randf_range(0.65, 1.15)
		var raio := r * esc
		pts.append(Vector2(raio, 0).rotated(TAU * k / lados))
	var cor: Color = {"carne": Color(0.55, 0.03, 0.06).lerp(Color(0.75, 0.1, 0.12), randf() * 0.6),
		"olho": Color(0.97, 0.97, 0.95)}[tipo]
	var corpo := Polygon2D.new()
	corpo.polygon = pts
	corpo.color = cor
	g.add_child(corpo)
	var borda := Line2D.new()
	var fechado := pts.duplicate()
	fechado.append(pts[0])
	borda.points = fechado
	borda.width = 5.0
	borda.default_color = Color(0.3, 0.02, 0.03)
	g.add_child(borda)
	if tipo == "olho":
		var iris := Polygon2D.new()
		var ip := PackedVector2Array()
		for k in 10:
			ip.append(Vector2(r * 0.45, 0).rotated(TAU * k / 10.0) + Vector2(r * 0.3, 0))
		iris.polygon = ip
		iris.color = Color(0.12, 0.08, 0.05)
		g.add_child(iris)
	if tipo == "carne":
		var veia := Line2D.new()
		veia.points = PackedVector2Array([Vector2(-r * 0.5, 0), Vector2(0, r * 0.3), Vector2(r * 0.4, -r * 0.2)])
		veia.width = 6.0
		veia.default_color = Color(0.4, 0.0, 0.03)
		g.add_child(veia)
	g.position = pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	g.rotation = randf() * TAU
	add_child(g)
	g.linear_velocity = vel * 0.5 + Vector2.UP.rotated(randf_range(-1.4, 1.4)) * randf_range(900, 2400)
	g.angular_velocity = randf_range(-14, 14)
	if sangue and tipo == "carne":
		sangue.esguichar(g, Vector2.ZERO, Vector2.UP, 1.5)
	get_tree().create_timer(25.0).timeout.connect(g.queue_free)

func foco() -> Node2D:
	return chassi if montado else corpos.get("tronco", chassi)
