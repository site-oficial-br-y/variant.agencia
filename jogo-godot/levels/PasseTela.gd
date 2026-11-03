extends Control
## Tela do passe de batalha: nível da conta, barra de XP e a trilha com os 30 níveis.
## Toca num item liberado pra equipar (ou tirar). Skins do passe chegam no nível delas.

const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.9)
const OURO := Color(1.0, 0.8, 0.25)
const CARTAO := Vector2(190, 270)

var fundo: TextureRect
var titulo: Label
var b_voltar: Button
var nivel_lbl: Label
var barra_fundo: Panel
var barra: Panel
var xp_lbl: Label
var dica: Label
var rolagem: ScrollContainer
var trilha: HBoxContainer
var cartoes: Array = []

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo = TextureRect.new()
	fundo.texture = load("res://assets/ui/lobby.jpg")
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.modulate = Color(0.55, 0.5, 0.7)
	add_child(fundo)
	titulo = _rotulo("PASSE DE BATALHA", 56, 16, Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(titulo)
	b_voltar = _botao("‹ VOLTAR", ROXO, func() -> void:
		Audio.tocar("clique")
		get_tree().change_scene_to_file("res://levels/Menu.tscn"))
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
	dica = _rotulo("", 20, 6, Color(0.85, 0.82, 0.95))
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(dica)
	rolagem = ScrollContainer.new()
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(rolagem)
	trilha = HBoxContainer.new()
	trilha.add_theme_constant_override("separation", 16)
	rolagem.add_child(trilha)
	for it in Passe.ITENS:
		var c := _cartao(it)
		trilha.add_child(c)
		cartoes.append(c)
	Passe.mudou.connect(_atualizar)
	get_viewport().size_changed.connect(_layout)
	_atualizar()
	_layout()
	Passe.atualizar()
	await get_tree().process_frame                 # começa mostrando o nível atual
	rolagem.scroll_horizontal = maxi(0, int((CARTAO.x + 16) * (Passe.nivel() - 2)))

func _cartao(it: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARTAO
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("id", it[1])
	b.pressed.connect(func() -> void:
		if Passe.liberado(it[1]) and it[3] != "skin":
			Passe.alternar(it[1])
			Audio.tocar("confirma")
		else:
			Audio.tocar("clique"))
	var nv := _rotulo("NÍVEL %d" % it[0], 22, 6, Color(0.9, 0.9, 1.0))
	nv.position = Vector2(0, 8)
	nv.size = Vector2(CARTAO.x, 30)
	b.add_child(nv)
	var ic := IconeItem.new()
	ic.item = it
	ic.position = Vector2(CARTAO.x / 2.0 - 60, 44)
	ic.size = Vector2(120, 120)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var tipo := _rotulo(Passe.TIPOS.get(it[3], ""), 16, 4, it[4])
	tipo.position = Vector2(0, 168)
	tipo.size = Vector2(CARTAO.x, 22)
	b.add_child(tipo)
	var nome := _rotulo(it[2], 20, 6, Color.WHITE)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.position = Vector2(8, 188)
	nome.size = Vector2(CARTAO.x - 16, 48)
	b.add_child(nome)
	var est := _rotulo("", 18, 5, Color.WHITE)
	est.name = "estado"
	est.position = Vector2(0, 238)
	est.size = Vector2(CARTAO.x, 26)
	b.add_child(est)
	return b

func _atualizar() -> void:
	var n := Passe.nivel()
	var pr: Array = Passe.progresso()
	nivel_lbl.text = "NÍVEL %d" % n
	xp_lbl.text = "%d / %d XP" % [pr[0], pr[1]]
	barra.size.x = maxf(18.0, (barra_fundo.size.x - 8.0) * float(pr[0]) / float(pr[1]))
	dica.text = ("Ganha XP jogando: 10 por minuto · fase vencida 50 (1ª vez 200) · chefe 150 (1ª vez 500) · recorde 100 · online até 120"
		if Conta.logado() else "Entra numa conta (MINHA CONTA no menu) pra ganhar XP e liberar os itens.")
	for c in cartoes:
		var id: String = c.get_meta("id")
		var it := Passe.item(id)
		var lib := Passe.liberado(id)
		var eq := Passe.equipado(it[3]) == id
		var est: Label = c.get_node("estado")
		var cor: Color = it[4]
		if it[3] == "skin":
			est.text = "CHEGA EM BREVE" if lib else "🔒 NÍVEL %d" % it[0]
		elif eq:
			est.text = "✓ EQUIPADO"
		elif lib:
			est.text = "TOCA PRA USAR"
		else:
			est.text = "BLOQUEADO"
		est.add_theme_color_override("font_color", Color(0.45, 1, 0.5) if eq else (Color.WHITE if lib else Color(0.6, 0.6, 0.7)))
		var st := _caixa(cor if lib else Color(0.35, 0.33, 0.42), 18,
			Color(cor.r * 0.25, cor.g * 0.25, cor.b * 0.3, 0.92) if lib else Color(0.06, 0.05, 0.1, 0.9))
		if eq:
			st.set_border_width_all(6)
			st.border_color = Color(0.45, 1, 0.5)
		if it[3] == "skin":
			st.set_border_width_all(5)
			st.border_color = OURO if lib else Color(0.6, 0.5, 0.25)
			st.bg_color = Color(0.25, 0.18, 0.04, 0.92)
		for k in ["normal", "hover", "pressed", "disabled"]:
			c.add_theme_stylebox_override(k, st)
		c.modulate = Color.WHITE if lib or it[3] == "skin" else Color(0.7, 0.7, 0.75)

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	fundo.size = v
	titulo.position = Vector2(40, 24)
	titulo.size = Vector2(700, 70)
	b_voltar.position = Vector2(v.x - 230, 30)
	b_voltar.size = Vector2(190, 58)
	nivel_lbl.position = Vector2(40, 104)
	nivel_lbl.size = Vector2(260, 50)
	barra_fundo.position = Vector2(270, 112)
	barra_fundo.size = Vector2(minf(620.0, v.x - 320.0), 36)
	barra.position = Vector2(4, 4)
	barra.size.y = 28
	xp_lbl.position = Vector2.ZERO
	xp_lbl.size = barra_fundo.size
	dica.position = Vector2(40, 160)
	dica.size = Vector2(v.x - 80, 30)
	rolagem.position = Vector2(30, maxf(205.0, v.y * 0.5 - CARTAO.y / 2.0 + 40.0))
	rolagem.size = Vector2(v.x - 60, CARTAO.y + 20)
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
	b.add_theme_font_size_override("font_size", 26)
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
