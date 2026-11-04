extends Node2D
class_name Sangue
## Sangue com física: gotas balísticas (gravidade + arrasto) que colidem com o
## mundo por raycast e viram manchas grudadas na superfície; e esguichos
## pulsantes presos a um corpo (toco de membro arrancado).

@export var gravidade: float = 1300.0
@export var arrasto: float = 0.35          # perda de velocidade por segundo (fração)
@export var max_gotas: int = 200
@export var max_manchas: int = 400
const BLOCO := 40                          # manchas por bloco de desenho (só o bloco novo redesenha)
const MAX_EMISSORES := 6
@export var escala: float = 1.0          # tamanho do mundo: gota e mancha crescem junto com o boneco
@export var mascara_mundo: int = 0b001

const COR_GOTA := Color(0.72, 0.03, 0.07)
const COR_BORDA := Color(0.32, 0.0, 0.02)
const COR_BRILHO := Color(1.0, 0.55, 0.55, 0.55)
const COR_MANCHA := Color(0.45, 0.01, 0.04, 0.92)

var gotas: Array = []      # {p, v, r, vida}
var manchas: Array = []    # {p, ang, rx, ry}
var emissores: Array = []  # {corpo, local, dir_local, t, dur, base_vel}
var escorrendo: Array = [] # {p, comp, alvo, larg, c} sangue escorrendo na parede/teto
var pocas: Array = []      # {p, r, alvo, ang, c} poça crescendo embaixo de quem sangra parado
var _camada_vivas: Node2D  # escorridos e poças que ainda estão crescendo

var _camada_manchas: Node2D
var _blocos: Array = []    # [{no, itens}] blocos de manchas; o mais velho sai inteiro
var _manchas_sujas := false
var _tinha_gotas := false

func _ready() -> void:
	z_index = 20
	if Game.leve:
		max_gotas = 90
		max_manchas = 200
	_camada_manchas = Node2D.new()          # manchas paradas: em blocos, só o bloco novo redesenha
	add_child(_camada_manchas)
	_camada_vivas = Node2D.new()
	_camada_vivas.draw.connect(_desenhar_vivas)
	add_child(_camada_vivas)

## Espirra n gotas em `pos`, em leque na direção `dir` (ou em volta se ZERO).
func jorrar(pos: Vector2, n: int, forca: float = 500.0, dir: Vector2 = Vector2.ZERO, vel_base: Vector2 = Vector2.ZERO) -> void:
	if Game.leve:
		n = maxi(1, n / 3)
	for i in n:
		var d: Vector2
		if dir == Vector2.ZERO:
			d = Vector2.UP.rotated(randf_range(-PI * 0.85, PI * 0.85))
		else:
			d = dir.normalized().rotated(randf_range(-0.45, 0.45))
		var v := d * forca * randf_range(0.35, 1.15) + vel_base * 0.6
		gotas.append({"p": pos + d * randf_range(0, 10) * escala, "v": v, "r": randf_range(3.0, 8.0) * escala, "vida": 6.0,
			"c": COR_GOTA.lerp(Color(0.5, 0.0, 0.03), randf() * 0.6)})
	if gotas.size() > max_gotas:
		gotas = gotas.slice(gotas.size() - max_gotas)

## Esguicho pulsante preso a um corpo, em coordenadas locais dele.
func esguichar(corpo: Node2D, local: Vector2, dir_local: Vector2, dur: float = 3.0) -> void:
	if emissores.size() >= MAX_EMISSORES:            # muitos jatos ao mesmo tempo: o mais velho para
		emissores.pop_front()
	emissores.append({"corpo": corpo, "local": local, "dir_local": dir_local, "t": dur, "dur": dur})

func _process(delta: float) -> void:                 # por quadro: física a 180 Hz não precisa de 180 raios/gota
	var espaco := get_world_2d().direct_space_state
	var vivas: Array = []
	for g in gotas:
		g["vida"] -= delta
		if g["vida"] <= 0.0:
			continue
		var v: Vector2 = g["v"]
		v.y += gravidade * delta
		v *= (1.0 - arrasto * delta)
		var de: Vector2 = g["p"]
		var para: Vector2 = de + v * delta
		var q := PhysicsRayQueryParameters2D.create(de, para, mascara_mundo)
		var hit := espaco.intersect_ray(q)
		if hit:
			_manchar(hit["position"], hit["normal"], g["r"], v.length())
			continue
		g["p"] = para
		g["v"] = v
		vivas.append(g)
	gotas = vivas

	var ativos: Array = []
	for e in emissores:
		e["t"] -= delta
		if e["t"] <= 0.0 or not is_instance_valid(e["corpo"]):
			continue
		var corpo: Node2D = e["corpo"]
		var origem := corpo.to_global(e["local"])
		var dir: Vector2 = corpo.global_transform.basis_xform(e["dir_local"]).normalized()
		var fase: float = e["dur"] - e["t"]
		var pulso := 0.5 + 0.5 * sin(fase * TAU * 2.2)          # batimento
		var resto: float = e["t"] / e["dur"]
		var n := int(round(randf_range(0.6, 2.2) * pulso * (0.3 + resto)))
		var vel_corpo: Vector2 = corpo.linear_velocity if corpo is RigidBody2D else Vector2.ZERO
		if n > 0:
			jorrar(origem, n, 700.0 + 1100.0 * pulso * resto, dir, vel_corpo)
		e["poca_t"] = float(e.get("poca_t", 0.0)) - delta
		if vel_corpo.length() < 80.0 and e["poca_t"] <= 0.0:       # parado sangrando: forma poça embaixo
			e["poca_t"] = 0.3
			_poca(origem)
		ativos.append(e)
	emissores = ativos
	var crescendo := false
	for m in escorrendo:
		if m["comp"] < m["alvo"]:
			m["comp"] = minf(m["alvo"], m["comp"] + delta * 40.0 * escala * (1.2 - m["comp"] / m["alvo"]))
			crescendo = true
	for pc in pocas:
		if pc["r"] < pc["alvo"]:
			pc["r"] = minf(pc["alvo"], pc["r"] + delta * 30.0 * escala)
			crescendo = true
	if crescendo:
		_camada_vivas.queue_redraw()
	if gotas.size() > 0 or _manchas_sujas or _tinha_gotas:
		queue_redraw()
	_tinha_gotas = gotas.size() > 0

