extends Node2D
class_name Protesto
## Mecânicas do percurso da fase 10 (o protesto antes do James):
##  - ARPOADOR: canhão de arpão no poste. Mira (linha vermelha) e dispara; o arpão que pega
##    braço/perna arranca e você segue montado; no tronco/cabeça crava no corpo e te derruba.
##  - FAIXA DE TURBO: setas verdes no chão que vão somando velocidade até a rampa grande.
##  - CANHÃO D'ÁGUA: caminhão na calçada; o jato liga e desliga e empurra pra trás.
##  - MOLOTOV: a multidão joga garrafas; um círculo vermelho mostra onde cai e o chão pega fogo.
## Tempos em segundos REAIS; movimento do arpão no passo de física.

const VEL_ARPAO := 3400.0                 # px/s de jogo
const ALCANCE := 4200.0
const MEMBROS := ["braco", "perna", "perna2", "coxa", "canela"]

var fase: Node2D
var _arpoadores: Array = []
var _arpoes: Array = []
var _canhoes: Array = []
var _molotov_zonas: Array = []           # {x0, x1, t}
var _garrafas: Array = []
var _fogos: Array = []
var _sorteio := RandomNumberGenerator.new()
var _t := 0.0

func _real(delta: float) -> float:
	return delta / Engine.time_scale

func montar(main: Node2D) -> void:
	fase = main
	_sorteio.seed = 4242

func _player() -> Player:
	var pl: Player = fase.player
	return pl if is_instance_valid(pl) else null

func _foco() -> Vector2:
	var pl := _player()
	return pl.foco().global_position if pl and is_instance_valid(pl.chassi) else Vector2(-1e9, 0)

# ---------- ARPOADOR ----------
## poste com canhão de arpão; `alvo_y` é a altura (acima do chão) que ele mira; `ang` inclina o tiro
func arpoador(base: Vector2, altura := 330.0, periodo := 2.6, atraso := 0.0, ang := 0.0) -> void:
	var no := Node2D.new()
	no.position = base
	no.z_index = 2
	fase.add_child(no)
	var sapata := Polygon2D.new()
	sapata.polygon = Pecas.retangulo(Vector2(0, -20), Vector2(220, 40))
	sapata.color = Color(0.15, 0.15, 0.18)
	no.add_child(sapata)
	var poste := Polygon2D.new()
	poste.polygon = Pecas.retangulo(Vector2(0, -altura / 2.0), Vector2(90, altura))
	poste.color = Color(0.22, 0.22, 0.26)
	no.add_child(poste)
	var cano := Node2D.new()
	cano.position = Vector2(0, -altura)
	cano.rotation = PI + ang
	cano.scale = Vector2.ONE * 1.5
	no.add_child(cano)
	var corpo := Polygon2D.new()
	corpo.polygon = PackedVector2Array([Vector2(-70, -45), Vector2(150, -30), Vector2(150, 30), Vector2(-70, 45)])
	corpo.color = Color(0.35, 0.33, 0.3)
	cano.add_child(corpo)
	var faixa := Polygon2D.new()
	faixa.polygon = Pecas.retangulo(Vector2(40, 0), Vector2(30, 92))
	faixa.color = Color(1, 0.75, 0.15)
	cano.add_child(faixa)
	var ponta := _desenho_arpao()
	ponta.position = Vector2(120, 0)
	cano.add_child(ponta)
	var mira := Line2D.new()
	mira.points = PackedVector2Array([Vector2(160, 0), Vector2(ALCANCE, 0)])
	mira.width = 10.0
	mira.default_color = Color(1, 0.1, 0.1, 0.0)
	cano.add_child(mira)
	_arpoadores.append({"no": no, "cano": cano, "ponta": ponta, "mira": mira, "periodo": periodo,
		"t": -atraso, "base": base})

