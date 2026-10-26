extends Control
## Loja: skins com raridade e preço. Comprar = gera o Pix (QR + copia e cola) com o código do
## pedido; o dono recebe o aviso no celular, confirma, e a skin aparece em Minha conta.

const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.86)
const OURO := Color(1.0, 0.8, 0.25)
const VERDE := Color(0.4, 1.0, 0.5)
const RARIDADE := {"comum": ["COMUM", Color(0.62, 0.8, 0.68)], "epico": ["ÉPICO", Color(0.75, 0.45, 1.0)],
	"lendario": ["LENDÁRIO", Color(1.0, 0.78, 0.2)]}

var fundo: TextureRect
var nevoa: ColorRect
var titulo: Label
var b_voltar: Button
var b_conta: Button
var info: Label
var rolagem: ScrollContainer
var grade: HFlowContainer
var _itens: Array = []                # do servidor (preço que vale)
var _pendentes: Dictionary = {}       # item -> código do pedido em aberto
var _janela: Control
var _ocupado := false

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo = TextureRect.new()
	fundo.texture = load("res://assets/ui/lobby.jpg")
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(fundo)
	nevoa = ColorRect.new()
	nevoa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/ui/nevoa.gdshader")
	nevoa.material = mat
	add_child(nevoa)
	titulo = _rotulo("LOJA", 64, 16, Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(titulo)
	b_voltar = _botao("‹ VOLTAR", ROXO, func() -> void: get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	b_conta = _botao("MINHA CONTA", ROXO, func() -> void: get_tree().change_scene_to_file("res://levels/MinhaConta.tscn"))
	add_child(b_voltar)
	add_child(b_conta)
	info = _rotulo("", 22, 6, Color(0.9, 0.85, 1.0))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(info)
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(rolagem)
	grade = HFlowContainer.new()
	grade.add_theme_constant_override("h_separation", 20)
	grade.add_theme_constant_override("v_separation", 20)
	rolagem.add_child(grade)
	for k in Game.SKINS:                       # mostra já; o servidor confirma preço e o que está à venda
		var s: Dictionary = Game.SKINS[k]
		_itens.append({"item": k, "personagem": s["pers"], "nome": s["nome"], "raridade": s["raridade"], "preco": s["preco"], "ativo": true})
	Conta.mudou.connect(_montar)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_montar()
	_carregar()

func _carregar() -> void:
	var r: Array = await Conta.itens_loja()
	if not is_inside_tree():
		return
	if int(r[0]) == 200 and typeof(r[1]) == TYPE_ARRAY and not (r[1] as Array).is_empty():
		_itens = r[1]
	if Conta.logado():
		var p: Array = await Conta.meus_pedidos()
		if not is_inside_tree():
			return
		_pendentes.clear()
		if int(p[0]) == 200 and typeof(p[1]) == TYPE_ARRAY:
			for d in p[1]:
				if str(d.get("status", "")) == "aguardando":
					_pendentes[str(d["item"])] = str(d["codigo"])
	_montar()

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	var tw := 1672.0
	var th := 941.0
	var esc := maxf(v.x / tw, v.y / th)
	fundo.size = Vector2(tw, th) * esc
	fundo.position = (v - fundo.size) / 2.0
	nevoa.size = v
	b_voltar.position = Vector2(24, 22)
	b_voltar.size = Vector2(170, 60)
	titulo.position = Vector2(214, 8)
	titulo.size = Vector2(400, 80)
	b_conta.size = Vector2(230, 60)
	b_conta.position = Vector2(v.x - 254, 22)
	info.position = Vector2(v.x - 760, 84)
	info.size = Vector2(736, 30)
	rolagem.position = Vector2(24, 122)
	rolagem.size = Vector2(v.x - 48, v.y - 140)
	grade.custom_minimum_size = Vector2(rolagem.size.x - 16, 0)
	if _janela:
		_janela.size = v

func _montar() -> void:
	info.text = ("Logado como %s" % Conta.nick) if Conta.logado() else "Pra comprar, entra na sua conta (MINHA CONTA)."
	for n in grade.get_children():
		n.queue_free()
	for d in _itens:
		grade.add_child(_cartao(d))

func _cartao(d: Dictionary) -> Control:
	var item := str(d["item"])
	var pers := str(d.get("personagem", Game.SKINS.get(item, {}).get("pers", "")))
	var rar: Array = RARIDADE.get(str(d.get("raridade", "comum")), RARIDADE["comum"])
	var pronta := FileAccess.file_exists("res://assets/%s/parts.json" % item)
	var a_venda := bool(d.get("ativo", true)) and pronta
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(286, 380)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.04, 0.14, 0.92)
	st.set_corner_radius_all(18)
	st.set_border_width_all(3)
	st.border_color = rar[1]
	st.shadow_color = Color(rar[1], 0.35)
	st.shadow_size = 12
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 14
	c.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	var faixa := _rotulo(rar[0], 22, 6, Color(0.05, 0.03, 0.1))
	var fs := StyleBoxFlat.new()
	fs.bg_color = rar[1]
	fs.set_corner_radius_all(8)
	faixa.add_theme_stylebox_override("normal", fs)
	v.add_child(faixa)
	var img := TextureRect.new()
	var arq := "res://assets/menu/%s.png" % (item if pronta else pers)
	if ResourceLoader.exists(arq):
		img.texture = load(arq)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(0, 170)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not pronta:
		img.modulate = Color(0, 0, 0, 0.85)       # ainda sem arte: silhueta
	v.add_child(img)
	v.add_child(_rotulo(str(d["nome"]).to_upper(), 30, 8, Color.WHITE))
	if Conta.logado() and Conta.tem(item) and Game.skin_de(pers) == item:
		st.border_color = VERDE
		v.add_child(_rotulo("USANDO", 20, 6, VERDE))
	v.add_child(_rotulo(str(Game.NOMES.get(pers, pers)), 22, 6, Color(0.85, 0.8, 0.95)))
	var preco := _rotulo("R$ " + ("%.2f" % float(d["preco"])).replace(".", ","), 30, 8, OURO)
	v.add_child(preco)
	var texto := "COMPRAR"
	var cor := VERDE
	var ativo := a_venda
	var dono := Conta.logado() and Conta.tem(item) and pronta
	if dono:                                    # já é seu: a loja vira inventário (usar/tirar)
		var usando := Game.skin_de(pers) == item
		texto = "TIRAR" if usando else "USAR"
		cor = Color(1, 0.45, 0.4) if usando else VERDE
		ativo = true
	elif not a_venda:
		texto = "EM BREVE"
		cor = Color(0.6, 0.6, 0.65)
	elif _pendentes.has(item):
		texto = "VER PIX"
		cor = OURO
	var b := _botao(texto, cor, func() -> void:
		if dono:
			Audio.tocar("confirma")
			Game.equipar(pers, "" if Game.skin_de(pers) == item else item)
			_montar()
		else:
			_comprar(d))
	b.disabled = not ativo
	b.custom_minimum_size = Vector2(0, 56)
	v.add_child(b)
	return c

func _comprar(d: Dictionary) -> void:
	if _ocupado:
		return
	Audio.tocar("clique")
	if not Conta.logado():
		_mostrar_aviso("Entra na sua conta primeiro (MINHA CONTA). A skin fica guardada nela.")
		return
	_ocupado = true
	var p: Dictionary = await Conta.criar_pedido(str(d["item"]))
	_ocupado = false
	if not is_inside_tree():
		return
	if p.has("erro"):
		_mostrar_aviso({"ja_tem": "Você já tem essa skin!", "item": "Essa skin não está à venda agora.",
			"conexao": "Sem conexão. Tenta de novo.", "sem_conta": "Entra na sua conta primeiro."}.get(str(p["erro"]), "Deu erro. Tenta de novo."))
		return
	_pendentes[str(d["item"])] = str(p["codigo"])
	_montar()
	_mostrar_pix(d, float(p["valor"]), str(p["codigo"]))

# ---------- janela do Pix ----------
func _janela_base() -> VBoxContainer:
	if _janela:
		_janela.queue_free()
	_janela = Control.new()
	_janela.size = get_viewport().get_visible_rect().size
	add_child(_janela)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.75)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_janela.add_child(escuro)
	var c := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.05, 0.16, 0.98)
	st.set_corner_radius_all(20)
	st.set_border_width_all(3)
	st.border_color = OURO
	st.content_margin_left = 26
	st.content_margin_right = 26
	st.content_margin_top = 20
	st.content_margin_bottom = 20
	c.add_theme_stylebox_override("panel", st)
	c.set_anchors_preset(Control.PRESET_CENTER)
	_janela.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	c.resized.connect(func() -> void: c.position = (_janela.size - c.size) / 2.0)
	return v

