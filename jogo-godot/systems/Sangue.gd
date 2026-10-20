extends Node2D
class_name Sangue
## Sangue com física: gotas balísticas (gravidade + arrasto) que colidem com o
## mundo por raycast e viram manchas grudadas na superfície; e esguichos
## pulsantes presos a um corpo (toco de membro arrancado).

@export var gravidade: float = 1300.0
@export var arrasto: float = 0.35          # perda de velocidade por segundo (fração)
@export var max_gotas: int = 450
@export var max_manchas: int = 700
@export var mascara_mundo: int = 0b001

const COR_GOTA := Color(0.72, 0.03, 0.07)
const COR_MANCHA := Color(0.45, 0.01, 0.04, 0.92)

var gotas: Array = []      # {p, v, r, vida}
var manchas: Array = []    # {p, ang, rx, ry}
var emissores: Array = []  # {corpo, local, dir_local, t, dur, base_vel}

func _ready() -> void:
	z_index = 20

## Espirra n gotas em `pos`, em leque na direção `dir` (ou em volta se ZERO).
func jorrar(pos: Vector2, n: int, forca: float = 500.0, dir: Vector2 = Vector2.ZERO, vel_base: Vector2 = Vector2.ZERO) -> void:
	for i in n:
		var d: Vector2
		if dir == Vector2.ZERO:
			d = Vector2.UP.rotated(randf_range(-PI * 0.85, PI * 0.85))
		else:
			d = dir.normalized().rotated(randf_range(-0.45, 0.45))
		var v := d * forca * randf_range(0.35, 1.15) + vel_base * 0.6
		gotas.append({"p": pos + d * randf_range(0, 10), "v": v, "r": randf_range(3.0, 8.0), "vida": 6.0})
	if gotas.size() > max_gotas:
		gotas = gotas.slice(gotas.size() - max_gotas)

## Esguicho pulsante preso a um corpo, em coordenadas locais dele.
func esguichar(corpo: Node2D, local: Vector2, dir_local: Vector2, dur: float = 3.0) -> void:
	emissores.append({"corpo": corpo, "local": local, "dir_local": dir_local, "t": dur, "dur": dur})

func _physics_process(delta: float) -> void:
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
		var n := int(round(randf_range(1.0, 3.5) * pulso * (0.3 + resto)))
		var vel_corpo: Vector2 = corpo.linear_velocity if corpo is RigidBody2D else Vector2.ZERO
		if n > 0:
			jorrar(origem, n, 380.0 + 520.0 * pulso * resto, dir, vel_corpo)
		ativos.append(e)
	emissores = ativos
	queue_redraw()

func _manchar(pos: Vector2, normal: Vector2, r: float, vel: float) -> void:
	var achata := clampf(vel / 900.0, 1.0, 3.2)                    # mais rápida = mais espalhada
	manchas.append({"p": pos + normal * 1.5, "ang": normal.angle() + PI / 2.0,
		"rx": r * achata * randf_range(0.9, 1.4), "ry": r * randf_range(0.35, 0.6)})
	if manchas.size() > max_manchas:
		manchas.pop_front()

func _draw() -> void:
	for m in manchas:
		draw_set_transform(m["p"], m["ang"], Vector2(m["rx"], m["ry"]))
		draw_circle(Vector2.ZERO, 1.0, COR_MANCHA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for g in gotas:
		var v: Vector2 = g["v"]
		var esticada := clampf(v.length() / 700.0, 1.0, 2.6)       # gota alonga na direção do voo
		draw_set_transform(g["p"], v.angle(), Vector2(g["r"] * esticada, g["r"]))
		draw_circle(Vector2.ZERO, 1.0, COR_GOTA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func limpar() -> void:
	gotas.clear(); manchas.clear(); emissores.clear(); queue_redraw()
