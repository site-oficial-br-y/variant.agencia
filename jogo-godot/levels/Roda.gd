extends Node2D
class_name Roda
## Chefe da fase 10: JAMES. Você está dentro de uma roda gigante que gira (roda de hamster);
## ele fica no fundo, trocando de lado, abrindo e fechando a boca, e comanda o giro.
##  - GIRO: o chão anda o tempo todo; parou de acelerar, ele te leva parede acima e você despenca.
##  - COSTELAS: lombadas presas na parede; no giro normal dá pra passar, na virada elas te arremessam.
##  - ESPINHOS: um trecho da parede acende vermelho e depois solta espinhos. Sai de cima (o chão anda!).
##  - VIRADA: ele dá um tranco e a roda dispara (ou troca de lado). Segura.
##  - LASERS: raios saindo do núcleo, girando. Pegam quem é arremessado pro meio.
## Dano: o INTERRUPTOR verde na parede vem vindo com o giro; passou por cima, choque nele.
## Zerou o James, ele vira o SEMAJ (reverso, vida cheia): roda mais rápida, troca de lado, mais raios.
## Giro em rad/s de JOGO (física); o resto em segundos REAIS (o jogo roda acelerado).

signal derrotado

const R := 2400.0                        # raio de dentro (onde o chão está)
const ESP := 320.0                       # espessura da parede
const N := 96                            # pedaços da parede
const VIDA_1 := 6
const VIDA_2 := 8
const MUSICA_1 := "james"                # percurso e James
const MUSICA_2 := "semaj"                # Semaj
const LARANJA := Color(1.0, 0.55, 0.15)
const VERDE := Color(0.35, 1.0, 0.45)
const VERMELHO := Color(1.0, 0.18, 0.15)

var fase: Node2D
var centro := Vector2.ZERO
var corpo: AnimatableBody2D
var ang := 0.0
var omega := 0.0
var omega_alvo := 0.0
var vida := VIDA_1
var ativo := false
var morto := false
var luta := 1
var _estado := "pausa"
var _timer := 2.0
var _t := 0.0
var _rodada := 0
var _virada_t := 14.0
var _mortes_teste_virada := 0
var _costelas: Array = []               # ângulo (local) de cada lombada: interruptor não nasce embaixo
var _arrasto_t := 0.0
var _pos_virada_t := 0.0                    # tranco da virada: o chão arrasta quem está nele
var _lado := 1.0
var _sorteio := RandomNumberGenerator.new()
var _interruptor: Dictionary = {}
var _espinhos: Array = []
var _raios: Array = []                   # {linha, halo, a}
var _raio_ang := 0.0
var _raio_len := R * 0.42
var _nucleo: Node2D
var _olho: Polygon2D
var _cara: Sprite2D
var _aura: Sprite2D
var _cara_lado := -1.0
var _troca_t := 8.0
var _sumir := 0.0                        # 0 = na tela; 1 = escondido embaixo (trocando de lado)
var _boca_t := 0.4
var _boca_aberta := false
var _texs: Dictionary = {}
var _virando_t := 0.0                    # transformação James -> Semaj
var _brilho_t := 0.0
var _tremor := 0.0
var _fim_t := 0.0
var _barra: ColorRect
var _barra_fundo: ColorRect
var _rotulo: Label
var _aviso: Label

func _real(delta: float) -> float:
	return delta / Engine.time_scale

static func _dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))

