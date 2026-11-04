extends Control
## Escolha de fase em carrossel: a do meio grande, as do lado menores. Arrasta, setas ou toca na do lado.

const ROXO := Color(0.6, 0.38, 1.0)
const OURO := Color(1.0, 0.8, 0.25)
const VERDE := Color(0.5, 1, 0.55)

var cartoes: Array = []
var titulo: Label
var voltar: Button
var logo: TextureRect
var online: Button
var jogar: Button
var b_esq: Button
var b_dir: Button
var pontos: Array = []
var _pos := 0.0                 # índice (float) da fase no meio
var _alvo := 0.0
var _arrastando := false
var _moveu := 0.0
var _ult_x := 0.0
var _vel := 0.0
var _t := 0.0
var _larg := 560.0              # largura do cartão do meio

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
	logo.position = Vector2(18, 10)
	logo.size = Vector2(190, 102)
	add_child(logo)
	titulo = _rotulo("ESCOLHER FASE", 52, 14, Color.WHITE)
	titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.5))
	titulo.add_theme_color_override("font_shadow_color", Color(0.55, 0.3, 1.0, 0.8))
	titulo.add_theme_constant_override("shadow_offset_x", 0)
	titulo.add_theme_constant_override("shadow_offset_y", 6)
	add_child(titulo)
	for id in Game.ORDEM:
		cartoes.append(_cartao(id))
	for i in Game.ORDEM.size():
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		pontos.append(p)
	b_esq = _botao("‹", ROXO, 54, func() -> void: _ir(roundi(_alvo) - 1))
	b_dir = _botao("›", ROXO, 54, func() -> void: _ir(roundi(_alvo) + 1))
	jogar = _botao("▶  JOGAR", Color(1.0, 0.92, 0.6), 40, _jogar_atual)
	var sj := jogar.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	sj.bg_color = Color(1.0, 0.74, 0.18)
	sj.border_width_bottom = 7
	sj.border_color = Color(0.75, 0.45, 0.05)
	sj.shadow_color = Color(1.0, 0.7, 0.2, 0.5)
	sj.shadow_size = 18
	for k in ["normal", "hover", "pressed"]:
		jogar.add_theme_stylebox_override(k, sj)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		jogar.add_theme_color_override(k, Color(0.2, 0.06, 0.32))
	voltar = _botao("‹ VOLTAR", ROXO, 28, func() -> void: get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	online = _botao("JOGAR ONLINE", OURO, 28, func() -> void: get_tree().change_scene_to_file("res://levels/Sala.tscn"))
	var i0 := Game.ORDEM.find(Game.fase)
	_pos = float(maxi(i0, 0))
	_alvo = _pos
	get_viewport().size_changed.connect(_layout)
	_layout()
	if "screenshot" in OS.get_cmdline_user_args():
		for k in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://fases.png")
		get_tree().quit()

func _cartao(n: int) -> Panel:
	var c := Panel.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(560, 430)
	c.pivot_offset = c.size / 2.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.05, 0.18, 0.95)
	st.set_corner_radius_all(22)
	st.set_border_width_all(4)
	st.border_color = ROXO
	st.shadow_color = Color(0.6, 0.38, 1.0, 0.4)
	st.shadow_size = 16
	c.add_theme_stylebox_override("panel", st)
	c.set_meta("estilo", st)
	var mini := TextureRect.new()
	mini.texture = load("res://assets/ui/fase_%d.png" % n)
	mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mini.position = Vector2(14, 14)
	mini.size = Vector2(532, 299)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(mini)
	var partes := Game.nome_fase(n).split(": ", true, 1)
	var num := _rotulo(partes[0], 20, 0, Color(0.06, 0.03, 0.1))
	var sn := StyleBoxFlat.new()
	sn.bg_color = OURO
	sn.corner_radius_top_left = 12
	sn.corner_radius_bottom_right = 12
	sn.content_margin_left = 14
	sn.content_margin_right = 14
	num.add_theme_stylebox_override("normal", sn)
	num.position = Vector2(14, 14)
	num.size = Vector2(0, 34)
	num.visible = partes.size() > 1
	c.add_child(num)
	var nome := _rotulo(partes[1] if partes.size() > 1 else partes[0], 40, 10, Color.WHITE)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.position = Vector2(22, 318)
	nome.size = Vector2(516, 56)
	nome.clip_text = true
	c.add_child(nome)
	var r := Game.recorde(n)
	var rec := _rotulo(("✓ SEU MELHOR TEMPO: %.1f s" % r) if r < INF else "AINDA NÃO TERMINOU", 22, 6,
		VERDE if r < INF else Color(0.8, 0.72, 0.95, 0.8))
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rec.position = Vector2(22, 374)
	rec.size = Vector2(516, 36)
	c.add_child(rec)
	add_child(c)
	return c

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	titulo.position = Vector2(0, 18)
	titulo.size = Vector2(v.x, 70)
	_larg = clampf(minf(v.x * 0.44, (v.y - 290.0) / 430.0 * 560.0), 300.0, 620.0)
	jogar.size = Vector2(340, 84)
	jogar.position = Vector2((v.x - jogar.size.x) / 2.0, v.y - 104)
	b_esq.size = Vector2(76, 96)
	b_dir.size = Vector2(76, 96)
	b_esq.position = Vector2(24, _centro().y - 48)
	b_dir.position = Vector2(v.x - 100, _centro().y - 48)
	voltar.size = Vector2(200, 62)
	voltar.position = Vector2(24, v.y - 86)
	online.size = Vector2(250, 62)
	online.position = Vector2(v.x - 274, v.y - 86)
	_posicionar()

