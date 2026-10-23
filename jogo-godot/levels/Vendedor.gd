extends Node2D
class_name Vendedor
## Chefe da fase 6: o Vendedor gigante no fundo do atacadão, arremessando o que vê
## pela frente (caixa, prateleira, carrinho, carro, caminhão, melancia) em arco
## até onde você vai estar. Sombra vermelha no chão mostra onde cai. Aguente até
## ele cansar: aí ele desaba e a saída abre. Tempo em segundos reais.

signal cansou

const DURACAO := 35.0
var fase: Node2D
var chao := 1000.0
var corpo: Sprite2D
var ativo := false
var acabou := false
var _t := 0.0
var _prox := 1.5
var _voando: Array = []
var _barra: ColorRect
var _fundo: ColorRect
var _rotulo: Label

func montar(main: Node2D, y_chao: float) -> void:
	fase = main
	chao = y_chao
	z_index = -5
	corpo = Sprite2D.new()
	corpo.texture = load("res://assets/arte/vendedor.png")
	corpo.scale = Vector2.ONE * 1.6                      # ~2150 px de altura: cabeça na tela
	corpo.offset = Vector2(0, -676)                      # pé na origem
	add_child(corpo)
	visible = false

func comecar() -> void:
	if ativo or acabou:
		return
	ativo = true
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	var hud: CanvasLayer = fase.get_node("HUD")
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.7)
	_fundo.size = Vector2(620, 40)
	hud.add_child(_fundo)
	_barra = ColorRect.new()
	_barra.color = Color(1, 0.5, 0.1)
	_barra.size = Vector2(600, 24)
	hud.add_child(_barra)
	_rotulo = Label.new()
	_rotulo.text = "VENDEDOR — AGUENTE!"
	_rotulo.add_theme_font_size_override("font_size", 30)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	hud.add_child(_rotulo)
	fase._mensagem("O VENDEDOR TE VIU! DESVIA DE TUDO!", Color(1, 0.6, 0.2))
	Audio.musica_chefe("vendedor")

func _real(delta: float) -> float:
	return delta / Engine.time_scale

func atualizar(delta: float) -> void:
	if not ativo:
		return
	var dt := _real(delta)
	_t += dt
	var pl: Player = fase.player
	var v := get_viewport().get_visible_rect().size
	_fundo.position = Vector2(v.x / 2.0 - 310, 112)
	_barra.position = _fundo.position + Vector2(10, 8)
	_barra.size.x = 600.0 * clampf(1.0 - _t / DURACAO, 0.0, 1.0)
	_rotulo.position = _fundo.position + Vector2(0, -38)
	global_position.x = lerpf(global_position.x, fase.camera.global_position.x + 1700.0, clampf(dt * 6.0, 0.0, 1.0))
	global_position.y = chao + 80.0 + (sin(_t * 2.0) * 30.0 if not acabou else minf(1.0, (_t - DURACAO)) * 2500.0)
	for o in _voando.duplicate():
		_voar(o, dt)
	if acabou:
		corpo.rotation = lerpf(corpo.rotation, 0.6, dt * 2.0)
		return
	corpo.rotation = sin(_t * 1.5) * 0.04
	if _t >= DURACAO:
		acabou = true
		_rotulo.text = "O VENDEDOR CANSOU!"
		_rotulo.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		fase._mensagem("ELE CANSOU! A SAÍDA ABRIU!", Color(0.5, 1, 0.5))
		cansou.emit()
		return
	if not fase.ativo or not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	_prox -= dt
	if _prox <= 0.0:
		_prox = maxf(0.75, 1.8 - _t * 0.03)                # vai jogando mais rápido
		_jogada(pl)