## monta a roda parada (o jogador já pode andar nela antes da luta)
func montar(main: Node2D, c: Vector2, mat: PhysicsMaterial) -> void:
	fase = main
	centro = c
	position = c
	var fundo := Polygon2D.new()                      # interior escuro, parado
	fundo.polygon = _circulo(R + ESP * 0.5, 72)
	fundo.color = Color(0.05, 0.03, 0.08, 0.6)          # meio transparente: o chefe aparece atrás da roda
	fundo.z_index = -20
	add_child(fundo)
	for k in 6:                                        # anéis de luz parados atrás (dão noção do giro)
		var anel := Line2D.new()
		anel.points = _circulo(R * (0.25 + k * 0.13), 64)
		anel.closed = true
		anel.width = 10.0
		anel.default_color = Color(1, 0.5, 0.15, 0.06 + k * 0.012)
		anel.z_index = -19
		add_child(anel)
	corpo = AnimatableBody2D.new()
	corpo.sync_to_physics = true
	corpo.collision_layer = 0b01
	corpo.collision_mask = 0
	corpo.physics_material_override = mat
	add_child(corpo)
	for i in N:
		var a0 := TAU * i / N
		var a1 := TAU * (i + 1) / N + 0.002
		var pts := PackedVector2Array([_dir(a0) * R, _dir(a1) * R, _dir(a1) * (R + ESP), _dir(a0) * (R + ESP)])
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
		corpo.add_child(cp)
		var vis := Polygon2D.new()
		vis.polygon = pts
		vis.color = Color(0.2, 0.17, 0.24) if i % 2 == 0 else Color(0.27, 0.22, 0.3)
		vis.z_index = 2
		corpo.add_child(vis)
		if i % 4 == 0:                                 # faixa laranja: dá pra ver a roda andando
			var fx := Polygon2D.new()
			var b0 := a0 + 0.01
			var b1 := a0 + TAU / N * 0.45
			fx.polygon = PackedVector2Array([_dir(b0) * (R + 6), _dir(b1) * (R + 6), _dir(b1) * (R + 60), _dir(b0) * (R + 60)])
			fx.color = LARANJA
			fx.z_index = 3
			corpo.add_child(fx)
	var borda := Line2D.new()
	borda.points = _circulo(R + 2, 128)
	borda.closed = true
	borda.width = 16.0
	borda.default_color = Color(1, 0.62, 0.25, 0.9)
	borda.z_index = 4
	corpo.add_child(borda)
	var fora := Line2D.new()
	fora.points = _circulo(R + ESP, 128)
	fora.closed = true
	fora.width = 40.0
	fora.default_color = Color(0.1, 0.08, 0.12)
	fora.z_index = 4
	corpo.add_child(fora)
	for k in 4:                                        # costelas (lombadas) presas na parede
		_costela(PI / 2.0 + PI / 4.0 + k * TAU / 4.0)
		_costelas.append(PI / 2.0 + PI / 4.0 + k * TAU / 4.0)
	_montar_nucleo()

