extends Control
## Lobby de escolha de personagem: arena roxa ao fundo, rostos no topo (o escolhido
## com moldura dourada e "SELECIONADO"), o personagem em pé no pedestal, nome grande
## com título, caixa do especial, barras de vida/velocidade/força e o botão JOGAR.

const OPCOES := ["segway", "cadeira", "scooter", "monociclo", "gamer", "bicho", "wendell", "caio", "lima", "chefe", "vini"]
## título, especial, descrição, [vida, velocidade, força] (0..4)
const INFO := {
	"segway": ["EQUILIBRISTA", "SUPER SALTO", "Pulo reforçado pra passar por cima dos obstáculos.", [3, 3, 2]],
	"cadeira": ["TURBINADO", "TURBO INFINITO", "Jato na cadeira que nunca acaba.", [3, 4, 2]],
	"scooter": ["PIROTÉCNICO", "TURBO + BOMBA", "Turbo pra acelerar e bomba no outro botão.", [3, 4, 3]],
	"monociclo": ["MALABARISTA", "PULO DUPLO", "Pula no chão e pula de novo no ar.", [2, 3, 2]],
	"gamer": ["GAMER", "TURBO", "Cadeira gamer com jato nas costas.", [3, 3, 2]],
	"bicho": ["COMPRADOR", "BALÕES", "Três balões nas costas: plana por 10 segundos.", [3, 2, 2]],
	"wendell": ["MOTOQUEIRO", "ESTRELA", "Fica imortal por 10 segundos, igual ao Mário.", [3, 4, 3]],
	"caio": ["EQUILIBRISTA", "RAPIDEZ", "Fica muito mais rápido por 8 segundos.", [2, 4, 2]],
	"lima": ["DOMADOR", "MEGA PULO", "Segura pra mirar e solta: o gorila salta longe.", [4, 3, 4]],
	"chefe": ["O CHEFE", "SEM CAMISA", "Tira a camisa e rebate os golpes dos chefões.", [3, 4, 4]],
	"vini": ["SECRETO", "DASH", "Arrancada rapidíssima. Segurando no ar, plana.", [2, 4, 3]],
}
const ICONES := {"salto": "pula", "turbo": "turbo", "pulo_duplo": "pula", "baloes": "baloes", "estrela": "estrela",
	"rapido": "rapido", "mega_pulo": "mega_pulo", "repele": "repele", "dash": "dash"}
const ROXO := Color(0.6, 0.38, 1.0)
const ROXO_ESCURO := Color(0.09, 0.05, 0.18, 0.82)
const OURO := Color(1.0, 0.8, 0.25)

var atual := 0
var fundo: TextureRect
var nevoa: ColorRect
var logo: TextureRect
var titulo_lista: Label
var quadros: Array = []
var nomes_quadro: Array = []
var selo: Label
var preview: TextureRect
var nome: Label
var subtitulo: Label
var caixa_esp: Panel
var esp_icone: TextureRect
var esp_nome: Label
var esp_desc: Label
var caixa_stats: Panel
var barras: Array = []                  # [[ColorRect x4] x3]
var ok: TextureButton
var ok_anel: Panel
var jogar: Label
var trava: Label
var _t := 0.0
var _rank: Button
var _vol: Volume

