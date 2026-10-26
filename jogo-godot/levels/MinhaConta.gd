extends Control
## Minha conta: entrar/criar (usuário + senha + nick), trocar nick, sair; skins compradas
## (escolher qual usar), pedidos em andamento e, pro dono, os pedidos pra confirmar.

const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.86)
const OURO := Color(1.0, 0.8, 0.25)
const VERDE := Color(0.4, 1.0, 0.5)
const VERMELHO := Color(1, 0.45, 0.4)

var fundo: TextureRect
var nevoa: ColorRect
var titulo: Label
var b_voltar: Button
var b_loja: Button
var caixa_conta: Panel
var conta_vbox: VBoxContainer
var caixa_itens: Panel
var rolagem: ScrollContainer
var itens_vbox: VBoxContainer
var _campo_usuario: LineEdit
var _campo_senha: LineEdit
var _campo_nick: LineEdit
var _status: Label
var _ocupado := false
var _ult_prompt := -10000
var _geracao := 0                    # lista refeita: descarta resposta que chegou atrasada

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
	titulo = _rotulo("MINHA CONTA", 64, 16, Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(titulo)
	b_voltar = _botao("‹ VOLTAR", ROXO, func() -> void: get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	b_loja = _botao("LOJA", OURO, func() -> void: get_tree().change_scene_to_file("res://levels/Loja.tscn"))
	caixa_conta = _painel()
	conta_vbox = VBoxContainer.new()
	conta_vbox.add_theme_constant_override("separation", 12)
	caixa_conta.add_child(conta_vbox)
	caixa_itens = _painel()
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caixa_itens.add_child(rolagem)
	itens_vbox = VBoxContainer.new()
	itens_vbox.add_theme_constant_override("separation", 10)
	itens_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(itens_vbox)
	Conta.mudou.connect(_conta_mudou)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_montar_conta()
	_montar_itens()
	if Conta.logado():
		Conta.carregar_inventario()

func _conta_mudou() -> void:
	_montar_conta()
	_montar_itens()

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
	titulo.size = Vector2(600, 80)
	b_loja.size = Vector2(170, 60)
	b_loja.position = Vector2(v.x - 194, 22)
	var lc := minf(470.0, v.x * 0.38)
	caixa_conta.position = Vector2(24, 100)
	caixa_conta.size = Vector2(lc, v.y - 122)
	conta_vbox.position = Vector2(26, 22)
	conta_vbox.size = caixa_conta.size - Vector2(52, 44)
	caixa_itens.position = Vector2(24 + lc + 24, 100)
	caixa_itens.size = Vector2(v.x - caixa_itens.position.x - 24, v.y - 122)
	rolagem.position = Vector2(18, 18)
	rolagem.size = caixa_itens.size - Vector2(36, 36)
	itens_vbox.custom_minimum_size = Vector2(rolagem.size.x - 16, 0)

# ---------- conta ----------
func _montar_conta() -> void:
	for n in conta_vbox.get_children():
		n.queue_free()
	if Conta.logado():
		var nome := _rotulo(Conta.nick, 48, 12, Color.WHITE)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nome.clip_text = true
		conta_vbox.add_child(nome)
		conta_vbox.add_child(_texto("usuário pra entrar: " + Conta.usuario))
		conta_vbox.add_child(_texto("No ranking aparece o nick. Dá pra trocar quando quiser:"))
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 12)
		conta_vbox.add_child(linha)
		_campo_nick = _campo("NOVO NICK", false, "Novo nick (3 a 16 letras):", 16)
		_campo_nick.reparent(linha)
		_campo_nick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b_nick := _botao("TROCAR", OURO, _trocar_nick)
		b_nick.reparent(linha)
		b_nick.custom_minimum_size = Vector2(150, 64)
		_status = _texto("")
		conta_vbox.add_child(_status)
		var b := _botao("SAIR DA CONTA", VERMELHO, func() -> void:
			Audio.tocar("clique")
			await Conta.sair())
		b.reparent(conta_vbox)
		b.custom_minimum_size = Vector2(0, 62)
		return
	var t := _rotulo("ENTRAR OU CRIAR CONTA", 30, 10, OURO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	conta_vbox.add_child(t)
	conta_vbox.add_child(_texto("Com conta você aparece no ranking e as skins da loja ficam guardadas."))
	_campo_usuario = _campo("USUÁRIO (pra entrar)", false, "Usuário pra entrar (3 a 20 letras ou números):", 20)
	_campo_senha = _campo("SENHA", true, "Senha (mínimo 6):", 64)
	_campo_nick = _campo("NICK (aparece no ranking)", false, "Nick que aparece no ranking (3 a 16 letras):", 16)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	conta_vbox.add_child(botoes)
	var b_criar := _botao("CRIAR CONTA", VERDE, func() -> void: _enviar(true))
	var b_entrar := _botao("ENTRAR", ROXO, func() -> void: _enviar(false))
	for b in [b_criar, b_entrar]:
		b.reparent(botoes)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 62)
	_status = _texto("Pra entrar basta usuário e senha. Senha esquecida não tem volta, então anota.")
	conta_vbox.add_child(_status)

func _enviar(criar: bool) -> void:
	if _ocupado:
		return
	Audio.tocar("clique")
	_ocupado = true
	_aviso("Criando a conta..." if criar else "Entrando...", false)
	var erro: String
	if criar:
		erro = await Conta.criar(_campo_usuario.text, _campo_senha.text, _campo_nick.text)
	else:
		erro = await Conta.entrar(_campo_usuario.text, _campo_senha.text)
	_ocupado = false
	if erro != "":
		_aviso(erro, true)
	else:
		Audio.tocar("confirma")

func _trocar_nick() -> void:
	if _ocupado:
		return
	Audio.tocar("clique")
	_ocupado = true
	_aviso("Trocando...", false)
	var erro: String = await Conta.trocar_nick(_campo_nick.text)
	_ocupado = false
	if erro != "":
		_aviso(erro, true)
	else:
		Audio.tocar("confirma")

func _aviso(t: String, ruim: bool) -> void:
	if is_instance_valid(_status):
		_status.text = t
		_status.add_theme_color_override("font_color", VERMELHO if ruim else Color(0.9, 0.85, 1.0))

# ---------- skins e pedidos ----------
func _montar_itens() -> void:
	_geracao += 1
	for n in itens_vbox.get_children():
		n.queue_free()
	itens_vbox.add_child(_titulo_secao("SUAS SKINS"))
	if not Conta.logado():
		itens_vbox.add_child(_texto("Entra na conta pra ver suas skins."))
		return
	var tem_alguma := false
	for item in Game.SKINS:
		if not Conta.tem(item) or not FileAccess.file_exists("res://assets/%s/parts.json" % item):
			continue
		tem_alguma = true
		itens_vbox.add_child(_linha_skin(item))
	if not tem_alguma:
		itens_vbox.add_child(_texto("Você ainda não tem nenhuma skin. Passa na LOJA!"))
	_montar_pedidos()

func _linha_skin(item: String) -> Control:
	var s: Dictionary = Game.SKINS[item]
	var pers: String = s["pers"]
	var usando := Game.skin_de(pers) == item
	var p := _linha_painel(usando)
	var h: HBoxContainer = p.get_child(0)
	h.add_child(_rosto(item))
	var nome := _rotulo("%s · %s" % [Game.NOMES.get(pers, pers), s["nome"]], 28, 8, Color.WHITE)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nome)
	var b := _botao("TIRAR" if usando else "USAR", VERMELHO if usando else VERDE, func() -> void:
		Audio.tocar("confirma")
		Game.equipar(pers, "" if usando else item)
		_montar_itens())
	b.reparent(h)
	b.custom_minimum_size = Vector2(150, 56)
	return p

