extends Control
## Lobby de escolha de personagem: arena roxa ao fundo, rostos no topo (o escolhido
## com moldura dourada e "SELECIONADO"), o personagem em pé no pedestal, nome grande
## com título, caixa do especial, barras de vida/velocidade/força e o botão JOGAR.

const OPCOES := ["segway", "cadeira", "scooter", "monociclo", "gamer", "bicho", "wendell", "caio", "lima", "chefe", "sartori", "boucas", "vini"]
## título, especial, descrição, [vida, velocidade, força] (0..4)
const INFO := {
	"segway": ["EQUILIBRISTA", "SUPER SALTO", "Pulo reforçado pra passar por cima dos obstáculos.", [3, 3, 2]],
	"cadeira": ["TURBINADO", "TURBO INFINITO", "Jato na cadeira que nunca acaba.", [3, 4, 2]],
	"scooter": ["PIROTÉCNICO", "TURBO + BOMBA", "Turbo pra acelerar e bomba no outro botão.", [3, 4, 3]],
	"monociclo": ["MALABARISTA", "PULO DUPLO", "Pula no chão e pula de novo no ar.", [2, 3, 2]],
	"gamer": ["SOLDADO GAMER", "TURBO + ULT", "Turbo infinito. No outro botão, a ult: fica muito mais rápido, com rastro vermelho.", [3, 4, 2]],
	"bicho": ["COMPRADOR", "TELEPORTE + LASER", "Some num clarão e reaparece lá na frente. No outro botão, o laser: parado, derrete o chefe cada vez mais rápido.", [3, 3, 4]],
	"wendell": ["MOTOQUEIRO", "ESTRELA", "Fica imortal por 10 segundos, igual ao Mário.", [3, 4, 3]],
	"caio": ["EQUILIBRISTA", "RAPIDEZ", "Fica muito mais rápido por 8 segundos.", [2, 4, 2]],
	"lima": ["DOMADOR", "MEGA PULO", "Segura pra mirar e solta: o gorila salta longe.", [4, 3, 4]],
	"chefe": ["O CHEFE", "SEM CAMISA", "Tira a camisa e rebate os golpes dos chefões.", [3, 4, 4]],
	"sartori": ["BEACH TENNIS", "RAQUETADA", "Bate a raquete sem parar: rebate tudo que vem nele e fica bem rápido. Não machuca chefe.", [3, 4, 2]],
	"boucas": ["AVIADOR", "TURBO + ESQUADRILHA", "O avião de papel plana sozinho no ar e é muito ágil. Turbo infinito no especial e, no outro botão, a esquadrilha: 14 aviões de papel que voam no chefe e tiram vida dele.", [3, 4, 3]],
	"vini": ["SECRETO", "DASH", "Arrancada rapidíssima. Segurando no ar, plana.", [2, 4, 3]],
}
const ICONES := {"salto": "pula", "turbo": "turbo", "pulo_duplo": "pula", "baloes": "baloes", "estrela": "estrela",
	"rapido": "rapido", "mega_pulo": "mega_pulo", "repele": "repele", "dash": "dash", "raquete": "repele", "teleporte": "dash"}
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
var jogar: Button
var online: Button
var trava: Label
var _t := 0.0
var _nivel_btn: Button
var _nivel_barra: ColorRect
var _nivel_fundo: ColorRect
var _nivel_txt: Label
var _nivel_prox: Label
var _ponto_passe: Panel
var _passe_st: StyleBoxFlat
var _passe_brilho: ColorRect
var _passe_icone: IconeItem
var _passe_tit: Label
var _ponto_inv: Panel
var _atalhos: Array = []              # LOJA, INVENTÁRIO, RANKING, CONTA (grade 2x2 na direita)
var _continuar: Button
var _vol: Volume
var _engr: Button
var _ajustes: Panel
var _leve: Button

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
	_nivel_btn = Button.new()                        # cartão do passe: nível, barra de XP e o próximo prêmio
	_nivel_btn.focus_mode = Control.FOCUS_NONE
	_nivel_btn.clip_contents = true
	_passe_st = StyleBoxFlat.new()
	_passe_st.bg_color = Color(0.42, 0.22, 0.04, 0.96)
	_passe_st.set_corner_radius_all(18)
	_passe_st.set_border_width_all(4)
	_passe_st.border_color = OURO
	_passe_st.shadow_color = Color(1, 0.75, 0.2, 0.5)
	_passe_st.shadow_size = 16
	var sp_p := _passe_st.duplicate() as StyleBoxFlat
	sp_p.bg_color = Color(0.32, 0.16, 0.03, 0.96)
	_nivel_btn.add_theme_stylebox_override("normal", _passe_st)
	_nivel_btn.add_theme_stylebox_override("hover", _passe_st)
	_nivel_btn.add_theme_stylebox_override("pressed", sp_p)
	_passe_brilho = ColorRect.new()                  # faixa de brilho passando
	_passe_brilho.color = Color(1, 0.95, 0.75, 0.22)
	_passe_brilho.size = Vector2(46, 260)
	_passe_brilho.rotation = 0.45
	_passe_brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nivel_btn.add_child(_passe_brilho)
	var circ := Panel.new()
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0.1, 0.05, 0.02, 0.6)
	sc.set_corner_radius_all(40)
	sc.set_border_width_all(3)
	sc.border_color = Color(1, 0.85, 0.4)
	circ.add_theme_stylebox_override("panel", sc)
	circ.name = "circ"
	circ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nivel_btn.add_child(circ)
	_passe_icone = IconeItem.new()
	_passe_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_passe_icone.size = Vector2(130, 130)
	_passe_icone.scale = Vector2(0.52, 0.52)
	circ.add_child(_passe_icone)
	_passe_tit = _rotulo("PASSE DE BATALHA  ›", 16, 5, Color(1, 0.92, 0.7))
	_passe_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nivel_btn.add_child(_passe_tit)
	_nivel_btn.pressed.connect(func() -> void:
		Audio.tocar("clique")
		_marcar_visto()
		get_tree().change_scene_to_file("res://levels/PasseTela.tscn"))
	add_child(_nivel_btn)
	_nivel_txt = _rotulo("", 30, 7, Color.WHITE)
	_nivel_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nivel_btn.add_child(_nivel_txt)
	_nivel_fundo = ColorRect.new()
	_nivel_fundo.color = Color(1, 1, 1, 0.12)
	_nivel_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nivel_btn.add_child(_nivel_fundo)
	_nivel_barra = ColorRect.new()
	_nivel_barra.color = Color(1.0, 0.85, 0.3)
	_nivel_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nivel_btn.add_child(_nivel_barra)
	_nivel_prox = _rotulo("", 15, 4, Color(1, 0.9, 0.7))
	_nivel_prox.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nivel_prox.clip_text = true
	_nivel_btn.add_child(_nivel_prox)
	_ponto_passe = _ponto()
	_nivel_btn.add_child(_ponto_passe)
	Passe.mudou.connect(_texto_nivel)
	_texto_nivel()
	Passe.atualizar()
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

	online = _botao_grande("ONLINE", "online", ROXO, Color(0.3, 0.16, 0.6, 0.95), Color.WHITE, 30)
	online.pressed.connect(_online)
	add_child(online)
	jogar = _botao_grande("JOGAR", "play", Color(1.0, 0.92, 0.6), Color(1.0, 0.74, 0.18), Color(0.2, 0.06, 0.32), 46)
	jogar.pressed.connect(_jogar)
	add_child(jogar)
	trava = _rotulo("VENÇA O PÉCE (FASE 7) PRA LIBERAR", 26, 8, OURO)
	add_child(trava)

	var ver := _rotulo(Game.VERSAO, 16, 4, Color(1, 1, 1, 0.55))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(10, get_viewport().get_visible_rect().size.y - 26)
	add_child(ver)
	for a in [["LOJA", "loja", "Loja"], ["INVENTÁRIO", "inventario", "Inventario"], ["RANKING", "ranking", "Ranking"], ["CONTA", "conta", "MinhaConta"]]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		var cx := _caixa(ROXO, 16)
		var cp := cx.duplicate() as StyleBoxFlat
		cp.bg_color = Color(0.25, 0.14, 0.45, 0.95)
		b.add_theme_stylebox_override("normal", cx)
		b.add_theme_stylebox_override("hover", cx)
		b.add_theme_stylebox_override("pressed", cp)
		var ic := IconeMenu.new(a[1], OURO if a[1] == "loja" else Color(0.92, 0.88, 1.0))
		ic.name = "icone"
		b.add_child(ic)
		var tx := _rotulo(a[0], 17, 5, Color.WHITE)
		tx.name = "texto"
		b.add_child(tx)
		var cena: String = a[2]
		b.pressed.connect(func() -> void:
			Audio.tocar("clique")
			if cena == "Inventario":
				_marcar_visto()
			get_tree().change_scene_to_file("res://levels/%s.tscn" % cena))
		add_child(b)
		_atalhos.append(b)
	_ponto_inv = _ponto()
	(_atalhos[1] as Button).add_child(_ponto_inv)
	if not Game.retomada().is_empty():                # a página caiu no meio da fase: volta pro checkpoint
		_continuar = Button.new()
		_continuar.text = "CONTINUAR FASE %d" % int(Game.retomada()["fase"])
		_continuar.focus_mode = Control.FOCUS_NONE
		_continuar.add_theme_font_size_override("font_size", 22)
		_continuar.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
		for k in ["normal", "hover", "pressed"]:
			_continuar.add_theme_stylebox_override(k, _caixa(Color(0.45, 1, 0.5), 14))
		_continuar.pressed.connect(func() -> void:
			Audio.tocar("confirma")
			Game.retomar())
		add_child(_continuar)
	_vol = Volume.new()
	_vol.abre_direita = true
	add_child(_vol)
	_engr = Button.new()                             # ajustes: modo leve (celular fraco)
	_engr.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "pressed"]:
		_engr.add_theme_stylebox_override(k, _caixa(ROXO, 14))
	_engr.size = Vector2(64, 64)
	var ig := IconeMenu.new("engrenagem", Color(0.92, 0.88, 1.0))
	ig.position = Vector2(12, 12)
	ig.size = Vector2(40, 40)
	_engr.add_child(ig)
	_engr.pressed.connect(func() -> void:
		Audio.tocar("clique")
		_ajustes.visible = not _ajustes.visible)
	add_child(_engr)
	_ajustes = Panel.new()
	var sj := _caixa(ROXO, 16)
	sj.bg_color = Color(0.1, 0.06, 0.2)
	_ajustes.add_theme_stylebox_override("panel", sj)
	_ajustes.z_index = 5
	_ajustes.size = Vector2(250, 120)
	_ajustes.visible = false
	add_child(_ajustes)
	var at := _rotulo("AJUSTES", 18, 5, Color(0.75, 0.65, 0.95))
	at.position = Vector2(0, 10)
	at.size = Vector2(250, 24)
	_ajustes.add_child(at)
	_leve = Button.new()                             # celular fraco: menos efeitos e tela mais leve
	_leve.focus_mode = Control.FOCUS_NONE
	_leve.add_theme_font_size_override("font_size", 20)
	_leve.position = Vector2(16, 44)
	_leve.size = Vector2(218, 58)
	_leve.pressed.connect(func() -> void:
		Audio.tocar("clique")
		Game.set_leve(not Game.leve)
		_texto_leve())
	_ajustes.add_child(_leve)
	_texto_leve()
	get_viewport().size_changed.connect(_atualizar)
	if not "screenshot" in OS.get_cmdline_user_args() and not load("res://levels/Novidades.gd").ja_viu():
		add_child(load("res://levels/Novidades.gd").new())     # aviso da atualização, por cima do lobby
	_atualizar()

	if "screenshot" in OS.get_cmdline_user_args():
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://menu.png")
		get_tree().quit()