func _manchar(pos: Vector2, normal: Vector2, r: float, vel: float) -> void:
	var achata := clampf(vel / 900.0, 1.0, 3.2)                    # mais rápida = mais espalhada
	var ang := normal.angle() + PI / 2.0
	var cor := COR_MANCHA.lerp(Color(0.6, 0.02, 0.05, 0.9), randf() * 0.5)
	_por({"p": pos + normal * 1.5, "ang": ang, "c": cor,
		"rx": r * achata * randf_range(0.9, 1.4), "ry": r * randf_range(0.35, 0.6)})
	if vel > 1400.0 and not Game.leve and randf() < 0.5:   # respingo: uma gotinha do lado
		var tan := Vector2.from_angle(ang)
		var rr := r * randf_range(0.2, 0.45)
		_por({"p": pos + normal * 1.5 + tan * randf_range(1.5, 4.0) * r * achata * (1.0 if randf() < 0.5 else -1.0),
			"ang": ang, "c": cor, "rx": rr, "ry": rr * 0.7})
	if normal.y > -0.55 and r > 4.0 * escala and escorrendo.size() < 25 and randf() < 0.4:   # parede/teto: escorre
		escorrendo.append({"p": pos + normal * 1.5, "comp": 0.0, "alvo": randf_range(25.0, 110.0) * escala,
			"larg": r * randf_range(0.5, 0.9), "c": cor})


func _por(m: Dictionary) -> void:
	if _blocos.is_empty() or (_blocos[-1]["itens"] as Array).size() >= BLOCO:
		var no := Node2D.new()
		var itens: Array = []
		no.draw.connect(func() -> void:
			for q in itens:
				no.draw_set_transform(q["p"], q["ang"], Vector2(q["rx"], q["ry"]))
				no.draw_circle(Vector2.ZERO, 1.0, q["c"])
			no.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
		_camada_manchas.add_child(no)
		_blocos.append({"no": no, "itens": itens})
		if _blocos.size() * BLOCO > max_manchas:            # o bloco mais velho some inteiro
			var velho: Dictionary = _blocos.pop_front()
			(velho["no"] as Node).queue_free()
			manchas = manchas.slice((velho["itens"] as Array).size())
	(_blocos[-1]["itens"] as Array).append(m)
	(_blocos[-1]["no"] as Node2D).queue_redraw()
	manchas.append(m)

## poça no chão embaixo de `pos` (cresce devagar; perto de outra, aumenta ela)
func _poca(pos: Vector2) -> void:
	if Game.leve:
		return
	var q := PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0, 600.0 * escala), mascara_mundo)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var p: Vector2 = hit["position"]
	var n: Vector2 = hit["normal"]
	for pc in pocas:
		if (pc["p"] as Vector2).distance_to(p) < pc["alvo"] * 0.8:
			pc["alvo"] = minf(pc["alvo"] + 6.0 * escala, 120.0 * escala)
			return
	pocas.append({"p": p + n * 1.0, "r": 4.0 * escala, "alvo": 22.0 * escala, "ang": n.angle() + PI / 2.0,
		"c": Color(0.38, 0.0, 0.03, 0.95)})
	if pocas.size() > 30:
		pocas.pop_front()
		_camada_vivas.queue_redraw()

func _draw() -> void:
	for g in gotas:
		var v: Vector2 = g["v"]
		var esticada := clampf(v.length() / 700.0, 1.0, 2.6)       # gota alonga na direção do voo
		draw_set_transform(g["p"], v.angle(), Vector2(g["r"] * esticada, g["r"]))
		draw_circle(Vector2.ZERO, 1.0, g.get("c", COR_GOTA))
		if g["r"] > 6.5 * escala and not Game.leve:   # gota grande: brilhinho
			draw_circle(Vector2(0.35, -0.35), 0.3, COR_BRILHO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _desenhar_vivas() -> void:
	for pc in pocas:                                # poça: borda escura + miolo brilhante
		_camada_vivas.draw_set_transform(pc["p"], pc["ang"], Vector2(pc["r"], pc["r"] * 0.22))
		_camada_vivas.draw_circle(Vector2.ZERO, 1.0, pc["c"])
		_camada_vivas.draw_circle(Vector2(-0.15, -0.2), 0.55, Color(0.62, 0.03, 0.07, 0.9))
		_camada_vivas.draw_circle(Vector2(-0.3, -0.35), 0.15, Color(1, 0.6, 0.6, 0.35))
	_camada_vivas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m in escorrendo:                            # fio escorrendo com gota na ponta
		var a: Vector2 = m["p"]
		var b: Vector2 = a + Vector2(0, m["comp"])
		_camada_vivas.draw_line(a, b, m["c"], m["larg"])
		_camada_vivas.draw_circle(b, m["larg"] * 0.85, m["c"])

func limpar() -> void:
	gotas.clear(); manchas.clear(); emissores.clear(); escorrendo.clear(); pocas.clear()
	for b in _blocos:
		(b["no"] as Node).queue_free()
	_blocos.clear()
	queue_redraw()
	_camada_vivas.queue_redraw()
