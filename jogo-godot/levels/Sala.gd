extends Control
## Sala online: cria uma sala e passa o código pros amigos, ou entra com o código de
## alguém. Dentro da sala (lobby) o líder escolhe a fase, todo mundo dá PRONTO e o líder
## começa. Fase do Péce = todos juntos contra o chefe; as outras = corrida.

const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.86)
const OURO := Color(1.0, 0.8, 0.25)
const VERDE := Color(0.4, 1.0, 0.5)

var titulo: Label
var info: Label
var campo: LineEdit
var b_criar: Button
var b_entrar: Button
var b_voltar: Button
# lobby
var caixa_jog: Panel
var codigo_lbl: Label
var dica_codigo: Label
var linhas: VBoxContainer
var caixa_fase: Panel
var mini: TextureRect
var nome_fase: Label
var modo_fase: Label
var b_ant: Button
var b_prox: Button
var b_pronto: Button
var b_comecar: Button
var espera: Label
var _t_ui := 0.0
var _assinatura := ""                 # só refaz a lista quando algo muda

func _ready() -> void:
	Audio.musica_menu(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := TextureRect.new()
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
	titulo = _rotulo("JOGAR ONLINE", 64, 16)
	info = _rotulo("Cria uma sala e passa o código, ou entra com o código de um amigo.", 26, 8)
	campo = LineEdit.new()
	campo.placeholder_text = "TOQUE AQUI"
	campo.max_length = 4
	campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	campo.add_theme_font_size_override("font_size", 48)
	campo.custom_minimum_size = Vector2(260, 80)
	campo.text_changed.connect(func(t: String) -> void:
		var c := campo.caret_column
		campo.text = t.to_upper()
		campo.caret_column = c)
	campo.gui_input.connect(func(ev: InputEvent) -> void:     # celular: abre o teclado do navegador
		if OS.has_feature("web") and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)):
			_pedir_codigo())
	add_child(campo)
	b_criar = _botao("CRIAR SALA", ROXO, _criar)
	b_entrar = _botao("ENTRAR", ROXO, _entrar)
	b_voltar = _botao("‹ VOLTAR", ROXO, _voltar)
	# lobby
	caixa_jog = _caixa_painel()
	codigo_lbl = _rotulo("", 76, 16)
	codigo_lbl.add_theme_color_override("font_color", OURO)
	codigo_lbl.reparent(caixa_jog)
	dica_codigo = _rotulo("", 20, 6)
	dica_codigo.reparent(caixa_jog)
	linhas = VBoxContainer.new()
	linhas.add_theme_constant_override("separation", 8)
	caixa_jog.add_child(linhas)
	caixa_fase = _caixa_painel()
	mini = TextureRect.new()
	mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_fase.add_child(mini)
	nome_fase = _rotulo("", 34, 10)
	nome_fase.reparent(caixa_fase)
	modo_fase = _rotulo("", 22, 6)
	modo_fase.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	modo_fase.reparent(caixa_fase)
	b_ant = _botao("‹", ROXO, func() -> void: _trocar_fase(-1))
	b_ant.reparent(caixa_fase)
	b_prox = _botao("›", ROXO, func() -> void: _trocar_fase(1))
	b_prox.reparent(caixa_fase)
	b_pronto = _botao("PRONTO", VERDE, _alternar_pronto)
	b_comecar = _botao("COMEÇAR!", OURO, _comecar)
	espera = _rotulo("", 22, 6)
	Online.conectou.connect(_atualizar)
	Online.jogadores_mudou.connect(_atualizar)
	Online.caiu.connect(_caiu)
	Online.recebeu.connect(_recebeu)
	get_viewport().size_changed.connect(_layout)
	Online.pronto = false
	if Online.sala != "":                         # voltou da partida: já está na sala
		Online.oi()
	_atualizar()
	for a in OS.get_cmdline_user_args():           # teste automático: entra direto
		if a.begins_with("sala="):
			campo.text = a.substr(5)
			if "host" in OS.get_cmdline_user_args():
				Online.entrar(campo.text, true)
				for b in OS.get_cmdline_user_args():
					if b.begins_with("fase="):
						Online.fase_sala = int(b.substr(5))
				if "auto" in OS.get_cmdline_user_args():      # teste: começa quando alguém entrar e der pronto
					while not (Online.conectado and not Online.jogadores.is_empty() and _todos_prontos()):
						await get_tree().create_timer(0.5).timeout
					_comecar()
					return
			else:
				_entrar()
				if "pronto" in OS.get_cmdline_user_args():
					while not Online.conectado:
						await get_tree().create_timer(0.5).timeout
					await get_tree().create_timer(1.5).timeout
					_alternar_pronto()
			_atualizar()

func _process(delta: float) -> void:
	_t_ui -= delta
	if _t_ui > 0.0:
		return
	_t_ui = 0.25
	if Online.sala == "" or not Online.conectado:
		return
	if not Online.host:                              # segue a fase que o líder escolheu
		for k in Online.jogadores:
			var j: Dictionary = Online.jogadores[k]
			if j.get("host", false) and j.has("fase") and int(j["fase"]) != Online.fase_sala:
				Online.fase_sala = int(j["fase"])
				if Online.pronto:                    # mudou o mapa: precisa dar pronto de novo
					Online.pronto = false
					Online.oi()
	_atualizar()

