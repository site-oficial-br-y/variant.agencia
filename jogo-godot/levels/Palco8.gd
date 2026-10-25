extends Control
## Fundo da fase 8 (Geresch): degradê vivo com holofotes (shader leve) + peças de Block
## Blast flutuando em 3 profundidades (parallax). Cada peça é desenhada UMA vez (nó
## próprio) e depois só se move: leve até em celular fraco.

const CORES := [Color(1.0, 0.6, 0.15), Color(0.95, 0.3, 0.42), Color(0.3, 0.82, 0.45), Color(0.18, 0.8, 0.68),
	Color(0.25, 0.65, 0.98), Color(0.55, 0.45, 0.98), Color(1.0, 0.82, 0.2)]
const FORMAS := [[[0, 0], [1, 0]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [1, 0], [0, 1], [1, 1]],
	[[0, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [1, 0], [2, 0], [3, 0]],
	[[0, 0], [0, 1], [0, 2]], [[0, 0], [1, 0], [1, 1], [2, 1]]]

var camera: Camera2D
var _fundo: ColorRect
var _pecas: Array = []
var _t := 0.0
var _tam_ant := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo = ColorRect.new()
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/ui/fundo_bb.gdshader")
	_fundo.material = m
	add_child(_fundo)
	var r := RandomNumberGenerator.new()
	r.seed = 88
	for k in 14:
		var prof: float = [0.15, 0.3, 0.5][k % 3]
		var no := Peca.new()
		no.forma = FORMAS[r.randi() % FORMAS.size()]
		no.cor = CORES[r.randi() % CORES.size()]
		no.alpha = 0.1 + prof * 0.55
		add_child(no)
		_pecas.append({"no": no, "x": r.randf_range(0.0, 1.0), "y": r.randf_range(0.04, 0.5), "prof": prof,
			"giro": r.randf_range(-0.4, 0.4), "fase": r.randf_range(0.0, TAU), "vel": r.randf_range(0.4, 1.0)})

func _process(delta: float) -> void:
	_t += delta
	var v := get_viewport_rect().size
	if v != _tam_ant:                                    # só refaz quando a tela muda de tamanho
		_tam_ant = v
		size = v
		_fundo.size = v
		(_fundo.material as ShaderMaterial).set_shader_parameter("aspecto", v.x / maxf(1.0, v.y))
		for p in _pecas:
			var no: Peca = p["no"]
			no.cel = v.y * (0.03 + float(p["prof"]) * 0.07)
			no.queue_redraw()
	var cx := camera.global_position.x if is_instance_valid(camera) else 0.0
	(_fundo.material as ShaderMaterial).set_shader_parameter("desloc", cx * 0.000004)
	for p in _pecas:
		var no: Peca = p["no"]
		var prof: float = p["prof"]
		no.position = Vector2(fposmod(float(p["x"]) * v.x * 1.6 - cx * prof * 0.08, v.x * 1.6) - v.x * 0.3,
			float(p["y"]) * v.y + sin(_t * float(p["vel"]) + float(p["fase"])) * no.cel * 0.4)
		no.rotation = float(p["giro"]) + sin(_t * 0.3 + float(p["fase"])) * 0.08

class Peca extends Node2D:
	var forma: Array = []
	var cor := Color.WHITE
	var alpha := 1.0
	var cel := 40.0

	func _caixa(c: Color, raio: float) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(int(raio))
		return s

	func _draw() -> void:
		var r := cel * 0.92
		for c in forma:
			var o := Vector2(int(c[0]), int(c[1])) * cel + Vector2(cel, cel) * 0.04
			draw_style_box(_caixa(Color(cor.darkened(0.3), alpha), cel * 0.2), Rect2(o, Vector2(r, r)))
			draw_style_box(_caixa(Color(cor, alpha), cel * 0.2), Rect2(o, Vector2(r, r * 0.86)))
			draw_style_box(_caixa(Color(1, 1, 1, 0.35 * alpha), cel * 0.06), Rect2(o + Vector2(r * 0.16, r * 0.1), Vector2(r * 0.68, r * 0.1)))
