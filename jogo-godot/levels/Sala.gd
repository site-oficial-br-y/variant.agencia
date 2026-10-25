extends Control
## Sala online (luta do Péce em grupo): cria uma sala e passa o código pros amigos,
## ou entra com o código de alguém. Quem criou aperta COMEÇAR quando todos estiverem.

var titulo: Label
var info: Label
var codigo_lbl: Label
var lista: Label
var campo: LineEdit
var b_criar: Button
var b_entrar: Button
var b_comecar: Button
var b_voltar: Button

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
	titulo = _rotulo("PÉCE EM GRUPO", 64, 16)
	info = _rotulo("Cria uma sala e passa o código, ou entra com o código de um amigo.", 26, 8)
	codigo_lbl = _rotulo("", 120, 20)
	codigo_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	lista = _rotulo("", 30, 8)
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
	b_criar = _botao("CRIAR SALA", _criar)
	b_entrar = _botao("ENTRAR", _entrar)
	b_comecar = _botao("COMEÇAR!", _comecar)
	b_voltar = _botao("‹ VOLTAR", _voltar)
	Online.conectou.connect(_atualizar)
	Online.jogadores_mudou.connect(_atualizar)
	Online.caiu.connect(func() -> void:
		info.text = "Conexão caiu. Tenta de novo."
		_atualizar())
	Online.recebeu.connect(_recebeu)
	get_viewport().size_changed.connect(_layout)
	_atualizar()
	for a in OS.get_cmdline_user_args():           # teste automático: entra direto
		if a.begins_with("sala="):
			campo.text = a.substr(5)
			if "host" in OS.get_cmdline_user_args():
				Online.entrar(campo.text, true)
				if "auto" in OS.get_cmdline_user_args():      # teste: começa sozinho quando alguém entrar
					while Online.jogadores.is_empty() or not Online.conectado:
						await get_tree().create_timer(0.5).timeout
					_comecar()
					return
			else:
				_entrar()
			_atualizar()

func _rotulo(t: String, tam: int, contorno: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.3))
	l.add_theme_constant_override("outline_size", contorno)
	add_child(l)
	return l

func _botao(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 36)
	var sv := StyleBoxFlat.new()
	sv.bg_color = Color(0.09, 0.05, 0.18, 0.88)
	sv.set_corner_radius_all(16)
	sv.set_border_width_all(3)
	sv.border_color = Color(0.6, 0.38, 1.0)
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

func _criar() -> void:
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

func _comecar() -> void:
	if not Online.host or not Online.conectado:
		return
	var ids := [Online.id] + Online.jogadores.keys()
	Online.rodada = 1
	Online.enviar("comecar", {"ids": ids, "r": 1})
	_ir(ids)

func _recebeu(e: String, d: Dictionary, _de: String) -> void:
	if e == "comecar" and not Online.host:
		var ids: Array = d.get("ids", [])
		if Online.id in ids:
			Online.rodada = int(d.get("r", 1))
			_ir(ids)

func _ir(ids: Array) -> void:
	Online.ativo = true
	Game.online_n = clampi(ids.size(), 1, Online.MAX_JOGADORES)
	Game.fase = 5
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
	codigo_lbl.visible = na_sala
	lista.visible = na_sala
	b_comecar.visible = na_sala and Online.host and Online.conectado
	if na_sala:
		codigo_lbl.text = Online.sala
		if not Online.conectado:
			info.text = "Conectando..."
		else:
			info.text = ("Passa esse código pros amigos (até %d jogadores). Aperta COMEÇAR quando todos entrarem." % Online.MAX_JOGADORES) if Online.host else "Esperando quem criou a sala começar..."
		var nomes: Array = ["• " + Game.NOMES.get(Game.personagem, "?") + " (você)"]
		for k in Online.jogadores:
			var j: Dictionary = Online.jogadores[k]
			nomes.append("• " + str(j.get("nome", "?")) + ("  (criou a sala)" if j.get("host", false) else ""))
		lista.text = "JOGADORES: %d\n" % (nomes.size()) + "\n".join(nomes)
	_layout()

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	titulo.size = Vector2(v.x, 90)
	titulo.position = Vector2(0, 30)
	info.size = Vector2(v.x - 120, 80)
	info.position = Vector2(60, 120)
	codigo_lbl.size = Vector2(v.x, 150)
	codigo_lbl.position = Vector2(0, 190)
	lista.size = Vector2(v.x, 260)
	lista.position = Vector2(0, 340)
	campo.size = Vector2(260, 80)
	campo.position = Vector2(v.x / 2.0 - 130, 250)
	b_entrar.position = Vector2(v.x / 2.0 + 150, 252)
	b_criar.position = Vector2(v.x / 2.0 - b_criar.size.x / 2.0, 400)
	b_comecar.position = Vector2(v.x - b_comecar.size.x - 50, v.y - 120)
	b_voltar.position = Vector2(30, v.y - 100)
