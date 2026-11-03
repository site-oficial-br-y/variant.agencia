extends Control
## Inventário: aba SKINS (as que você tem, com USAR/TIRAR) e aba ITENS (efeitos do passe),
## separados por tipo: rastro, aura, roda, chapéu, nick e morte. Toca pra equipar ou tirar.

const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.9)
const OURO := Color(1.0, 0.8, 0.25)
const VERDE := Color(0.45, 1.0, 0.5)
const SUB := ["rastro", "aura", "roda", "chapeu", "moldura", "morte"]

var fundo: TextureRect
var titulo: Label
var b_voltar: Button
var b_passe: Button
var abas: Array = []                       # [botão, nome]
var subabas: Array = []
var grade: GridContainer
var vazio: Label
var aba := "skins"
var sub := "rastro"

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo = TextureRect.new()
	fundo.texture = load("res://assets/ui/lobby.jpg")
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.modulate = Color(0.55, 0.5, 0.7)
	add_child(fundo)
	titulo = _rotulo("INVENTÁRIO", 52, 16, Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(titulo)
	b_voltar = _botao("‹ VOLTAR", ROXO, func() -> void:
		Audio.tocar("clique")
		get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	b_passe = _botao("PASSE", OURO, func() -> void:
		Audio.tocar("clique")
		get_tree().change_scene_to_file("res://levels/PasseTela.tscn"))
	for a in [["skins", "SKINS"], ["itens", "ITENS"]]:
		var nome: String = a[0]
		var b := _botao(a[1], ROXO, func() -> void: _trocar_aba(nome))
		b.add_theme_font_size_override("font_size", 30)
		abas.append([b, nome])
	for t in SUB:
		var nome: String = t
		var b := _botao(Passe.TIPOS[t], ROXO, func() -> void: _trocar_sub(nome))
		b.add_theme_font_size_override("font_size", 20)
		subabas.append([b, nome])
	grade = GridContainer.new()
	grade.add_theme_constant_override("h_separation", 16)
	grade.add_theme_constant_override("v_separation", 16)
	add_child(grade)
	vazio = _rotulo("", 26, 8, Color(0.85, 0.82, 0.95))
	vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(vazio)
	Passe.mudou.connect(_montar)
	Conta.mudou.connect(_montar)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_montar()
	Conta.carregar_inventario()

func _trocar_aba(a: String) -> void:
	Audio.tocar("clique")
	aba = a
	_layout()
	_montar()

func _trocar_sub(s: String) -> void:
	Audio.tocar("clique")
	sub = s
	_montar()

## skins que a conta tem (compradas ou do passe, quando a arte existir)
func _minhas_skins() -> Array:
	var r: Array = []
	for item in Game.SKINS:
		if Conta.tem(item):
			r.append(item)
	return r

func _montar() -> void:
	for c in grade.get_children():
		c.queue_free()
	for a in abas:
		_estilo_aba(a[0], a[1] == aba, OURO)
	for s in subabas:
		(s[0] as Button).visible = aba == "itens"
		_estilo_aba(s[0], s[1] == sub, Passe.item(_primeiro(s[1]))[4] if _primeiro(s[1]) != "" else ROXO)
	vazio.text = ""
	if aba == "skins":
		var lista := _minhas_skins()
		grade.columns = 5
		for item in lista:
			grade.add_child(_cartao_skin(item))
		if lista.is_empty():
			vazio.text = "Você ainda não tem skin. Compra na LOJA ou chega no nível 35 do PASSE (skin do Wendell) e 50 (skin do Gian)."
	else:
		grade.columns = 6
		for it in Passe.ITENS:
			if it[3] == sub:
				grade.add_child(_cartao_item(it))

func _primeiro(tipo: String) -> String:
	for it in Passe.ITENS:
		if it[3] == tipo:
			return it[1]
	return ""

func _cartao_skin(item: String) -> Button:
	var d: Dictionary = Game.SKINS[item]
	var pers: String = d["pers"]
	var usando := Game.skin_de(pers) == item
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 290)
	b.focus_mode = Control.FOCUS_NONE
	var cor: Color = {"comum": Color(0.7, 0.75, 0.85), "epico": Color(0.75, 0.4, 1.0), "lendario": OURO}.get(d["raridade"], ROXO)
	var st := _caixa(VERDE if usando else cor, 18, Color(cor.r * 0.2, cor.g * 0.2, cor.b * 0.25, 0.92))
	st.set_border_width_all(5 if usando else 3)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, st)
	var img := TextureRect.new()
	var arq := "res://assets/menu/%s.png" % item
	img.texture = load(arq) if ResourceLoader.exists(arq) else load("res://assets/menu/%s.png" % pers)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position = Vector2(14, 12)
	img.size = Vector2(172, 180)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(img)
	var n1 := _rotulo(Game.NOMES.get(pers, pers), 20, 6, Color(0.85, 0.85, 0.95))
	n1.position = Vector2(0, 196)
	n1.size = Vector2(200, 24)
	b.add_child(n1)
	var n2 := _rotulo(str(d["nome"]).to_upper(), 22, 6, cor)
	n2.position = Vector2(0, 218)
	n2.size = Vector2(200, 28)
	b.add_child(n2)
	var est := _rotulo("✓ USANDO" if usando else "TOCA PRA USAR", 18, 5, VERDE if usando else Color.WHITE)
	est.position = Vector2(0, 252)
	est.size = Vector2(200, 26)
	b.add_child(est)
	b.pressed.connect(func() -> void:
		Audio.tocar("confirma")
		Game.equipar(pers, "" if usando else item)
		_montar())
	return b