func _process(delta: float) -> void:
	_t += delta
	if jogar and jogar.visible:                      # botão pulsando
		jogar.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 4.0))
	if _passe_st:                                    # passe: brilho pulsando + faixa passando
		_passe_st.shadow_size = int(14 + 10 * absf(sin(_t * 2.5)))
		_passe_st.border_color = OURO.lerp(Color(1, 1, 0.85), 0.5 + 0.5 * sin(_t * 5.0))
		_passe_brilho.position = Vector2(fmod(_t * 220.0, _nivel_btn.size.x + 500.0) - 160.0, -60)
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
		var pasta := Game.pasta(OPCOES[i])               # skin equipada aparece no rosto e no pedestal
		var tex: String = pasta if i == atual else pasta + "_cinza"
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
	var tex2: Texture2D = load("res://assets/menu/%s.png" % Game.pasta(p))
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
	# coluna da direita: passe, atalhos 2x2, online, jogar
	var cw := 260.0
	var colx := vp.x - cw - 24
	var y := 160.0
	_nivel_btn.position = Vector2(colx, y)
	_nivel_btn.size = Vector2(cw, 104)
	_texto_nivel()
	y += 116
	var tw2 := (cw - 10) / 2.0
	var th2 := clampf((vp.y - 160 - 116 - 76 - 104 - 40) / 2.0 - 10, 64.0, 92.0)
	for i in _atalhos.size():
		var b: Button = _atalhos[i]
		b.position = Vector2(colx + (i % 2) * (tw2 + 10), y + (i / 2) * (th2 + 10))
		b.size = Vector2(tw2, th2)
		var ic: Control = b.get_node("icone")
		var lado_ic := minf(40.0, th2 - 34)
		ic.position = Vector2((tw2 - lado_ic) / 2.0, 8)
		ic.size = Vector2(lado_ic, lado_ic)
		var tx: Label = b.get_node("texto")
		tx.position = Vector2(0, th2 - 28)
		tx.size = Vector2(tw2, 22)
	_ponto_inv.position = Vector2(tw2 - 20, 6)
	y += 2 * (th2 + 10) + 4
	online.position = Vector2(colx, y)
	online.size = Vector2(cw, 64)
	_arruma_grande(online)
	y += 76
	jogar.position = Vector2(colx, y)
	jogar.size = Vector2(cw, 96)
	jogar.pivot_offset = jogar.size / 2.0
	_arruma_grande(jogar)
	jogar.visible = not preso
	online.disabled = preso
	online.modulate = Color(1, 1, 1, 0.4) if preso else Color.WHITE
	trava.visible = preso
	trava.text = "DERROTE O SEMAJ (FASE 10) PRA LIBERAR" if OPCOES[atual] == "boucas" else "VENÇA O PÉCE (FASE 7) PRA LIBERAR"
	trava.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trava.size = Vector2(cw, 96)
	trava.position = jogar.position
	if _continuar:
		_continuar.position = Vector2(34, 166)
		_continuar.size = Vector2(250, 54)
	if _vol:
		_vol.position = Vector2(30, vp.y - 112)
		_engr.position = Vector2(122, vp.y - 112)
		_ajustes.position = Vector2(30, vp.y - 112 - 132)