func _desenho_arpao() -> Node2D:
	var n := Node2D.new()
	var haste := Line2D.new()
	haste.points = PackedVector2Array([Vector2(-260, 0), Vector2(30, 0)])
	haste.width = 16.0
	haste.default_color = Color(0.55, 0.45, 0.35)
	n.add_child(haste)
	var cabeca := Polygon2D.new()
	cabeca.polygon = PackedVector2Array([Vector2(30, -26), Vector2(110, 0), Vector2(30, 26), Vector2(48, 0)])
	cabeca.color = Color(0.8, 0.82, 0.88)
	n.add_child(cabeca)
	var farpa := Polygon2D.new()
	farpa.polygon = PackedVector2Array([Vector2(20, -10), Vector2(-20, -34), Vector2(0, 0), Vector2(-20, 34), Vector2(20, 10)])
	farpa.color = Color(0.7, 0.72, 0.78)
	n.add_child(farpa)
	return n

func _passo_arpoador(a: Dictionary, dt: float) -> void:
	var longe := absf((a["base"] as Vector2).x - _foco().x) > 6500.0
	a["t"] += dt
	var t: float = a["t"]
	var per: float = a["periodo"]
	var mira: Line2D = a["mira"]
	if t < 0.0 or longe:
		mira.default_color.a = 0.0
		return
	var fase_t := fmod(t, per)
	if fase_t > per - 0.8:                               # mira vermelha piscando antes do tiro
		mira.default_color.a = 0.25 + 0.55 * absf(sin(fase_t * 20.0))
	else:
		mira.default_color.a = 0.0
	if fase_t < dt:                                      # dispara
		var cano: Node2D = a["cano"]
		var dir := Vector2.RIGHT.rotated(cano.global_rotation)
		var proj := _desenho_arpao()
		proj.scale = Vector2.ONE * 1.5
		proj.z_index = 18
		proj.rotation = dir.angle()
		fase.add_child(proj)
		proj.global_position = cano.global_position + dir * 160.0
		_arpoes.append({"no": proj, "dir": dir, "andou": 0.0, "preso": false})
		(a["ponta"] as Node2D).visible = false
		Audio.tocar("metal", 1.0, 0.1)
		Audio.tocar("turbo", 0.5, 0.2)
	elif fase_t > 0.6:
		(a["ponta"] as Node2D).visible = true                 # recarregou

func _passo_arpao(p: Dictionary, delta: float) -> void:
	var no: Node2D = p["no"]
	if p["preso"]:
		return
	var passo := VEL_ARPAO * delta
	var de := no.global_position
	var ate := de + (p["dir"] as Vector2) * passo
	no.global_position = ate
	p["andou"] += passo
	if p["andou"] > ALCANCE:
		no.queue_free()
		_arpoes.erase(p)
		return
	var ponta_de := de + (p["dir"] as Vector2) * 100.0
	var ponta_ate := ate + (p["dir"] as Vector2) * 100.0
	var pl := _player()
	if pl == null or not fase.ativo:
		return
	for alvo in _partes(pl):
		var pos: Vector2 = (alvo[1] as Node2D).global_position
		if pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, ponta_de, ponta_ate)) < float(alvo[2]):
			_acertou(p, pl, alvo[0], alvo[1])
			return

## [nome, nó, raio] de cada parte que o arpão pode pegar
func _partes(pl: Player) -> Array:
	var r: Array = []
	if pl.montado:
		for k in pl.sprites:                              # centro de cada peça desenhada
			var nome: String = str(k).split("_")[0]
			if pl.perdeu.has(nome) or not pl.membros.has(nome) or not is_instance_valid(pl.sprites[k]):
				continue
			r.append([nome, pl.sprites[k], 110.0 if nome in MEMBROS else 140.0])
		if is_instance_valid(pl.chassi):
			r.append(["chassi", pl.chassi, 130.0])
		for rd in pl.rodas:
			if is_instance_valid(rd):
				r.append(["chassi", rd, 90.0])
	else:
		for k in pl.corpos:
			r.append([k, pl.corpos[k], 95.0])
	return r

