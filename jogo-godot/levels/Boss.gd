extends Node2D
class_name Boss
## Chefão gigante no fundo da fase 5. Montado em partes (tronco, cabeça, duas mãos)
## com braços desenhados (manga azul com listras) ligando ombro e mão. Acompanha o
## jogador pelo cenário e ataca com as mãos:
##  - tapa: a mão sobe, sombra vermelha no chão mostra onde cai, e esmaga;
##  - agarrão: a mão desce na diagonal até onde você vai estar; pegou, arremessa;
##  - entulho: soca o chão lá na frente e caem pedregulhos com sombra.
## Toda a temporização é em segundos REAIS (o jogo roda acelerado).
## Vida: 5. Os botões vermelhos da pista dão choque nele. Zerou, ele desaba.

signal derrotado

const ESC := 2.6                         # tamanho do chefe (imagem 1672x941 -> ~4350 px)
const VIDA_MAX := 5
var fase: Node2D                         # Main
var vida := VIDA_MAX
var morto := false
var chao := 1000.0

var tronco: Sprite2D
var cabeca: Sprite2D
var maos: Array = []                     # [{no, braco, ombro, repouso, estado, t, alvo, de, hit}]
var _t := 0.0
var _prox_ataque := 3.0
var _sombra: Polygon2D
var _pedras: Array = []
var _barra: ColorRect
var _barra_fundo: ColorRect
var _rotulo: Label
var _tremor := 0.0
var _dano_t := 0.0

func _real(delta: float) -> float:
	return delta / Engine.time_scale

func montar(main: Node2D, y_chao: float) -> void:
	fase = main
	chao = y_chao
	z_index = -5
	var p: Dictionary = JSON.parse_string(FileAccess.open("res://assets/boss/partes.json", FileAccess.READ).get_as_text())
	var centro := Vector2(836, 470)
	tronco = _parte("corpo", p, centro)
	cabeca = _parte("cabeca", p, centro)
	cabeca.offset = Vector2(0, -100)                 # gira pelo pescoço
	cabeca.position += Vector2(0, 100) * ESC
	var ombros := [Vector2(590, 345), Vector2(1150, 360)]
	var pulsos := [Vector2(590, 560), Vector2(1020, 760)]
	for i in 2:
		var nome := "mao_e" if i == 0 else "mao_d"
		var bb: Array = p[nome]
		var s := Sprite2D.new()
		s.texture = load("res://assets/boss/%s.png" % nome)
		s.scale = Vector2.ONE * ESC
		var c := Vector2((float(bb[0]) + float(bb[2])) / 2.0, (float(bb[1]) + float(bb[3])) / 2.0)
		s.offset = c - pulsos[i]                     # a mão gira e se posiciona pelo pulso
		var braco := Line2D.new()
		braco.width = 260.0
		braco.default_color = Color(0.13, 0.22, 0.62)
		braco.begin_cap_mode = Line2D.LINE_CAP_ROUND
		braco.end_cap_mode = Line2D.LINE_CAP_ROUND
		var listra := Line2D.new()
		listra.width = 26.0
		listra.default_color = Color(0.95, 0.95, 0.95)
		var contorno := Line2D.new()
		contorno.width = 300.0
		contorno.default_color = Color(0.03, 0.05, 0.15)
		contorno.begin_cap_mode = Line2D.LINE_CAP_ROUND
		contorno.end_cap_mode = Line2D.LINE_CAP_ROUND
		for l in [contorno, braco, listra]:
			l.z_index = -4
			fase.add_child(l)
		s.z_index = -3
		fase.add_child(s)
		var hit := Area2D.new()
		hit.collision_layer = 0
		hit.collision_mask = 0b110
		hit.monitoring = false
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 520.0
		cs.shape = circ
		cs.position = (c - pulsos[i]) * ESC
		hit.add_child(cs)
		s.add_child(hit)
		var m := {"no": s, "braco": braco, "listra": listra, "contorno": contorno, "ombro": (ombros[i] - centro) * ESC,
			"repouso": (pulsos[i] - centro) * ESC, "estado": "repouso", "t": 0.0, "alvo": Vector2.ZERO,
			"de": Vector2.ZERO, "hit": hit, "i": i}
		hit.body_entered.connect(_acertou.bind(m))
		maos.append(m)
		s.global_position = global_position + m["repouso"]
	_sombra = Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 24:
		pts.append(Vector2(700, 0).rotated(TAU * k / 24.0) * Vector2(1, 0.18))
	_sombra.polygon = pts
	_sombra.color = Color(1, 0.1, 0.1, 0.0)
	_sombra.z_index = 4
	fase.add_child(_sombra)
	_hud.call_deferred()