func _ready() -> void:
	Audio.musica_menu(true)
	Audio.motor(false)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	atual = maxi(0, OPCOES.find(Game.personagem))
	fundo = TextureRect.new()
	fundo.texture = load("res://assets/ui/lobby.jpg")
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(fundo)
	nevoa = ColorRect.new()                          # névoa roxa se mexendo devagar por cima do fundo
	nevoa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/ui/nevoa.gdshader")
	nevoa.material = mat
	add_child(nevoa)
	logo = TextureRect.new()
	logo.texture = load("res://assets/ui/logo_roxo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(logo)
	titulo_lista = _rotulo("ESCOLHER PERSONAGEM", 22, 6, Color(0.82, 0.7, 1.0))
	add_child(titulo_lista)
	for i in OPCOES.size():
		var q := Panel.new()
		add_child(q)
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.offset_left = 4; b.offset_top = 4; b.offset_right = -4; b.offset_bottom = -4
		b.pressed.connect(_selecionar.bind(i))
		q.add_child(b)
		var n := _rotulo("", 17, 5, Color.WHITE)
		q.add_child(n)
		nomes_quadro.append(n)
		quadros.append(q)
	selo = _rotulo("SELECIONADO", 12, 0, Color(0.15, 0.08, 0.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = OURO
	sb.set_corner_radius_all(4)
	selo.add_theme_stylebox_override("normal", sb)
	add_child(selo)

	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(preview)

	nome = _rotulo("", 110, 22, Color.WHITE)
	nome.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.5))
	nome.add_theme_color_override("font_shadow_color", Color(0.55, 0.3, 1.0, 0.8))
	nome.add_theme_constant_override("shadow_offset_x", 0)
	nome.add_theme_constant_override("shadow_offset_y", 8)
	add_child(nome)
	subtitulo = _rotulo("", 30, 8, Color(0.78, 0.62, 1.0))
	add_child(subtitulo)

	caixa_esp = Panel.new()
	caixa_esp.add_theme_stylebox_override("panel", _caixa(ROXO, 16))
	add_child(caixa_esp)
	var esp_tit := _rotulo("E S P E C I A L", 15, 0, Color(0.75, 0.65, 0.95))
	esp_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	esp_tit.position = Vector2(22, 12)
	caixa_esp.add_child(esp_tit)
	var moldura := Panel.new()
	moldura.add_theme_stylebox_override("panel", _caixa(ROXO, 12))
	moldura.position = Vector2(20, 44)
	moldura.size = Vector2(96, 96)
	caixa_esp.add_child(moldura)
	esp_icone = TextureRect.new()
	esp_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	esp_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	esp_icone.position = Vector2(10, 10)
	esp_icone.size = Vector2(76, 76)
	moldura.add_child(esp_icone)
	esp_nome = _rotulo("", 26, 6, Color.WHITE)
	esp_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	esp_nome.position = Vector2(132, 46)
	esp_nome.size = Vector2(250, 34)
	caixa_esp.add_child(esp_nome)
	esp_desc = Label.new()
	esp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esp_desc.add_theme_font_size_override("font_size", 18)
	esp_desc.add_theme_color_override("font_color", Color(0.86, 0.82, 0.95))
	esp_desc.position = Vector2(132, 84)
	esp_desc.size = Vector2(250, 60)
	caixa_esp.add_child(esp_desc)

	caixa_stats = Panel.new()
	caixa_stats.add_theme_stylebox_override("panel", _caixa(Color(0.45, 0.3, 0.8), 18))
	add_child(caixa_stats)
	var stats := [["VIDA", Color(1.0, 0.3, 0.4)], ["VELOCIDADE", Color(0.3, 0.6, 1.0)], ["FORÇA", Color(1.0, 0.8, 0.25)]]
	for k in 3:
		var ic := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = stats[k][1]
		st.set_corner_radius_all(20)
		ic.add_theme_stylebox_override("panel", st)
		ic.position = Vector2(28 + k * 200, 26)
		ic.size = Vector2(34, 34)
		caixa_stats.add_child(ic)
		var tl := _rotulo(stats[k][0], 16, 4, Color.WHITE)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tl.position = Vector2(74 + k * 200, 14)
		caixa_stats.add_child(tl)
		var fila: Array = []
		for j in 4:
			var r := ColorRect.new()
			r.position = Vector2(74 + k * 200 + j * 28, 42)
			r.size = Vector2(24, 14)
			r.set_meta("cor", stats[k][1])
			caixa_stats.add_child(r)
			fila.append(r)
		barras.append(fila)
		if k < 2:
			var sep := ColorRect.new()
			sep.color = Color(1, 1, 1, 0.15)
			sep.position = Vector2(194 + k * 200, 14)
			sep.size = Vector2(2, 50)
			caixa_stats.add_child(sep)

	ok_anel = Panel.new()
	var sa := StyleBoxFlat.new()
	sa.bg_color = Color(0.2, 0.1, 0.4, 0.9)
	sa.set_corner_radius_all(90)
	sa.set_border_width_all(8)
	sa.border_color = ROXO
	sa.shadow_color = Color(0.6, 0.35, 1.0, 0.7)
	sa.shadow_size = 22
	ok_anel.add_theme_stylebox_override("panel", sa)
	ok_anel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ok_anel)
	ok = TextureButton.new()
	ok.texture_normal = load("res://assets/ui/confirma.png")
	ok.ignore_texture_size = true
	ok.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ok.pressed.connect(_jogar)
	add_child(ok)
	jogar = _rotulo("JOGAR", 46, 12, Color.WHITE)
	jogar.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.6))
	add_child(jogar)
	trava = _rotulo("VENÇA O PÉCE (FASE 7) PRA LIBERAR", 26, 8, OURO)
	add_child(trava)

	var ver := _rotulo(Game.VERSAO, 16, 4, Color(1, 1, 1, 0.55))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(10, get_viewport().get_visible_rect().size.y - 26)
	add_child(ver)
	_rank = Button.new()                             # antes do volume: a barrinha dele abre por cima
	_rank.text = "RANKING"
	_rank.focus_mode = Control.FOCUS_NONE
	_rank.add_theme_font_size_override("font_size", 28)
	for k in ["normal", "hover", "pressed"]:
		_rank.add_theme_stylebox_override(k, _caixa(OURO, 14))
	_rank.size = Vector2(190, 64)
	_rank.pressed.connect(func() -> void:
		Audio.tocar("clique")
		get_tree().change_scene_to_file("res://levels/Ranking.tscn"))
	add_child(_rank)
	_vol = Volume.new()
	_vol.abre_direita = true
	add_child(_vol)
	get_viewport().size_changed.connect(_atualizar)
	_atualizar()

	if "screenshot" in OS.get_cmdline_user_args():
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://menu.png")
		get_tree().quit()