func _acertou(p: Dictionary, pl: Player, parte: String, no_parte: Node2D) -> void:
	if "secoes" in OS.get_cmdline_user_args(): print("[ARPAO] pegou ", parte)
	var proj: Node2D = p["no"]
	var dir: Vector2 = p["dir"]
	var sangue: Sangue = fase.sangue
	sangue.jorrar(no_parte.global_position, 50, 1500.0, Vector2.ZERO, dir * 600.0)
	Audio.tocar("splat", 1.0)
	Audio.tocar("osso", 1.0)
	if pl.montado and parte in MEMBROS:                  # arranca o membro e segue montado
		pl._amputar_montado(parte)
		p["andou"] = ALCANCE - 900.0                       # o arpão passa e some logo depois
		fase._mensagem("ARRANCOU!", Color(1, 0.3, 0.3))
		return
	if pl.montado and parte == "chassi":                 # pegou no veículo: tranco pra trás
		pl.chassi.linear_velocity += dir * 900.0
		p["andou"] = ALCANCE - 300.0
		Audio.tocar("metal", 1.0)
		return
	if not pl.montado and parte in MEMBROS:              # já caído: arranca o pedaço
		pl.arrancar(parte)
		p["andou"] = ALCANCE - 900.0
		return
	# tronco/cabeça: crava no corpo e fica
	p["preso"] = true
	_arpoes.erase(p)
	if pl.montado:
		pl.soltar_ragdoll(pl.chassi.linear_velocity * 0.4 + dir * 1600.0, false)
	_cravar.call_deferred(proj, pl, parte, dir)
	fase._fim(false, "arpao")

func _cravar(proj: Node2D, pl: Player, parte: String, dir: Vector2) -> void:
	if not is_instance_valid(proj) or not is_instance_valid(pl):
		return
	var rb: RigidBody2D = pl.corpos.get(parte, pl.corpos.get("tronco"))
	if rb == null:
		return
	var gt := proj.global_transform
	proj.get_parent().remove_child(proj)
	rb.add_child(proj)
	proj.global_transform = gt
	proj.global_position = rb.global_position - dir * 40.0       # atravessado no corpo
	rb.apply_central_impulse(dir * 1800.0 * rb.mass)
	fase.sangue.esguichar(rb, Vector2.ZERO, -dir, 3.0)

# ---------- CANHÃO D'ÁGUA ----------
## caminhão blindado na beira da rua, virado pra trás; o canhão do teto liga e desliga
const CAM_ALT := 1350.0                  # altura do caminhão no mundo
const CAM_BICO := Vector2(430, 22)       # boca do canhão na arte (1100 x 672)
const JATO_ALCANCE := Vector2(-2500, 0)  # até onde o jato vai (o y é o chão)

