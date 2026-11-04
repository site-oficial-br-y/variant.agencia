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
var destaque: Control
var icone_tit: IconeMenu
var sub: Label
var _t := 0.0
var _tam_cartao := Vector2(250, 290)
var _brilhos: Array = []              # faixas de brilho passando nos lendários
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
	icone_tit = IconeMenu.new("loja", OURO)
	add_child(icone_tit)
	sub = _rotulo("SKINS EXCLUSIVAS · PAGA NO PIX", 18, 5, OURO)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(sub)
	destaque = Control.new()
	add_child(destaque)
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
	grade.add_theme_constant_override("h_separation", 16)
	grade.add_theme_constant_override("v_separation", 16)
	rolagem.add_child(grade)
	for k in Game.SKINS:                       # mostra já; o servidor confirma preço e o que está à venda
		var s: Dictionary = Game.SKINS[k]
		if s.has("passe"):
			continue
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
		_itens = (r[1] as Array).filter(func(d) -> bool: return not Game.SKINS.get(str(d.get("item", "")), {}).has("passe"))
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
	icone_tit.position = Vector2(216, 18)
	icone_tit.size = Vector2(56, 56)
	titulo.position = Vector2(282, 0)
	titulo.size = Vector2(300, 80)
	sub.position = Vector2(284, 66)
	sub.size = Vector2(500, 24)
	b_conta.size = Vector2(230, 60)
	b_conta.position = Vector2(v.x - 254, 22)
	info.position = Vector2(v.x - 760, 84)
	info.size = Vector2(736, 30)
	var dw := clampf(v.x * 0.28, 300.0, 420.0)
	destaque.position = Vector2(24, 118)
	destaque.size = Vector2(dw, v.y - 136)
	for n in destaque.get_children():
		(n as Control).size = destaque.size
	rolagem.position = Vector2(24 + dw + 20, 118)
	rolagem.size = Vector2(v.x - dw - 68, v.y - 130)
	grade.custom_minimum_size = Vector2(rolagem.size.x - 16, 0)
	var cols := maxi(1, int((rolagem.size.x - 16 + 16) / (230.0 + 16)))
	_tam_cartao = Vector2(floorf((rolagem.size.x - 16 - 16 * (cols - 1)) / cols), maxf(260.0, floorf((rolagem.size.y - 20) / 2.0)))
	for n in grade.get_children():
		(n as Control).custom_minimum_size = _tam_cartao
	if _janela:
		_janela.size = v

func _montar() -> void:
	info.text = ("Logado como %s" % Conta.nick) if Conta.logado() else "Pra comprar, entra na sua conta (MINHA CONTA)."
	for n in grade.get_children():
		n.queue_free()
	for n in destaque.get_children():
		n.queue_free()
	_brilhos.clear()
	var top := -1                               # destaque: o lendário (ou o mais caro) à venda
	for i in _itens.size():
		var d: Dictionary = _itens[i]
		if top < 0 or (str(d.get("raridade", "")) == "lendario" and str(_itens[top].get("raridade", "")) != "lendario") \
				or (str(d.get("raridade", "")) == str(_itens[top].get("raridade", "")) and float(d["preco"]) > float(_itens[top]["preco"])):
			top = i
	for i in _itens.size():
		if i == top:
			var c := _cartao(_itens[i], true)
			destaque.add_child(c)
			c.size = destaque.size
		else:
			grade.add_child(_cartao(_itens[i], false))

func _process(delta: float) -> void:
	_t += delta
	for b in _brilhos:
		if is_instance_valid(b):
			var pai := (b as Control).get_parent() as Control
			(b as Control).position.x = fmod(_t * 260.0, pai.size.x + 600.0) - 300.0