func _parte(nome: String, p: Dictionary, centro: Vector2) -> Sprite2D:
	var bb: Array = p[nome]
	var s := Sprite2D.new()
	s.texture = load("res://assets/boss/%s.png" % nome)
	s.scale = Vector2.ONE * ESC
	s.position = (Vector2((float(bb[0]) + float(bb[2])) / 2.0, (float(bb[1]) + float(bb[3])) / 2.0) - centro) * ESC
	add_child(s)
	return s

func _hud() -> void:
	var hud: CanvasLayer = fase.get_node("HUD")
	_barra_fundo = ColorRect.new()
	_barra_fundo.color = Color(0, 0, 0, 0.7)
	_barra_fundo.size = Vector2(620, 40)
	hud.add_child(_barra_fundo)
	_barra = ColorRect.new()
	_barra.color = Color(0.9, 0.15, 0.15)
	_barra.size = Vector2(600, 24)
	hud.add_child(_barra)
	_rotulo = Label.new()
	_rotulo.text = "CHEFÃO"
	_rotulo.add_theme_font_size_override("font_size", 30)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	hud.add_child(_rotulo)
	_posicionar_barra()

func _posicionar_barra() -> void:
	if _barra == null:
		return
	var v := get_viewport().get_visible_rect().size
	_barra_fundo.position = Vector2(v.x / 2.0 - 310, 112)
	_barra.position = _barra_fundo.position + Vector2(10, 8)
	_barra.size.x = 600.0 * float(vida) / VIDA_MAX
	_rotulo.position = _barra_fundo.position + Vector2(0, -38)

# ---------- passo ----------
func atualizar(delta: float) -> void:
	var dt := _real(delta)
	_t += dt
	var pl: Player = fase.player
	if not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	var foco := pl.foco().global_position
	var vel := pl.chassi.linear_velocity if pl.montado else Vector2.ZERO
	# acompanha o jogador pelo fundo (um pouco à frente), balançando o corpo
	var alvo_x: float = fase.camera.global_position.x + 1300.0      # centro da tela (a câmera olha à frente)
	global_position.x = lerpf(global_position.x, alvo_x, clampf(dt * 9.0, 0.0, 1.0))
	global_position.y = chao - 690.0 + sin(_t * 1.6) * 40.0 + (900.0 if morto else 0.0) * minf(1.0, _dano_t)
	rotation = sin(_t * 0.9) * 0.02
	cabeca.rotation = sin(_t * 1.3) * 0.06 + (sin(_t * 40.0) * 0.12 if _dano_t > 0.0 and not morto else 0.0)
	_dano_t = maxf(0.0, _dano_t - dt) if not morto else _dano_t + dt
	modulate = Color(1, 0.4, 0.4) if (_dano_t > 0.0 and not morto and fmod(_t, 0.12) < 0.06) else Color.WHITE
	if _tremor > 0.0:
		_tremor -= dt
		fase.camera.offset = Vector2(800, -150) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 120.0 * (_tremor / 0.4)
	else:
		fase.camera.offset = Vector2(800, -150)
	for m in maos:
		_mover_mao(m, dt, foco, vel)
	_pedras_passo(dt)
	if morto or not fase.ativo:
		return
	_prox_ataque -= dt
	if _prox_ataque <= 0.0:
		_atacar(foco, vel)

func _intervalo() -> float:
	return maxf(0.9, 2.6 - 0.35 * float(VIDA_MAX - vida))       # fica mais agressivo a cada choque

func _livre() -> Array:
	return maos.filter(func(m): return m["estado"] == "repouso")

