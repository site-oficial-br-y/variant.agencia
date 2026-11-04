class_name IconeMenu
extends Control
## ícones desenhados do lobby (loja, inventário, ranking, conta, engrenagem, play)

var tipo := "loja"
var cor := Color.WHITE

func _init(t: String = "loja", c: Color = Color.WHITE) -> void:
	tipo = t
	cor = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s := minf(size.x, size.y) / 48.0
	var o := (size - Vector2(48, 48) * s) / 2.0
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var w := 3.6 * s
	match tipo:
		"loja":
			draw_polyline(PackedVector2Array([P.call(4, 8), P.call(10, 8), P.call(15, 32), P.call(38, 32), P.call(43, 15), P.call(12, 15)]), cor, w, true)
			draw_circle(P.call(17, 40), 3.6 * s, cor)
			draw_circle(P.call(35, 40), 3.6 * s, cor)
		"inventario":
			var corpo := Rect2(P.call(8, 16), Vector2(32, 26) * s)
			draw_rect(corpo, cor, false, w)
			draw_arc(P.call(24, 16), 8 * s, PI, TAU, 16, cor, w, true)
			draw_line(P.call(8, 26), P.call(40, 26), cor, w * 0.8)
			draw_rect(Rect2(P.call(20, 23), Vector2(8, 7) * s), cor)
		"ranking":
			draw_colored_polygon(PackedVector2Array([P.call(12, 6), P.call(36, 6), P.call(34, 20), P.call(24, 28), P.call(14, 20)]), cor)
			draw_arc(P.call(12, 13), 6 * s, PI * 0.5, PI * 1.5, 12, cor, w * 0.8, true)
			draw_arc(P.call(36, 13), 6 * s, -PI * 0.5, PI * 0.5, 12, cor, w * 0.8, true)
			draw_rect(Rect2(P.call(21, 27), Vector2(6, 8) * s), cor)
			draw_rect(Rect2(P.call(14, 35), Vector2(20, 6) * s), cor)
		"conta":
			draw_circle(P.call(24, 15), 8.5 * s, cor)
			draw_colored_polygon(_meia_lua(P.call(24, 44), 16 * s), cor)
		"engrenagem":
			var c: Vector2 = P.call(24, 24)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2.from_angle(a) * 12 * s, c + Vector2.from_angle(a) * 19 * s, cor, 7 * s)
			draw_circle(c, 13 * s, cor)
			draw_circle(c, 5.5 * s, Color(0.09, 0.05, 0.18))
		"play":
			draw_colored_polygon(PackedVector2Array([P.call(10, 4), P.call(42, 24), P.call(10, 44)]), cor)
		"online":
			draw_circle(P.call(16, 14), 6.5 * s, cor)
			draw_colored_polygon(_meia_lua(P.call(16, 38), 12 * s), cor)
			draw_circle(P.call(33, 14), 6.5 * s, cor)
			draw_colored_polygon(_meia_lua(P.call(33, 38), 12 * s), cor)

func _meia_lua(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(c + Vector2.from_angle(PI + PI * i / 16.0) * r)
	return pts
