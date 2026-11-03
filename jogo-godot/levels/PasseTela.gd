extends Control
## Tela do passe de batalha: nível da conta, barra de XP e a trilha com os 50 níveis.
## A trilha é rolada arrastando (com embalo) ou pelas setas; tocar sem arrastar mostra o item.
## Equipar fica no INVENTÁRIO.

const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.9)
const OURO := Color(1.0, 0.8, 0.25)
const CARTAO := Vector2(176, 250)
const PASSO := 196.0                       # cartão + espaço

var fundo: TextureRect
var titulo: Label
var b_voltar: Button
var b_inv: Button
var nivel_lbl: Label
var barra_fundo: Panel
var barra: Panel
var xp_lbl: Label
var dica: Label
var dobro_lbl: Label
var janela: Control                        # área da trilha (corta o que sai)
var trilha: Control
var cartoes: Array = []
var b_esq: Button
var b_dir: Button
var detalhe: Label

var _rol := 0.0                           # quanto a trilha está rolada (px)
var _vel := 0.0
var _arrastando := false
var _moveu := 0.0
var _ult_x := 0.0
var _alvo := -1.0                          # rolagem animada pelas setas

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo = TextureRect.new()
	fundo.texture = load("res://assets/ui/lobby.jpg")
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.modulate = Color(0.55, 0.5, 0.7)
	add_child(fundo)
	titulo = _rotulo("PASSE DE BATALHA", 52, 16, Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(titulo)
	b_voltar = _botao("‹ VOLTAR", ROXO, func() -> void:
		Audio.tocar("clique")
		get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	b_inv = _botao("INVENTÁRIO", OURO, func() -> void:
		Audio.tocar("clique")
		get_tree().change_scene_to_file("res://levels/Inventario.tscn"))
	nivel_lbl = _rotulo("", 40, 12, OURO)
	nivel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(nivel_lbl)
	barra_fundo = Panel.new()
	barra_fundo.add_theme_stylebox_override("panel", _caixa(ROXO, 12, Color(0.05, 0.03, 0.1, 0.9)))
	add_child(barra_fundo)
	barra = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.85, 1.0)
	sb.set_corner_radius_all(9)
	barra.add_theme_stylebox_override("panel", sb)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_fundo.add_child(barra)
	xp_lbl = _rotulo("", 22, 6, Color.WHITE)
	barra_fundo.add_child(xp_lbl)
	dobro_lbl = _rotulo("", 24, 8, Color(0.45, 0.9, 1.0))
	dobro_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(dobro_lbl)
	dica = _rotulo("", 19, 6, Color(0.85, 0.82, 0.95))
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(dica)
	janela = Control.new()
	janela.clip_contents = true
	janela.mouse_filter = Control.MOUSE_FILTER_STOP
	janela.gui_input.connect(_toque)
	add_child(janela)
	trilha = Control.new()
	trilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trilha.draw.connect(_linha_progresso)
	janela.add_child(trilha)
	for it in Passe.ITENS:
		var c := _cartao(it)
		trilha.add_child(c)
		cartoes.append(c)
	b_esq = _botao("‹", ROXO, func() -> void: _pular(-4))
	b_dir = _botao("›", ROXO, func() -> void: _pular(4))
	for b in [b_esq, b_dir]:
		b.add_theme_font_size_override("font_size", 44)
	detalhe = _rotulo("Arrasta pro lado pra ver os níveis · toca num cartão pra ver o que é", 22, 8, Color(0.85, 0.82, 0.95))
	add_child(detalhe)
	Passe.mudou.connect(_atualizar)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_rol = _rol_do_nivel(Passe.nivel())
	_atualizar()
	Passe.atualizar()

func _cartao(it: Array) -> Panel:
	var b := Panel.new()
	b.size = CARTAO
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("id", it[1])
	var nv := _rotulo("NÍVEL %d" % it[0], 22, 6, Color(0.9, 0.9, 1.0))
	nv.position = Vector2(0, 8)
	nv.size = Vector2(CARTAO.x, 30)
	b.add_child(nv)
	var ic := IconeItem.new()
	ic.item = it
	ic.position = Vector2(CARTAO.x / 2.0 - 56, 40)
	ic.size = Vector2(112, 112)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var tipo := _rotulo(Passe.TIPOS.get(it[3], ""), 16, 4, it[4])
	tipo.position = Vector2(0, 154)
	tipo.size = Vector2(CARTAO.x, 22)
	b.add_child(tipo)
	var nome := _rotulo(it[2], 19, 6, Color.WHITE)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.position = Vector2(8, 174)
	nome.size = Vector2(CARTAO.x - 16, 46)
	b.add_child(nome)
	var est := _rotulo("", 17, 5, Color.WHITE)
	est.name = "estado"
	est.position = Vector2(0, 220)
	est.size = Vector2(CARTAO.x, 24)
	b.add_child(est)
	return b

# ---------- rolagem por toque ----------
func _max_rol() -> float:
	return maxf(0.0, cartoes.size() * PASSO - janela.size.x + 10.0)

func _rol_do_nivel(n: int) -> float:
	return clampf((n - 1) * PASSO - janela.size.x / 2.0 + CARTAO.x / 2.0, 0.0, _max_rol())

func _pular(d: int) -> void:
	Audio.tocar("clique")
	_alvo = clampf(_rol + d * PASSO, 0.0, _max_rol())
	_vel = 0.0

func _toque(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	var apertou := false
	var soltou := false
	var moveu := false
	if ev is InputEventScreenTouch:
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_alvo = clampf(_rol + (-PASSO if ev.button_index == MOUSE_BUTTON_WHEEL_UP else PASSO), 0.0, _max_rol())
		return
	elif ev is InputEventScreenDrag or ev is InputEventMouseMotion:
		pos = ev.position
		moveu = true
	if apertou:
		_arrastando = true
		_ult_x = pos.x
		_moveu = 0.0
		_vel = 0.0
		_alvo = -1.0
	elif moveu and _arrastando:
		var dx := pos.x - _ult_x
		_ult_x = pos.x
		_moveu += absf(dx)
		_rol = clampf(_rol - dx, -60.0, _max_rol() + 60.0)
		_vel = -dx / maxf(get_process_delta_time(), 0.001)
	elif soltou and _arrastando:
		_arrastando = false
		if _moveu < 14.0:                               # foi um toque, não arrasto
			_vel = 0.0
			var x := pos.x + _rol
			var i := int(x / PASSO)
			if i >= 0 and i < cartoes.size() and fmod(x, PASSO) <= CARTAO.x:
				_tocou(cartoes[i])

func _process(delta: float) -> void:
	if not _arrastando:
		if _alvo >= 0.0:
			_rol = lerpf(_rol, _alvo, minf(1.0, delta * 10.0))
			if absf(_rol - _alvo) < 1.0:
				_rol = _alvo
				_alvo = -1.0
		else:
			_rol += _vel * delta                        # embalo
			_vel = lerpf(_vel, 0.0, minf(1.0, delta * 4.0))
			if _rol < 0.0:
				_rol = lerpf(_rol, 0.0, minf(1.0, delta * 12.0))
				_vel = 0.0
			elif _rol > _max_rol():
				_rol = lerpf(_rol, _max_rol(), minf(1.0, delta * 12.0))
				_vel = 0.0
	trilha.position.x = -_rol
	b_esq.modulate.a = 0.35 if _rol <= 1.0 else 1.0
	b_dir.modulate.a = 0.35 if _rol >= _max_rol() - 1.0 else 1.0
	var r := Passe.dobro_resta()
	dobro_lbl.text = ("XP EM DOBRO: %d:%02d" % [r / 60, r % 60]) if r > 0 else ""

func _tocou(c: Panel) -> void:
	var it := Passe.item(c.get_meta("id"))
	Audio.tocar("clique")
	var lib := Passe.liberado(it[1])
	var txt := "NÍVEL %d · %s" % [it[0], it[2]]
	if it[3] == "bonus":
		txt += " — " + ("já recebido" if lib else "você ganha ao chegar nesse nível")
	elif it[3] == "skin":
		txt += " — " + ("chega em breve" if lib else "libera no nível %d" % it[0])
	elif lib:
		txt += " — liberado! Equipa no INVENTÁRIO"
	else:
		txt += " — faltam %d níveis" % (int(it[0]) - Passe.nivel())
	detalhe.text = txt
	detalhe.add_theme_color_override("font_color", it[4])
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 1.06, 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12)

## linha embaixo dos cartões ligando os níveis (acesa até o nível atual)
func _linha_progresso() -> void:
	var y := CARTAO.y + 26.0
	var fim := (cartoes.size() - 1) * PASSO + CARTAO.x / 2.0
	trilha.draw_line(Vector2(CARTAO.x / 2.0, y), Vector2(fim, y), Color(0.25, 0.2, 0.35), 10.0)
	var ate := (Passe.nivel() - 1) * PASSO + CARTAO.x / 2.0
	trilha.draw_line(Vector2(CARTAO.x / 2.0, y), Vector2(minf(ate, fim), y), OURO, 10.0)
	for i in cartoes.size():
		var x := i * PASSO + CARTAO.x / 2.0
		var feito := i + 1 <= Passe.nivel()
		trilha.draw_circle(Vector2(x, y), 14.0 if i + 1 == Passe.nivel() else 10.0, OURO if feito else Color(0.35, 0.3, 0.45))

func _atualizar() -> void:
	var n := Passe.nivel()
	var pr: Array = Passe.progresso()
	nivel_lbl.text = "NÍVEL %d" % n
	xp_lbl.text = "%d / %d XP" % [pr[0], pr[1]]
	barra.size.x = maxf(18.0, (barra_fundo.size.x - 8.0) * float(pr[0]) / float(pr[1]))
	dica.text = ("XP: 10 por minuto · fase 50 (1ª vez 200) · chefe 150 (1ª vez 500) · recorde 100 · online até 120"
		if Conta.logado() else "Entra numa conta (MINHA CONTA no menu) pra ganhar XP e liberar os itens.")
	for c in cartoes:
		var id: String = c.get_meta("id")
		var it := Passe.item(id)
		var lib := Passe.liberado(id)
		var atual := int(it[0]) == n + 1
		var est: Label = c.get_node("estado")
		var cor: Color = it[4]
		if it[3] == "skin":
			est.text = "✓ NO INVENTÁRIO" if lib else "NÍVEL %d" % it[0]
		elif it[3] == "bonus":
			est.text = "✓ RECEBIDO" if lib else "BÔNUS"
		elif Passe.equipado(it[3]) == id:
			est.text = "✓ EQUIPADO"
		elif lib:
			est.text = "✓ LIBERADO"
		else:
			est.text = "PRÓXIMO" if atual else "BLOQUEADO"
		est.add_theme_color_override("font_color", Color(0.45, 1, 0.5) if lib else (OURO if atual else Color(0.6, 0.6, 0.7)))
		var st := _caixa(cor if lib else (OURO if atual else Color(0.35, 0.33, 0.42)), 18,
			Color(cor.r * 0.25, cor.g * 0.25, cor.b * 0.3, 0.92) if lib else Color(0.06, 0.05, 0.1, 0.9))
		if atual:
			st.set_border_width_all(5)
		if it[3] == "skin":
			st.set_border_width_all(5)
			st.border_color = OURO if lib else Color(0.75, 0.6, 0.25)
			st.bg_color = Color(0.25, 0.18, 0.04, 0.92)
		c.add_theme_stylebox_override("panel", st)
		c.modulate = Color.WHITE if lib or atual or it[3] == "skin" else Color(0.72, 0.72, 0.78)
	trilha.queue_redraw()

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	fundo.size = v
	titulo.position = Vector2(40, 20)
	titulo.size = Vector2(700, 64)
	b_voltar.position = Vector2(v.x - 220, 24)
	b_voltar.size = Vector2(180, 56)
	b_inv.position = Vector2(v.x - 430, 24)
	b_inv.size = Vector2(195, 56)
	nivel_lbl.position = Vector2(40, 92)
	nivel_lbl.size = Vector2(230, 50)
	barra_fundo.position = Vector2(250, 100)
	barra_fundo.size = Vector2(minf(560.0, v.x - 300.0), 36)
	barra.position = Vector2(4, 4)
	barra.size.y = 28
	xp_lbl.position = Vector2.ZERO
	xp_lbl.size = barra_fundo.size
	dobro_lbl.position = Vector2(barra_fundo.position.x + barra_fundo.size.x + 20, 100)
	dobro_lbl.size = Vector2(320, 36)
	dica.position = Vector2(40, 146)
	dica.size = Vector2(v.x - 80, 28)
	var y := maxf(190.0, v.y * 0.5 - CARTAO.y / 2.0 + 10.0)
	janela.position = Vector2(80, y)
	janela.size = Vector2(v.x - 160, CARTAO.y + 50)
	trilha.size = Vector2(cartoes.size() * PASSO, CARTAO.y + 50)
	for i in cartoes.size():
		(cartoes[i] as Panel).position = Vector2(i * PASSO, 0)
		(cartoes[i] as Panel).pivot_offset = CARTAO / 2.0
	b_esq.position = Vector2(12, y + CARTAO.y / 2.0 - 40)
	b_esq.size = Vector2(58, 80)
	b_dir.position = Vector2(v.x - 70, y + CARTAO.y / 2.0 - 40)
	b_dir.size = Vector2(58, 80)
	detalhe.position = Vector2(0, y + CARTAO.y + 56)
	detalhe.size = Vector2(v.x, 36)
	_atualizar()

func _caixa(borda: Color, raio: int, fundo_cor := ROXO_ESCURO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo_cor
	s.set_corner_radius_all(raio)
	s.set_border_width_all(3)
	s.border_color = borda
	return s

func _botao(texto: String, borda: Color, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	var st := _caixa(borda, 14)
	for k in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(k, st)
	b.pressed.connect(acao)
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