func _montar_pedidos() -> void:
	var g := _geracao
	var r: Array = await Conta.meus_pedidos()
	if not is_inside_tree() or g != _geracao or int(r[0]) != 200 or typeof(r[1]) != TYPE_ARRAY:
		return
	var abertos: Array = (r[1] as Array).filter(func(d): return str(d.get("status", "")) == "aguardando")
	if not abertos.is_empty():
		itens_vbox.add_child(_titulo_secao("PAGAMENTOS EM ANÁLISE"))
		for d in abertos:
			var s: Dictionary = Game.SKINS.get(str(d["item"]), {"nome": d["item"], "pers": ""})
			itens_vbox.add_child(_texto("%s · %s — R$ %s — pedido %s. Libera assim que o pagamento for confirmado." % [
				Game.NOMES.get(s["pers"], ""), s["nome"], _reais(float(d["valor"])), d["codigo"]]))
	if Conta.admin:
		_montar_admin()

func _montar_admin() -> void:
	var g := _geracao
	var r: Array = await Conta.pedidos_abertos()
	if not is_inside_tree() or g != _geracao:
		return
	itens_vbox.add_child(_titulo_secao("PEDIDOS PRA CONFIRMAR (DONO)"))
	if int(r[0]) != 200 or typeof(r[1]) != TYPE_ARRAY:
		itens_vbox.add_child(_texto("Não deu pra carregar os pedidos."))
		return
	if (r[1] as Array).is_empty():
		itens_vbox.add_child(_texto("Nenhum pedido esperando. Quando chegar um, o aviso cai no seu celular."))
		return
	for d in r[1]:
		var p := _linha_painel(false)
		var h: HBoxContainer = p.get_child(0)
		var t := _rotulo("%s  ·  %s  ·  R$ %s  ·  %s" % [d["codigo"], d["apelido"], _reais(float(d["valor"])), d["nome"]], 24, 6, Color.WHITE)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		h.add_child(t)
		var codigo := str(d["codigo"])
		var b_ok := _botao("PAGO", VERDE, func() -> void: _resolver(codigo, true))
		b_ok.reparent(h)
		b_ok.custom_minimum_size = Vector2(110, 52)
		var b_nao := _botao("✕", VERMELHO, func() -> void: _resolver(codigo, false))
		b_nao.reparent(h)
		b_nao.custom_minimum_size = Vector2(60, 52)
		itens_vbox.add_child(p)