## varia a mira pra não dar pra decorar: às vezes onde você vai estar, às vezes onde
## você está, às vezes atrás (pega quem freia) e às vezes uma rajada que fecha o caminho
func _jogada(pl: Player) -> void:
	var modos := ["futuro", "agora", "atras", "cerco"]
	if _t > 10.0:
		modos += ["rajada", "cerco"]
	if _t > 22.0:
		modos += ["rajada", "parede"]
	match modos[randi() % modos.size()]:
		"futuro":
			_arremessar(pl, 0.0, 0.85)
		"agora":
			_arremessar(pl, 0.0, 0.0)
		"atras":
			_arremessar(pl, -900.0, 0.3)
		"cerco":                                          # onde você vai e onde você está
			_arremessar(pl, 0.0, 0.9)
			_arremessar(pl, 0.0, 0.0, 1.35)
		"rajada":                                         # três seguidas varrendo pra frente
			for i in 3:
				get_tree().create_timer(0.3 * i * Engine.time_scale).timeout.connect(func() -> void:
					if ativo and not acabou and is_instance_valid(pl) and is_instance_valid(pl.chassi):
						_arremessar(pl, -600.0 + i * 900.0, 0.6))
		"parede":                                         # uma na frente e uma atrás ao mesmo tempo
			_arremessar(pl, 1600.0, 0.7)
			_arremessar(pl, -1100.0, 0.2)

func _arremessar(pl: Player, desvio := 0.0, mira := 0.85, voo := 1.1) -> void:
	var tipos := ["caixa", "caixa", "melancia", "carrinho", "prateleira", "carro", "caminhao"]
	var tipo: String = tipos[randi() % tipos.size()]
	var vx := pl.chassi.linear_velocity.x if pl.montado else 0.0
	var alvo_x := pl.foco().global_position.x + vx * voo * Engine.time_scale * mira + desvio
	var no := _visual(tipo)
	no.z_index = 7
	fase.add_child(no)
	var de := global_position + Vector2(-640, -900)        # mão dele
	no.global_position = de
	corpo.rotation = -0.2                                   # tranco do arremesso
	var sombra := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 20:
		pts.append(Vector2(float(no.get_meta("raio")) * 1.2, 0).rotated(TAU * k / 20.0) * Vector2(1, 0.18))
	sombra.polygon = pts
	sombra.color = Color(1, 0.15, 0.1, 0.4)
	sombra.global_position = Vector2(alvo_x, chao - 6)
	sombra.z_index = 4
	fase.add_child(sombra)
	var hit := Area2D.new()
	hit.collision_layer = 0
	hit.collision_mask = 0b110
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = float(no.get_meta("raio")) * 0.85
	cs.shape = c
	hit.add_child(cs)
	no.add_child(hit)
	var o := {"no": no, "de": de, "alvo": Vector2(alvo_x, chao - float(no.get_meta("raio"))), "t": 0.0, "T": voo,
		"sombra": sombra, "hit": hit, "giro": randf_range(-6, 6)}
	hit.body_entered.connect(func(b: Node2D) -> void:
		if o["t"] < o["T"] * 0.55 or not (b.is_in_group("veiculo") or b.is_in_group("piloto")):
			return
		fase._on_perigo(b, "esmagado"))
	_voando.append(o)
	Audio.tocar("pulo", 0.5, 0.2)

func _voar(o: Dictionary, dt: float) -> void:
	o["t"] += dt
	var k: float = clampf(o["t"] / o["T"], 0.0, 1.0)
	var no: Node2D = o["no"]
	var p := (o["de"] as Vector2).lerp(o["alvo"], k)
	p.y -= sin(k * PI) * 2200.0                              # arco
	no.global_position = p
	no.rotation += float(o["giro"]) * dt
	(o["sombra"] as Polygon2D).color.a = 0.25 + 0.5 * k
	if k >= 1.0:
		_voando.erase(o)
		(o["sombra"] as Node).queue_free()
		Audio.tocar("impacto_forte", 0.9)
		fase.pecas.poeira(no.global_position + Vector2(0, float(no.get_meta("raio"))), 1.6)
		(o["hit"] as Area2D).set_deferred("monitoring", false)
		var tw := no.create_tween()                          # fica um pouco no chão e some
		tw.tween_interval(2.5)
		tw.tween_property(no, "modulate:a", 0.0, 0.5)
		tw.tween_callback(no.queue_free)