func _cartao(d: Dictionary, grande: bool) -> Control:
	var item := str(d["item"])
	var pers := str(d.get("personagem", Game.SKINS.get(item, {}).get("pers", "")))
	var rk := str(d.get("raridade", "comum"))
	var rar: Array = RARIDADE.get(rk, RARIDADE["comum"])
	var cor_r: Color = rar[1]
	var pronta := FileAccess.file_exists("res://assets/%s/parts.json" % item)
	var a_venda := bool(d.get("ativo", true)) and pronta
	var dono := Conta.logado() and Conta.tem(item) and pronta
	var usando := dono and Game.skin_de(pers) == item
	var c := Panel.new()
	c.custom_minimum_size = _tam_cartao
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.clip_contents = true
	var st := StyleBoxFlat.new()
	st.bg_color = Color(cor_r.r * 0.16, cor_r.g * 0.12, cor_r.b * 0.2 + 0.06, 0.96)
	st.set_corner_radius_all(18)
	st.set_border_width_all(4 if grande else 3)
	st.border_color = VERDE if usando else cor_r
	st.shadow_color = Color(cor_r, 0.45 if grande else 0.3)
	st.shadow_size = 20 if grande else 10
	c.add_theme_stylebox_override("panel", st)
	# brilho da raridade atrás do personagem
	var g := Gradient.new()
	g.set_color(0, Color(cor_r, 0.75))
	g.set_color(1, Color(cor_r, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	var glow := TextureRect.new()
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(glow)
	if rk == "lendario":                        # faixa de brilho passando
		var fx := ColorRect.new()
		fx.color = Color(1, 0.95, 0.7, 0.12)
		fx.size = Vector2(70, 1400)
		fx.rotation = 0.35
		fx.position = Vector2(-300, -300)
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(fx)
		_brilhos.append(fx)
	var img := TextureRect.new()
	var arq := "res://assets/menu/%s.png" % (item if pronta else pers)
	if ResourceLoader.exists(arq):
		img.texture = load(arq)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not pronta:
		img.modulate = Color(0, 0, 0, 0.85)       # ainda sem arte: silhueta
	c.add_child(img)
	var tag := _rotulo(("★ DESTAQUE · " if grande else "") + rar[0], 16 if not grande else 20, 0, Color(0.06, 0.03, 0.1))
	var fs := StyleBoxFlat.new()
	fs.bg_color = cor_r
	fs.corner_radius_bottom_right = 12
	fs.corner_radius_top_left = 16
	fs.content_margin_left = 12
	fs.content_margin_right = 12
	tag.add_theme_stylebox_override("normal", fs)
	c.add_child(tag)
	var nm := str(d["nome"]).to_upper()
	var nome_l := _rotulo(nm, (44 if nm.length() <= 10 else 34) if grande else (26 if nm.length() <= 12 else 21), 10 if grande else 7, Color.WHITE)
	nome_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome_l.clip_text = true
	c.add_child(nome_l)
	var pers_l := _rotulo("SKIN DO " + str(Game.NOMES.get(pers, pers)), 20 if grande else 16, 5, Color(cor_r.lightened(0.35)))
	pers_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.add_child(pers_l)
	var texto := "R$ " + ("%.2f" % float(d["preco"])).replace(".", ",")
	var fundo_b := Color(0.25, 0.85, 0.4)
	var ativo := a_venda
	if dono:                                    # já é seu: a loja vira inventário (usar/tirar)
		texto = "✓ TIRAR" if usando else "✓ USAR"
		fundo_b = Color(0.85, 0.35, 0.35) if usando else Color(0.5, 0.35, 0.9)
		ativo = true
	elif not a_venda:
		texto = "EM BREVE"
		fundo_b = Color(0.35, 0.35, 0.42)
	elif _pendentes.has(item):
		texto = "VER PIX"
		fundo_b = OURO
	var b := _botao_cheio(texto, fundo_b, 30 if grande else 24, func() -> void:
		if dono:
			Audio.tocar("confirma")
			Game.equipar(pers, "" if Game.skin_de(pers) == item else item)
			_montar()
		else:
			_comprar(d))
	b.disabled = not ativo
	if not dono and a_venda and not _pendentes.has(item):
		var ic := IconeMenu.new("loja", Color(0.05, 0.2, 0.08))
		ic.name = "carrinho"
		b.add_child(ic)
	c.add_child(b)
	var arruma := func() -> void:
		var w := c.size.x
		var h := c.size.y
		var bh := 66.0 if grande else 52.0
		glow.size = Vector2(w - 8, minf(w - 8, h - bh - 20))
		glow.position = Vector2(4, maxf(4.0, (h - bh) * 0.42 - glow.size.y / 2.0))
		tag.position = Vector2(0, 0)
		tag.size = Vector2(0, 30 if grande else 26)
		b.position = Vector2(12, h - bh - 12)
		b.size = Vector2(w - 24, bh)
		var ic2 := b.get_node_or_null("carrinho") as Control
		if ic2:
			ic2.size = Vector2(bh * 0.5, bh * 0.5)
			ic2.position = Vector2(14, bh * 0.25)
		pers_l.position = Vector2(16, b.position.y - (32 if grande else 26))
		pers_l.size = Vector2(w - 32, 24)
		nome_l.position = Vector2(16, pers_l.position.y - (50 if grande else 32))
		nome_l.size = Vector2(w - 32, 50 if grande else 32)
		img.position = Vector2(10, 34 if grande else 30)
		img.size = Vector2(w - 20, nome_l.position.y - img.position.y - 4)
	c.resized.connect(arruma)
	arruma.call()
	return c

func _botao_cheio(texto: String, fundo_cor: Color, tam: int, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", tam)
	var claro := fundo_cor.get_luminance() > 0.45
	var cor_txt := Color(0.05, 0.03, 0.1) if claro else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, cor_txt)
	var st := StyleBoxFlat.new()
	st.bg_color = fundo_cor
	st.set_corner_radius_all(14)
	st.border_width_bottom = 5
	st.border_color = fundo_cor.darkened(0.35)
	var sp := st.duplicate() as StyleBoxFlat
	sp.bg_color = fundo_cor.darkened(0.15)
	sp.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("disabled", st)
	b.pressed.connect(acao)
	return b

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