func _caiu() -> void:
	info.text = "Conexão caiu. Tenta de novo."
	_atualizar()

func _criar() -> void:
	Online.fase_sala = Game.fase if Game.ORDEM.has(Game.fase) else 1
	Online.entrar(Online.novo_codigo(), true)
	info.text = "Conectando..."
	_atualizar()

## janela nativa do navegador pra digitar: sempre abre o teclado do celular
func _pedir_codigo() -> void:
	var r = JavaScriptBridge.eval("(window.prompt('Código da sala (4 letras):', '') || '')", true)
	var t := str(r).strip_edges().to_upper().left(4)
	if t != "":
		campo.text = t
		campo.release_focus()
		if t.length() == 4:
			_entrar()

func _entrar() -> void:
	if campo.text.strip_edges().length() != 4 and OS.has_feature("web"):
		_pedir_codigo()
		return
	if campo.text.strip_edges().length() != 4:
		info.text = "O código tem 4 letras."
		return
	Online.entrar(campo.text, false)
	info.text = "Conectando..."
	_atualizar()

func _trocar_fase(d: int) -> void:
	if not Online.host:
		return
	var i := Game.ORDEM.find(Online.fase_sala)
	Online.fase_sala = Game.ORDEM[posmod(i + d, Game.ORDEM.size())]
	Online.oi()
	_atualizar()

func _alternar_pronto() -> void:
	Online.pronto = not Online.pronto
	Online.oi()
	if Online.pronto:
		Audio.tocar("confirma")
	_atualizar()

func _todos_prontos() -> bool:
	for k in Online.jogadores:
		var j: Dictionary = Online.jogadores[k]
		if not j.get("host", false) and not j.get("pronto", false):
			return false
	return true

func _comecar() -> void:
	if not Online.host or not Online.conectado or not _todos_prontos():
		return
	var ids := [Online.id] + Online.jogadores.keys()
	Online.rodada += 1
	Online.enviar("comecar", {"ids": ids, "r": Online.rodada, "fase": Online.fase_sala})
	_ir(ids, Online.fase_sala)

func _recebeu(e: String, d: Dictionary, _de: String) -> void:
	if e == "comecar" and not Online.host:
		var ids: Array = d.get("ids", [])
		if Online.id in ids and int(d.get("r", 1)) > Online.rodada:
			Online.rodada = int(d.get("r", 1))
			_ir(ids, int(d.get("fase", 5)))

func _ir(ids: Array, fase: int) -> void:
	Online.ativo = true
	Online.pronto = false
	Online.corrida = {"r": Online.rodada, "fase": fase, "ids": ids, "largou": false, "chegadas": {}, "primeiro_ms": -1}
	Game.online_n = clampi(ids.size(), 1, Online.MAX_JOGADORES)
	Game.fase = fase
	Game.checkpoint_x = -1.0
	Audio.tocar("confirma")
	get_tree().change_scene_to_file("res://levels/Main.tscn")

func _voltar() -> void:
	Online.sair()
	get_tree().change_scene_to_file("res://levels/Fases.tscn")

func _atualizar() -> void:
	var na_sala := Online.sala != ""
	campo.visible = not na_sala
	b_criar.visible = not na_sala
	b_entrar.visible = not na_sala
	info.visible = not na_sala or not Online.conectado
	for n in [caixa_jog, caixa_fase, espera]:
		n.visible = na_sala and Online.conectado
	b_pronto.visible = na_sala and Online.conectado and not Online.host
	b_comecar.visible = na_sala and Online.conectado and Online.host
	if na_sala and not Online.conectado:
		info.text = "Conectando..."
	if na_sala and Online.conectado:
		codigo_lbl.text = Online.sala
		dica_codigo.text = "Passa esse código pros amigos (até %d jogadores)" % Online.MAX_JOGADORES
		var f := Online.fase_sala
		mini.texture = load("res://assets/ui/fase_%d.png" % f)
		nome_fase.text = Game.nome_fase(f)
		modo_fase.text = ("TODOS JUNTOS contra o chefe: todo mundo tem que apertar os botões." if f == 5
			else "CORRIDA: quem chegar primeiro ganha. Morreu, volta pro começo.")
		if not Online.host:
			modo_fase.text += "\nO líder escolhe a fase."
		b_ant.visible = Online.host
		b_prox.visible = Online.host
		_montar_lista()
		var faltam: Array = []
		for k in Online.jogadores:
			var j: Dictionary = Online.jogadores[k]
			if not j.get("host", false) and not j.get("pronto", false):
				faltam.append(str(j.get("nome", "?")))
		if Online.host:
			b_comecar.disabled = not faltam.is_empty()
			b_comecar.modulate.a = 1.0 if faltam.is_empty() else 0.45
			espera.text = ("Esperando dar pronto: " + ", ".join(faltam)) if not faltam.is_empty() else (
				"Todo mundo pronto! Aperta COMEÇAR." if not Online.jogadores.is_empty() else "Esperando alguém entrar... (dá pra começar sozinho)")
		else:
			b_pronto.text = "PRONTO ✓" if Online.pronto else "DAR PRONTO"
			espera.text = "Você tá pronto. Esperando o líder começar." if Online.pronto else "Aperta DAR PRONTO quando estiver preparado."
	_layout()