func _circulo(r: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		p.append(_dir(TAU * i / n) * r)
	return p

## lombada arredondada na parede (ângulo local da roda)
func _costela(a: float) -> void:
	var meia := 0.075
	var pts := PackedVector2Array()
	for k in 9:
		var t := float(k) / 8.0
		var aa := a - meia + t * meia * 2.0
		var h := sin(t * PI) * 150.0
		pts.append(_dir(aa) * (R + 30.0 - h))
	pts.append(_dir(a + meia) * (R + 40.0))
	pts.append(_dir(a - meia) * (R + 40.0))
	var cp := CollisionPolygon2D.new()
	cp.polygon = pts
	corpo.add_child(cp)
	var vis := Polygon2D.new()
	vis.polygon = pts
	vis.color = Color(0.36, 0.3, 0.38)
	vis.z_index = 3
	corpo.add_child(vis)
	var linha := Line2D.new()
	linha.points = pts.slice(0, 9)
	linha.width = 12.0
	linha.default_color = LARANJA
	linha.z_index = 4
	corpo.add_child(linha)

## núcleo no meio (o chefe): bola com olho, presa no eixo, gira com a roda
func _montar_nucleo() -> void:
	_nucleo = Node2D.new()
	_nucleo.z_index = 6
	add_child(_nucleo)
	var halo := Polygon2D.new()
	halo.polygon = _circulo(520.0, 48)
	halo.color = Color(1, 0.45, 0.1, 0.12)
	_nucleo.add_child(halo)
	for k in 6:                                        # raios do eixo até a parede (decoração)
		var aro := Line2D.new()
		aro.points = PackedVector2Array([_dir(TAU * k / 6.0) * 360.0, _dir(TAU * k / 6.0) * (R - 40.0)])
		aro.width = 26.0
		aro.default_color = Color(0.16, 0.13, 0.2, 0.85)
		aro.z_index = -1
		corpo.add_child(aro)
	var bola := Polygon2D.new()
	bola.polygon = _circulo(380.0, 48)
	bola.color = Color(0.18, 0.12, 0.2)
	_nucleo.add_child(bola)
	var aro2 := Line2D.new()
	aro2.points = _circulo(380.0, 48)
	aro2.closed = true
	aro2.width = 22.0
	aro2.default_color = LARANJA
	_nucleo.add_child(aro2)
	_olho = Polygon2D.new()
	_olho.polygon = _circulo(150.0, 32)
	_olho.color = Color(1, 0.75, 0.3)
	_nucleo.add_child(_olho)

## liga a luta
func comecar() -> void:
	if ativo:
		return
	ativo = true
	_sorteio.seed = 1010 + (Online.rodada if Online.ativo else randi())
	_montar_cara()
	var hud: CanvasLayer = fase.get_node("HUD")
	_barra_fundo = ColorRect.new()
	_barra_fundo.color = Color(0, 0, 0, 0.7)
	_barra_fundo.size = Vector2(620, 40)
	hud.add_child(_barra_fundo)
	_barra = ColorRect.new()
	_barra.color = LARANJA
	_barra.size = Vector2(600, 24)
	hud.add_child(_barra)
	_rotulo = Label.new()
	_rotulo.text = "JAMES"
	_rotulo.add_theme_font_size_override("font_size", 30)
	_rotulo.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	hud.add_child(_rotulo)
	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 64)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 14)
	hud.add_child(_aviso)
	omega_alvo = 0.17
	_estado = "luta"
	_timer = 3.0
	_novo_interruptor(4.0)

func _novo_raio(a: float) -> void:
	var halo := Line2D.new()
	halo.width = 120.0
	halo.default_color = Color(1, 0.3, 0.1, 0.25)
	halo.z_index = 5
	halo.begin_cap_mode = Line2D.LINE_CAP_ROUND
	halo.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(halo)
	var l := Line2D.new()
	l.width = 44.0
	l.default_color = Color(1, 0.85, 0.6)
	l.z_index = 5
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(l)
	_raios.append({"linha": l, "halo": halo, "a": a})

# ---------- passo ----------
func atualizar(delta: float) -> void:
	_girar(delta)
	if not ativo:
		return
	var dt := _real(delta)
	_t += dt
	_posicionar_hud()
	_tremor = maxf(0.0, _tremor - dt * 2.0)
	_brilho_t = maxf(0.0, _brilho_t - dt)
	_olho.color = Color(1, 1, 1) if _brilho_t > 0.0 else (Color(0.85, 0.2, 1.0) if luta == 2 else Color(1, 0.75, 0.3))
	_nucleo.scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 3.0) + _brilho_t * 0.25)
	_passo_cara(dt)
	if morto:
		_passo_morte(dt)
		return
	_passo_raios(dt)
	_passo_interruptor(dt)
	for e in _espinhos.duplicate():
		_passo_espinho(e, dt)
	if _estado == "virada":
		_timer -= dt
		_virando_t = maxf(0.0, _virando_t - dt)
		if _timer <= 0.0:
			_pos_virada_t = 2.5
			_estado = "luta"
			omega_alvo = _giro_base()
			_aviso.text = ""
		return
	_timer -= dt
	if _timer <= 0.0:
		_timer = (3.4 if luta == 1 else 2.6) - minf(_rodada * 0.08, 0.8)
		_rodada += 1
		_novo_espinho()
		if luta == 2 and _rodada % 3 == 0:
			_novo_espinho()
	_virada_t -= dt
	if _virada_t <= 1.4 and _aviso.text == "":
		_aviso.text = "VIRADA! SEGURA!"
		_aviso.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		Audio.tocar("metal", 1.0, 0.0)
	if _virada_t <= 0.0:
		_virada()

