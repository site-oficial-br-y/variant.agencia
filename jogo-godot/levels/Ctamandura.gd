extends Node2D
class_name Ctamandura
## Chefe da fase 9 (O Julgamento). Duas lutas:
##  1) Çtamandura sozinho, alternando:
##     - MEMÓRIA: o chão é dividido em faixas; algumas acendem por um instante (é onde o
##       martelo vai bater), apagam, e depois o martelo cai nelas uma a uma. Fica onde NÃO acendeu.
##     - LASER ROSA: colunas e diagonais com aviso (mais fáceis que as do Adriano).
##     Depois de cada rodada aparece um olho no chão: passou por cima, ele leva dano.
##  2) O martelo cai (vídeos) e o Périne (Belzebu) pega: ele aparece no fundo, ao lado do
##     Çtamandura, e bate com o martelo onde você está, junto com as rodadas mais rápidas.

signal martelo_caiu                       # fim da luta 1 (Main toca o vídeo e chama luta_2)
signal derrotado

const VIDA_1 := 6
const VIDA_2 := 8
const MARCA_L := 1000.0                   # largura de cada marca (onde o martelo bate)
const ROSA := Color(1.0, 0.3, 0.75)
const ROXO := Color(0.72, 0.3, 1.0)

var fase: Node2D
var chao := 1000.0
var x0 := 0.0
var x1 := 0.0
var vida := VIDA_1
var luta := 1
var ativo := false
var morto := false
var _t := 0.0
var _estado := "pausa"
var _timer := 2.5
var _rodada := 0                          # quantas rodadas já passaram (dificuldade sobe)
var _marcadas: Array = []                 # x de cada marca (onde o martelo vai bater)
var _marcas: Array = []                   # nós das marcas no chão desta rodada
var _lasers: Array = []
var _olho: Dictionary = {}
var _tremor := 0.0
var _fim_t := 0.0
var _perine: Dictionary = {}
var _camada_fundo: CanvasLayer
var _camada_boss: CanvasLayer
var _fundo: TextureRect
var _cabeca: Sprite2D
var _mao_e: Sprite2D
var _mao_d: Sprite2D
var _barra: ColorRect
var _barra_fundo: ColorRect
var _rotulo: Label
var _tex_feixe: Texture2D
var _tex_brilho: Texture2D

func _real(delta: float) -> float:
	return delta / Engine.time_scale

func montar(main: Node2D, xa: float, xb: float, y_chao: float) -> void:
	fase = main
	x0 = xa
	x1 = xb
	chao = y_chao

## liga a luta: fundo de olhos, cabeça e mãos dele, barra de vida
func comecar() -> void:
	if ativo:
		return
	ativo = true
	_camada_fundo = CanvasLayer.new()
	_camada_fundo.layer = -60
	fase.add_child(_camada_fundo)
	_fundo = TextureRect.new()
	_fundo.texture = load("res://assets/julgamento/fundo_luta.jpg")
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada_fundo.add_child(_fundo)
	_camada_boss = CanvasLayer.new()
	_camada_boss.layer = -50
	fase.add_child(_camada_boss)
	_mao_e = _sprite("mao", true)
	_mao_d = _sprite("mao", false)
	_cabeca = _sprite("cabeca", false)
	var hud: CanvasLayer = fase.get_node("HUD")
	_barra_fundo = ColorRect.new()
	_barra_fundo.color = Color(0, 0, 0, 0.7)
	_barra_fundo.size = Vector2(620, 40)
	hud.add_child(_barra_fundo)
	_barra = ColorRect.new()
	_barra.color = Color(0.75, 0.25, 1.0)
	_barra.size = Vector2(600, 24)
	hud.add_child(_barra)
	_rotulo = Label.new()
	_rotulo.text = "ÇTAMANDURA"
	_rotulo.add_theme_font_size_override("font_size", 30)
	_rotulo.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	hud.add_child(_rotulo)
	_estado = "pausa"
	_timer = 2.5

