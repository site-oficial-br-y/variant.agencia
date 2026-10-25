extends Control
class_name Volume
## botão de volume (ícone de alto-falante): toca e abre a barrinha pra ajustar.
## Mexe no volume geral (bus Master) e fica salvo no progresso.

var abre_direita := false              # menu: barrinha abre do lado (embaixo não cabe)
var _painel: PanelContainer
var _barra: HSlider
var _rotulo: Label

func _ready() -> void:
	custom_minimum_size = Vector2(80, 64)
	size = custom_minimum_size
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_painel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.04, 0.12, 0.92)
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = Color(1, 1, 1, 0.5)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	_painel.add_theme_stylebox_override("panel", st)
	_painel.visible = false
	_painel.position = Vector2(92, -6) if abre_direita else Vector2(80 - 360, 74)
	_painel.custom_minimum_size = Vector2(360, 0)
	add_child(_painel)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	_painel.add_child(linha)
	_barra = HSlider.new()
	_barra.min_value = 0
	_barra.max_value = 100
	_barra.step = 5
	_barra.value = round(Game.volume() * 100.0)
	_barra.custom_minimum_size = Vector2(230, 56)
	_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barra.focus_mode = Control.FOCUS_NONE
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color(1, 1, 1, 0.18)
	trilho.set_corner_radius_all(6)
	trilho.content_margin_top = 6
	trilho.content_margin_bottom = 6
	var cheio := trilho.duplicate() as StyleBoxFlat
	cheio.bg_color = Color(0.95, 0.45, 0.75)
	_barra.add_theme_stylebox_override("slider", trilho)
	_barra.add_theme_stylebox_override("grabber_area", cheio)
	_barra.add_theme_stylebox_override("grabber_area_highlight", cheio)
	var bola := _bola()
	_barra.add_theme_icon_override("grabber", bola)
	_barra.add_theme_icon_override("grabber_highlight", bola)
	_barra.value_changed.connect(_mudou)
	linha.add_child(_barra)
	_rotulo = Label.new()
	_rotulo.custom_minimum_size = Vector2(64, 0)
	_rotulo.add_theme_font_size_override("font_size", 26)
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo.size_flags_vertical = Control.SIZE_FILL
	_rotulo.text = "%d%%" % int(_barra.value)
	linha.add_child(_rotulo)

func _bola() -> ImageTexture:
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(n, n) / 2.0)
			var a := clampf(n / 2.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _mudou(v: float) -> void:
	Game.set_volume(v / 100.0)
	_rotulo.text = "%d%%" % int(v)
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	var apertou := false
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		apertou = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		pos = mb.position
	elif ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		apertou = st.pressed and st.device != InputEvent.DEVICE_ID_EMULATION
		pos = st.position
	if apertou and Rect2(Vector2.ZERO, custom_minimum_size).has_point(pos):
		accept_event()
		if Time.get_ticks_msec() - int(get_meta("ult", 0)) < 250:   # clique chega como toque + mouse
			return
		set_meta("ult", Time.get_ticks_msec())
		_painel.visible = not _painel.visible
		Audio.tocar("clique")

func _has_point(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, custom_minimum_size).has_point(p)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, custom_minimum_size)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.35)
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = Color(1, 1, 1, 0.5)
	draw_style_box(st, r)
	var c := r.get_center() + Vector2(-8, 0)
	var branco := Color.WHITE
	draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -7), c + Vector2(-8, -7), c + Vector2(4, -17),
		c + Vector2(4, 17), c + Vector2(-8, 7), c + Vector2(-16, 7)]), branco)
	var v := Game.volume()
	if v <= 0.001:
		draw_line(c + Vector2(12, -9), c + Vector2(28, 9), Color(1, 0.35, 0.35), 4.0)
		draw_line(c + Vector2(12, 9), c + Vector2(28, -9), Color(1, 0.35, 0.35), 4.0)
		return
	for k in 3:
		if v > k / 3.0:
			draw_arc(c + Vector2(4, 0), 10.0 + k * 8.0, -0.85, 0.85, 12, branco, 3.5)