func _atacar(foco: Vector2, vel: Vector2) -> void:
	var livres := _livre()
	if livres.is_empty():
		_prox_ataque = 0.3
		return
	var golpes := ["tapa", "tapa", "agarrao", "entulho"]
	if vida <= 3:
		golpes += ["tapa", "agarrao"]
	var g: String = golpes[randi() % golpes.size()]
	var m: Dictionary = livres[randi() % livres.size()]
	match g:
		"tapa":
			_iniciar(m, "tapa_sobe", foco + Vector2(vel.x * 1.0 * Engine.time_scale * 0.9, 0))
		"agarrao":
			_iniciar(m, "agarra_mira", foco + Vector2(vel.x * 1.0 * Engine.time_scale * 1.2, 0))
		"entulho":
			_iniciar(m, "soco_sobe", foco + Vector2(5200, 0))
	_prox_ataque = _intervalo()
	if vida <= 2 and livres.size() == 2 and randf() < 0.5:     # combo: as duas mãos
		var outra: Dictionary = livres[1] if livres[0] == m else livres[0]
		_iniciar(outra, "tapa_sobe", foco + Vector2(vel.x * Engine.time_scale * 1.6, 0))

func _iniciar(m: Dictionary, estado: String, alvo: Vector2) -> void:
	m["golpe"] = estado
	m["estado"] = estado
	m["t"] = 0.0
	m["alvo"] = Vector2(alvo.x, chao)
	m["de"] = (m["no"] as Node2D).global_position

func _mover_mao(m: Dictionary, dt: float, foco: Vector2, vel: Vector2) -> void:
	var no: Sprite2D = m["no"]
	var ombro: Vector2 = global_position + (m["ombro"] as Vector2).rotated(rotation)
	var repouso: Vector2 = global_position + (m["repouso"] as Vector2) + Vector2(0, sin(_t * 2.0 + m["i"]) * 60.0)
	m["t"] += dt
	var t: float = m["t"]
	var alvo: Vector2 = m["alvo"]
	var acima := Vector2(alvo.x, chao - 2600.0)
	match m["estado"]:
		"repouso":
			no.global_position = no.global_position.lerp(repouso, clampf(dt * 5.0, 0.0, 1.0))
			no.rotation = lerp_angle(no.rotation, 0.0, dt * 5.0)
			no.z_index = -3
		"tapa_sobe":                    # vai pra cima do alvo (segue o jogador um pouco)
			m["alvo"].x = lerpf(alvo.x, foco.x + vel.x * Engine.time_scale * 0.8, dt * 2.0)
			no.global_position = (m["de"] as Vector2).lerp(acima, smoothstep(0.0, 1.0, t / 0.55))
			no.z_index = 6
			_mostrar_sombra(alvo.x, t / 0.55 * 0.5)
			if t >= 0.55:
				m["estado"] = "tapa_aviso"
				m["t"] = 0.0
		"tapa_aviso":                   # trava o alvo e treme: hora de desviar
			no.global_position = acima + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			_mostrar_sombra(alvo.x, 0.5 + 0.5 * absf(sin(t * 14.0)))
			if t >= 0.65:
				m["estado"] = "tapa_cai"
				m["t"] = 0.0
		"tapa_cai":
			no.global_position = acima.lerp(Vector2(alvo.x, chao - 420.0), minf(1.0, t / 0.11))
			(m["hit"] as Area2D).monitoring = true
			if t >= 0.11:
				_impacto(Vector2(alvo.x, chao), 1.0)
				m["estado"] = "segura"
				m["t"] = 0.0
		"segura":
			if t >= 0.15:
				(m["hit"] as Area2D).monitoring = false
			_mostrar_sombra(0.0, 0.0)
			if t >= 0.7:
				m["estado"] = "volta"
				m["t"] = 0.0
				m["de"] = no.global_position
		"agarra_mira":                  # sobe e mira na diagonal, mão aberta piscando
			var mira := Vector2(alvo.x + 2600.0, chao - 2000.0)
			no.global_position = (m["de"] as Vector2).lerp(mira, smoothstep(0.0, 1.0, minf(1.0, t / 0.5)))
			no.z_index = 6
			no.rotation = lerp_angle(no.rotation, -0.6, dt * 6.0)
			no.modulate = Color(1, 0.6, 0.6) if fmod(t, 0.16) < 0.08 else Color.WHITE
			_mostrar_sombra(alvo.x, 0.4)
			if t >= 0.8:
				no.modulate = Color.WHITE
				m["estado"] = "agarra_vai"
				m["t"] = 0.0
				m["de"] = no.global_position
		"agarra_vai":
			no.global_position = (m["de"] as Vector2).lerp(Vector2(alvo.x, chao - 450.0), minf(1.0, t / 0.3))
			(m["hit"] as Area2D).monitoring = true
			if t >= 0.3:
				_mostrar_sombra(0.0, 0.0)
				m["estado"] = "segura"
				m["t"] = 0.0
				_tremor = 0.15
		"soco_sobe":                    # entulho: soca o chão bem à frente
			no.global_position = (m["de"] as Vector2).lerp(Vector2(alvo.x, chao - 2400.0), smoothstep(0.0, 1.0, minf(1.0, t / 0.45)))
			no.z_index = 6
			if t >= 0.6:
				m["estado"] = "soco_cai"
				m["t"] = 0.0
				m["de"] = no.global_position
		"soco_cai":
			no.global_position = (m["de"] as Vector2).lerp(Vector2(alvo.x, chao - 420.0), minf(1.0, t / 0.12))
			if t >= 0.12:
				_impacto(Vector2(alvo.x, chao), 0.8)
				_chover(foco, vel)
				m["estado"] = "segura"
				m["t"] = 0.0
		"volta":
			no.global_position = (m["de"] as Vector2).lerp(repouso, smoothstep(0.0, 1.0, minf(1.0, t / 0.6)))
			no.rotation = lerp_angle(no.rotation, 0.0, dt * 4.0)
			if t >= 0.6:
				m["estado"] = "repouso"
	# braço: do ombro ao pulso
	var pts := PackedVector2Array([ombro, ombro.lerp(no.global_position, 0.5) + Vector2(0, 120), no.global_position])
	for l in [m["contorno"], m["braco"]]:
		(l as Line2D).points = pts
	var lado := (no.global_position - ombro).orthogonal().normalized() * 70.0
	(m["listra"] as Line2D).points = PackedVector2Array([ombro + lado, ombro.lerp(no.global_position, 0.85) + lado])