func _giro_base() -> float:
	return (0.17 if luta == 1 else 0.24) * _lado

## gira a roda (no passo de física, pra o chão arrastar quem está em cima)
func _girar(delta: float) -> void:
	omega = move_toward(omega, omega_alvo, delta * (1.6 if _estado == "virada" else 0.25))
	ang += omega * delta
	corpo.rotation = ang
	_nucleo.rotation = ang * 0.5
	if _arrasto_t > 0.0:
		_arrasto_t -= _real(delta)
		for b in _corpos():
			var rb := b as RigidBody2D
			if rb == null:
				continue
			var rel := rb.global_position - centro
			if rel.length() > R - 450.0:
				var v_chao := Vector2(-rel.y, rel.x) * omega
				var acel := Input.get_axis("brake", "accelerate")
				var segura := 0.2 if acel != 0.0 and signf(acel) == -signf(v_chao.x) else 1.0   # acelerando contra: segura melhor
				rb.linear_velocity = rb.linear_velocity.lerp(v_chao, clampf(delta * 3.0 * segura, 0.0, 1.0))
	if _tremor > 0.0:
		var cam: Camera2D = fase.camera
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _tremor * 120.0

## virada: tranco forte (dispara pro mesmo lado ou inverte), depois volta ao giro normal
func _virada() -> void:
	_estado = "virada"
	_virada_t = _sorteio.randf_range(13.0, 17.0) if luta == 1 else _sorteio.randf_range(9.0, 12.0)
	if "viradas" in OS.get_cmdline_user_args():          # teste: virada a cada 5 s
		_virada_t = 5.0
		_mortes_teste_virada += 1
		print("[VIRADA] n=%d luta=%d" % [_mortes_teste_virada, luta])
	var inverte := luta == 2 and _sorteio.randf() < 0.6
	if inverte:
		_lado = -_lado
	omega_alvo = (0.95 if luta == 1 else 1.15) * _lado
	_timer = 2.4
	_arrasto_t = 0.55
	_tremor = 1.0
	Audio.tocar("impacto_forte", 1.0, 0.0)

## parte do corpo do jogador em ângulo local da roda e distância do centro
func _local(p: Vector2) -> Vector2:
	var d := p - centro
	return Vector2(wrapf(d.angle() - ang, -PI, PI), d.length())

func _corpos() -> Array:
	var pl: Player = fase.player
	if not is_instance_valid(pl):
		return []
	if pl.montado and is_instance_valid(pl.chassi):
		return [pl.chassi] + pl.rodas + pl.membros.values()
	return pl.corpos.values()

func _morre(b: Node2D, motivo: String) -> void:
	var pl: Player = fase.player
	if morto or not fase.ativo or (pl.imortal_t > 0.0 and pl.montado) or "imortal" in OS.get_cmdline_user_args():
		return
	if pl.repelir(b.global_position):
		return
	fase._on_perigo(b, motivo)

func _jogador_ang() -> float:
	var pl: Player = fase.player
	if is_instance_valid(pl) and is_instance_valid(pl.chassi):
		return _local(pl.foco().global_position).x
	return PI / 2.0 - ang

# ---------- o chefe no fundo ----------
func _montar_cara() -> void:
	for n in ["james", "james_grito", "semaj", "semaj_grito"]:
		_texs[n] = load("res://assets/roda/%s.png" % n)
	var fundo := CanvasLayer.new()
	fundo.layer = -70
	fase.add_child(fundo)
	var tr := TextureRect.new()
	tr.name = "fundo"
	tr.texture = load("res://assets/roda/fundo_luta.jpg")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(tr)
	set_meta("fundo", tr)
	var camada := CanvasLayer.new()
	camada.layer = -50
	fase.add_child(camada)
	_aura = Sprite2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_aura.texture = gt
	_aura.modulate = Color(1, 0.5, 0.2, 0.35)
	camada.add_child(_aura)
	_cara = Sprite2D.new()
	_cara.texture = _texs["james"]
	camada.add_child(_cara)

