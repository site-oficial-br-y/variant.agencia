extends Control
## Escolha de fase: cartões com miniatura, nome e recorde.

var cartoes: Array = []
var titulo: Label
var voltar: Button
var logo: TextureRect

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := TextureRect.new()                   # mesmo fundo do lobby (arena roxa + névoa)
	fundo.texture = load("res://assets/ui/lobby.jpg")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(fundo)
	var nevoa := ColorRect.new()
	nevoa.set_anchors_preset(Control.PRESET_FULL_RECT)
	nevoa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/ui/nevoa.gdshader")
	nevoa.material = mat
	add_child(nevoa)
	logo = TextureRect.new()
	logo.texture = load("res://assets/ui/logo_roxo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(22, 14)
	logo.size = Vector2(270, 145)
	add_child(logo)
	titulo = Label.new()
	titulo.text = "ESCOLHER FASE"
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.5))
	titulo.add_theme_constant_override("outline_size", 16)
	titulo.add_theme_color_override("font_shadow_color", Color(0.55, 0.3, 1.0, 0.8))
	titulo.add_theme_constant_override("shadow_offset_x", 0)
	titulo.add_theme_constant_override("shadow_offset_y", 6)
	add_child(titulo)
	for i in Game.FASES.size():
		cartoes.append(_cartao(i + 1))
	voltar = Button.new()
	voltar.text = "‹ VOLTAR"
	voltar.focus_mode = Control.FOCUS_NONE
	voltar.add_theme_font_size_override("font_size", 30)
	var sv := StyleBoxFlat.new()
	sv.bg_color = Color(0.09, 0.05, 0.18, 0.85)
	sv.set_corner_radius_all(14)
	sv.set_border_width_all(3)
	sv.border_color = Color(0.6, 0.38, 1.0)
	sv.content_margin_left = 22
	sv.content_margin_right = 22
	sv.content_margin_top = 8
	sv.content_margin_bottom = 8
	voltar.add_theme_stylebox_override("normal", sv)
	voltar.add_theme_stylebox_override("hover", sv)
	voltar.add_theme_stylebox_override("pressed", sv)
	voltar.pressed.connect(func() -> void:
		Audio.tocar("clique")
		get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	add_child(voltar)
	get_viewport().size_changed.connect(_layout)
	_layout()
	if "screenshot" in OS.get_cmdline_user_args():
		for k in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://fases.png")
		get_tree().quit()

func _cartao(n: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(196, 250)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.05, 0.18, 0.85)
	st.set_corner_radius_all(18)
	st.set_border_width_all(3)
	st.border_color = Color(0.6, 0.38, 1.0)
	st.shadow_color = Color(0.6, 0.38, 1.0, 0.35)
	st.shadow_size = 10
	b.add_theme_stylebox_override("normal", st)
	var st2 := st.duplicate() as StyleBoxFlat
	st2.border_color = Color(1, 0.8, 0.25)
	st2.bg_color = Color(0.3, 0.17, 0.6, 0.85)
	st2.shadow_color = Color(1, 0.75, 0.2, 0.55)
	st2.shadow_size = 14
	b.add_theme_stylebox_override("hover", st2)
	b.add_theme_stylebox_override("pressed", st2)
	var mini := TextureRect.new()
	mini.texture = load("res://assets/ui/fase_%d.png" % n)
	mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mini.position = Vector2(14, 14)
	mini.size = Vector2(172, 97)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(mini)
	var nome := Label.new()
	nome.text = Game.FASES[n - 1]
	nome.position = Vector2(10, 118)
	nome.add_theme_font_size_override("font_size", 17)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nome)
	var rec := Label.new()
	var r := Game.recorde(n)
	rec.text = ("✓ melhor: %.1f s" % r) if r < INF else "ainda não terminou"
	rec.add_theme_color_override("font_color", Color(0.5, 1, 0.55) if r < INF else Color(0.8, 0.72, 0.95, 0.7))
	rec.position = Vector2(10, 190)
	rec.add_theme_font_size_override("font_size", 15)
	rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(rec)
	b.pressed.connect(func() -> void:
		Audio.tocar("confirma")
		Game.fase = n
		Game.checkpoint_x = -1.0
		get_tree().change_scene_to_file("res://levels/Main.tscn"))
	add_child(b)
	return b

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	titulo.position = Vector2((v.x - titulo.get_minimum_size().x) / 2.0, 150)
	var esc := minf(1.0, (v.x - 40.0) / (cartoes.size() * 206.0))   # muitas fases: cartões encolhem pra caber
	var larg := 196.0 * esc
	var esp := 10.0 * esc
	var total := cartoes.size() * larg + (cartoes.size() - 1) * esp
	for i in cartoes.size():
		(cartoes[i] as Button).scale = Vector2.ONE * esc
		(cartoes[i] as Button).position = Vector2((v.x - total) / 2.0 + i * (larg + esp), v.y / 2.0 - 140)
	voltar.position = Vector2(30, v.y - 90)