func _texto_leve() -> void:
	_leve.text = "MODO LEVE ✓" if Game.leve else "MODO LEVE"
	for k in ["normal", "hover", "pressed"]:
		_leve.add_theme_stylebox_override(k, _caixa(Color(0.4, 1.0, 0.5) if Game.leve else ROXO, 14))

func _trancado(i: int) -> bool:
	return (OPCOES[i] == "vini" and not Game.vini_liberado()) or (OPCOES[i] == "boucas" and not Game.boucas_liberado())

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

func _texto_nivel() -> void:
	if not is_instance_valid(_nivel_btn):
		return
	var pr: Array = Passe.progresso()
	var n := Passe.nivel()
	var w := _nivel_btn.size.x
	_nivel_txt.text = "NÍVEL %d" % n
	var circ: Panel = _nivel_btn.get_node("circ")
	circ.position = Vector2(10, 18)
	circ.size = Vector2(68, 68)
	_passe_icone.position = (circ.size - _passe_icone.size * _passe_icone.scale) / 2.0
	var x0 := 88.0
	_passe_tit.position = Vector2(x0, 6)
	_passe_tit.size = Vector2(w - x0 - 10, 22)
	_nivel_txt.position = Vector2(x0, 24)
	_nivel_txt.size = Vector2(w - x0 - 10, 36)
	_nivel_fundo.position = Vector2(x0, 62)
	_nivel_fundo.size = Vector2(w - x0 - 14, 12)
	_nivel_barra.position = _nivel_fundo.position
	_nivel_barra.size = Vector2(maxf(6.0, (w - x0 - 14) * float(pr[0]) / float(pr[1])), 12)
	var prox := ""
	var prox_it: Array = []
	for it in Passe.ITENS:
		if int(it[0]) > n and it[3] != "bonus":
			prox = "Próximo: %s" % it[2]
			prox_it = it
			break
	_passe_icone.item = prox_it if not prox_it.is_empty() else Passe.ITENS[Passe.ITENS.size() - 1]
	_passe_icone._rosto = null
	_nivel_prox.text = prox if prox != "" else "%d / %d XP" % [pr[0], pr[1]]
	_nivel_prox.position = Vector2(x0, 78)
	_nivel_prox.size = Vector2(w - x0 - 10, 20)
	var visto := _visto()
	_ponto_passe.visible = n > visto
	_ponto_passe.position = Vector2(w - 30, 8)
	var novo := false
	for it in Passe.ITENS:
		if int(it[0]) > visto and int(it[0]) <= n and it[3] != "bonus":
			novo = true
	if _ponto_inv:
		_ponto_inv.visible = novo