func _nome_cara() -> String:
	return "james" if luta == 1 else "semaj"

## boca abrindo e fechando; grita (aberta) na virada e quando leva choque; troca de lado de tempos em tempos
func _passo_cara(dt: float) -> void:
	if _cara == null:
		return
	var grito := _estado == "virada" or _brilho_t > 0.0 or _virando_t > 0.0
	_boca_t -= dt
	if _boca_t <= 0.0:
		_boca_aberta = not _boca_aberta
		_boca_t = _sorteio.randf_range(0.6, 1.4) if not _boca_aberta else _sorteio.randf_range(0.35, 0.8)
		if luta == 2:
			_boca_t *= 0.7
	_cara.texture = _texs[_nome_cara() + ("_grito" if grito or _boca_aberta else "")]
	if not morto and _virando_t <= 0.0:
		_troca_t -= dt
	if _troca_t <= 0.0:                               # afunda, troca de lado e sobe do outro
		_sumir = minf(1.0, _sumir + dt * 1.8)
		if _sumir >= 1.0:
			_cara_lado = -_cara_lado
			_troca_t = _sorteio.randf_range(7.0, 10.0) if luta == 1 else _sorteio.randf_range(5.0, 7.5)
	else:
		_sumir = maxf(0.0, _sumir - dt * 1.8)
	var flash := 1.0 + _brilho_t * 3.0
	_cara.modulate = Color(flash, flash, flash, 1.0 - _sumir * 0.6) if not morto else Color(1, 1, 1, maxf(0.0, 1.0 - _fim_t / 2.5))
	_aura.modulate = (Color(0.8, 0.2, 1.0, 0.55) if luta == 2 else Color(1, 0.5, 0.2, 0.3)) * Color(1, 1, 1, _cara.modulate.a)

## onde a cara está na tela (pra o raio do choque ir até ela)
func _cara_no_mundo() -> Vector2:
	if _cara == null:
		return centro
	return fase.get_viewport().get_canvas_transform().affine_inverse() * _cara.position

# ---------- raios do núcleo ----------
func _passo_raios(dt: float) -> void:
	_raio_ang += dt * (0.45 if luta == 1 else -0.7)
	var alvo_len := R * 0.4                         # não alcança a cabeça de quem está no chão (bonecos têm ~1250 de altura)
	_pos_virada_t = maxf(0.0, _pos_virada_t - dt)
	var calmo := _estado == "virada" or _virada_t <= 1.6 or _pos_virada_t > 0.0
	if calmo:                                       # do aviso até 2,5 s depois da virada: sem laser (você está sem controle)
		alvo_len = 0.0
	_raio_len = move_toward(_raio_len, alvo_len, dt * (2600.0 if calmo else 300.0))
	for r in _raios:
		(r["linha"] as Line2D).visible = _raio_len > 430.0
		(r["halo"] as Line2D).visible = _raio_len > 430.0
	if _raio_len <= 430.0:
		return
	for r in _raios:
		var a: float = r["a"] + _raio_ang
		var p0 := _dir(a) * 420.0
		var p1 := _dir(a) * _raio_len
		var pisca := 0.85 + 0.15 * sin(_t * 30.0)
		(r["linha"] as Line2D).points = PackedVector2Array([p0, p1])
		(r["halo"] as Line2D).points = PackedVector2Array([p0, p1])
		(r["linha"] as Line2D).modulate.a = pisca
		for b in _corpos():
			var p: Vector2 = (b as Node2D).global_position - centro
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, p0, p1)) < 70.0:
				if "secoes" in OS.get_cmdline_user_args(): print("[LASER] parte %s raio=%.0f len=%.0f estado=%s t=%.1f" % [b.name, p.length(), _raio_len, _estado, _t])
				_morre(b, "laser")
				return

