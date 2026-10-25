extends Control
## Mini Block Blast (luta do Geresch): grade 8x8, 3 peças pra arrastar com o dedo/mouse.
## Fechar linha ou coluna dá dano no chefe; fechar várias de uma vez (ou em sequência)
## é combo e dá dano extra. Acaba quando o tempo zera. Roda com o jogo pausado.

signal acabou(dano: int)

const N := 8
const CORES := [Color(1.0, 0.62, 0.18), Color(0.96, 0.3, 0.45), Color(0.32, 0.84, 0.46), Color(0.16, 0.82, 0.72),
	Color(0.24, 0.62, 1.0), Color(0.58, 0.44, 1.0), Color(1.0, 0.83, 0.22)]
const FORMAS := [
	[[0, 0]], [[0, 0], [1, 0]], [[0, 0], [0, 1]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [0, 1], [0, 2]],
	[[0, 0], [1, 0], [2, 0], [3, 0]], [[0, 0], [0, 1], [0, 2], [0, 3]], [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]],
	[[0, 0], [1, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]],
	[[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2]],
	[[0, 0], [0, 1], [1, 1]], [[1, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [0, 1]], [[0, 0], [1, 0], [1, 1]],
	[[0, 0], [0, 1], [0, 2], [1, 2]], [[1, 0], [1, 1], [1, 2], [0, 2]], [[0, 0], [1, 0], [2, 0], [2, 1]],
	[[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [1, 0], [1, 1], [2, 1]], [[1, 0], [2, 0], [0, 1], [1, 1]],
]

var duracao := 25.0
var tempo := 25.0
var avatar: Texture2D                # rosto do chefe (canto)
var estagio := 0
var grade: Array = []                # [y][x] -> -1 ou índice de cor
var pecas: Array = []                # 3 x {forma, cor} ou null
var dano := 0
var _dano_vis := 0.0
var _dano_pop := 0.0
var _seq := 0                        # jogadas seguidas fechando linha (combo)
var _arrasta := -1
var _arrasta_pos := Vector2.ZERO     # posição suavizada da peça na mão
var _ponteiro := Vector2.ZERO
var _particulas: Array = []
var _textos: Array = []
var _limpando: Array = []            # células estourando {x, y, cor, t}
var _pop: Dictionary = {}            # Vector2i -> t (encaixe)
var _entra: Array = [0.0, 0.0, 0.0]  # peças novas surgindo na bandeja
var _sb: Dictionary = {}
var _tremor := 0.0
var _flash := 0.0
var _fim := false
var _t := 0.0
var _cel := 60.0
var _origem := Vector2.ZERO
var _slots: Array = []
var _fundo: ColorRect
var _toque := false                  # último input foi dedo (true) ou mouse (false)
var _segurando := false              # botão/dedo apertado
var _inicio := Vector2.ZERO          # onde apertou (clique curto = pegar e clicar no lugar)
var _ignorar_soltar := false         # soltar do clique que colocou a peça (não é outro clique)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fundo = ColorRect.new()
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/ui/fundo_bb.gdshader")
	m.set_shader_parameter("feixes", 0.6)
	_fundo.material = m
	add_child(_fundo)
	tempo = duracao
	for y in N:
		var linha: Array = []
		for x in N:
			linha.append(-1)
		grade.append(linha)
	_encher()
	_layout()
	get_viewport().size_changed.connect(_layout)

func _encher() -> void:
	pecas.clear()
	for i in 3:
		pecas.append({"forma": FORMAS[randi() % FORMAS.size()], "cor": randi() % CORES.size()})
		_entra[i] = 0.0
	if not _tem_jogada():
		pecas[0] = {"forma": [[0, 0]], "cor": randi() % CORES.size()}

func _layout() -> void:
	var v := get_viewport_rect().size
	(_fundo.material as ShaderMaterial).set_shader_parameter("aspecto", v.x / maxf(1.0, v.y))
	_fundo.position = Vector2.ZERO
	_fundo.size = v
	size = v
	_cel = floorf(minf(v.y * 0.66, v.x * 0.44) / N)
	var lado := _cel * N
	_origem = Vector2(v.x * 0.4 - lado / 2.0, v.y * 0.6 - lado / 2.0)
	_slots.clear()
	var x0 := _origem.x + lado + _cel * 0.9
	var largura := minf(v.x - x0 - _cel * 0.5, _cel * 5.2)
	var h := (lado - _cel * 0.6) / 3.0
	for i in 3:
		_slots.append(Rect2(x0, _origem.y + _cel * 0.3 + i * (h + _cel * 0.15), largura, h - _cel * 0.15))
	_sb.clear()

func _cabe(forma: Array, gx: int, gy: int) -> bool:
	for c in forma:
		var x: int = gx + int(c[0])
		var y: int = gy + int(c[1])
		if x < 0 or y < 0 or x >= N or y >= N or grade[y][x] != -1:
			return false
	return true

func _tem_jogada() -> bool:
	for p in pecas:
		if p == null:
			continue
		for y in N:
			for x in N:
				if _cabe(p["forma"], x, y):
					return true
	return false

func _tam(forma: Array) -> Vector2i:
	var mx := 0
	var my := 0
	for c in forma:
		mx = maxi(mx, int(c[0]))
		my = maxi(my, int(c[1]))
	return Vector2i(mx + 1, my + 1)

func _canto_arrasto() -> Vector2:
	var t := _tam(pecas[_arrasta]["forma"])
	if _toque:                                              # dedo: peça acima do dedo pra dar pra ver
		return _ponteiro - Vector2(t.x * _cel / 2.0, t.y * _cel + _cel * 0.7)
	return _ponteiro - Vector2(t.x, t.y) * _cel / 2.0      # mouse: centrada no cursor

func _celula_alvo() -> Vector2i:
	var c := (_canto_arrasto() - _origem) / _cel
	return Vector2i(roundi(c.x), roundi(c.y))

## linhas e colunas que ficariam completas com a peça nesse lugar (pra acender antes de soltar)
func _completaria(forma: Array, g: Vector2i) -> Array:
	var tmp: Dictionary = {}
	for c in forma:
		tmp[Vector2i(g.x + int(c[0]), g.y + int(c[1]))] = true
	var ls: Array = []
	var cs: Array = []
	for y in N:
		var cheia := true
		for x in N:
			if grade[y][x] == -1 and not tmp.has(Vector2i(x, y)):
				cheia = false
		if cheia:
			ls.append(y)
	for x in N:
		var cheia := true
		for y in N:
			if grade[y][x] == -1 and not tmp.has(Vector2i(x, y)):
				cheia = false
		if cheia:
			cs.append(x)
	return [ls, cs]

## dois jeitos: arrastar e soltar, ou clicar na peça e depois clicar no lugar. Aceita
## mouse e toque (o navegador manda os dois pra cada clique: o repetido é ignorado)
func _gui_input(ev: InputEvent) -> void:
	if _fim:
		return
	var pos := Vector2.ZERO
	var apertou := false
	var soltou := false
	if ev is InputEventMouseButton:
		if ev.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
		if ev.device == InputEvent.DEVICE_ID_EMULATION:      # veio de um dedo
			_toque = true
		elif apertou:
			_toque = false
	elif ev is InputEventScreenTouch:
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
		if ev.device != InputEvent.DEVICE_ID_EMULATION and apertou:   # dedo de verdade
			_toque = true
	elif ev is InputEventMouseMotion or ev is InputEventScreenDrag:
		pos = ev.position
	else:
		return
	if not soltou:                                        # soltar às vezes chega com posição velha: usa o último movimento
		_ponteiro = pos
	if apertou and not _segurando:
		_segurando = true
		_inicio = pos
		if _arrasta >= 0:                                    # já tinha peça na mão: clique no lugar
			_soltar_peca()
			_segurando = false
			_ignorar_soltar = true
		else:
			for i in 3:
				if pecas[i] != null and (_slots[i] as Rect2).grow(_cel * 0.3).has_point(pos):
					_arrasta = i
					_arrasta_pos = _canto_arrasto()
					Audio.tocar("clique", 0.6)
	elif soltou:
		if _ignorar_soltar:
			_ignorar_soltar = false
		elif _segurando:
			_segurando = false
			if _arrasta >= 0 and _ponteiro.distance_to(_inicio) > _cel * 0.4:   # arrastou: solta aqui
				_soltar_peca()
			# clique curto na peça: continua na mão até clicar no lugar
	accept_event()

func _soltar_peca() -> void:
	var g := _celula_alvo()
	if _cabe(pecas[_arrasta]["forma"], g.x, g.y):
		_colocar(_arrasta, g)
		_arrasta = -1
	elif (_slots[_arrasta] as Rect2).grow(_cel * 0.3).has_point(_ponteiro) or not Rect2(_origem, Vector2(N, N) * _cel).grow(_cel).has_point(_ponteiro):
		_arrasta = -1                                         # largou fora: devolve pra bandeja
	else:
		Audio.tocar("impacto_leve", 0.4)

func _colocar(i: int, g: Vector2i) -> void:
	var p: Dictionary = pecas[i]
	for c in p["forma"]:
		var k := Vector2i(g.x + int(c[0]), g.y + int(c[1]))
		grade[k.y][k.x] = p["cor"]
		_pop[k] = 0.0
	pecas[i] = null
	Audio.tocar("caixa", 0.7)
	var comp := _completaria([], Vector2i.ZERO)
	var linhas: Array = comp[0]
	var colunas: Array = comp[1]
	var n := linhas.size() + colunas.size()
	if n > 0:
		_seq += 1
		var d := n + (n - 1) + (1 if _seq >= 2 else 0)      # várias de uma vez e jogadas seguidas: combo
		dano += d
		_dano_pop = 1.0
		var marcadas: Dictionary = {}
		for y in linhas:
			for x in N:
				marcadas[Vector2i(x, y)] = true
		for x in colunas:
			for y in N:
				marcadas[Vector2i(x, y)] = true
		var ordem := 0
		for k in marcadas:
			_limpando.append({"x": k.x, "y": k.y, "cor": CORES[grade[k.y][k.x]], "t": -0.02 * (ordem % N)})
			ordem += 1
			_explodir(k.x, k.y)
		for k in marcadas:
			grade[k.y][k.x] = -1
		var txt := "-%d" % d
		var sub := ""
		if n >= 2:
			txt = "COMBO x%d" % n
			sub = "-%d DE VIDA" % d
		elif _seq >= 2:
			txt = "SEQUÊNCIA x%d" % _seq
			sub = "-%d DE VIDA" % d
		var cx := _origem + Vector2(N * _cel / 2.0, N * _cel * 0.42)
		_textos.append({"t": txt, "sub": sub, "p": cx, "v": 0.0, "grande": n >= 2 or _seq >= 2})
		_tremor = 0.18 + 0.12 * n
		_flash = 0.25 + 0.15 * n
		Audio.tocar("impacto_forte", 0.6 + 0.1 * n)
		Audio.tocar("checkpoint", 0.5)
	else:
		_seq = 0
	if pecas.all(func(q): return q == null):
		_encher()
	elif not _tem_jogada():
		_textos.append({"t": "SEM ESPAÇO!", "sub": "PEÇAS NOVAS", "p": _origem + Vector2(N * _cel / 2.0, N * _cel / 2.0), "v": 0.0, "grande": false})
		_encher()

func _explodir(x: int, y: int) -> void:
	var cor: Color = CORES[grade[y][x]] if grade[y][x] >= 0 else Color.WHITE
	var c := _origem + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cel
	for k in 6:
		var ang := randf() * TAU
		_particulas.append({"p": c, "v": Vector2(cos(ang), sin(ang) - 0.6) * _cel * randf_range(4.0, 11.0), "t": 0.0,
			"cor": cor.lightened(0.15), "s": randf_range(0.12, 0.3) * _cel, "g": randf_range(-6, 6)})

func _process(delta: float) -> void:
	_t += delta
	if _fim:
		queue_redraw()
		return
	tempo -= delta / Engine.time_scale
	_tremor = maxf(0.0, _tremor - delta)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_dano_pop = maxf(0.0, _dano_pop - delta * 3.0)
	_dano_vis = lerpf(_dano_vis, float(dano), clampf(delta * 10.0, 0.0, 1.0))
	if _arrasta >= 0:
		_arrasta_pos = _arrasta_pos.lerp(_canto_arrasto(), clampf(delta * 28.0, 0.0, 1.0))
	for i in 3:
		_entra[i] = minf(1.0, _entra[i] + delta * 4.0)
	for k in _pop.keys():
		_pop[k] += delta
		if _pop[k] > 0.3:
			_pop.erase(k)
	for c in _limpando.duplicate():
		c["t"] += delta
		if c["t"] > 0.4:
			_limpando.erase(c)
	for p in _particulas.duplicate():
		p["t"] += delta
		p["v"] += Vector2(0, _cel * 22.0) * delta
		p["p"] += p["v"] * delta
		if p["t"] > 0.9:
			_particulas.erase(p)
	for t in _textos.duplicate():
		t["v"] += delta
		if t["v"] > 1.4:
			_textos.erase(t)
	if tempo <= 0.0:
		tempo = 0.0
		_fim = true
		_arrasta = -1
		acabou.emit(dano)
	queue_redraw()

func _caixa(cor: Color, raio: float, borda := Color(0, 0, 0, 0), espessura := 0) -> StyleBoxFlat:
	var k := "%s|%d|%s|%d" % [cor.to_html(), int(raio), borda.to_html(), espessura]
	if not _sb.has(k):
		var s := StyleBoxFlat.new()
		s.bg_color = cor
		s.set_corner_radius_all(int(raio))
		s.anti_aliasing = true
		if espessura > 0:
			s.border_color = borda
			s.set_border_width_all(espessura)
		_sb[k] = s
	return _sb[k]

## bloco com volume: base escura, face com degradê, faixa de brilho e borda clara
func _bloco(pos: Vector2, tam: float, cor: Color, alpha := 1.0, escala := 1.0) -> void:
	var m := tam * 0.05
	var lado := (tam - m * 2.0) * escala
	var o := pos + Vector2(tam, tam) / 2.0 - Vector2(lado, lado) / 2.0
	var raio := lado * 0.2
	draw_style_box(_caixa(Color(0, 0, 0, 0.25 * alpha), raio), Rect2(o + Vector2(0, lado * 0.07), Vector2(lado, lado)))
	draw_style_box(_caixa(Color(cor.darkened(0.32), alpha), raio), Rect2(o, Vector2(lado, lado)))
	draw_style_box(_caixa(Color(cor, alpha), raio), Rect2(o, Vector2(lado, lado * 0.88)))
	draw_style_box(_caixa(Color(cor.lightened(0.18), alpha), raio * 0.8), Rect2(o + Vector2(lado * 0.06, lado * 0.05), Vector2(lado * 0.88, lado * 0.42)))
	draw_style_box(_caixa(Color(1, 1, 1, 0.55 * alpha), lado * 0.05), Rect2(o + Vector2(lado * 0.2, lado * 0.11), Vector2(lado * 0.42, lado * 0.09)))
	draw_style_box(_caixa(Color(1, 1, 1, 0.35 * alpha), lado * 0.05), Rect2(o + Vector2(lado * 0.68, lado * 0.11), Vector2(lado * 0.1, lado * 0.09)))

func _texto(fonte: Font, pos: Vector2, txt: String, tam: int, cor: Color, contorno: Color, alinh := HORIZONTAL_ALIGNMENT_LEFT, largura := -1.0) -> void:
	draw_string_outline(fonte, pos + Vector2(0, tam * 0.06), txt, alinh, largura, tam, int(tam * 0.22), Color(0, 0, 0, 0.35 * cor.a))
	draw_string_outline(fonte, pos, txt, alinh, largura, tam, int(tam * 0.2), Color(contorno, cor.a))
	draw_string(fonte, pos, txt, alinh, largura, tam, cor)

func _draw() -> void:
	var v := get_viewport_rect().size
	var fonte := get_theme_default_font()
	var tr := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _cel * 0.14 * minf(1.0, _tremor / 0.3)
	var lado := _cel * N
	var o := _origem + tr
	# tabuleiro: sombra, moldura com borda clara, fundo escuro com brilho em cima
	var pad := _cel * 0.32
	draw_style_box(_caixa(Color(0, 0, 0, 0.35), _cel * 0.5), Rect2(o - Vector2(pad, pad) + Vector2(0, _cel * 0.25), Vector2(lado + pad * 2, lado + pad * 2)))
	draw_style_box(_caixa(Color(0.16, 0.12, 0.3, 0.96), _cel * 0.45, Color(1, 1, 1, 0.12), maxi(2, int(_cel * 0.04))), Rect2(o - Vector2(pad, pad), Vector2(lado + pad * 2, lado + pad * 2)))
	# prévia: onde cai e quais linhas estouram
	var alvo := Vector2i(-99, -99)
	var cabe := false
	var acende: Dictionary = {}
	var cor_mao := Color.WHITE
	if _arrasta >= 0:
		alvo = _celula_alvo()
		cabe = _cabe(pecas[_arrasta]["forma"], alvo.x, alvo.y)
		cor_mao = CORES[pecas[_arrasta]["cor"]]
		if cabe:
			var comp := _completaria(pecas[_arrasta]["forma"], alvo)
			for y in comp[0]:
				for x in N:
					acende[Vector2i(x, y)] = true
			for x in comp[1]:
				for y in N:
					acende[Vector2i(x, y)] = true
	for y in N:
		for x in N:
			var p := o + Vector2(x, y) * _cel
			var k := Vector2i(x, y)
			var vazio := Rect2(p + Vector2(_cel * 0.06, _cel * 0.06), Vector2(_cel * 0.88, _cel * 0.88))
			draw_style_box(_caixa(Color(0.07, 0.05, 0.16, 0.7), _cel * 0.18), vazio)
			draw_style_box(_caixa(Color(1, 1, 1, 0.03), _cel * 0.16, Color(1, 1, 1, 0.05), 1), vazio.grow(-_cel * 0.03))
			if grade[y][x] >= 0:
				var esc := 1.0
				if _pop.has(k):                                   # encaixe: estica e volta
					var tp: float = _pop[k] / 0.3
					esc = 1.0 + 0.16 * sin(tp * PI) * (1.0 - tp)
				var cor: Color = cor_mao if acende.has(k) else CORES[grade[y][x]]
				_bloco(p, _cel, cor, 1.0, esc)
				if acende.has(k):
					draw_style_box(_caixa(Color(1, 1, 1, 0.18 + 0.12 * sin(_t * 12.0)), _cel * 0.18), vazio)
	if cabe:
		for c in pecas[_arrasta]["forma"]:
			var p := o + Vector2(alvo.x + int(c[0]), alvo.y + int(c[1])) * _cel
			_bloco(p, _cel, cor_mao, 0.38)
	for c in _limpando:                                       # estouro: clarão branco e encolhe
		var tc: float = c["t"]
		if tc < 0.0:
			continue
		var f := tc / 0.4
		var p := o + Vector2(int(c["x"]), int(c["y"])) * _cel
		_bloco(p, _cel, (c["cor"] as Color).lerp(Color.WHITE, 0.6 * (1.0 - f)), 1.0 - f, 1.0 + 0.25 * f)
	# bandeja das peças
	for i in 3:
		var slot: Rect2 = _slots[i]
		var ativo := pecas[i] != null and i != _arrasta
		draw_style_box(_caixa(Color(0.1, 0.07, 0.22, 0.55), _cel * 0.35, Color(1, 1, 1, 0.08 if ativo else 0.03), 2), slot)
		if not ativo:
			continue
		var p: Dictionary = pecas[i]
		var t := _tam(p["forma"])
		var mini := minf(_cel * 0.62, minf(slot.size.x * 0.82 / t.x, slot.size.y * 0.82 / t.y))
		var e: float = _entra[i]
		var esc := e * e * (3.0 - 2.0 * e)
		var base := slot.get_center() - Vector2(t.x, t.y) * mini * esc / 2.0 + Vector2(0, sin(_t * 2.0 + i) * _cel * 0.04)
		for c in p["forma"]:
			_bloco(base + Vector2(int(c[0]), int(c[1])) * mini * esc, mini * esc, CORES[p["cor"]])
	if _arrasta >= 0:
		var p2: Dictionary = pecas[_arrasta]
		for c in p2["forma"]:
			_bloco(_arrasta_pos + Vector2(int(c[0]), int(c[1])) * _cel * 1.04, _cel * 1.04, CORES[p2["cor"]])
	for p in _particulas:
		var a := 1.0 - float(p["t"]) / 0.9
		var s: float = p["s"] * (0.6 + 0.4 * a)
		draw_set_transform(p["p"], float(p["t"]) * float(p["g"]), Vector2.ONE)
		draw_style_box(_caixa(Color(p["cor"], a), s * 0.25), Rect2(-Vector2(s, s) / 2.0, Vector2(s, s)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, v), Color(1, 0.85, 1, _flash * 0.35))
	for t in _textos:                                          # combo: entra grande com elástico e sobe
		var tv: float = t["v"]
		var entra := minf(1.0, tv / 0.25)
		var el := 1.0 + 0.35 * sin(entra * PI) * (1.0 - entra) + (0.25 if t["grande"] else 0.0) * (1.0 - entra)
		var a := 1.0 - maxf(0.0, tv - 0.9) / 0.5
		var tam := int(_cel * (1.15 if t["grande"] else 0.8) * el)
		var pos: Vector2 = t["p"] - Vector2(0, tv * _cel * 0.8)
		var cor := Color(1, 0.86, 0.25, a) if t["grande"] else Color(1, 1, 1, a)
		_texto(fonte, pos - Vector2(v.x, 0), t["t"], tam, cor, Color(0.45, 0.08, 0.35), HORIZONTAL_ALIGNMENT_CENTER, v.x * 2.0)
		if t["sub"] != "":
			_texto(fonte, pos + Vector2(-v.x, tam * 0.75), t["sub"], int(tam * 0.45), Color(1, 1, 1, a), Color(0.2, 0.05, 0.3), HORIZONTAL_ALIGNMENT_CENTER, v.x * 2.0)
	# cabeçalho: rosto e nome do chefe, dano, barra de tempo
	var topo := _origem.y - _cel * 1.9
	var cab := Rect2(_origem.x - pad, topo, lado + pad * 2, _cel * 1.25)
	draw_style_box(_caixa(Color(0.1, 0.06, 0.22, 0.75), _cel * 0.35, Color(1, 1, 1, 0.1), 2), cab)
	var ar := Rect2(cab.position + Vector2(_cel * 0.15, _cel * 0.12), Vector2(_cel, _cel))
	draw_style_box(_caixa(Color(0.95, 0.35, 0.75), _cel * 0.25), ar.grow(_cel * 0.04))
	if avatar:
		var w := avatar.get_width()
		draw_texture_rect_region(avatar, ar, Rect2(w / 2.0 - w * 0.27, 0, w * 0.54, w * 0.54))
	var nome: String = ["GERESCH", "GERESCH (SÉRIO)", "GERESCH (BRAVO!)", "GERESCH (FURIOSO!!)"][clampi(estagio, 0, 3)]
	_texto(fonte, ar.position + Vector2(_cel * 1.25, _cel * 0.42), nome, int(_cel * 0.38), Color(1, 0.8, 0.92), Color(0.2, 0.05, 0.3))
	_texto(fonte, ar.position + Vector2(_cel * 1.25, _cel * 0.92), "FECHA LINHAS PRA DAR DANO", int(_cel * 0.3), Color(1, 1, 1, 0.85), Color(0.2, 0.05, 0.3))
	var dtam := int(_cel * (0.85 + 0.35 * _dano_pop))
	_texto(fonte, Vector2(cab.end.x - _cel * 0.25, cab.position.y + _cel * 0.88), "-%d" % roundi(_dano_vis), dtam, Color(1, 0.86, 0.25), Color(0.45, 0.08, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, -1)
	var frac := clampf(tempo / duracao, 0.0, 1.0)
	var barra := Rect2(_origem.x - pad, topo + _cel * 1.38, lado + pad * 2, _cel * 0.26)
	draw_style_box(_caixa(Color(0, 0, 0, 0.4), barra.size.y / 2.0), barra)
	var urg := tempo < 5.0
	var cor_b := Color(1, 0.3, 0.35) if urg else Color(0.35, 1, 0.65).lerp(Color(1, 0.85, 0.25), 1.0 - frac)
	if urg:
		cor_b = cor_b.lightened(0.25 * (0.5 + 0.5 * sin(_t * 14.0)))
	if frac > 0.0:
		var cheia := Rect2(barra.position, Vector2(maxf(barra.size.y, barra.size.x * frac), barra.size.y))
		draw_style_box(_caixa(Color(cor_b, 0.3), barra.size.y), cheia.grow(_cel * 0.08))
		draw_style_box(_caixa(cor_b, barra.size.y / 2.0), cheia)
		draw_style_box(_caixa(Color(1, 1, 1, 0.35), barra.size.y / 4.0), Rect2(cheia.position + Vector2(barra.size.y * 0.4, barra.size.y * 0.18), Vector2(maxf(0.0, cheia.size.x - barra.size.y * 0.8), barra.size.y * 0.22)))
	_texto(fonte, Vector2(barra.end.x + _cel * 0.25, barra.end.y + _cel * 0.08), "%ds" % ceili(tempo), int(_cel * (0.42 + (0.08 * sin(_t * 14.0) if urg else 0.0))), Color(1, 0.4, 0.4) if urg else Color.WHITE, Color(0.2, 0.05, 0.3))
	if _fim:
		var a := 1.0
		_texto(fonte, Vector2(0, v.y * 0.5), "TEMPO!", int(_cel * 1.6), Color(1, 1, 1, a), Color(0.45, 0.08, 0.35), HORIZONTAL_ALIGNMENT_CENTER, v.x)
