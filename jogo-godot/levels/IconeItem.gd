extends Control
class_name IconeItem
## Desenho do item do passe no cartão (sem arte: tudo com formas). item = linha de Passe.ITENS.

var item: Array = []
var _t := 0.0
var _rosto: Texture2D

func _process(delta: float) -> void:
	_t += delta
	if _rosto == null and not item.is_empty() and item[3] == "skin":    # carrega fora do _draw (dentro dele sai branco)
		var sp: Array = Passe.SKINS_PASSE.get(item[1], ["wendell", ""])
		var arq := "res://assets/ui/rosto_%s.png" % sp[1]
		_rosto = load(arq if sp[1] != "" and ResourceLoader.exists(arq) else "res://assets/ui/rosto_%s.png" % sp[0])
	queue_redraw()

func _draw() -> void:
	if item.is_empty():
		return
	var c := size / 2.0
	var cor: Color = item[4]
	var id: String = item[1]
	match item[3]:
		"rastro":
			for k in 5:
				var x := c.x + 40 - k * 22
				var a := 1.0 - k * 0.18
				var cc := Color.from_hsv(fmod(_t * 0.5 + k * 0.15, 1.0), 0.7, 1.0, a) if id == "rastro_arco" else Color(cor, a)
				if id == "rastro_raio":
					draw_line(Vector2(x + 22, c.y + (k % 2) * 16 - 8), Vector2(x, c.y + ((k + 1) % 2) * 16 - 8), cc, 6.0)
				else:
					draw_circle(Vector2(x, c.y + sin(_t * 4.0 + k) * 6.0), 16 - k * 2, cc)
			draw_circle(Vector2(c.x + 46, c.y), 10, Color.WHITE)
		"aura":
			for k in 4:
				var r := 54 - k * 10 + sin(_t * 3.0) * 4
				var cc := Color.from_hsv(fmod(_t * 0.4, 1.0), 0.6, 1.0, 0.25) if id == "aura_arco" else Color(cor, 0.22 + k * 0.08)
				draw_circle(c, r, cc)
			draw_circle(c + Vector2(0, -14), 13, Color(0.95, 0.85, 0.75))
			draw_rect(Rect2(c + Vector2(-12, 0), Vector2(24, 34)), Color(0.95, 0.95, 1.0))
		"roda":
			var cc := Color.from_hsv(fmod(_t * 0.6, 1.0), 0.8, 1.0) if id == "roda_arco" else cor
			draw_circle(c, 46, Color(0.12, 0.12, 0.14))
			draw_arc(c, 48, 0, TAU, 40, cc, 9.0)
			for k in 6:
				var a := _t * 3.0 + TAU * k / 6.0
				draw_line(c, c + Vector2(36, 0).rotated(a), Color(0.5, 0.5, 0.55), 4.0)
			draw_circle(c, 10, cc)
		"chapeu":
			draw_circle(c + Vector2(0, 24), 30, Color(0.95, 0.82, 0.7))
			match id:
				"chapeu_coroa":
					draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -2), c + Vector2(-34, -34), c + Vector2(-17, -16), c + Vector2(0, -42),
						c + Vector2(17, -16), c + Vector2(34, -34), c + Vector2(34, -2)]), cor)
				"chapeu_aureola":
					draw_arc(c + Vector2(0, -24 + sin(_t * 3.0) * 4), 30, 0, TAU, 32, cor, 6.0)
				"chapeu_chifre":
					for s in [-1.0, 1.0]:
						draw_colored_polygon(PackedVector2Array([c + Vector2(s * 12, 0), c + Vector2(s * 30, 0), c + Vector2(s * 34, -40)]), cor)
				"chapeu_cartola":
					draw_rect(Rect2(c + Vector2(-40, -6), Vector2(80, 10)), cor)
					draw_rect(Rect2(c + Vector2(-24, -52), Vector2(48, 48)), cor)
					draw_rect(Rect2(c + Vector2(-24, -18), Vector2(48, 9)), Color(0.75, 0.1, 0.15))
		"morte":
			for k in 14:
				var a := TAU * k / 14.0 + _t
				var r := 20 + fmod(_t * 40.0 + k * 9.0, 34.0)
				var cc := Color.from_hsv(k / 14.0, 0.8, 1.0) if id == "morte_confete" else cor
				if id == "morte_pixel":
					draw_rect(Rect2(c + Vector2(r, 0).rotated(a) - Vector2(5, 5), Vector2(10, 10)), cc)
				elif id == "morte_fantasma":
					pass
				else:
					draw_circle(c + Vector2(r, 0).rotated(a), 6, cc)
			if id == "morte_fantasma":
				var y := c.y + 10 - fmod(_t * 20.0, 20.0)
				draw_circle(Vector2(c.x, y - 6), 30, Color(0.95, 0.97, 1.0, 0.9))
				draw_rect(Rect2(Vector2(c.x - 30, y - 6), Vector2(60, 34)), Color(0.95, 0.97, 1.0, 0.9))
				draw_circle(Vector2(c.x - 11, y - 10), 6, Color(0.1, 0.1, 0.15))
				draw_circle(Vector2(c.x + 11, y - 10), 6, Color(0.1, 0.1, 0.15))
			if id == "morte_raio":
				for k in 4:
					var a := TAU * k / 4.0 + _t
					draw_polyline(PackedVector2Array([c, c + Vector2(20, 8).rotated(a), c + Vector2(34, -6).rotated(a), c + Vector2(52, 4).rotated(a)]), cor, 4.0)
		"moldura":
			var cc := Color.from_hsv(fmod(_t * 0.4, 1.0), 0.6, 1.0) if id == "moldura_arco" else cor
			if id == "moldura_fogo":
				cc = Color(1, 0.55 + 0.25 * sin(_t * 8.0), 0.15)
			var f := get_theme_default_font()
			draw_string_outline(f, Vector2(4, c.y + 14), "NICK", HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 38, 10, Color(0.1, 0.05, 0.15))
			draw_string(f, Vector2(4, c.y + 14), "NICK", HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 38, cc)
		"bonus":
			var dobro: bool = id.begins_with("bonus_dobro")
			draw_circle(c, 50 + sin(_t * 3.0) * 3.0, Color(cor, 0.2))
			draw_arc(c, 48, -PI / 2.0, -PI / 2.0 + TAU * fmod(_t * 0.3, 1.0), 40, cor, 6.0)
			var f := get_theme_default_font()
			var txt := "2x" if dobro else "+300"
			draw_string_outline(f, Vector2(0, c.y + 14), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40 if dobro else 32, 10, Color(0.05, 0.1, 0.15))
			draw_string(f, Vector2(0, c.y + 14), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40 if dobro else 32, Color(1, 1, 1))
			draw_string(f, Vector2(0, c.y + 38), "XP", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, cor)
		"skin":
			var tex := _rosto
			if tex:
				draw_circle(c, 56, Color(1, 0.8, 0.25, 0.25 + 0.1 * sin(_t * 3.0)))
				draw_texture_rect(tex, Rect2(c - Vector2(50, 50), Vector2(100, 100)), false)