func _centro() -> Vector2:
	var v := get_viewport().get_visible_rect().size
	var esc := _larg / 560.0
	return Vector2(v.x / 2.0, 100.0 + 430.0 * esc / 2.0)

func _posicionar() -> void:
	var esc := _larg / 560.0
	var c0 := _centro()
	for i in cartoes.size():
		var c: Panel = cartoes[i]
		var d := float(i) - _pos
		var ad := absf(d)
		var s := esc * maxf(0.35, 1.0 - 0.38 * minf(ad, 1.0) - 0.15 * maxf(0.0, ad - 1.0))
		c.scale = Vector2(s, s)
		var x := c0.x + signf(d) * (minf(ad, 1.0) * _larg * 0.78 + maxf(0.0, ad - 1.0) * _larg * 0.42)
		c.position = Vector2(x, c0.y) - c.pivot_offset
		c.modulate = Color(1, 1, 1, clampf(1.6 - ad * 0.55, 0.0, 1.0)) * Color(1.0 - minf(ad, 1.0) * 0.35, 1.0 - minf(ad, 1.0) * 0.35, 1.0 - minf(ad, 1.0) * 0.3, 1)
		c.visible = ad < 3.2
		c.z_index = 10 - int(round(ad * 2.0))
		var st: StyleBoxFlat = c.get_meta("estilo")
		var meio := ad < 0.5
		st.border_color = OURO if meio else ROXO
		st.shadow_color = Color(1, 0.75, 0.2, 0.35 + 0.25 * absf(sin(_t * 3.0))) if meio else Color(0.6, 0.38, 1.0, 0.3)
		st.shadow_size = 24 if meio else 10
	var atual := clampi(roundi(_pos), 0, cartoes.size() - 1)
	var v := get_viewport().get_visible_rect().size
	var larg_p := 14.0
	var y_p := c0.y + 430.0 * esc / 2.0 + 14.0
	var x0 := v.x / 2.0 - (pontos.size() * (larg_p + 10.0) - 10.0) / 2.0
	for i in pontos.size():
		var p: Panel = pontos[i]
		var sp := StyleBoxFlat.new()
		sp.bg_color = OURO if i == atual else Color(1, 1, 1, 0.3)
		sp.set_corner_radius_all(7)
		p.add_theme_stylebox_override("panel", sp)
		var w := 34.0 if i == atual else larg_p
		p.size = Vector2(w, larg_p)
		p.position = Vector2(x0 + i * (larg_p + 10.0) - (10.0 if i > atual else 0.0) + (0.0 if i <= atual else 20.0) - (0.0 if i != atual else 0.0), y_p)
	jogar.text = "▶  JOGAR FASE %d" % Game.ORDEM[atual] if Game.ORDEM[atual] <= 10 else "▶  JOGAR"
	b_esq.modulate.a = 0.3 if _alvo <= 0.0 else 1.0
	b_dir.modulate.a = 0.3 if _alvo >= cartoes.size() - 1 else 1.0