func _montar_lista() -> void:
	var itens: Array = [[Online.id, Online.meu_nome(), Game.personagem, Online.host, Online.pronto]]
	for k in Online.jogadores:
		var j: Dictionary = Online.jogadores[k]
		itens.append([k, str(j.get("nome", "?")), str(j.get("p", "")), j.get("host", false), j.get("pronto", false)])
	var ass := str(itens)
	if ass == _assinatura:
		return
	_assinatura = ass
	for n in linhas.get_children():
		n.queue_free()
	for it in itens:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1, 0.07)
		st.set_corner_radius_all(12)
		st.content_margin_left = 8
		st.content_margin_right = 16
		st.content_margin_top = 6
		st.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", st)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(h)
		var r := TextureRect.new()
		if ResourceLoader.exists("res://assets/ui/rosto_%s.png" % it[2]):
			r.texture = load("res://assets/ui/rosto_%s.png" % it[2])
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(48, 48)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
		var nome := _rotulo(str(it[1]) + ("  (você)" if it[0] == Online.id else ""), 26, 8)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nome.autowrap_mode = TextServer.AUTOWRAP_OFF
		nome.clip_text = true
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.reparent(h)
		var est := _rotulo("LÍDER" if it[3] else ("PRONTO" if it[4] else "esperando..."), 24, 8)
		est.add_theme_color_override("font_color", OURO if it[3] else (VERDE if it[4] else Color(0.8, 0.75, 0.9, 0.8)))
		est.autowrap_mode = TextServer.AUTOWRAP_OFF
		est.reparent(h)
		linhas.add_child(p)

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	titulo.size = Vector2(v.x, 90)
	titulo.position = Vector2(0, 18)
	info.size = Vector2(v.x - 120, 80)
	info.position = Vector2(60, 120)
	campo.size = Vector2(260, 80)
	campo.position = Vector2(v.x / 2.0 - 130, 250)
	b_entrar.position = Vector2(v.x / 2.0 + 150, 252)
	b_criar.position = Vector2(v.x / 2.0 - b_criar.size.x / 2.0, 400)
	b_voltar.position = Vector2(30, v.y - 100)
	var lj := minf(500.0, v.x * 0.42)
	caixa_jog.position = Vector2(40, 110)
	caixa_jog.size = Vector2(lj, v.y - 250)
	codigo_lbl.position = Vector2(0, 6)
	codigo_lbl.size = Vector2(lj, 90)
	dica_codigo.position = Vector2(10, 92)
	dica_codigo.size = Vector2(lj - 20, 30)
	linhas.position = Vector2(18, 136)
	linhas.size = Vector2(lj - 36, caixa_jog.size.y - 150)
	caixa_fase.position = Vector2(40 + lj + 30, 110)
	caixa_fase.size = Vector2(v.x - caixa_fase.position.x - 40, v.y - 250)
	var lf := caixa_fase.size.x
	var alt_mini := minf((lf - 40) * 9.0 / 16.0, caixa_fase.size.y - 190)
	mini.size = Vector2(alt_mini * 16.0 / 9.0, alt_mini)
	mini.position = Vector2((lf - mini.size.x) / 2.0, 20)
	nome_fase.position = Vector2(70, 30 + alt_mini)
	nome_fase.size = Vector2(lf - 140, 50)
	b_ant.position = Vector2(14, 28 + alt_mini)
	b_ant.size = Vector2(54, 54)
	b_prox.position = Vector2(lf - 68, 28 + alt_mini)
	b_prox.size = Vector2(54, 54)
	modo_fase.position = Vector2(20, 88 + alt_mini)
	modo_fase.size = Vector2(lf - 40, 80)
	espera.position = Vector2(260, v.y - 128)
	espera.size = Vector2(v.x - 560, 40)
	b_pronto.position = Vector2(v.x - b_pronto.size.x - 40, v.y - 110)
	b_comecar.position = Vector2(v.x - b_comecar.size.x - 40, v.y - 110)

func _caixa_painel() -> Panel:
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

func _rotulo(t: String, tam: int, contorno: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.3))
	l.add_theme_constant_override("outline_size", contorno)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _botao(t: String, borda: Color, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 34)
	var sv := StyleBoxFlat.new()
	sv.bg_color = Color(0.09, 0.05, 0.18, 0.88)
	sv.set_corner_radius_all(16)
	sv.set_border_width_all(3)
	sv.border_color = borda
	sv.content_margin_left = 26
	sv.content_margin_right = 26
	sv.content_margin_top = 10
	sv.content_margin_bottom = 10
	for k in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(k, sv)
	b.pressed.connect(func() -> void:
		Audio.tocar("clique")
		f.call())
	add_child(b)
	return b
