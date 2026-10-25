extends Control
## Mini Block Blast (luta do Geresch): grade 8x8, 3 peças pra arrastar com o dedo/mouse.
## Fechar linha ou coluna dá dano no chefe; fechar várias de uma vez (ou em sequência)
## é combo e dá dano extra. Acaba quando o tempo zera. Roda com o jogo pausado.

signal acabou(dano: int)

const N := 8
const CORES := [Color(1.0, 0.6, 0.15), Color(0.95, 0.3, 0.42), Color(0.3, 0.82, 0.45), Color(0.18, 0.8, 0.68),
	Color(0.25, 0.65, 0.98), Color(0.55, 0.45, 0.98), Color(1.0, 0.82, 0.2)]
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
var grade: Array = []                # [y][x] -> -1 ou índice de cor
var pecas: Array = []                # 3 x {forma, cor} ou null
var dano := 0
var _seq := 0                        # jogadas seguidas fechando linha (combo)
var _arrasta := -1
var _ponteiro := Vector2.ZERO
var _particulas: Array = []
var _textos: Array = []
var _sb: Dictionary = {}
var _tremor := 0.0
var _fim := false
var _cel := 60.0
var _origem := Vector2.ZERO
var _slots: Array = []               # Rect2 de cada peça na bandeja

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tempo = duracao
	for y in N:
		var linha: Array = []
		for x in N:
			linha.append(-1)
		grade.append(linha)
	_encher()
	_layout()

func _encher() -> void:
	pecas.clear()
	for i in 3:
		pecas.append({"forma": FORMAS[randi() % FORMAS.size()], "cor": randi() % CORES.size()})
	if not _tem_jogada():                            # sem jogada possível: troca uma por um quadradinho
		pecas[0] = {"forma": [[0, 0]], "cor": randi() % CORES.size()}

func _layout() -> void:
	var v := get_viewport_rect().size
	_cel = floorf(minf(v.y * 0.7, v.x * 0.46) / N)
	var lado := _cel * N
	_origem = Vector2(v.x * 0.38 - lado / 2.0, v.y * 0.58 - lado / 2.0)
	_slots.clear()
	var x0 := _origem.x + lado + _cel * 1.0
	var h := (lado - _cel) / 3.0
	for i in 3:
		_slots.append(Rect2(x0, _origem.y + _cel + i * h, minf(v.x - x0 - 20.0, _cel * 6.0), h))

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

## canto de cima/esquerda da peça arrastada (fica um pouco acima do dedo pra dar pra ver)
func _canto_arrasto() -> Vector2:
	var t := _tam(pecas[_arrasta]["forma"])
	return _ponteiro - Vector2(t.x * _cel / 2.0, t.y * _cel + _cel * 0.6)

func _celula_alvo() -> Vector2i:
	var c := (_canto_arrasto() - _origem) / _cel
	return Vector2i(roundi(c.x), roundi(c.y))

func _gui_input(ev: InputEvent) -> void:
	if _fim:
		return
	var pos := Vector2.ZERO
	var apertou := false
	var soltou := false
	var moveu := false
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
	elif ev is InputEventScreenTouch:
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
	elif ev is InputEventMouseMotion or ev is InputEventScreenDrag:
		pos = ev.position
		moveu = true
	else:
		return
	_ponteiro = pos
	if apertou and _arrasta < 0:
		for i in 3:
			if pecas[i] != null and (_slots[i] as Rect2).grow(10).has_point(pos):
				_arrasta = i
				Audio.tocar("clique", 0.6)
	elif soltou and _arrasta >= 0:
		var g := _celula_alvo()
		if _cabe(pecas[_arrasta]["forma"], g.x, g.y):
			_colocar(_arrasta, g)
		_arrasta = -1
	elif moveu:
		pass
	accept_event()
	queue_redraw()

