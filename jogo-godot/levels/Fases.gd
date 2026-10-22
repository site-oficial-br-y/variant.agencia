extends Control
## Escolha de fase: cartões com miniatura, nome e recorde.

var cartoes: Array = []
var titulo: Label
var voltar: Button

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := TextureRect.new()
	fundo.texture = load("res://assets/ui/fundo.png")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(fundo)
	titulo = Label.new()
	titulo.text = "ESCOLHE A FASE"
	titulo.add_theme_font_size_override("font_size", 60)
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 12)
	add_child(titulo)
	for i in Game.FASES.size():
		cartoes.append(_cartao(i + 1))
	voltar = Button.new()
	voltar.text = "‹ VOLTAR"
	voltar.focus_mode = Control.FOCUS_NONE
	voltar.add_theme_font_size_override("font_size", 30)
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
	b.custom_minimum_size = Vector2(340, 330)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.1)
	st.set_corner_radius_all(18)
	st.set_border_width_all(4)
	st.border_color = Color(1, 1, 1, 0.55)
	b.add_theme_stylebox_override("normal", st)
	var st2 := st.duplicate() as StyleBoxFlat
	st2.border_color = Color(1, 0.85, 0.3)
	st2.bg_color = Color(1, 1, 1, 0.2)
	b.add_theme_stylebox_override("hover", st2)
	b.add_theme_stylebox_override("pressed", st2)
	var mini := TextureRect.new()
	mini.texture = load("res://assets/ui/fase_%d.png" % n)
	mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mini.position = Vector2(14, 14)
	mini.size = Vector2(312, 176)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(mini)
	var nome := Label.new()
	nome.text = Game.FASES[n - 1]
	nome.position = Vector2(18, 200)
	nome.add_theme_font_size_override("font_size", 32)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nome)
	var rec := Label.new()
	var r := Game.recorde(n)
	rec.text = ("✓ melhor: %.1f s" % r) if r < INF else "ainda não terminou"
	rec.add_theme_color_override("font_color", Color(0.5, 1, 0.55) if r < INF else Color(1, 1, 1, 0.55))
	rec.position = Vector2(18, 250)
	rec.add_theme_font_size_override("font_size", 24)
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
	titulo.position = Vector2((v.x - titulo.get_minimum_size().x) / 2.0, 40)
	var larg := 340.0
	var esp := 34.0
	var total := cartoes.size() * larg + (cartoes.size() - 1) * esp
	for i in cartoes.size():
		(cartoes[i] as Button).position = Vector2((v.x - total) / 2.0 + i * (larg + esp), v.y / 2.0 - 140)
	voltar.position = Vector2(30, v.y - 90)