func _fechar() -> void:
	Audio.tocar("clique")
	if _janela:
		_janela.queue_free()
		_janela = null

func _mostrar_aviso(t: String) -> void:
	var v := _janela_base()
	var l := _rotulo(t, 28, 8, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	v.add_child(l)
	var b := _botao("OK", ROXO, _fechar)
	b.custom_minimum_size = Vector2(0, 56)
	v.add_child(b)

func _mostrar_pix(d: Dictionary, valor: float, codigo: String) -> void:
	var texto := Pix.copia_e_cola(valor, codigo)
	var v := _janela_base()
	var lado := HBoxContainer.new()
	lado.add_theme_constant_override("separation", 26)
	v.add_child(lado)
	var m := Pix.qr(texto)
	if not m.is_empty():                       # QR (pra pagar pelo celular olhando a tela do PC)
		var n := m.size()
		var img := Image.create(n + 8, n + 8, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		for y in n:
			for x in n:
				if m[y][x]:
					img.set_pixel(x + 4, y + 4, Color.BLACK)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(300, 300)
		lado.add_child(tr)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(400, 0)
	lado.add_child(col)
	var t := _rotulo("PAGUE COM PIX", 40, 10, OURO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(t)
	var nome := _rotulo("%s · %s" % [Game.NOMES.get(str(d.get("personagem", "")), ""), str(d["nome"])], 26, 6, Color.WHITE)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(nome)
	var vl := _rotulo("R$ " + ("%.2f" % valor).replace(".", ","), 48, 12, VERDE)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(vl)
	var cod := _rotulo("Pedido " + codigo, 26, 6, Color(0.9, 0.85, 1.0))
	cod.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(cod)
	var ex := _rotulo(("No celular: copia o código e cola no app do banco (Pix → Copia e cola)."
		+ ("\nNo PC: aponta a câmera do app do banco pro QR." if not m.is_empty() else "")
		+ "\nDepois de pagar, a skin aparece em MINHA CONTA assim que o pagamento for confirmado."), 20, 6, Color(0.88, 0.84, 0.98))
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex.custom_minimum_size = Vector2(400, 0)         # texto com quebra precisa de largura fixa no container
	col.add_child(ex)
	var copiar := _botao("COPIAR PIX COPIA E COLA", VERDE, func() -> void:
		DisplayServer.clipboard_set(texto)
		Audio.tocar("confirma"))
	copiar.custom_minimum_size = Vector2(0, 58)
	col.add_child(copiar)
	var fechar := _botao("FECHAR", ROXO, _fechar)
	fechar.custom_minimum_size = Vector2(0, 52)
	col.add_child(fechar)
	print("[LOJA] pix ", codigo, " ", texto)

# ---------- estilo ----------
func _botao(texto: String, borda: Color, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	var st := StyleBoxFlat.new()
	st.bg_color = ROXO_ESCURO
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = borda
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, st)
	var sd := st.duplicate() as StyleBoxFlat
	sd.border_color = Color(borda, 0.5)
	b.add_theme_stylebox_override("disabled", sd)
	b.pressed.connect(acao)
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