func _sprite(nome: String, espelhar: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/julgamento/%s.png" % nome)
	s.flip_h = espelhar
	_camada_boss.add_child(s)
	return s

## luta 2: o Périne pegou o martelo. Mãos pegando fogo, cabeça com raiva, vida nova
func luta_2() -> void:
	luta = 2
	vida = VIDA_2
	_rodada = 2
	_cabeca.texture = load("res://assets/julgamento/cabeca_raiva.png")
	_mao_e.visible = false                             # o Périne fica no lugar da mão esquerda
	_mao_d.texture = load("res://assets/julgamento/mao_fogo_d.png")
	_rotulo.text = "ÇTAMANDURA E PÉRINE (BELZEBU)"
	_criar_perine()
	_estado = "pausa"
	_timer = 2.0
	fase._mensagem("O PÉRINE PEGOU O MARTELO!", Color(1, 0.45, 0.85))

# ---------- passo ----------
func atualizar(delta: float) -> void:
	if not ativo:
		return
	var dt := _real(delta)
	_t += dt
	_posicionar(dt)
	for l in _lasers.duplicate():
		_passo_laser(l, dt)
	if morto:
		_fim_t += dt
		if _fim_t > 1.8 and _fim_t - dt <= 1.8:
			derrotado.emit()
		return
	if not _perine.is_empty():
		_passo_perine(dt)
	_passo_olho(dt)
	if not fase.ativo:
		return
	match _estado:
		"pausa":
			_timer -= dt
			if _timer <= 0.0:
				if _rodada % 2 == 0:
					_iniciar_memoria()
				else:
					_iniciar_laser()
		"mostra":                                       # marcas acesas por pouco tempo: decore
			_timer -= dt
			if _timer <= 0.0:
				for m in _marcas:
					(m as Node).queue_free()
				_marcas.clear()
				_estado = "espera"
				_timer = 1.6 if luta == 1 else 1.2
				fase._mensagem("LEMBRA ONDE ERA?", Color(1, 0.6, 0.9))
		"espera":                                       # sem marca nenhuma: vai pra onde não estava marcado
			_timer -= dt
			if _timer <= 0.0:
				for x in _marcadas:                     # o martelo bate em todas ao mesmo tempo
					_martelada(float(x), MARCA_L / 2.0)
				_estado = "golpes"
				_timer = 1.0
		"golpes":
			_timer -= dt
			if _timer <= 0.0:
				_fim_rodada()
		"laser":
			_timer -= dt
			if _timer <= 0.0 and _lasers.is_empty():
				_fim_rodada()

func _posicionar(dt: float) -> void:
	var v := fase.get_viewport().get_visible_rect().size
	var esc := maxf(v.x / 1916.0, v.y / 821.0) * (1.08 + 0.02 * sin(_t * 0.4))
	_fundo.size = Vector2(1916, 821) * esc
	_fundo.position = (v - _fundo.size) / 2.0 + Vector2(sin(_t * 0.2) * 20.0, 0)
	_fundo.modulate = Color(0.9, 0.85, 1.0) if luta == 1 else Color(1.0, 0.7, 0.85)
	var tremor := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 16.0 * _tremor
	_tremor = maxf(0.0, _tremor - dt * 2.0)
	var e := v.y * 0.36 / 700.0
	_cabeca.scale = Vector2.ONE * e
	_cabeca.position = Vector2(v.x / 2.0, v.y * 0.33 + sin(_t * 1.2) * 8.0) + tremor
	for k in 2:
		var m: Sprite2D = [_mao_e, _mao_d][k]
		var lado := -1.0 if k == 0 else 1.0
		m.scale = Vector2.ONE * e * 0.75
		m.position = Vector2(v.x / 2.0 + lado * v.x * 0.3, v.y * 0.36 + sin(_t * 1.5 + k * 2.0) * 14.0) + tremor
		m.rotation = sin(_t * 0.9 + k) * 0.08 * lado
	if morto:
		var f := minf(1.0, _fim_t / 1.6)
		for s in [_cabeca, _mao_e, _mao_d]:
			(s as CanvasItem).modulate = Color(1, 1, 1, 1.0 - f)
		_cabeca.position.y += f * v.y * 0.3
	_barra_fundo.position = Vector2(v.x / 2.0 - 310, 112)
	_barra.position = _barra_fundo.position + Vector2(10, 8)
	_barra.size.x = 600.0 * float(vida) / float(VIDA_1 if luta == 1 else VIDA_2)
	_rotulo.position = _barra_fundo.position + Vector2(0, -38)

func _fim_rodada() -> void:
	_rodada += 1
	_estado = "pausa"
	_timer = 99.0                                      # espera o olho ser pego (ou some e volta a atacar)
	_criar_olho()

# ---------- memória: o martelo bate nas faixas que acenderam ----------
func _iniciar_memoria() -> void:
	var n := clampi(2 + _rodada / 3, 2, 4)            # começa com 2 marcas, chega a 4
	if luta == 2:
		n = 4
	_marcadas.clear()
	var tentativas := 0
	while _marcadas.size() < n and tentativas < 200:  # lugares soltos, sem encostar uns nos outros
		tentativas += 1
		var x := randf_range(x0 + MARCA_L / 2.0, x1 - MARCA_L / 2.0)
		var ok := true
		for y in _marcadas:
			if absf(float(y) - x) < MARCA_L + 250.0:
				ok = false
		if ok:
			_marcadas.append(x)
	for x in _marcadas:
		var m := Geresch.marcador(MARCA_L / 2.0)
		m.position = Vector2(float(x), chao)
		m.modulate.a = 1.0
		fase.add_child(m)
		_marcas.append(m)
	_estado = "mostra"
	_timer = maxf(0.7, 1.3 - 0.06 * _rodada) if luta == 1 else 0.6   # marca fica pouco tempo
	Audio.tocar("checkpoint", 0.8)
	fase._mensagem("DECORE!", Color(1, 0.35, 0.6))

## o martelo despenca do céu numa faixa: quem estiver nela morre
func _martelada(x: float, meia: float) -> void:
	var s := Sprite2D.new()
	if luta == 2:                                      # martelo do Yohan (já vem de cabeça pra baixo, com a mão)
		s.texture = load("res://assets/julgamento/martelo2.png")
		s.scale = Vector2.ONE * meia * 2.3 / 677.0
		s.offset = Vector2(0, -400)                    # ponto de batida na base da cabeça
	else:
		s.texture = load("res://assets/julgamento/martelo.png")
		s.scale = Vector2.ONE * 2.6
		s.rotation = PI                                # cabeça do martelo pra baixo
	s.position = Vector2(x, chao - 4200.0)
	s.z_index = 7
	fase.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", chao - (1050.0 if luta == 1 else 20.0), 0.16 * Engine.time_scale).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		_acerta_faixa(x, meia, "esmagado")
		_impacto(Vector2(x, chao), 2.2))
	tw.tween_interval(0.3 * Engine.time_scale)
	tw.tween_property(s, "position:y", chao - 4500.0, 0.3 * Engine.time_scale)
	tw.tween_callback(s.queue_free)