# ---------- interruptor (dá dano) ----------
## aparece longe do jogador; com o giro ele vem vindo (ou você vai até ele)
func _novo_interruptor(espera: float) -> void:
	var vem := _sorteio.randf() < 0.5               # metade vem até você, metade sobe e você corre atrás
	var a := _jogador_ang() + _lado * (_sorteio.randf_range(-2.4, -1.7) if vem else _sorteio.randf_range(0.7, 1.1))
	for c in _costelas:                                 # caiu em cima de uma lombada: empurra pro lado
		var d := wrapf(a - float(c), -PI, PI)
		if absf(d) < 0.25:
			a = float(c) + (0.25 if d >= 0.0 else -0.25)
	var no := Node2D.new()
	no.position = _dir(a) * R
	no.rotation = a + PI / 2.0
	no.z_index = 7
	no.visible = false
	corpo.add_child(no)
	var base := Polygon2D.new()
	base.polygon = Pecas.retangulo(Vector2(0, 14), Vector2(260, 36))
	base.color = Color(0.15, 0.15, 0.18)
	no.add_child(base)
	var tampa := Polygon2D.new()
	tampa.polygon = Pecas.retangulo(Vector2(0, -10), Vector2(200, 30))
	tampa.color = VERDE
	no.add_child(tampa)
	var luz := Polygon2D.new()                        # coluna de luz verde apontando pro meio
	luz.polygon = PackedVector2Array([Vector2(-90, -20), Vector2(90, -20), Vector2(160, -900), Vector2(-160, -900)])
	luz.color = Color(0.35, 1, 0.45, 0.18)
	no.add_child(luz)
	var seta := Label.new()
	seta.text = "▼"
	seta.add_theme_font_size_override("font_size", 220)
	seta.add_theme_color_override("font_color", VERDE)
	seta.add_theme_color_override("font_outline_color", Color.BLACK)
	seta.add_theme_constant_override("outline_size", 24)
	seta.position = Vector2(-80, -620)
	no.add_child(seta)
	_interruptor = {"no": no, "a": a, "espera": espera, "seta": seta, "dura": 9.0}

func _passo_interruptor(dt: float) -> void:
	if _interruptor.is_empty() or not fase.ativo:
		return
	var no: Node2D = _interruptor["no"]
	if _interruptor["espera"] > 0.0:
		_interruptor["espera"] -= dt
		no.visible = _interruptor["espera"] <= 0.0
		return
	(_interruptor["seta"] as Label).position.y = -620.0 + sin(_t * 8.0) * 50.0
	_interruptor["dura"] -= dt
	if _interruptor["dura"] < 2.0:
		no.modulate.a = 0.4 + 0.6 * absf(sin(_t * 12.0))
	if _interruptor["dura"] <= 0.0:                     # demorou: some e volta em outro lugar
		no.queue_free()
		_interruptor = {}
		_novo_interruptor(2.5)
		return
	var pos := no.global_position
	for b in _corpos():
		if (b as Node2D).global_position.distance_to(pos) < 230.0:
			_apertou()
			return

func _apertou() -> void:
	var no: Node2D = _interruptor["no"]
	var de := no.global_position
	_interruptor = {}
	no.queue_free()
	levar_dano()
	var raio := Line2D.new()                           # choque do interruptor até o núcleo
	var pts := PackedVector2Array()
	for k in 12:
		var t := k / 11.0
		pts.append(de.lerp(_cara_no_mundo(), t) - centro + Vector2(randf_range(-120, 120), randf_range(-120, 120)) * (0.0 if k == 0 or k == 11 else 1.0))
	raio.points = pts
	raio.width = 34.0
	raio.default_color = VERDE
	raio.z_index = 8
	add_child(raio)
	var tw := raio.create_tween()
	tw.tween_property(raio, "modulate:a", 0.0, 0.6)
	tw.tween_callback(raio.queue_free)
	if not morto:
		_novo_interruptor(6.0 if luta == 1 else 5.0)