func _mostrar_sombra(x: float, forca: float) -> void:
	if forca <= 0.0:
		_sombra.color.a = 0.0
		return
	_sombra.global_position = Vector2(x, chao - 8.0)
	_sombra.color = Color(1, 0.1, 0.1, 0.25 + 0.45 * forca)

func _impacto(onde: Vector2, forca: float) -> void:
	_tremor = 0.4 * forca
	fase.pecas.poeira(onde + Vector2(-500, 0), 2.0)
	fase.pecas.poeira(onde + Vector2(500, 0), 2.0)
	Audio.tocar("impacto_forte", 1.0)
	Audio.tocar("metal", 0.7)
	var pl: Player = fase.player
	if is_instance_valid(pl) and pl.montado and absf(pl.chassi.global_position.x - onde.x) < 2500.0:
		for rb in [pl.chassi] + pl.rodas:                     # tranco no chão: o veículo pula
			(rb as RigidBody2D).linear_velocity.y -= 500.0

func _acertou(b: Node2D, m: Dictionary) -> void:
	if morto or not (b.is_in_group("veiculo") or b.is_in_group("piloto")):
		return
	var pl: Player = fase.player
	if pl.imortal_t > 0.0 and pl.montado:
		return
	(m["hit"] as Area2D).set_deferred("monitoring", false)
	if String(m.get("golpe", "")).begins_with("agarra"):
		_agarrar.call_deferred()
	else:
		fase._on_perigo(b, "esmagado")

## pegou: levanta e arremessa longe pra trás
func _agarrar() -> void:
	var pl: Player = fase.player
	if not is_instance_valid(pl):
		return
	if pl.montado:
		pl.soltar_ragdoll(Vector2.ZERO, false)
	for k in pl.corpos:
		(pl.corpos[k] as RigidBody2D).linear_velocity = Vector2(-2600, -3800)
	Audio.tocar("osso", 1.0)
	fase._fim(false, "agarrado")

func _chover(foco: Vector2, vel: Vector2) -> void:
	for i in 4:
		var x := foco.x + 1500.0 + i * 1400.0 + randf_range(-300, 300) + vel.x * 0.5
		_pedras.append({"x": x, "t": 0.0, "no": null, "sombra": _sombra_pedra(x)})