func _impacto(onde: Vector2, f: float) -> void:
	_tremor = 1.0
	fase.pecas.particulas(onde + Vector2(0, -30), int(24 * f), Color(0.8, 0.45, 1.0), Color(0.4, 0.1, 0.7, 0.0), 800.0, 2400.0, 0.8, 30.0, 70.0, 2600.0, Vector2.UP, 75.0)
	fase.pecas.poeira(onde + Vector2(-300, -10), 2.0)
	fase.pecas.poeira(onde + Vector2(300, -10), 2.0)
	var j: Julgamento = fase.julgamento
	if j:
		j.tremer(onde, f)
	Audio.tocar("impacto_forte", 1.0, 0.1)
	Audio.tocar("caixa", 0.7)

# ---------- laser rosa ----------
func _iniciar_laser() -> void:
	_estado = "laser"
	var tipos := ["colunas", "fila", "cruz"]
	var tipo: String = tipos[(_rodada / 2) % tipos.size()]
	var rapido := 0.75 if luta == 2 else 1.0
	match tipo:
		"colunas":                                      # 3 colunas em lugares sorteados, uma depois da outra
			for k in (3 if luta == 1 else 5):
				_coluna(randf_range(x0 + 500.0, x1 - 500.0), 1.3 * rapido + k * 0.55 * rapido)
		"fila":                                         # colunas varrendo de um lado ao outro com um buraco seguro
			var buraco := randi() % 6
			for k in 7:
				if k == buraco:
					continue
				_coluna(lerpf(x0 + 600.0, x1 - 600.0, k / 6.0), 1.4 * rapido + k * 0.22 * rapido)
		"cruz":                                         # das mãos até o chão, cruzando
			var a := randf_range(x0 + 1500.0, x0 + (x1 - x0) * 0.45)
			var b := randf_range(x0 + (x1 - x0) * 0.55, x1 - 1500.0)
			_diagonal(Vector2(x1 + 1200.0, chao - 5200.0), Vector2(a, chao), 1.4 * rapido)
			_diagonal(Vector2(x0 - 1200.0, chao - 5200.0), Vector2(b, chao), 1.4 * rapido + 0.5)
	_timer = 0.5
	fase._mensagem("LASER!", ROSA)