## dano no núcleo (interruptor ou vindo do online)
func levar_dano() -> void:
	if morto:
		return
	vida -= 1
	_brilho_t = 0.5
	_tremor = 0.6
	Audio.tocar("choque", 1.0, 0.05)
	Audio.tocar("impacto_forte", 0.8, 0.0)
	fase._mensagem("CHOQUE NO %s!" % _nome_cara().to_upper(), VERDE)
	if vida <= 0:
		if luta == 1:
			_virar_semaj()
		else:
			_morrer()

## zerou o James: ele vira o Semaj (reverso), com vida cheia, música nova e tudo mais difícil
func _virar_semaj() -> void:
	luta = 2
	vida = VIDA_2
	_virando_t = 2.6
	_estado = "virada"
	_timer = 2.6
	omega_alvo = 0.0
	_tremor = 1.2
	for e in _espinhos:
		(e["no"] as Node).queue_free()
	_espinhos.clear()
	if not _interruptor.is_empty():
		(_interruptor["no"] as Node).queue_free()
		_interruptor = {}
	_aviso.text = "JAMES VIROU SEMAJ!"
	_aviso.add_theme_color_override("font_color", Color(0.85, 0.4, 1.0))
	_rotulo.text = "SEMAJ"
	_rotulo.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	_barra.color = Color(0.7, 0.2, 1.0)
	Audio.parar_chefe()
	Audio.musica_chefe(MUSICA_2)
	Audio.tocar("ronco", 1.0, 0.0)
	_preto_e_branco()
	_lado = -_lado
	_virada_t = 9.0
	_raio_len = 0.0                                   # lasers do meio só no Semaj: nascem do núcleo e crescem
	for k in 4:
		_novo_raio(TAU * k / 4.0)
	_novo_interruptor(5.0)

## Semaj: o mundo perde a cor (filtro preto e branco por cima de tudo, entra aos poucos)
func _preto_e_branco() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 70
	fase.add_child(camada)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float forca = 0.0;
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * 1.15 + 0.5, 0.0, 1.0);
	COLOR = vec4(mix(c, vec3(l), forca), 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	camada.add_child(r)
	var tw := r.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("forca", v), 0.0, 1.0, 1.6)

## online: o time já está no Semaj
func forcar_luta2() -> void:
	if luta == 1 and not morto:
		vida = 0
		_virar_semaj()

# ---------- espinhos ----------
func _novo_espinho() -> void:
	if "sem_espinho" in OS.get_cmdline_user_args():
		return
	var largura := deg_to_rad(_sorteio.randf_range(38.0, 52.0) if luta == 1 else _sorteio.randf_range(45.0, 65.0))
	var meio := _jogador_ang() + _sorteio.randf_range(-1.2, 1.2)
	if not _interruptor.is_empty() and absf(wrapf(meio - float(_interruptor["a"]), -PI, PI)) < largura:
		meio += largura * 1.5                          # não cobre o interruptor
	var no := Node2D.new()
	no.z_index = 6
	corpo.add_child(no)
	var faixa := Polygon2D.new()
	var pts := PackedVector2Array()
	var n := 14
	for k in n + 1:
		pts.append(_dir(meio - largura / 2.0 + largura * k / n) * (R - 6.0))
	for k in range(n, -1, -1):
		pts.append(_dir(meio - largura / 2.0 + largura * k / n) * (R - 90.0))
	faixa.polygon = pts
	faixa.color = Color(1, 0.15, 0.1, 0.0)
	no.add_child(faixa)
	var dentes := Node2D.new()
	dentes.visible = false
	no.add_child(dentes)
	var qtd := int(largura * R / 120.0)
	for k in qtd:
		var a := meio - largura / 2.0 + largura * (k + 0.5) / qtd
		var d := Polygon2D.new()
		d.polygon = PackedVector2Array([_dir(a - 0.02) * (R + 4), _dir(a + 0.02) * (R + 4), _dir(a) * (R - 190.0)])
		d.color = Color(0.85, 0.85, 0.9)
		dentes.add_child(d)
	_espinhos.append({"no": no, "faixa": faixa, "dentes": dentes, "meio": meio, "larg": largura, "t": 0.0,
		"aviso": 1.7 if luta == 1 else 1.35, "dura": 1.8})

