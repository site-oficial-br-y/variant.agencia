extends Control
## Abertura: cenário do jogo, os personagens em fila, logo entrando com quique e
## "toque pra começar". Qualquer toque/tecla leva à escolha de personagem.

var logo: TextureRect
var toque: Label
var gente: Array = []
var morros: Array = []
var _saindo := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.motor(false)
	var ceu := ColorRect.new()
	ceu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ceu.color = Color(0.36, 0.58, 0.95)
	add_child(ceu)
	for k in 3:
		var n := TextureRect.new()
		n.texture = load("res://assets/ui/nuvem%d.png" % k)
		n.modulate = Color(1, 1, 1, 0.95)
		add_child(n)
		morros.append(n)
	for nome in ["morros_longe", "morros_perto"]:
		var m := TextureRect.new()
		m.texture = load("res://assets/ui/%s.png" % nome)
		m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(m)
		morros.append(m)
	var chao := ColorRect.new()
	chao.color = Color(0.42, 0.23, 0.09)
	add_child(chao)
	morros.append(chao)
	var faixa := ColorRect.new()
	faixa.color = Color(0.2, 0.18, 0.19)
	add_child(faixa)
	morros.append(faixa)
	for p in ["cadeira", "segway", "scooter"]:
		var t := TextureRect.new()
		t.texture = load("res://assets/menu/%s.png" % p)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(t)
		gente.append(t)
	logo = TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(logo)
	toque = Label.new()
	toque.text = "TOQUE PRA COMEÇAR"
	toque.add_theme_font_size_override("font_size", 46)
	toque.add_theme_color_override("font_outline_color", Color.BLACK)
	toque.add_theme_constant_override("outline_size", 12)
	add_child(toque)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# logo entra caindo e quica; texto pisca
	logo.pivot_offset = logo.size / 2.0
	logo.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(logo, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var pisca := create_tween().set_loops()
	pisca.tween_property(toque, "modulate:a", 0.25, 0.6)
	pisca.tween_property(toque, "modulate:a", 1.0, 0.6)
	if "screenshot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://abertura.png")
		get_tree().quit()

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	var nuvens := [Vector2(0.08, 0.06), Vector2(0.62, 0.02), Vector2(0.38, 0.22)]
	for k in 3:
		(morros[k] as TextureRect).position = Vector2(v.x * nuvens[k].x, v.y * nuvens[k].y)
	(morros[3] as TextureRect).position = Vector2(0, v.y * 0.36)
	(morros[3] as TextureRect).size = Vector2(v.x, v.y * 0.5)
	(morros[4] as TextureRect).position = Vector2(0, v.y * 0.48)
	(morros[4] as TextureRect).size = Vector2(v.x, v.y * 0.5)
	(morros[5] as ColorRect).position = Vector2(0, v.y * 0.84)
	(morros[5] as ColorRect).size = Vector2(v.x, v.y * 0.2)
	(morros[6] as ColorRect).position = Vector2(0, v.y * 0.84)
	(morros[6] as ColorRect).size = Vector2(v.x, 18)
	var alt := v.y * 0.46
	var xs := [0.2, 0.5, 0.8]
	for i in gente.size():
		var t: TextureRect = gente[i]
		var tex := t.texture
		var w := alt * tex.get_width() / tex.get_height()
		t.size = Vector2(w, alt)
		t.position = Vector2(v.x * xs[i] - w / 2.0, v.y * 0.84 - alt)
	logo.size = Vector2(v.x * 0.42, v.y * 0.36)
	logo.position = Vector2((v.x - logo.size.x) / 2.0, v.y * 0.02)
	logo.pivot_offset = logo.size / 2.0
	toque.position = Vector2((v.x - toque.get_minimum_size().x) / 2.0, v.y * 0.86)

func _input(e: InputEvent) -> void:
	var tocou: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed) \
		or (e is InputEventKey and e.pressed)
	if tocou and not _saindo:
		_saindo = true
		Audio.tocar("confirma")
		get_tree().change_scene_to_file("res://levels/Menu.tscn")