func _process(delta: float) -> void:
	_t += delta
	if ok_anel:                                      # botão pulsando
		var s := 1.0 + 0.04 * sin(_t * 4.0)
		ok_anel.scale = Vector2.ONE * s
	if quadros.size() > atual:
		var st: StyleBoxFlat = (quadros[atual] as Panel).get_theme_stylebox("panel")
		if st:
			st.shadow_size = int(10 + 6 * absf(sin(_t * 3.0)))

func _rotulo(texto: String, tamanho: int, contorno: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", contorno)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _caixa(borda: Color, raio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ROXO_ESCURO
	s.set_corner_radius_all(raio)
	s.set_border_width_all(3)
	s.border_color = borda
	s.shadow_color = Color(borda, 0.35)
	s.shadow_size = 10
	return s

func _estilo_quadro(destaque: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.35, 0.2, 0.7, 0.55) if destaque else Color(0.08, 0.05, 0.16, 0.75)
	s.set_corner_radius_all(8)
	s.set_border_width_all(4 if destaque else 2)
	s.border_color = OURO if destaque else Color(0.45, 0.32, 0.75, 0.9)
	s.shadow_color = Color(1, 0.75, 0.2, 0.55) if destaque else Color(0, 0, 0, 0)
	s.shadow_size = 12 if destaque else 0
	return s

func _atualizar() -> void:
	var vp := get_viewport().get_visible_rect().size
	# fundo cobrindo a tela (guarda a escala pra pôr o personagem em cima do pedestal)
	var tw := 1672.0
	var th := 941.0
	var esc := maxf(vp.x / tw, vp.y / th)
	var off := (vp - Vector2(tw, th) * esc) / 2.0
	fundo.position = off
	fundo.size = Vector2(tw, th) * esc
	nevoa.position = Vector2.ZERO
	nevoa.size = vp
	var pedestal_y := off.y + 0.775 * th * esc
	logo.position = Vector2(22, 14)
	logo.size = Vector2(270, 145)
	# rostos
	var lado := minf(76.0, (vp.x - 340.0) / OPCOES.size() - 10.0)
	var x0 := maxf(310.0, vp.x / 2.0 - (OPCOES.size() * (lado + 10) - 10) / 2.0 + 120)
	titulo_lista.size = Vector2(OPCOES.size() * (lado + 10), 30)
	titulo_lista.position = Vector2(x0, 10)
	titulo_lista.text = "———   ESCOLHER PERSONAGEM   ———"
	for i in quadros.size():
		var q: Panel = quadros[i]
		q.position = Vector2(x0 + i * (lado + 10), 48)
		q.size = Vector2(lado, lado)
		q.add_theme_stylebox_override("panel", _estilo_quadro(i == atual))
		var b: TextureButton = q.get_child(0)
		var tex: String = OPCOES[i] if i == atual else OPCOES[i] + "_cinza"
		if _trancado(i):
			tex = OPCOES[i] + "_bloq"
		b.texture_normal = load("res://assets/ui/rosto_%s.png" % tex)
		var n: Label = nomes_quadro[i]
		n.text = "???" if _trancado(i) else Game.NOMES[OPCOES[i]]
		n.position = Vector2(-20, lado + 2)
		n.size = Vector2(lado + 40, 24)
		n.add_theme_color_override("font_color", Color.WHITE if i == atual else Color(0.85, 0.8, 0.95, 0.75))
	selo.position = (quadros[atual] as Panel).position + Vector2(lado / 2.0 - 52, -16)
	selo.size = Vector2(104, 18)
	# personagem no pedestal
	var p: String = OPCOES[atual]
	var preso := _trancado(atual)
	var tex2: Texture2D = load("res://assets/menu/%s.png" % p)
	preview.texture = tex2
	var h := minf(minf(vp.y * 0.74, pedestal_y - 165.0), minf(vp.x * 0.45, 640.0) * tex2.get_height() / tex2.get_width())
	preview.size = Vector2(h * tex2.get_width() / tex2.get_height(), h)
	var limite := 46.0 + minf(360.0, vp.x * 0.27) + 16.0     # não entra embaixo da caixa do especial
	var cx := maxf(vp.x / 2.0, limite + preview.size.x / 2.0)
	preview.position = Vector2(cx - preview.size.x / 2.0, pedestal_y - h + 6)
	preview.modulate = Color(0, 0, 0, 0.9) if preso else Color.WHITE
	# nome e título
	var info: Array = INFO[p]
	nome.text = "???" if preso else Game.NOMES[p]
	nome.add_theme_font_size_override("font_size", 110 if nome.text.length() <= 6 else 88)
	nome.size = Vector2(minf(520.0, vp.x * 0.36), 130)
	nome.position = Vector2(40, vp.y * 0.30)
	subtitulo.text = "——  %s  ——" % ("???" if preso else info[0])
	subtitulo.size = Vector2(nome.size.x, 40)
	subtitulo.position = nome.position + Vector2(0, 128)
	# especial
	caixa_esp.size = Vector2(minf(360.0, vp.x * 0.27), 170)
	caixa_esp.position = Vector2(46, vp.y * 0.30 + 190)
	esp_nome.size.x = caixa_esp.size.x - 150
	esp_desc.size.x = caixa_esp.size.x - 150
	esp_nome.text = "???" if preso else info[1]
	esp_desc.text = "Personagem secreto." if preso else info[2]
	esp_icone.texture = load("res://assets/ui/%s.png" % ICONES.get(Game.HABILIDADES.get(p, "salto"), "pula"))
	esp_icone.modulate = Color(0, 0, 0, 0.9) if preso else Color.WHITE
	# atributos
	caixa_stats.size = Vector2(620, 80)
	caixa_stats.position = Vector2(vp.x / 2.0 - 310, vp.y - 98)
	var vals: Array = info[3]
	for k in 3:
		for j in 4:
			var r: ColorRect = barras[k][j]
			r.color = (r.get_meta("cor") as Color) if j < int(vals[k]) and not preso else Color(1, 1, 1, 0.14)
	# jogar
	var d := 150.0
	ok_anel.size = Vector2(d, d)
	ok_anel.pivot_offset = Vector2(d, d) / 2.0
	ok_anel.position = Vector2(vp.x - d - 50, vp.y - d - 92)
	ok.size = Vector2(d * 0.62, d * 0.62)
	ok.position = ok_anel.position + Vector2(d * 0.19, d * 0.19)
	jogar.size = Vector2(d + 60, 60)
	jogar.position = Vector2(ok_anel.position.x - 30, ok_anel.position.y + d + 6)
	ok.visible = not preso
	ok_anel.visible = not preso
	jogar.visible = not preso
	trava.visible = preso
	trava.size = Vector2(420, 70)
	trava.position = Vector2(vp.x - 440, vp.y - 170)
	if _vol:
		_vol.position = Vector2(30, vp.y - 112)
		_rank.position = Vector2(122, vp.y - 112)

func _trancado(i: int) -> bool:
	return OPCOES[i] == "vini" and not Game.vini_liberado()

func _selecionar(i: int) -> void:
	Audio.tocar("clique")
	atual = i
	_atualizar()

func _jogar() -> void:
	if _trancado(atual):
		return
	Audio.tocar("confirma")
	Game.personagem = OPCOES[atual]
	Game.checkpoint_x = -1.0
	get_tree().change_scene_to_file("res://levels/Fases.tscn")