func _coluna(x: float, espera: float) -> void:
	var aviso := _linha(12.0, Color(1, 0.4, 0.8, 0.9), 8)
	aviso.points = PackedVector2Array([Vector2(x, chao - 4500.0), Vector2(x, chao + 400.0)])
	aviso.visible = false
	var feixe := _feixe(260.0, 9)
	_pts(feixe, aviso.points, 0.0)
	_lasers.append({"tipo": "coluna", "x": x, "t": -espera + 1.0, "aviso": aviso, "feixe": feixe})

func _diagonal(de: Vector2, ate: Vector2, espera: float) -> void:
	var fim := ate + (ate - de).normalized() * 800.0
	var aviso := _linha(12.0, Color(1, 0.4, 0.8, 0.9), 8)
	aviso.points = PackedVector2Array([de, fim])
	aviso.visible = false
	var feixe := _feixe(220.0, 9)
	_pts(feixe, aviso.points, 0.0)
	_lasers.append({"tipo": "diag", "de": de, "ate": fim, "t": -espera + 1.0, "aviso": aviso, "feixe": feixe})

## -1..0 espera escondido | 0..1 aviso piscando | 1..1.45 aceso (mata) | some
func _passo_laser(l: Dictionary, dt: float) -> void:
	l["t"] = float(l["t"]) + dt
	var t: float = l["t"]
	var aviso: Line2D = l["aviso"]
	var feixe: Line2D = l["feixe"]
	if t < 0.0:
		return
	if t < 1.0:
		aviso.visible = fmod(t, 0.14) < 0.09
		aviso.width = 8.0 + 18.0 * t
		return
	if aviso.visible:
		Audio.tocar("metal", 0.5, 0.0)
	aviso.visible = false
	var f := minf(1.0, (t - 1.0) / 0.05) * minf(1.0, (1.45 - t) / 0.12)
	_pts(feixe, aviso.points, f)
	if f > 0.5:
		if l["tipo"] == "coluna":
			_acerta_faixa(float(l["x"]), 140.0, "laser")
		else:
			_acerta_seg(l["de"], l["ate"], 130.0)
	if t >= 1.45:
		(feixe.get_meta("halo") as Node).queue_free()
		feixe.queue_free()
		aviso.queue_free()
		_lasers.erase(l)

# ---------- olho: passou por cima, ele leva dano ----------
func _criar_olho() -> void:
	var px := _alvo_x()
	var x := x0 + 700.0 if px > (x0 + x1) / 2.0 else x1 - 700.0   # longe de você: tem que ir buscar
	x += randf_range(-400.0, 400.0)
	var no := Node2D.new()
	no.position = Vector2(x, chao - 260.0)
	no.z_index = 6
	fase.add_child(no)
	var luz := _bola(Vector2.ZERO, 12.0, ROSA)
	luz.reparent(no, false)
	var olho := Sprite2D.new()                         # o olho da mão dele, solto no chão
	olho.texture = load("res://assets/julgamento/mao.png")
	olho.region_enabled = true
	olho.region_rect = Rect2(170, 230, 230, 230)
	olho.scale = Vector2.ONE * 1.6
	no.add_child(olho)
	var seta := Polygon2D.new()
	seta.polygon = PackedVector2Array([Vector2(-150, -620), Vector2(150, -620), Vector2(0, -420)])
	seta.color = ROSA
	no.add_child(seta)
	_olho = {"no": no, "seta": seta, "t": 0.0}
	fase._mensagem("PEGA O OLHO!", Color(0.5, 1, 0.6))
	Audio.tocar("checkpoint", 0.9)