## nível que a pessoa já viu (pra bolinha vermelha de novidade no passe e no inventário)
func _visto() -> int:
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	return int(cfg.get_value("extra", "passe_visto", 1))

func _marcar_visto() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	cfg.set_value("extra", "passe_visto", maxi(Passe.nivel(), _visto()))
	cfg.save(Game.ARQ_PROGRESSO)

func _ponto() -> Panel:
	var p := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1.0, 0.25, 0.3)
	st.set_corner_radius_all(11)
	st.set_border_width_all(3)
	st.border_color = Color(0.09, 0.05, 0.18)
	p.add_theme_stylebox_override("panel", st)
	p.size = Vector2(22, 22)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	return p

func _botao_grande(texto: String, icone: String, borda: Color, fundo_cor: Color, cor_txt: Color, tam: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = fundo_cor
	st.set_corner_radius_all(22)
	st.set_border_width_all(4)
	st.border_color = borda
	st.shadow_color = Color(fundo_cor, 0.55)
	st.shadow_size = 18
	var sp := st.duplicate() as StyleBoxFlat
	sp.bg_color = fundo_cor.darkened(0.2)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("disabled", st)
	var ic := IconeMenu.new(icone, cor_txt)
	ic.name = "icone"
	b.add_child(ic)
	var tx := _rotulo(texto, tam, 0, cor_txt)
	tx.name = "texto"
	b.add_child(tx)
	return b

func _arruma_grande(b: Button) -> void:
	var h := b.size.y
	var ic: Control = b.get_node("icone")
	var tx: Label = b.get_node("texto")
	var lado_ic := h * 0.42
	var largura_txt := tx.get_theme_font("font").get_string_size(tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tx.get_theme_font_size("font_size")).x
	var total := lado_ic + 14 + largura_txt
	var x0 := (b.size.x - total) / 2.0
	ic.position = Vector2(x0, (h - lado_ic) / 2.0)
	ic.size = Vector2(lado_ic, lado_ic)
	tx.position = Vector2(x0 + lado_ic + 14, 0)
	tx.size = Vector2(largura_txt + 4, h)
	tx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _online() -> void:
	if _trancado(atual):
		return
	Audio.tocar("confirma")
	Game.personagem = OPCOES[atual]
	Game.checkpoint_x = -1.0
	get_tree().change_scene_to_file("res://levels/Sala.tscn")