func canhao(base: Vector2, periodo := 3.4, liga := 1.6, atraso := 0.0) -> void:
	var no := Node2D.new()
	no.position = base
	no.z_index = -1
	fase.add_child(no)
	var esc := CAM_ALT / 672.0
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/roda/caminhao.png")
	spr.centered = false
	spr.scale = Vector2.ONE * esc
	spr.position = Vector2(-1100.0 * esc * 0.45, -672.0 * esc + 40.0)
	no.add_child(spr)
	var bico := spr.position + CAM_BICO * esc
	var giro := Sprite2D.new()                           # giroflex por cima (pisca vermelho/azul)
	giro.texture = fase.pecas._brilho
	giro.scale = Vector2.ONE * 9.0
	giro.position = spr.position + Vector2(330, 140) * esc
	giro.z_index = 1
	no.add_child(giro)
	var jato := Node2D.new()
	jato.z_index = 14
	no.add_child(jato)
	var fora := _linha_agua(230.0, Color(0.6, 0.85, 1.0, 0.35))
	var meio := _linha_agua(120.0, Color(0.75, 0.92, 1.0, 0.75))
	var miolo := _linha_agua(46.0, Color(1, 1, 1, 0.9))
	for l in [fora, meio, miolo]:
		jato.add_child(l)
	var gotas := _spray(Vector2.LEFT, 260.0, 0.9)
	gotas.position = bico
	no.add_child(gotas)
	var pingo := _spray(Vector2.DOWN, 60.0, 0.6)          # o bico pinga antes de disparar
	pingo.position = bico
	pingo.amount = 6
	no.add_child(pingo)
	var respingo := _spray(Vector2.UP, 900.0, 0.7)
	respingo.spread = 70.0
	respingo.amount = 22 if Game.leve else 60
	respingo.gravity = Vector2(0, 2400)
	no.add_child(respingo)
	var nevoa := _spray(Vector2.UP, 160.0, 1.4)
	nevoa.amount = 8 if Game.leve else 20
	nevoa.scale_amount_min = 6.0
	nevoa.scale_amount_max = 11.0
	nevoa.gravity = Vector2(0, -60)
	no.add_child(nevoa)
	_canhoes.append({"no": no, "jato": jato, "linhas": [fora, meio, miolo], "gotas": gotas, "pingo": pingo,
		"respingo": respingo, "nevoa": nevoa, "giro": giro, "bico": bico, "periodo": periodo, "liga": liga,
		"t": -atraso, "base": base, "abre": 0.0, "pts": PackedVector2Array()})

func _linha_agua(larg: float, cor: Color) -> Line2D:
	var l := Line2D.new()
	l.width = larg
	l.default_color = cor
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(0.5, 0.85))
	c.add_point(Vector2(1.0, 1.0))
	l.width_curve = c
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	return l

func _spray(dir: Vector2, vel: float, vida: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = fase.pecas._brilho
	p.amount = 18 if Game.leve else 50
	p.lifetime = vida
	p.direction = dir
	p.spread = 20.0
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel * 1.4
	p.gravity = Vector2(0, 1600)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.97, 1.0, 0.9))
	g.set_color(1, Color(0.6, 0.85, 1.0, 0.0))
	p.color_ramp = g
	p.emitting = false
	p.z_index = 15
	return p

## caminho do jato: sai do bico, sobe um pouco e cai no chão lá atrás (só o pedaço já aberto)
func _caminho_jato(c: Dictionary, abre: float) -> PackedVector2Array:
	var de: Vector2 = c["bico"]
	var ate := Vector2(JATO_ALCANCE.x, -30.0)
	var pts := PackedVector2Array()
	var n := 16
	for k in n + 1:
		var u := float(k) / n * abre
		var p := de.lerp(ate, u) + Vector2(0, -120.0 * sin(PI * u))
		p.y += sin(_t * 23.0 + u * 9.0) * 14.0 * u                 # treme
		pts.append(p)
	return pts

