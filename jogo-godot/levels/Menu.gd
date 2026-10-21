extends Control
## Seleção de personagem no estilo Happy Wheels: rostos em quadros no topo,
## o escolhido grande em cima da pedra, ✓ pra confirmar.

const OPCOES := ["segway", "cadeira", "scooter"]
const SLOTS := 7                    # quadros vazios = personagens que ainda vão vir

var atual := 0
var preview: TextureRect
var quadros: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.motor(false)
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x / 2.0                    # tela larga: tudo centralizado na largura real
	atual = maxi(0, OPCOES.find(Game.personagem))
	var fundo := TextureRect.new()
	fundo.texture = load("res://assets/ui/fundo.png")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(fundo)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(20, 14)
	logo.size = Vector2(250, 136)
	add_child(logo)

	var lado := 100.0
	var x0 := cx - (SLOTS * (lado + 12) - 12) / 2.0 + 60
	for i in SLOTS:
		var q := Panel.new()
		q.position = Vector2(x0 + i * (lado + 12), 24)
		q.size = Vector2(lado, lado)
		add_child(q)
		if i < OPCOES.size():
			var b := TextureButton.new()
			b.ignore_texture_size = true
			b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			b.set_anchors_preset(Control.PRESET_FULL_RECT)
			b.offset_left = 6; b.offset_top = 6; b.offset_right = -6; b.offset_bottom = -6
			b.pressed.connect(_selecionar.bind(i))
			q.add_child(b)
		quadros.append(q)

	var pedra := TextureRect.new()
	pedra.texture = load("res://assets/ui/pedra.png")
	pedra.position = Vector2(cx - 300, vp.y - 130)
	add_child(pedra)

	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.position = Vector2(640 - 260, 168)
	preview.size = Vector2(520, 440)
	add_child(preview)

	var ok := _botao("confirma", Vector2(vp.x - 175, vp.y - 165), 140)
	ok.pressed.connect(_jogar)
	_atualizar()

	if "screenshot" in OS.get_cmdline_user_args():
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://menu.png")
		get_tree().quit()

func _botao(icone: String, pos: Vector2, tam: float) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/ui/%s.png" % icone)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = pos
	b.size = Vector2(tam, tam)
	add_child(b)
	return b

func _estilo(destaque: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.16 if destaque else 0.06)
	s.set_border_width_all(5 if destaque else 3)
	s.border_color = Color(1, 1, 1, 0.95 if destaque else 0.35)
	s.shadow_color = Color(1, 1, 1, 0.45 if destaque else 0.0)
	s.shadow_size = 10 if destaque else 0
	return s

func _atualizar() -> void:
	for i in quadros.size():
		var q: Panel = quadros[i]
		q.add_theme_stylebox_override("panel", _estilo(i == atual))
		if i < OPCOES.size():
			var b: TextureButton = q.get_child(0)
			var nome: String = OPCOES[i] if i == atual else OPCOES[i] + "_cinza"
			b.texture_normal = load("res://assets/ui/rosto_%s.png" % nome)
	var tex: Texture2D = load("res://assets/menu/%s.png" % OPCOES[atual])
	preview.texture = tex
	var h := minf(440.0, 560.0 * tex.get_height() / tex.get_width())     # cabe em 560x440
	preview.size = Vector2(h * tex.get_width() / tex.get_height(), h)
	var vp := get_viewport().get_visible_rect().size
	preview.position = Vector2(vp.x / 2.0 - preview.size.x / 2.0, vp.y - 108 - h)   # em pé na pedra

func _selecionar(i: int) -> void:
	Audio.tocar("clique")
	atual = i
	_atualizar()

func _jogar() -> void:
	Audio.tocar("confirma")
	Game.personagem = OPCOES[atual]
	Game.checkpoint_x = -1.0
	get_tree().change_scene_to_file("res://levels/Main.tscn")