func _passo_olho(dt: float) -> void:
	if _olho.is_empty():
		return
	var no: Node2D = _olho["no"]
	_olho["t"] = float(_olho["t"]) + dt
	(_olho["seta"] as Node2D).position.y = absf(sin(_t * 6.0)) * 90.0
	no.scale = Vector2.ONE * (1.0 + 0.08 * sin(_t * 8.0))
	for b in _corpos():
		var p := (b as Node2D).global_position
		if absf(p.x - no.position.x) < 380.0 and p.y > no.position.y - 1300.0 and p.y < chao + 100.0:
			_pegou_olho()
			return
	if float(_olho["t"]) > 14.0:                       # demorou: some e ele ataca de novo
		no.queue_free()
		_olho = {}
		_estado = "pausa"
		_timer = 1.0

func _pegou_olho() -> void:
	var no: Node2D = _olho["no"]
	var de := no.get_global_transform_with_canvas().origin
	no.queue_free()
	_olho = {}
	vida -= 1
	_tremor = 1.0
	Audio.tocar("metal", 1.0)
	Audio.tocar("impacto_forte", 1.0)
	var alvo := _cabeca.position
	for camada in 2:                                   # raio rosa do olho até a cabeça
		var l := Line2D.new()
		var pts := PackedVector2Array([de])
		for i in range(1, 12):
			pts.append(de.lerp(alvo, i / 12.0) + Vector2(randf_range(-40, 40), randf_range(-25, 25)))
		pts.append(alvo)
		l.points = pts
		l.width = 26.0 if camada == 0 else 9.0
		l.default_color = Color(1, 0.4, 0.85, 0.7) if camada == 0 else Color.WHITE
		_camada_boss.add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.5)
		tw.tween_callback(l.queue_free)
	var tw2 := _cabeca.create_tween()
	tw2.tween_property(_cabeca, "modulate", Color(2, 0.6, 1.4), 0.06)
	tw2.tween_property(_cabeca, "modulate", Color.WHITE, 0.3)
	if vida <= 0:
		if luta == 1:
			_estado = "fim1"
			for l in _lasers.duplicate():
				(l["feixe"].get_meta("halo") as Node).queue_free()
				(l["feixe"] as Node).queue_free()
				(l["aviso"] as Node).queue_free()
			_lasers.clear()
			martelo_caiu.emit()
		else:
			morto = true
			_fim_t = 0.0
			_rotulo.text = "ÇTAMANDURA DERROTADO!"
			_rotulo.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
			if not _perine.is_empty():
				(_perine["marca"] as Node).queue_free()
				for k in ["img", "aura"]:
					var n: CanvasItem = _perine[k]
					n.create_tween().tween_property(n, "modulate:a", 0.0, 1.2)
				_perine = {}
		return
	_estado = "pausa"
	_timer = 1.6