func _process(delta: float) -> void:
	_t += delta
	if not _arrastando:
		_pos = lerpf(_pos, _alvo, minf(1.0, delta * 11.0))
		if absf(_pos - _alvo) < 0.002:
			_pos = _alvo
	_posicionar()

func _ir(i: int) -> void:
	var novo := clampi(i, 0, cartoes.size() - 1)
	if novo != roundi(_alvo):
		Audio.tocar("clique")
	_alvo = float(novo)

func _jogar_atual() -> void:
	var n: int = Game.ORDEM[clampi(roundi(_alvo), 0, cartoes.size() - 1)]
	Audio.tocar("confirma")
	Game.fase = n
	Game.checkpoint_x = -1.0
	get_tree().change_scene_to_file("res://levels/Main.tscn")

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode in [KEY_LEFT, KEY_A]:
			_ir(roundi(_alvo) - 1)
		elif ev.keycode in [KEY_RIGHT, KEY_D]:
			_ir(roundi(_alvo) + 1)
		elif ev.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_jogar_atual()
		return
	var pos := Vector2.ZERO
	var apertou := false
	var soltou := false
	var moveu := false
	if ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_ir(roundi(_alvo) + (-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
		return
	elif ev is InputEventScreenDrag or ev is InputEventMouseMotion:
		pos = ev.position
		moveu = true
	var esc := _larg / 560.0
	var c0 := _centro()
	var faixa := Rect2(Vector2(110, c0.y - 215.0 * esc), Vector2(get_viewport().get_visible_rect().size.x - 220, 430.0 * esc))
	if apertou:
		if not faixa.has_point(pos):
			return
		_arrastando = true
		_ult_x = pos.x
		_moveu = 0.0
		_vel = 0.0
	elif moveu and _arrastando:
		var dx := pos.x - _ult_x
		_ult_x = pos.x
		_moveu += absf(dx)
		_pos = clampf(_pos - dx / (_larg * 0.78), -0.4, cartoes.size() - 0.6)
		_vel = -dx / (_larg * 0.78) / maxf(get_process_delta_time(), 0.001)
	elif soltou and _arrastando:
		_arrastando = false
		if _moveu < 14.0:                           # toque: no do meio joga, no do lado vai pra ele
			var lado := pos.x - c0.x
			if absf(lado) < _larg / 2.0:
				_jogar_atual()
			else:
				_ir(roundi(_alvo) + (1 if lado > 0 else -1))
		else:
			_ir(roundi(_pos + clampf(_vel * 0.12, -1.5, 1.5)))

func _botao(texto: String, borda: Color, tam: int, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", tam)
	var sv := StyleBoxFlat.new()
	sv.bg_color = Color(0.09, 0.05, 0.18, 0.88)
	sv.set_corner_radius_all(16)
	sv.set_border_width_all(3)
	sv.border_color = borda
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, sv)
	b.pressed.connect(func() -> void:
		Audio.tocar("clique")
		acao.call())
	b.z_index = 20
	add_child(b)
	return b

func _rotulo(texto: String, tamanho: int, contorno: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", contorno)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