func _colocar(i: int, g: Vector2i) -> void:
	var p: Dictionary = pecas[i]
	for c in p["forma"]:
		grade[g.y + int(c[1])][g.x + int(c[0])] = p["cor"]
	pecas[i] = null
	Audio.tocar("caixa", 0.7)
	var linhas: Array = []
	var colunas: Array = []
	for y in N:
		if not grade[y].has(-1):
			linhas.append(y)
	for x in N:
		var cheia := true
		for y in N:
			if grade[y][x] == -1:
				cheia = false
		if cheia:
			colunas.append(x)
	var n := linhas.size() + colunas.size()
	if n > 0:
		_seq += 1
		var d := n + (n - 1) + (1 if _seq >= 2 else 0)      # várias de uma vez e jogadas seguidas: combo
		dano += d
		for y in linhas:
			for x in N:
				_explodir(x, y)
		for x in colunas:
			for y in N:
				_explodir(x, y)
		for y in linhas:
			for x in N:
				grade[y][x] = -1
		for x in colunas:
			for y in N:
				grade[y][x] = -1
		var txt := "-%d" % d
		if n >= 2:
			txt = "COMBO x%d!  -%d" % [n, d]
		elif _seq >= 2:
			txt = "SEQUÊNCIA!  -%d" % d
		var cx := _origem + Vector2(g.x + 1, g.y) * _cel
		_textos.append({"t": txt, "p": cx, "v": 0.0, "grande": n >= 2 or _seq >= 2})
		_tremor = 0.15 + 0.1 * n
		Audio.tocar("impacto_forte", 0.6 + 0.1 * n)
		Audio.tocar("checkpoint", 0.5)
	else:
		_seq = 0
	if pecas.all(func(q): return q == null):
		_encher()
	elif not _tem_jogada():
		_textos.append({"t": "SEM JOGADA! PEÇAS NOVAS", "p": _origem + Vector2(N * _cel / 2.0, N * _cel / 2.0), "v": 0.0, "grande": false})
		_encher()

func _explodir(x: int, y: int) -> void:
	var cor: Color = CORES[grade[y][x]] if grade[y][x] >= 0 else Color.WHITE
	var c := _origem + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cel
	for k in 5:
		_particulas.append({"p": c, "v": Vector2(randf_range(-1, 1), randf_range(-1.6, 0.4)) * _cel * 9.0, "t": 0.0,
			"cor": cor, "s": randf_range(0.15, 0.35) * _cel})

func _process(delta: float) -> void:
	if _fim:
		return
	tempo -= delta
	_tremor = maxf(0.0, _tremor - delta)
	for p in _particulas.duplicate():
		p["t"] += delta
		p["v"] += Vector2(0, _cel * 25.0) * delta
		p["p"] += p["v"] * delta
		if p["t"] > 0.9:
			_particulas.erase(p)
	for t in _textos.duplicate():
		t["v"] += delta
		if t["v"] > 1.2:
			_textos.erase(t)
	if tempo <= 0.0:
		_fim = true
		acabou.emit(dano)
	queue_redraw()

func _caixa(cor: Color) -> StyleBoxFlat:
	var k := cor.to_html()
	if not _sb.has(k):
		var s := StyleBoxFlat.new()
		s.bg_color = cor
		s.set_corner_radius_all(int(_cel * 0.18))
		s.shadow_color = Color(0, 0, 0, 0.25)
		s.shadow_size = int(_cel * 0.06)
		s.shadow_offset = Vector2(0, _cel * 0.05)
		_sb[k] = s
	return _sb[k]

func _bloco(pos: Vector2, tam: float, cor: Color, alpha := 1.0) -> void:
	var r := Rect2(pos + Vector2(tam * 0.04, tam * 0.04), Vector2(tam * 0.92, tam * 0.92))
	draw_style_box(_caixa(Color(cor.darkened(0.15), alpha)), r)
	draw_style_box(_caixa(Color(cor, alpha)), Rect2(r.position, Vector2(r.size.x, r.size.y * 0.88)))
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.18, r.size.y * 0.1), Vector2(r.size.x * 0.64, r.size.y * 0.1)), Color(1, 1, 1, 0.45 * alpha))