func _passo_canhao(c: Dictionary, dt: float, delta: float) -> void:
	c["t"] += dt
	var periodo: float = c["periodo"]
	var fase_t: float = fposmod(c["t"], periodo)
	var ligado: bool = fase_t < float(c["liga"])
	var avisa: bool = fase_t > periodo - 0.7
	var longe := absf((c["base"] as Vector2).x - _foco().x) > 7000.0
	(c["giro"] as Sprite2D).modulate = Color(1, 0.15, 0.15) if fmod(_t, 0.4) < 0.2 else Color(0.2, 0.4, 1)
	c["abre"] = move_toward(c["abre"], 1.0 if ligado else 0.0, dt * (4.0 if ligado else 6.0))
	var abre: float = c["abre"]
	(c["pingo"] as CPUParticles2D).emitting = avisa and not longe
	(c["gotas"] as CPUParticles2D).emitting = abre > 0.1 and not longe
	var jato: Node2D = c["jato"]
	jato.visible = abre > 0.01
	var no: Node2D = c["no"]
	var fim := Vector2(JATO_ALCANCE.x, -30.0)
	(c["respingo"] as CPUParticles2D).position = fim
	(c["nevoa"] as CPUParticles2D).position = fim
	(c["respingo"] as CPUParticles2D).emitting = abre > 0.95 and not longe
	(c["nevoa"] as CPUParticles2D).emitting = abre > 0.95 and not longe
	if abre <= 0.01:
		return
	var pts := _caminho_jato(c, abre)
	for l in c["linhas"]:
		(l as Line2D).points = pts
	if not ligado and abre < 0.5:
		return
	var pl := _player()
	if pl == null:
		return
	var empurrou := false
	for parte in _partes(pl):
		var rb := parte[1] as RigidBody2D
		var pos: Vector2 = (parte[1] as Node2D).global_position
		var perto := false
		for k in pts.size() - 1:
			var a := no.to_global(pts[k])
			var b := no.to_global(pts[k + 1])
			if pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, a, b)) < 200.0:
				perto = true
				break
		if not perto:
			continue
		empurrou = true
		if rb and rb.linear_velocity.x > -450.0:          # segura você, mas não te lança pra trás a mil
			rb.linear_velocity += Vector2(-4300.0, -400.0) * delta
	if empurrou and "secoes" in OS.get_cmdline_user_args() and fmod(_t, 0.5) < dt:
		print("[JATO] empurrando x=%.0f" % pl.foco().global_position.x)
	if empurrou and pl.montado and is_instance_valid(pl.chassi):
		if pl.chassi.linear_velocity.x > -450.0:
			pl.chassi.linear_velocity += Vector2(-4300.0, -400.0) * delta
			for rd in pl.rodas:
				(rd as RigidBody2D).linear_velocity += Vector2(-4300.0, -400.0) * delta
		if fmod(_t, 0.12) < dt:
			fase.pecas.particulas(pl.foco().global_position, 10, Color(0.85, 0.95, 1, 0.95), Color(0.7, 0.9, 1, 0), 300.0, 1100.0, 0.5, 25.0, 60.0, 1400.0, Vector2.LEFT, 70.0)

# ---------- MOLOTOV ----------
## trecho onde a multidão joga garrafas
func zona_molotov(x0: float, x1: float, chao: float, intervalo := 1.3) -> void:
	_molotov_zonas.append({"x0": x0, "x1": x1, "chao": chao, "t": 0.0, "int": intervalo})

func _passo_zona(z: Dictionary, dt: float) -> void:
	var px := _foco().x
	if px < z["x0"] - 1500.0 or px > z["x1"]:
		return
	z["t"] -= dt
	if z["t"] > 0.0:
		return
	z["t"] = z["int"] * _sorteio.randf_range(0.8, 1.2)
	var pl := _player()
	var vx: float = pl.chassi.linear_velocity.x if pl and is_instance_valid(pl.chassi) else 0.0
	var alvo_x := clampf(px + vx * _sorteio.randf_range(0.9, 1.6) / Engine.time_scale * 3.0 + _sorteio.randf_range(-300, 600), z["x0"], z["x1"])
	_garrafa(Vector2(alvo_x, z["chao"]))

func _garrafa(alvo: Vector2) -> void:
	var marca := Polygon2D.new()
	var c := PackedVector2Array()
	for k in 24:
		c.append(Vector2.from_angle(TAU * k / 24) * Vector2(190, 40))
	marca.polygon = c
	marca.color = Color(1, 0.15, 0.1, 0.0)
	marca.position = alvo + Vector2(0, -6)
	marca.z_index = 4
	fase.add_child(marca)
	var g := Node2D.new()
	g.z_index = 15
	var vidro := Polygon2D.new()
	vidro.polygon = PackedVector2Array([Vector2(-22, -40), Vector2(22, -40), Vector2(26, 40), Vector2(-26, 40)])
	vidro.color = Color(0.3, 0.55, 0.25, 0.9)
	g.add_child(vidro)
	var pano := Polygon2D.new()
	pano.polygon = PackedVector2Array([Vector2(-10, -40), Vector2(10, -40), Vector2(0, -90)])
	pano.color = Color(1, 0.6, 0.2)
	g.add_child(pano)
	fase.add_child(g)
	var de := alvo + Vector2(_sorteio.randf_range(-1800, -900), -2600)
	g.global_position = de
	_garrafas.append({"no": g, "marca": marca, "de": de, "alvo": alvo, "t": 0.0, "dura": 1.1})