# ---------- Périne (Belzebu) no fundo com o martelo (luta 2) ----------
## ele fica no fundo, ao lado do Çtamandura: ergue o martelo, uma marca vermelha pisca
## perto de você no chão e ele bate (o golpe cai do céu na marca)
func _criar_perine() -> void:
	var img := Sprite2D.new()
	img.texture = load("res://assets/julgamento/perine.png")
	img.modulate = Color(1.0, 0.8, 1.0)
	_camada_boss.add_child(img)
	_camada_boss.move_child(img, 0)                   # atrás da cabeça
	var aura := Sprite2D.new()
	var tmp := _bola(Vector2.ZERO, 1.0, ROXO)        # só pra pegar a textura de brilho
	aura.texture = tmp.texture
	tmp.queue_free()
	aura.material = CanvasItemMaterial.new()
	(aura.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.modulate = Color(0.8, 0.3, 1.0, 0.7)
	_camada_boss.add_child(aura)
	_camada_boss.move_child(aura, 0)
	var marca := Geresch.marcador(560.0)
	marca.position = Vector2((x0 + x1) / 2.0, chao)
	fase.add_child(marca)
	_perine = {"img": img, "aura": aura, "marca": marca, "estado": "espera", "t": 2.5}

## Yohan flutua no fundo; a marca pisca perto de você e o martelo dele desce do céu nela
func _passo_perine(dt: float) -> void:
	var v := fase.get_viewport().get_visible_rect().size
	var img: Sprite2D = _perine["img"]
	var aura: Sprite2D = _perine["aura"]
	var marca: Node2D = _perine["marca"]
	img.scale = Vector2.ONE * v.y * 0.5 / 900.0
	img.position = Vector2(v.x * 0.2, v.y * 0.36 + sin(_t * 1.1) * 14.0)
	img.rotation = sin(_t * 0.7) * 0.06
	aura.scale = Vector2.ONE * v.y * 0.9 / 64.0 * (1.0 + 0.06 * sin(_t * 3.0))
	aura.position = img.position
	_perine["t"] = float(_perine["t"]) - dt
	match _perine["estado"]:
		"espera":
			marca.modulate.a = 0.0
			if float(_perine["t"]) <= 0.0:
				_perine["estado"] = "ergue"
				_perine["t"] = 0.8
				marca.position = Vector2(clampf(_alvo_x() + randf_range(-300, 300), x0 + 600.0, x1 - 600.0), chao)
		"ergue":                                        # marca piscando: sai daí
			marca.modulate.a = 1.0 if fmod(float(_perine["t"]), 0.16) < 0.1 else 0.6
			if float(_perine["t"]) <= 0.0:
				_perine["estado"] = "espera"
				_perine["t"] = randf_range(2.0, 3.2)
				marca.modulate.a = 0.0
				_martelada(marca.position.x, 560.0)

# ---------- comum ----------
func _alvo_x() -> float:
	var pl: Player = fase.player
	if is_instance_valid(pl) and is_instance_valid(pl.chassi):
		return pl.foco().global_position.x
	return (x0 + x1) / 2.0

func _corpos() -> Array:
	var pl: Player = fase.player
	if not is_instance_valid(pl):
		return []
	if pl.montado and is_instance_valid(pl.chassi):
		return [pl.chassi] + pl.rodas + pl.membros.values()
	return pl.corpos.values()

func _morre(b: Node2D, motivo: String) -> void:
	var pl: Player = fase.player
	if morto or not fase.ativo or (pl.imortal_t > 0.0 and pl.montado):
		return
	if pl.repelir(b.global_position):
		return
	fase._on_perigo(b, motivo)

func _acerta_faixa(x: float, meia: float, motivo: String) -> void:
	for b in _corpos():
		var p := (b as Node2D).global_position
		if absf(p.x - x) < meia and p.y > chao - 4000.0:
			_morre(b, motivo)
			return

func _acerta_seg(a: Vector2, b2: Vector2, raio: float) -> void:
	for b in _corpos():
		var p := (b as Node2D).global_position
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b2)) < raio:
			_morre(b, "laser")
			return

func _feixe_tex() -> Texture2D:
	if _tex_feixe == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.28, 0.43, 0.5, 0.57, 0.72, 1.0])
		g.colors = PackedColorArray([Color(1, 0.1, 0.6, 0.0), Color(1, 0.2, 0.7, 0.55), Color(1, 0.6, 0.9, 1.0),
			Color(1, 1, 1, 1), Color(1, 0.6, 0.9, 1.0), Color(1, 0.2, 0.7, 0.55), Color(1, 0.1, 0.6, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 128
		_tex_feixe = t
	return _tex_feixe

func _feixe(larg: float, z: int) -> Line2D:
	var halo := _linha(larg * 2.6, Color(1, 0.2, 0.7, 0.25), z)
	halo.texture = _feixe_tex()
	halo.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var l := _linha(larg, Color.WHITE, z)
	l.texture = _feixe_tex()
	l.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	l.set_meta("halo", halo)
	return l

func _pts(l: Line2D, pts: PackedVector2Array, a: float) -> void:
	l.points = pts
	l.modulate.a = a
	var h: Line2D = l.get_meta("halo")
	h.points = pts
	h.modulate.a = a * (0.85 + 0.15 * sin(_t * 60.0))

func _linha(larg: float, cor: Color, z: int) -> Line2D:
	var l := Line2D.new()
	l.width = larg
	l.default_color = cor
	l.z_index = z
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = m
	fase.add_child(l)
	return l

func _bola(pos: Vector2, tam: float, cor: Color) -> Sprite2D:
	if _tex_brilho == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.25, Color(cor, 0.85))
		g.set_color(g.get_point_count() - 1, Color(cor, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_tex_brilho = t
	var s := Sprite2D.new()
	s.texture = _tex_brilho
	s.scale = Vector2.ONE * tam
	s.z_index = 10
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.position = pos
	fase.add_child(s)
	return s