## desenho de cada coisa arremessada (cartunesco, cor chapada, contorno)
func _visual(tipo: String) -> Node2D:
	var n := Node2D.new()
	var P: Pecas = fase.pecas
	var preto := Color(0.08, 0.08, 0.1)
	match tipo:
		"caixa":
			var s := Sprite2D.new()
			s.texture = P.tex("caixa")
			s.scale = Vector2.ONE * 600.0 / 256.0
			n.add_child(s)
			n.set_meta("raio", 330.0)
		"melancia":
			var pts := PackedVector2Array()
			for k in 24:
				pts.append(Vector2(300, 0).rotated(TAU * k / 24.0) * Vector2(1, 0.8))
			P.poligono(pts, Color(0.2, 0.6, 0.2), 0, null, 1.0, n)
			for k in 5:
				P.linha(PackedVector2Array([Vector2(-200 + k * 100, -230), Vector2(-220 + k * 110, 230)]), 22.0, Color(0.1, 0.38, 0.12), 0, n)
			P.linha(pts + PackedVector2Array([pts[0]]), 14.0, preto, 0, n)
			n.set_meta("raio", 300.0)
		"carrinho":
			var s := Sprite2D.new()
			s.texture = load("res://assets/bicho/veiculo.png")
			s.scale = Vector2.ONE * 0.75
			n.add_child(s)
			n.set_meta("raio", 450.0)
		"prateleira":
			P.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(800, 1300)), Color(0.55, 0.58, 0.62), 0, null, 1.0, n)
			var cores := [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(1, 0.8, 0.2), Color(0.3, 0.8, 0.3), Color(1, 0.5, 0.1)]
			for f in 4:
				var y := -560.0 + f * 330.0
				P.poligono(Pecas.retangulo(Vector2(0, y + 120), Vector2(800, 30)), Color(0.35, 0.37, 0.4), 0, null, 1.0, n)
				for i in 5:
					P.poligono(Pecas.retangulo(Vector2(-300 + i * 150, y + 30), Vector2(120, 150)), cores[(f + i) % 5], 0, null, 1.0, n)
			P.linha(Pecas.retangulo(Vector2.ZERO, Vector2(800, 1300)) + PackedVector2Array([Vector2(-400, -650)]), 16.0, preto, 0, n)
			n.set_meta("raio", 620.0)
		"carro":
			var corpo_c := PackedVector2Array([Vector2(-900, 100), Vector2(-900, -100), Vector2(-500, -150), Vector2(-250, -420),
				Vector2(350, -420), Vector2(600, -150), Vector2(900, -100), Vector2(900, 100)])
			P.poligono(corpo_c, Color(0.85, 0.15, 0.15), 0, null, 1.0, n)
			P.poligono(PackedVector2Array([Vector2(-200, -380), Vector2(300, -380), Vector2(500, -170), Vector2(-420, -170)]), Color(0.65, 0.85, 1.0), 0, null, 1.0, n)
			P.linha(corpo_c + PackedVector2Array([corpo_c[0]]), 16.0, preto, 0, n)
			for x in [-520.0, 520.0]:
				var r := PackedVector2Array()
				for k in 16:
					r.append(Vector2(x, 110) + Vector2(170, 0).rotated(TAU * k / 16.0))
				P.poligono(r, Color(0.12, 0.12, 0.14), 0, null, 1.0, n)
			n.set_meta("raio", 800.0)
		"caminhao":
			P.poligono(Pecas.retangulo(Vector2(-300, -350), Vector2(1800, 900)), Color(0.95, 0.5, 0.1), 0, null, 1.0, n)
			P.poligono(Pecas.retangulo(Vector2(-300, -560), Vector2(1800, 140)), Color(0.15, 0.55, 0.25), 0, null, 1.0, n)
			P.poligono(PackedVector2Array([Vector2(600, 100), Vector2(600, -500), Vector2(950, -500), Vector2(1150, -200), Vector2(1150, 100)]), Color(0.9, 0.9, 0.92), 0, null, 1.0, n)
			P.poligono(PackedVector2Array([Vector2(700, -450), Vector2(930, -450), Vector2(1080, -230), Vector2(700, -230)]), Color(0.65, 0.85, 1.0), 0, null, 1.0, n)
			var l := Label.new()
			l.text = "ATACADÃO"
			l.add_theme_font_size_override("font_size", 230)
			l.add_theme_color_override("font_color", Color.WHITE)
			l.add_theme_color_override("font_outline_color", preto)
			l.add_theme_constant_override("outline_size", 30)
			l.position = Vector2(-1150, -560)
			n.add_child(l)
			for x in [-900.0, 300.0, 900.0]:
				var r := PackedVector2Array()
				for k in 16:
					r.append(Vector2(x, 160) + Vector2(200, 0).rotated(TAU * k / 16.0))
				P.poligono(r, Color(0.12, 0.12, 0.14), 0, null, 1.0, n)
			n.set_meta("raio", 950.0)
	return n