func _cartao_item(it: Array) -> Button:
	var id: String = it[1]
	var lib := Passe.liberado(id)
	var eq := Passe.equipado(it[3]) == id
	var cor: Color = it[4]
	var b := Button.new()
	b.custom_minimum_size = Vector2(176, 236)
	b.focus_mode = Control.FOCUS_NONE
	var st := _caixa(VERDE if eq else (cor if lib else Color(0.35, 0.33, 0.42)), 18,
		Color(cor.r * 0.25, cor.g * 0.25, cor.b * 0.3, 0.92) if lib else Color(0.06, 0.05, 0.1, 0.9))
	st.set_border_width_all(6 if eq else 3)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, st)
	b.modulate = Color.WHITE if lib else Color(0.6, 0.6, 0.66)
	var ic := IconeItem.new()
	ic.item = it
	ic.position = Vector2(32, 14)
	ic.size = Vector2(112, 112)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var nome := _rotulo(it[2], 19, 6, Color.WHITE)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.position = Vector2(6, 132)
	nome.size = Vector2(164, 50)
	b.add_child(nome)
	var est := _rotulo("✓ EQUIPADO" if eq else ("TOCA PRA USAR" if lib else "NÍVEL %d" % it[0]), 18, 5,
		VERDE if eq else (Color.WHITE if lib else OURO))
	est.position = Vector2(0, 196)
	est.size = Vector2(176, 28)
	b.add_child(est)
	b.pressed.connect(func() -> void:
		if lib:
			Audio.tocar("confirma")
			Passe.alternar(id)
		else:
			Audio.tocar("clique"))
	return b

func _estilo_aba(b: Button, ativa: bool, cor: Color) -> void:
	var st := _caixa(cor if ativa else Color(0.35, 0.3, 0.5), 14, Color(cor.r * 0.3, cor.g * 0.3, cor.b * 0.35, 0.95) if ativa else ROXO_ESCURO)
	st.set_border_width_all(4 if ativa else 2)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, st)
	b.add_theme_color_override("font_color", Color.WHITE if ativa else Color(0.7, 0.68, 0.8))

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	fundo.size = v
	titulo.position = Vector2(40, 20)
	titulo.size = Vector2(500, 64)
	b_voltar.position = Vector2(v.x - 220, 24)
	b_voltar.size = Vector2(180, 56)
	b_passe.position = Vector2(v.x - 400, 24)
	b_passe.size = Vector2(160, 56)
	for i in abas.size():
		(abas[i][0] as Button).position = Vector2(40 + i * 230, 98)
		(abas[i][0] as Button).size = Vector2(215, 58)
	for i in subabas.size():
		(subabas[i][0] as Button).position = Vector2(40 + i * 150, 168)
		(subabas[i][0] as Button).size = Vector2(140, 46)
	var y := 230.0 if aba == "itens" else 176.0
	grade.position = Vector2(40, y)
	grade.size = Vector2(v.x - 80, v.y - y - 20)
	vazio.position = Vector2(80, y + 60)
	vazio.size = Vector2(v.x - 160, 120)

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