func _resolver(codigo: String, pago: bool) -> void:
	Audio.tocar("clique")
	var r := await Conta.resolver_pedido(codigo, pago)
	if r == "pago":
		Audio.tocar("confirma")
	_montar_itens()

func _reais(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")

# ---------- estilo ----------
func _titulo_secao(t: String) -> Label:
	var l := _rotulo(t, 30, 10, OURO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l

func _linha_painel(destaque: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.4, 1.0, 0.5, 0.14) if destaque else Color(1, 1, 1, 0.07)
	st.set_corner_radius_all(12)
	if destaque:
		st.set_border_width_all(2)
		st.border_color = VERDE
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	return p

func _rosto(pasta: String) -> TextureRect:
	var r := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/rosto_%s.png" % pasta):
		r.texture = load("res://assets/ui/rosto_%s.png" % pasta)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(64, 64)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _campo(dica: String, senha: bool, pergunta: String, maximo: int) -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = dica
	c.secret = senha
	c.max_length = maximo
	c.add_theme_font_size_override("font_size", 28)
	c.custom_minimum_size = Vector2(0, 64)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.45)
	st.set_corner_radius_all(12)
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.35)
	st.content_margin_left = 16
	st.content_margin_right = 16
	c.add_theme_stylebox_override("normal", st)
	c.add_theme_stylebox_override("focus", st)
	c.gui_input.connect(func(ev: InputEvent) -> void:      # navegador: janela de digitar (abre o teclado no celular)
		if OS.has_feature("web") and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)):
			c.accept_event()
			if Time.get_ticks_msec() - _ult_prompt < 500:      # clique chega como toque + mouse
				return
			var r = JavaScriptBridge.eval("(window.prompt(%s, %s) ?? '')" % [JSON.stringify(pergunta), JSON.stringify("" if senha else c.text)], true)
			_ult_prompt = Time.get_ticks_msec()
			var t := str(r).strip_edges()
			if t != "":
				c.text = t.left(c.max_length)
			c.release_focus())
	conta_vbox.add_child(c)
	return c

func _texto(t: String) -> Label:
	var l := _rotulo(t, 22, 6, Color(0.9, 0.85, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _painel() -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ROXO_ESCURO
	s.set_corner_radius_all(18)
	s.set_border_width_all(3)
	s.border_color = ROXO
	s.shadow_color = Color(ROXO, 0.3)
	s.shadow_size = 10
	p.add_theme_stylebox_override("panel", s)
	add_child(p)
	return p

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