func _sombra_pedra(x: float) -> Polygon2D:
	var s := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 16:
		pts.append(Vector2(260, 0).rotated(TAU * k / 16.0) * Vector2(1, 0.2))
	s.polygon = pts
	s.color = Color(1, 0.3, 0.1, 0.5)
	s.global_position = Vector2(x, chao - 6.0)
	s.z_index = 4
	fase.add_child(s)
	return s

func _pedras_passo(dt: float) -> void:
	for p in _pedras.duplicate():
		p["t"] += dt
		if p["no"] == null and p["t"] > 0.35:              # depois do aviso, a pedra cai
			var r := RigidBody2D.new()
			r.collision_layer = 0b11000
			r.collision_mask = 0b1011
			r.mass = 4.0
			var cs := CollisionShape2D.new()
			var c := CircleShape2D.new()
			c.radius = 200.0
			cs.shape = c
			r.add_child(cs)
			var formulas := ["π", "Σ", "∫", "√x", "x²", "∞", "a²+b²", "Δ", "÷", "%", "f(x)", "=", "e^x", "sen θ"]
			var cores := [Color(1, 1, 1), Color(1, 0.9, 0.3), Color(0.5, 0.9, 1), Color(1, 0.55, 0.7), Color(0.6, 1, 0.6)]
			var txt := Label.new()
			txt.text = formulas[randi() % formulas.size()]
			txt.add_theme_font_size_override("font_size", 260)
			txt.add_theme_color_override("font_color", cores[randi() % cores.size()])
			txt.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
			txt.add_theme_constant_override("outline_size", 40)
			txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			txt.size = Vector2(700, 380)
			txt.position = Vector2(-350, -190)
			txt.pivot_offset = Vector2(350, 190)
			r.add_child(txt)
			r.angular_velocity = randf_range(-3.0, 3.0)
			r.position = Vector2(p["x"], chao - 3600.0)
			fase.add_child(r)
			r.linear_velocity = Vector2(0, 600)
			p["no"] = r
			r.add_to_group("pedra_boss")
			var a := Area2D.new()
			a.collision_layer = 0
			a.collision_mask = 0b110
			var ca := CollisionShape2D.new()
			var cc := CircleShape2D.new()
			cc.radius = 220.0
			ca.shape = cc
			a.add_child(ca)
			r.add_child(a)
			a.body_entered.connect(func(b: Node2D) -> void:
				if is_instance_valid(r) and r.linear_velocity.y > 400.0 and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
					fase._on_perigo(b, "pedra"))
		if p["t"] > 2.6:
			(p["sombra"] as Node).queue_free()
			_pedras.erase(p)
			if is_instance_valid(p["no"]):
				var no: Node = p["no"]
				fase.get_tree().create_timer(4.0).timeout.connect(func() -> void:
					if is_instance_valid(no): no.queue_free())

# ---------- dano ----------
func levar_choque() -> void:
	if morto:
		return
	vida -= 1
	_dano_t = 0.8
	_posicionar_barra()
	Audio.tocar("impacto_forte", 1.0)
	Audio.tocar("splat", 0.8)
	if fase.sangue:
		fase.sangue.jorrar(cabeca.global_position + Vector2(0, -300), 60, 1800.0)
	if vida <= 0:
		morto = true
		_dano_t = 0.0
		for m in maos:
			m["estado"] = "volta"
			m["t"] = 0.0
			m["de"] = (m["no"] as Node2D).global_position
			(m["hit"] as Area2D).set_deferred("monitoring", false)
		_rotulo.text = "CHEFÃO DERROTADO!"
		_rotulo.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		for k in 5:
			fase.get_tree().create_timer(0.15 * k).timeout.connect(func() -> void:
				if is_instance_valid(self):
					var onde := global_position + Vector2(randf_range(-1500, 1500), randf_range(-1500, 300))
					Audio.tocar("impacto_forte", 1.0)
					fase.pecas.particulas(onde, 45, Color(1, 0.75, 0.2), Color(0.95, 0.2, 0.05, 0.0), 900.0, 2000.0, 0.8, 300.0, 600.0)
					fase.pecas.particulas(onde, 26, Color(0.3, 0.28, 0.27, 0.95), Color(0.55, 0.55, 0.55, 0.0), 250.0, 800.0, 2.6, 500.0, 1000.0, -300.0))
		derrotado.emit()
