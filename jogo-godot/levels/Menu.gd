extends Control
## Tela inicial: escolher o personagem e entrar no nível.

const OPCOES := [
	["segway", "O DO SEGWAY"],
	["cadeira", "O DA CADEIRA"],
	["scooter", "O DA SCOOTER"],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0.09, 0.08, 0.13)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	add_child(col)

	var titulo := Label.new()
	titulo.text = "CAPOTA BRASIL"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 56)
	titulo.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
	col.add_child(titulo)

	var sub := Label.new()
	sub.text = "escolhe o vacilão"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.modulate = Color(1, 1, 1, 0.6)
	col.add_child(sub)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 22)
	col.add_child(linha)

	var alt := get_viewport().get_visible_rect().size.y * 0.55
	for op in OPCOES:
		var caixa := VBoxContainer.new()
		caixa.add_theme_constant_override("separation", 6)
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/menu/%s.png" % op[0])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var tex: Texture2D = b.texture_normal
		b.custom_minimum_size = Vector2(alt * tex.get_width() / tex.get_height(), alt)
		b.pressed.connect(_escolher.bind(op[0]))
		caixa.add_child(b)
		var nome := Button.new()
		nome.text = op[1]
		nome.add_theme_font_size_override("font_size", 22)
		nome.pressed.connect(_escolher.bind(op[0]))
		caixa.add_child(nome)
		linha.add_child(caixa)

	if "screenshot" in OS.get_cmdline_user_args():
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://menu.png")
		get_tree().quit()

func _escolher(p: String) -> void:
	Game.personagem = p
	get_tree().change_scene_to_file("res://levels/Main.tscn")