func _passo_espinho(e: Dictionary, dt: float) -> void:
	e["t"] += dt
	var t: float = e["t"]
	var faixa: Polygon2D = e["faixa"]
	if t < e["aviso"]:
		faixa.color.a = 0.25 + 0.35 * absf(sin(t * 9.0))
		return
	if t < e["aviso"] + e["dura"]:
		if not (e["dentes"] as Node2D).visible:
			(e["dentes"] as Node2D).visible = true
			faixa.color = Color(1, 0.1, 0.05, 0.55)
			Audio.tocar("metal", 0.8)
		for b in _corpos():
			var l := _local((b as Node2D).global_position)
			if l.y > R - 230.0 and absf(wrapf(l.x - float(e["meio"]), -PI, PI)) < float(e["larg"]) / 2.0:
				_morre(b, "esmagado")
				return
		return
	(e["no"] as Node).queue_free()
	_espinhos.erase(e)

# ---------- fim ----------
func _morrer() -> void:
	morto = true
	_fim_t = 0.0
	omega_alvo = 0.0
	_aviso.text = ""
	if not _interruptor.is_empty():
		(_interruptor["no"] as Node).queue_free()
		_interruptor = {}
	for e in _espinhos:
		(e["no"] as Node).queue_free()
	_espinhos.clear()
	for r in _raios:
		(r["linha"] as Node).queue_free()
		(r["halo"] as Node).queue_free()
	_raios.clear()
	fase._mensagem("SEMAJ CAIU! A RODA PAROU!", VERDE)

func _passo_morte(dt: float) -> void:
	_fim_t += dt
	_tremor = 0.4
	_nucleo.modulate = Color(1, 1, 1, maxf(0.0, 1.0 - _fim_t / 2.5))
	if _fim_t > 2.6 and _fim_t - dt <= 2.6:
		_tremor = 0.0
		fase.camera.offset = Vector2.ZERO
		_barra.visible = false
		_barra_fundo.visible = false
		_rotulo.visible = false
		derrotado.emit()

func esconder_barra() -> void:
	for n in [_barra, _barra_fundo, _rotulo, _aviso]:
		if is_instance_valid(n):
			n.visible = false

func _posicionar_hud() -> void:
	var v: Vector2 = fase.get_viewport().get_visible_rect().size
	_barra_fundo.position = Vector2(v.x / 2.0 - 310.0, v.y - 70.0)
	_barra.position = _barra_fundo.position + Vector2(10, 8)
	_barra.size.x = 600.0 * maxf(0.0, float(vida) / (VIDA_1 if luta == 1 else VIDA_2))
	if _cara:
		var h := v.y * 0.9
		var esc := h / 1003.0
		var rs: float = (R + ESP) * (fase.camera.zoom.x if fase.camera else 0.125)
		_cara.scale = Vector2.ONE * esc
		_cara.position = Vector2(v.x / 2.0 + _cara_lado * rs * 0.72, v.y * 0.52 + sin(_t * 1.3) * 10.0 + _sumir * v.y * 0.9)
		_aura.position = _cara.position
		_aura.scale = Vector2.ONE * (h * 1.25 / 256.0)
		var tr: TextureRect = get_meta("fundo")
		var ef := maxf(v.x / 1024.0, v.y / 1536.0)
		tr.size = Vector2(1024, 1536) * ef
		tr.position = Vector2((v.x - tr.size.x) / 2.0, v.y - tr.size.y * 0.97)
	_rotulo.position = _barra_fundo.position + Vector2(0, -42)
	_aviso.size = Vector2(v.x, 100)
	_aviso.position = Vector2(0, v.y * 0.2)