func _passo_garrafa(g: Dictionary, dt: float) -> void:
	g["t"] += dt
	var u := clampf(g["t"] / g["dura"], 0.0, 1.0)
	var no: Node2D = g["no"]
	var de: Vector2 = g["de"]
	var alvo: Vector2 = g["alvo"]
	no.global_position = de.lerp(alvo, u) + Vector2(0, -1400.0 * sin(PI * u) * (1.0 - u * 0.3))
	no.rotation += dt * 12.0
	(g["marca"] as Polygon2D).color.a = 0.25 + 0.45 * absf(sin(g["t"] * 14.0))
	if u < 1.0:
		return
	no.queue_free()
	(g["marca"] as Node).queue_free()
	_garrafas.erase(g)
	Audio.tocar("caixa", 1.0, 0.2)
	Audio.tocar("impacto_leve", 0.8)
	fase.pecas.particulas(alvo + Vector2(0, -40), 20, Color(1, 0.8, 0.3, 1), Color(1, 0.3, 0.1, 0), 300.0, 900.0, 0.6, 30.0, 80.0, 900.0, Vector2.UP, 70.0)
	_fogo_chao(alvo, 2.2)

func _fogo_chao(onde: Vector2, dura: float) -> void:
	var fogo := CPUParticles2D.new()
	fogo.position = onde + Vector2(0, -30)
	fogo.amount = 10 if Game.leve else 30
	fogo.lifetime = 0.7
	fogo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fogo.emission_rect_extents = Vector2(170, 10)
	fogo.direction = Vector2.UP
	fogo.spread = 15.0
	fogo.gravity = Vector2(0, -500)
	fogo.initial_velocity_min = 150.0
	fogo.initial_velocity_max = 380.0
	fogo.texture = fase.pecas._brilho
	fogo.scale_amount_min = 1.8
	fogo.scale_amount_max = 3.6
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gr.colors = PackedColorArray([Color(1, 0.9, 0.4, 0.95), Color(1, 0.4, 0.1, 0.8), Color(0.2, 0.1, 0.1, 0.0)])
	fogo.color_ramp = gr
	fogo.z_index = 3
	fase.add_child(fogo)
	_fogos.append({"no": fogo, "onde": onde, "t": dura})

func _passo_fogo(f: Dictionary, dt: float) -> void:
	f["t"] -= dt
	if f["t"] <= 0.0:
		(f["no"] as CPUParticles2D).emitting = false
		var no: Node = f["no"]
		get_tree().create_timer(1.0).timeout.connect(no.queue_free)
		_fogos.erase(f)
		return
	var pl := _player()
	if pl == null or not fase.ativo:
		return
	var onde: Vector2 = f["onde"]
	for parte in _partes(pl):
		var pos: Vector2 = (parte[1] as Node2D).global_position
		if absf(pos.x - onde.x) < 170.0 and pos.y > onde.y - 160.0 and pos.y < onde.y + 40.0:
			fase._on_perigo(parte[1], "fogo")
			return

# ---------- passo ----------
func atualizar(delta: float) -> void:
	var dt := _real(delta)
	_t += dt
	for a in _arpoadores:
		_passo_arpoador(a, dt)
	for p in _arpoes.duplicate():
		_passo_arpao(p, delta)
	for c in _canhoes:
		_passo_canhao(c, dt, delta)
	for z in _molotov_zonas:
		_passo_zona(z, dt)
	for g in _garrafas.duplicate():
		_passo_garrafa(g, dt)
	for f in _fogos.duplicate():
		_passo_fogo(f, dt)
