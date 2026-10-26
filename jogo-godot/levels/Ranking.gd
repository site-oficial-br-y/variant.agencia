extends Control
## Ranking público: melhores tempos de cada fase (só vitória sozinho, do começo) e quem
## tem mais tempo de jogo. A conta fica na tela Minha conta.

const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.86)
const OURO := Color(1.0, 0.8, 0.25)
const VERDE := Color(0.4, 1.0, 0.5)
const MEDALHA := [Color(1.0, 0.8, 0.25), Color(0.82, 0.85, 0.92), Color(0.86, 0.55, 0.3)]

var fundo: TextureRect
var nevoa: ColorRect
var titulo: Label
var b_voltar: Button
var b_tempos: Button
var b_jogo: Button
var b_ant: Button
var b_prox: Button
var nome_fase: Label
var caixa_lista: Panel
var rolagem: ScrollContainer
var linhas: VBoxContainer
var aviso_lista: Label
var b_conta: Button

var modo := "tempos"
var fase_i := 0                       # índice em Game.ORDEM
var _pedido := 0                      # descarta resposta velha quando troca de aba rápido

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	fase_i = maxi(0, Game.ORDEM.find(Game.fase))
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
	titulo = _rotulo("RANKING", 64, 16, Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(titulo)
	b_voltar = _botao("‹ VOLTAR", ROXO, func() -> void: get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	b_tempos = _botao("MELHORES TEMPOS", OURO, func() -> void: _trocar_modo("tempos"))
	b_jogo = _botao("TEMPO DE JOGO", OURO, func() -> void: _trocar_modo("jogo"))
	b_ant = _botao("‹", ROXO, func() -> void: _trocar_fase(-1))
	b_prox = _botao("›", ROXO, func() -> void: _trocar_fase(1))
	nome_fase = _rotulo("", 34, 10, Color.WHITE)
	add_child(nome_fase)
	caixa_lista = Panel.new()
	caixa_lista.add_theme_stylebox_override("panel", _caixa(ROXO, 18))
	add_child(caixa_lista)
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caixa_lista.add_child(rolagem)
	linhas = VBoxContainer.new()
	linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linhas.add_theme_constant_override("separation", 6)
	rolagem.add_child(linhas)
	aviso_lista = _rotulo("", 28, 8, Color(0.9, 0.85, 1.0))
	aviso_lista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa_lista.add_child(aviso_lista)
	b_conta = _botao("MINHA CONTA", ROXO, func() -> void: get_tree().change_scene_to_file("res://levels/MinhaConta.tscn"))
	Conta.mudou.connect(_conta_mudou)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_carregar()

func _conta_mudou() -> void:
	_carregar()

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
	titulo.size = Vector2(500, 80)
	var larg_lista := v.x - 48.0
	b_conta.size = Vector2(230, 60)
	b_conta.position = Vector2(v.x - 254, 22)
	b_tempos.position = Vector2(24, 100)
	b_tempos.size = Vector2((larg_lista - 12.0) / 2.0, 58)
	b_jogo.position = Vector2(36 + b_tempos.size.x, 100)
	b_jogo.size = b_tempos.size
	var y_lista := 100.0 + 58.0 + 14.0
	var com_fase := modo == "tempos"
	b_ant.visible = com_fase
	b_prox.visible = com_fase
	nome_fase.visible = com_fase
	if com_fase:
		b_ant.position = Vector2(24, y_lista)
		b_ant.size = Vector2(64, 58)
		b_prox.position = Vector2(24 + larg_lista - 64, y_lista)
		b_prox.size = b_ant.size
		nome_fase.position = Vector2(100, y_lista + 4)
		nome_fase.size = Vector2(larg_lista - 152, 50)
		y_lista += 58.0 + 14.0
	caixa_lista.position = Vector2(24, y_lista)
	caixa_lista.size = Vector2(larg_lista, v.y - y_lista - 22.0)
	rolagem.position = Vector2(14, 14)
	rolagem.size = caixa_lista.size - Vector2(28, 28)
	linhas.custom_minimum_size = Vector2(rolagem.size.x - 16, 0)
	aviso_lista.position = Vector2(30, 30)
	aviso_lista.size = Vector2(caixa_lista.size.x - 60, caixa_lista.size.y - 60)
	(b_tempos.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Color(0.35, 0.22, 0.05, 0.92) if modo == "tempos" else ROXO_ESCURO
	(b_jogo.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Color(0.35, 0.22, 0.05, 0.92) if modo == "jogo" else ROXO_ESCURO
	nome_fase.text = Game.nome_fase(Game.ORDEM[fase_i])

func _trocar_modo(m: String) -> void:
	Audio.tocar("clique")
	if m == modo:
		return
	modo = m
	_layout()
	_carregar()

func _trocar_fase(d: int) -> void:
	Audio.tocar("clique")
	fase_i = posmod(fase_i + d, Game.ORDEM.size())
	_layout()
	_carregar()

func _carregar() -> void:
	_pedido += 1
	var meu := _pedido
	for n in linhas.get_children():
		n.queue_free()
	aviso_lista.text = "Carregando..."
	aviso_lista.visible = true
	var r: Array
	if modo == "tempos":
		r = await Conta.ranking_fase(Game.ORDEM[fase_i])
	else:
		r = await Conta.ranking_jogo()
	if meu != _pedido or not is_inside_tree():
		return
	var cod := int(r[0])
	if cod == 0:
		aviso_lista.text = "Sem conexão. Volta e tenta de novo."
		return
	if cod >= 400 or typeof(r[1]) != TYPE_ARRAY:
		aviso_lista.text = "O ranking ainda não foi ativado no servidor."
		return
	var lista: Array = r[1]
	if lista.is_empty():
		aviso_lista.text = ("Ninguém zerou essa fase com conta ainda. Vai lá e seja o primeiro!" if modo == "tempos"
			else "Ninguém tem tempo de jogo ainda. Cria a conta e joga!")
		return
	aviso_lista.visible = false
	for i in lista.size():
		var d: Dictionary = lista[i]
		var valor := ("%.1f s" % float(d.get("tempo", 0.0))) if modo == "tempos" else _horas(int(d.get("tempo_jogo", 0)))
		linhas.add_child(_linha(i, str(d.get("apelido", "?")), valor, str(d.get("personagem", "")), str(d.get("user_id", ""))))

func _linha(i: int, ap: String, valor: String, pers: String, uid: String) -> Control:
	var eu := Conta.logado() and (uid == Conta.user_id if uid != "" else ap.to_lower() == Conta.nick.to_lower())
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE         # deixa o dedo rolar a lista
	p.custom_minimum_size = Vector2(0, 58)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.07) if i % 2 == 0 else Color(1, 1, 1, 0.02)
	st.set_corner_radius_all(12)
	if eu:
		st.bg_color = Color(0.4, 1.0, 0.5, 0.16)
		st.set_border_width_all(2)
		st.border_color = VERDE
	p.add_theme_stylebox_override("panel", st)
	var pos := _rotulo("%d" % (i + 1), 30, 8, MEDALHA[i] if i < 3 else Color(0.85, 0.8, 0.95))
	pos.position = Vector2(4, 6)
	pos.size = Vector2(56, 46)
	p.add_child(pos)
	if pers != "" and ResourceLoader.exists("res://assets/ui/rosto_%s.png" % pers):
		var rosto := TextureRect.new()
		rosto.texture = load("res://assets/ui/rosto_%s.png" % pers)
		rosto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rosto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rosto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rosto.position = Vector2(64, 5)
		rosto.size = Vector2(48, 48)
		p.add_child(rosto)
	var nome := _rotulo(ap + ("  (você)" if eu else ""), 28, 8, Color.WHITE)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.clip_text = true
	nome.position = Vector2(124, 8)
	nome.size = Vector2(maxf(100.0, linhas.custom_minimum_size.x - 124 - 200), 44)
	p.add_child(nome)
	var val := _rotulo(valor, 30, 8, OURO if i < 3 else Color.WHITE)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.position = Vector2(linhas.custom_minimum_size.x - 214, 7)
	val.size = Vector2(200, 46)
	p.add_child(val)
	return p

func _horas(s: int) -> String:
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%d min" % (s / 60)
	return "%d s" % s

func _texto(t: String) -> Label:
	var l := _rotulo(t, 22, 6, Color(0.9, 0.85, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

# ---------- estilo ----------
func _caixa(borda: Color, raio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ROXO_ESCURO
	s.set_corner_radius_all(raio)
	s.set_border_width_all(3)
	s.border_color = borda
	s.shadow_color = Color(borda, 0.3)
	s.shadow_size = 10
	return s

func _botao(texto: String, borda: Color, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	var st := _caixa(borda, 14)
	st.shadow_size = 0
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