func _draw() -> void:
	var v := get_viewport_rect().size
	# fundo degradê roxo -> azul
	var faixas := 24
	for i in faixas:
		var t := float(i) / faixas
		draw_rect(Rect2(0, v.y * t, v.x, v.y / faixas + 1), Color(0.28, 0.16, 0.48).lerp(Color(0.6, 0.2, 0.5), sin(t * PI) * 0.6).lerp(Color(0.1, 0.42, 0.72), t))
	var tr := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _cel * 0.12 * (_tremor / 0.4)
	var lado := _cel * N
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.13, 0.11, 0.24, 0.92)
	fundo.set_corner_radius_all(int(_cel * 0.4))
	fundo.border_color = Color(1, 1, 1, 0.08)
	fundo.set_border_width_all(2)
	draw_style_box(fundo, Rect2(_origem + tr - Vector2(_cel * 0.3, _cel * 0.3), Vector2(lado + _cel * 0.6, lado + _cel * 0.6)))
	var alvo := Vector2i(-99, -99)
	var cabe := false
	if _arrasta >= 0:
		alvo = _celula_alvo()
		cabe = _cabe(pecas[_arrasta]["forma"], alvo.x, alvo.y)
	for y in N:
		for x in N:
			var p := _origem + tr + Vector2(x, y) * _cel
			if grade[y][x] >= 0:
				_bloco(p, _cel, CORES[grade[y][x]])
			else:
				draw_style_box(_caixa(Color(1, 1, 1, 0.06)), Rect2(p + Vector2(_cel * 0.05, _cel * 0.05), Vector2(_cel * 0.9, _cel * 0.9)))
	if cabe:                                           # sombra de onde a peça vai cair
		for c in pecas[_arrasta]["forma"]:
			_bloco(_origem + tr + Vector2(alvo.x + int(c[0]), alvo.y + int(c[1])) * _cel, _cel, CORES[pecas[_arrasta]["cor"]], 0.35)
	for i in 3:
		var p = pecas[i]
		if p == null or i == _arrasta:
			continue
		var t := _tam(p["forma"])
		var mini := _cel * 0.55
		var slot: Rect2 = _slots[i]
		var base := slot.get_center() - Vector2(t.x, t.y) * mini / 2.0
		for c in p["forma"]:
			_bloco(base + Vector2(int(c[0]), int(c[1])) * mini, mini, CORES[p["cor"]])
	if _arrasta >= 0:
		var p2: Dictionary = pecas[_arrasta]
		var canto := _canto_arrasto()
		for c in p2["forma"]:
			_bloco(canto + Vector2(int(c[0]), int(c[1])) * _cel, _cel, CORES[p2["cor"]])
	for p in _particulas:
		var a := 1.0 - float(p["t"]) / 0.9
		var s: float = p["s"]
		draw_rect(Rect2(p["p"] - Vector2(s, s) / 2.0, Vector2(s, s)), Color(p["cor"], a))
	var fonte := get_theme_default_font()
	for t in _textos:
		var a := 1.0 - maxf(0.0, float(t["v"]) - 0.6) / 0.6
		var tam := int(_cel * (1.0 if t["grande"] else 0.7))
		var pos: Vector2 = t["p"] - Vector2(0, float(t["v"]) * _cel * 1.2)
		draw_string_outline(fonte, pos, t["t"], HORIZONTAL_ALIGNMENT_CENTER, -1, tam, int(_cel * 0.12), Color(0.15, 0.05, 0.3, a))
		draw_string(fonte, pos, t["t"], HORIZONTAL_ALIGNMENT_CENTER, -1, tam, Color(1, 1, 1, a))
	# topo: título e tempo; à direita, o dano acima das peças
	var titulo := "FAZ COMBO NO GERESCH!"
	draw_string_outline(fonte, Vector2(0, _origem.y - _cel * 1.15), titulo, HORIZONTAL_ALIGNMENT_CENTER, v.x, int(_cel * 0.6), int(_cel * 0.12), Color(0.15, 0.05, 0.3))
	draw_string(fonte, Vector2(0, _origem.y - _cel * 1.15), titulo, HORIZONTAL_ALIGNMENT_CENTER, v.x, int(_cel * 0.6), Color.WHITE)
	var dt := "DANO: %d" % dano
	var sx: float = (_slots[0] as Rect2).position.x
	draw_string_outline(fonte, Vector2(sx, _origem.y + _cel * 0.6), dt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_cel * 0.7), int(_cel * 0.12), Color(0.15, 0.05, 0.3))
	draw_string(fonte, Vector2(sx, _origem.y + _cel * 0.6), dt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_cel * 0.7), Color(1, 0.85, 0.3))
	var frac := clampf(tempo / duracao, 0.0, 1.0)
	draw_rect(Rect2(_origem.x, _origem.y - _cel * 0.8, lado, _cel * 0.25), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(_origem.x, _origem.y - _cel * 0.8, lado * frac, _cel * 0.25), Color(1, 0.3, 0.3) if frac < 0.25 else Color(0.4, 1, 0.6))
