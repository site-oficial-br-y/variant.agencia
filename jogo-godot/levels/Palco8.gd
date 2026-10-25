extends Control
## Fundo da fase 8 (Geresch): degradê vivo com holofotes (shader) + peças de Block Blast
## brilhantes flutuando em 3 profundidades (parallax com a câmera) + faíscas subindo.

const CORES := [Color(1.0, 0.6, 0.15), Color(0.95, 0.3, 0.42), Color(0.3, 0.82, 0.45), Color(0.18, 0.8, 0.68),
	Color(0.25, 0.65, 0.98), Color(0.55, 0.45, 0.98), Color(1.0, 0.82, 0.2)]
const FORMAS := [[[0, 0], [1, 0]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [1, 0], [0, 1], [1, 1]],
	[[0, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [1, 0], [2, 0], [3, 0]],
	[[0, 0], [0, 1], [0, 2]], [[0, 0], [1, 0], [1, 1], [2, 1]]]

var camera: Camera2D
var _fundo: ColorRect
var _pecas: Array = []
var _faiscas: Array = []
var _t := 0.0
var _sb: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo = ColorRect.new()
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/ui/fundo_bb.gdshader")
	_fundo.material = m
	add_child(_fundo)
	var r := RandomNumberGenerator.new()
	r.seed = 88
	for k in 16:
		var prof: float = [0.15, 0.3, 0.5][k % 3]
		_pecas.append({"x": r.randf_range(0.0, 1.0), "y": r.randf_range(0.04, 0.5), "prof": prof,
			"forma": FORMAS[r.randi() % FORMAS.size()], "cor": CORES[r.randi() % CORES.size()],
			"giro": r.randf_range(-0.4, 0.4), "fase": r.randf_range(0.0, TAU), "vel": r.randf_range(0.4, 1.0)})
	_pecas.sort_custom(func(a, b): return a["prof"] < b["prof"])
	for k in 40:
		_faiscas.append({"x": r.randf(), "y": r.randf(), "v": r.randf_range(0.02, 0.07), "s": r.randf_range(1.5, 4.0), "f": r.randf() * TAU})

func _process(delta: float) -> void:
	_t += delta
	var v := get_viewport_rect().size
	position = Vector2.ZERO
	size = v
	_fundo.position = Vector2.ZERO
	_fundo.size = v
	(_fundo.material as ShaderMaterial).set_shader_parameter("aspecto", v.x / maxf(1.0, v.y))
	var cx := camera.global_position.x if is_instance_valid(camera) else 0.0
	(_fundo.material as ShaderMaterial).set_shader_parameter("desloc", cx * 0.000004)
	for f in _faiscas:
		f["y"] = fposmod(float(f["y"]) - float(f["v"]) * delta, 1.0)
	queue_redraw()

func _caixa(cor: Color, raio: int) -> StyleBoxFlat:
	var k := cor.to_html() + str(raio)
	if not _sb.has(k):
		var s := StyleBoxFlat.new()
		s.bg_color = cor
		s.set_corner_radius_all(raio)
		s.anti_aliasing = true
		_sb[k] = s
	return _sb[k]

func _draw() -> void:
	var v := size
	var cx := camera.global_position.x if is_instance_valid(camera) else 0.0
	for p in _pecas:
		var prof: float = p["prof"]
		var cel := v.y * (0.03 + prof * 0.07)
		var x := fposmod(float(p["x"]) * v.x * 1.6 - cx * prof * 0.08, v.x * 1.6) - v.x * 0.3
		var y := float(p["y"]) * v.y + sin(_t * float(p["vel"]) + float(p["fase"])) * cel * 0.4
		var a := 0.1 + prof * 0.55
		var cor: Color = p["cor"]
		draw_set_transform(Vector2(x, y), float(p["giro"]) + sin(_t * 0.3 + float(p["fase"])) * 0.08, Vector2.ONE)
		for c in p["forma"]:                                  # brilho atrás
			var o := Vector2(int(c[0]), int(c[1])) * cel
			draw_style_box(_caixa(Color(cor, 0.12 * a), int(cel * 0.45)), Rect2(o - Vector2(cel, cel) * 0.35, Vector2(cel, cel) * 1.7))
		for c in p["forma"]:
			var o := Vector2(int(c[0]), int(c[1])) * cel + Vector2(cel, cel) * 0.04
			var r := cel * 0.92
			draw_style_box(_caixa(Color(cor.darkened(0.3), a), int(cel * 0.2)), Rect2(o, Vector2(r, r)))
			draw_style_box(_caixa(Color(cor, a), int(cel * 0.2)), Rect2(o, Vector2(r, r * 0.86)))
			draw_style_box(_caixa(Color(1, 1, 1, 0.35 * a), int(cel * 0.06)), Rect2(o + Vector2(r * 0.16, r * 0.1), Vector2(r * 0.68, r * 0.1)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for f in _faiscas:
		var brilho := 0.35 + 0.35 * sin(_t * 3.0 + float(f["f"]))
		var p := Vector2(float(f["x"]) * v.x, float(f["y"]) * v.y)
		draw_circle(p, float(f["s"]) * 2.5, Color(1, 0.7, 1, 0.08 * brilho))
		draw_circle(p, float(f["s"]), Color(1, 0.9, 1, brilho))
