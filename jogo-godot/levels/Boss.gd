extends Node2D
class_name Boss
## Chefão gigante no fundo da fase 5. Montado em partes (tronco, cabeça, duas mãos)
## com braços desenhados (manga azul com listras) ligando ombro e mão. Acompanha o
## jogador pelo cenário e ataca com as mãos:
##  - tapa: a mão sobe, sombra vermelha no chão mostra onde cai, e esmaga;
##  - agarrão: a mão desce na diagonal até onde você vai estar; pegou, arremessa;
##  - entulho: soca o chão lá na frente e caem pedregulhos com sombra.
## Toda a temporização é em segundos REAIS (o jogo roda acelerado).
## Vida: 5. Os botões vermelhos da pista dão choque nele. Zerou a primeira vez, o
## Péce se transforma no Cepé (negativo), mais rápido, com vida cheia. Zerou de novo, desaba.

signal derrotado

const ESC := 2.6                         # tamanho do chefe (imagem 1672x941 -> ~4350 px)
const VIDA_MAX := 5
const ALCANCE := 650.0                   # raio da marca vermelha no chão = área que mata
var fase: Node2D                         # Main
var vida := VIDA_MAX
var vida_max := VIDA_MAX                 # online: cresce com o número de jogadores
var espelho := false                     # online, não sou quem criou a sala: só repete os ataques que chegam
var _escala := 1.0                       # online: ataques mais seguidos com mais gente
var _extra := 0                          # online: mais números/lasers por vez
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
var segunda := false                     # virou Cepé
var _grito_t := 10.0
var _chuva_t := 4.0
var _musica := false
var _laser_t := 3.0
var _lasers: Array = []

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
		maos.append(m)
		s.global_position = global_position + m["repouso"]
	for m in maos:                                   # uma marca vermelha por mão (ataque duplo mostra as duas)
		var sb := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in 24:
			pts.append(Vector2(ALCANCE, 0).rotated(TAU * k / 24.0) * Vector2(1, 0.18))
		sb.polygon = pts
		sb.color = Color(1, 0.1, 0.1, 0.0)
		sb.z_index = 4
		fase.add_child(sb)
		m["sombra"] = sb
	_sombra = maos[0]["sombra"]
	if Online.ativo:                                     # dificuldade proporcional ao número de jogadores
		var n := clampi(Game.online_n, 1, 4)
		vida_max = VIDA_MAX + 2 * (n - 1)
		vida = vida_max
		_escala = [1.0, 0.75, 0.6, 0.5][n - 1]
		_extra = n - 1
		espelho = not Online.host
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
	_rotulo.text = "PÉCE"
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
	_barra.size.x = 600.0 * float(vida) / vida_max
	_rotulo.position = _barra_fundo.position + Vector2(0, -38)

# ---------- passo ----------
func atualizar(delta: float) -> void:
	var dt := _real(delta)
	_t += dt
	if not _musica:
		_musica = true
		Audio.musica_chefe("pece")
	var pl: Player = fase.player
	if not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	var foco := pl.foco().global_position
	var vel := pl.chassi.linear_velocity if pl.montado else Vector2.ZERO
	var meu_foco := foco
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
	_lasers_passo(dt)
	if morto or (not fase.ativo and not Online.ativo):
		return
	_grito_t -= dt
	if _grito_t <= 0.0:
		_grito_t = 10.0
		Audio.tocar("pece_grito", 1.0, 0.0)
		Audio.abaixar_chefe(2.3)
	if espelho:                                             # online: os ataques vêm de quem criou a sala
		return
	if Online.ativo:                                        # mira num jogador sorteado (vivo)
		var alvo: Array = fase.alvo_online()
		if alvo.is_empty():
			return
		foco = alvo[0]
		vel = alvo[1]
	_chuva_t -= dt
	if _chuva_t <= 0.0:                                     # vai derrubando números e sinais
		_chuva_t = randf_range(2.5, 3.5) if segunda else randf_range(3.5, 5.0)
		_chuva_t *= _escala
		for i in (3 if segunda else 2) + _extra:
			if Online.ativo and i > 0:                          # online: espalha entre os jogadores
				var a2: Array = fase.alvo_online()
				if not a2.is_empty():
					foco = a2[0]
					vel = a2[1]
			var x := foco.x + vel.x * 0.4 + randf_range(900.0, 4200.0) * (1.0 if randf() < 0.75 else -0.5)
			soltar_pedra(x)
	if segunda:
		_laser_t -= dt
		if _laser_t <= 0.0:
			_laser_t = (randf_range(2.0, 3.0) if vida > 2 else randf_range(1.4, 2.2)) * _escala
			_laser(foco.x + vel.x * Engine.time_scale * 0.7)
			if (vida <= 2 or _extra > 0) and randf() < 0.5:      # no fim, dois de uma vez
				_laser(foco.x + randf_range(1800.0, 3000.0) * (1.0 if randf() < 0.5 else -1.0))
			for k in _extra - 1:                                # online com 3+: mais um laser em alguém
				var a3: Array = fase.alvo_online()
				if not a3.is_empty():
					_laser((a3[0] as Vector2).x + (a3[1] as Vector2).x * Engine.time_scale * 0.7)
	_prox_ataque -= dt
	if _prox_ataque <= 0.0:
		_atacar(foco, vel)

func _intervalo() -> float:
	var nivel := float(vida_max - vida) * 5.0 / float(vida_max)
	if segunda:
		return maxf(0.7, 1.9 - 0.25 * nivel) * _escala
	return maxf(0.9, 2.6 - 0.35 * nivel) * _escala       # fica mais agressivo a cada choque

func _livre() -> Array:
	return maos.filter(func(m): return m["estado"] == "repouso")

func _atacar(foco: Vector2, vel: Vector2) -> void:
	var livres := _livre()
	if livres.is_empty():
		_prox_ataque = 0.3
		return
	var golpes := ["tapa", "tapa", "agarrao", "entulho"]
	if vida <= 3 or segunda:
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
	if (vida <= 2 or segunda or _extra > 0) and livres.size() == 2 and randf() < (0.5 + 0.15 * _extra):     # combo: as duas mãos
		var outra: Dictionary = livres[1] if livres[0] == m else livres[0]
		if Online.ativo:                                         # online: a outra mão vai em outro jogador
			var a4: Array = fase.alvo_online()
			if not a4.is_empty():
				foco = a4[0]
				vel = a4[1]
		_iniciar(outra, "tapa_sobe", foco + Vector2(vel.x * Engine.time_scale * 1.6, 0))

func _iniciar(m: Dictionary, estado: String, alvo: Vector2, remoto := false) -> void:
	if Online.ativo and Online.host and not remoto:
		Online.enviar("atk", {"i": m["i"], "s": estado, "x": alvo.x})
	m["golpe"] = estado
	m["estado"] = estado
	m["t"] = 0.0
	m["alvo"] = Vector2(alvo.x, chao)
	m["de"] = (m["no"] as Node2D).global_position

func _mover_mao(m: Dictionary, dt: float, foco: Vector2, vel: Vector2) -> void:
	_sombra = m["sombra"]
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
			if not Online.ativo:                                  # online: alvo fixo (igual em todas as telas)
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
			if t >= 0.11:
				_impacto(Vector2(alvo.x, chao), 1.0)
				_golpe(m)
				m["estado"] = "segura"
				m["t"] = 0.0
		"segura":
			if t < 0.15 and not String(m.get("golpe", "")).begins_with("soco"):
				_golpe(m)                   # mão no chão: quem entrar no vermelho ainda é pego
				_mostrar_sombra(alvo.x, 1.0)    # marca fica acesa enquanto ainda mata
			else:
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
			if t >= 0.3:
				_golpe(m)
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
				if not espelho:
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

## mão chegou no chão: pega quem estiver dentro da marca vermelha (e só quem estiver nela)
func _golpe(m: Dictionary) -> void:
	if morto or not fase.ativo or m["estado"] == "volta":
		return
	var pl: Player = fase.player
	if not is_instance_valid(pl) or (pl.imortal_t > 0.0 and pl.montado):
		return
	var ax: float = (m["alvo"] as Vector2).x
	var corpos: Array = ([pl.chassi] + pl.rodas) if pl.montado and is_instance_valid(pl.chassi) else pl.corpos.values()
	for b in corpos:
		var p: Vector2 = (b as Node2D).global_position
		if absf(p.x - ax) < ALCANCE and p.y > chao - 1300.0:
			_acertou(b, m)
			return

func _acertou(b: Node2D, m: Dictionary) -> void:
	if morto or not (b.is_in_group("veiculo") or b.is_in_group("piloto")):
		return
	var pl: Player = fase.player
	if pl.imortal_t > 0.0 and pl.montado:
		return
	# só pega quem está dentro da área vermelha (a mão desenhada é maior que o golpe)
	if absf(b.global_position.x - (m["alvo"] as Vector2).x) > ALCANCE:
		return
	(m["hit"] as Area2D).set_deferred("monitoring", false)
	if pl.repelir(b.global_position):                  # Chefe sem camisa: a mão volta rebatida
		m["estado"] = "volta"
		m["t"] = 0.0
		m["de"] = (m["no"] as Node2D).global_position + Vector2(0, -900)
		return
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

## número/sinal caindo em x (online: quem criou a sala manda pros outros)
func soltar_pedra(x: float, remoto := false) -> void:
	if Online.ativo and Online.host and not remoto:
		Online.enviar("pd", {"x": x})
	_pedras.append({"x": x, "t": 0.0, "no": null, "sombra": _sombra_pedra(x)})

func _chover(foco: Vector2, vel: Vector2) -> void:
	for i in 4:
		var x := foco.x + 1500.0 + i * 1400.0 + randf_range(-300, 300) + vel.x * 0.5
		soltar_pedra(x)

## aviso de onde cai número: coluna de luz amarela do céu até o chão, alvo
## pulsando no chão e seta "!" em cima. Bem visível mesmo no meio da confusão
func _sombra_pedra(x: float) -> Node2D:
	var n := Node2D.new()
	n.global_position = Vector2(x, chao - 6.0)
	n.z_index = 4
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.1, 0.0))
	g.set_color(1, Color(1, 0.75, 0.1, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var coluna := TextureRect.new()
	coluna.texture = gt
	coluna.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coluna.stretch_mode = TextureRect.STRETCH_SCALE
	coluna.size = Vector2(420, 3400)
	coluna.position = Vector2(-210, -3400)
	n.add_child(coluna)
	var anel := PackedVector2Array()
	for k in 28:
		anel.append(Vector2(300, 0).rotated(TAU * k / 28.0) * Vector2(1, 0.22))
	var alvo := Polygon2D.new()
	alvo.polygon = anel
	alvo.color = Color(1, 0.15, 0.05, 0.75)
	n.add_child(alvo)
	var borda := Line2D.new()
	borda.points = anel + PackedVector2Array([anel[0]])
	borda.width = 22.0
	borda.default_color = Color(1, 0.95, 0.3)
	n.add_child(borda)
	var seta := Label.new()
	seta.text = "!"
	seta.add_theme_font_size_override("font_size", 300)
	seta.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	seta.add_theme_color_override("font_outline_color", Color(0.6, 0.05, 0.0))
	seta.add_theme_constant_override("outline_size", 50)
	seta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seta.size = Vector2(400, 360)
	seta.position = Vector2(-200, -760)
	n.add_child(seta)
	fase.add_child(n)
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate:a", 0.45, 0.12 * Engine.time_scale)
	tw.tween_property(n, "modulate:a", 1.0, 0.12 * Engine.time_scale)
	return n

## números e sinais: caem sem física (não ficam rolando no caminho). Só matam
## enquanto estão caindo; ao bater no chão quicam um pouco e somem
func _pedras_passo(dt: float) -> void:
	for p in _pedras.duplicate():
		p["t"] += dt
		if p["no"] == null and p["t"] > 0.35:              # depois do aviso, começa a cair
			var r := Node2D.new()
			var formulas := ["π", "÷", "+", "−", "×", "=", "√", "%", "∞", "Σ", "x²", "3,14", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "½", "≠"]
			var cores := [Color(1, 1, 1), Color(1, 0.9, 0.3), Color(0.5, 0.9, 1), Color(1, 0.55, 0.7), Color(0.6, 1, 0.6)]
			var txt := Label.new()
			txt.text = formulas[randi() % formulas.size()]
			txt.add_theme_font_override("font", load("res://assets/fonts/simbolos.ttf"))
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
			r.position = Vector2(p["x"], chao - 3600.0)
			r.z_index = 5
			fase.add_child(r)
			r.add_to_group("pedra_boss")
			p["no"] = r
			p["vy"] = 1800.0                                   # mesma queda de antes (física: 600 px/s e g 980, jogo 3x)
			p["giro"] = randf_range(-3.0, 3.0)
			p["caindo"] = true
		var no: Node2D = p["no"]
		if no == null or not is_instance_valid(no):
			if p["t"] > 3.0:
				(p["sombra"] as Node).queue_free()
				_pedras.erase(p)
			continue
		if p["caindo"]:
			p["vy"] += 8820.0 * dt                              # gravidade (segundos reais)
			no.position.y += float(p["vy"]) * dt
			no.rotation += float(p["giro"]) * dt
			if _pedra_acerta(no.global_position):         # rebatido: sai voando pra longe
				(p["sombra"] as Node).queue_free()
				_pedras.erase(p)
				var tw := no.create_tween()
				tw.tween_property(no, "position", no.position + Vector2(randf_range(1500, 2500), -2500), 0.5 * Engine.time_scale)
				tw.parallel().tween_property(no, "modulate:a", 0.0, 0.5 * Engine.time_scale)
				tw.tween_callback(no.queue_free)
				continue
			if no.position.y >= chao - 200.0:                   # bateu no chão: quica, para de matar e some
				no.position.y = chao - 200.0
				p["caindo"] = false
				(p["sombra"] as Node).queue_free()
				fase.pecas.poeira(Vector2(no.position.x, chao), 0.8)
				Audio.tocar("impacto_leve", 0.6)
				var tw := no.create_tween()
				tw.tween_property(no, "position:y", chao - 420.0, 0.15).set_ease(Tween.EASE_OUT)
				tw.tween_property(no, "position:y", chao - 200.0, 0.15).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(no, "modulate:a", 0.0, 0.5)
				tw.tween_callback(no.queue_free)
				_pedras.erase(p)

func _pedra_acerta(onde: Vector2) -> bool:
	var pl: Player = fase.player
	if morto or not fase.ativo or not is_instance_valid(pl) or (pl.imortal_t > 0.0 and pl.montado):
		return false
	var corpos: Array = [pl.chassi] + pl.membros.values() if pl.montado and is_instance_valid(pl.chassi) else pl.corpos.values()
	for b in corpos:
		if (b as Node2D).global_position.distance_to(onde) < 260.0:
			if pl.repelir(onde):
				return true
			fase._on_perigo(b, "pedra")
			return false
	return false

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
	if vida <= 0 and not segunda:
		_transformar()
	elif vida <= 0:
		morto = true
		_dano_t = 0.0
		for m in maos:
			m["estado"] = "volta"
			m["t"] = 0.0
			m["de"] = (m["no"] as Node2D).global_position
			(m["hit"] as Area2D).set_deferred("monitoring", false)
		_rotulo.text = "CEPÉ DERROTADO!"
		_rotulo.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		for k in 5:
			fase.get_tree().create_timer(0.15 * k).timeout.connect(func() -> void:
				if is_instance_valid(self):
					var onde := global_position + Vector2(randf_range(-1500, 1500), randf_range(-1500, 300))
					Audio.tocar("impacto_forte", 1.0)
					fase.pecas.particulas(onde, 45, Color(1, 0.75, 0.2), Color(0.95, 0.2, 0.05, 0.0), 900.0, 2000.0, 0.8, 300.0, 600.0)
					fase.pecas.particulas(onde, 26, Color(0.3, 0.28, 0.27, 0.95), Color(0.55, 0.55, 0.55, 0.0), 250.0, 800.0, 2.6, 500.0, 1000.0, -300.0))
		derrotado.emit()

# ---------- transformação: Péce vira Cepé ----------
const NEGATIVO := "shader_type canvas_item;\nvoid fragment() { COLOR.rgb = vec3(1.0) - COLOR.rgb; }"

func _transformar() -> void:
	vida = 0
	_dano_t = 0.0
	for m in maos:
		m["estado"] = "volta"
		m["t"] = 0.0
		m["de"] = (m["no"] as Node2D).global_position
		(m["hit"] as Area2D).set_deferred("monitoring", false)
	for m in maos:
		(m["sombra"] as Polygon2D).color.a = 0.0
	for p in _pedras:
		(p["sombra"] as Node).queue_free()
		if is_instance_valid(p["no"]):
			(p["no"] as Node).queue_free()
	_pedras.clear()
	for n in fase.get_tree().get_nodes_in_group("pedra_boss"):
		n.queue_free()
	Audio.musica_chefe("cepe")
	Audio.tocar("pece_grito", 1.0, 0.0)
	fase.get_tree().paused = true
	var cena := CanvasLayer.new()
	cena.layer = 50
	cena.process_mode = Node.PROCESS_MODE_ALWAYS
	fase.add_child(cena)
	var v := get_viewport().get_visible_rect().size
	var fundo := ColorRect.new()
	fundo.size = v
	fundo.color = Color.WHITE
	cena.add_child(fundo)
	var img := TextureRect.new()
	img.texture = load("res://assets/boss/cepe.png")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size = Vector2(v.x * 0.9, v.y * 0.75)
	img.position = Vector2(v.x * 0.05, v.y * 0.2)
	img.pivot_offset = img.size / 2.0
	img.scale = Vector2.ONE * 0.4
	img.modulate.a = 0.0
	cena.add_child(img)
	var txt := Label.new()
	txt.text = "O PÉCE ESTÁ SE TRANSFORMANDO..."
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.size = Vector2(v.x, 100)
	txt.position = Vector2(0, v.y * 0.04)
	txt.add_theme_font_size_override("font_size", 54)
	txt.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	txt.add_theme_color_override("font_outline_color", Color.BLACK)
	txt.add_theme_constant_override("outline_size", 14)
	cena.add_child(txt)
	var tw := cena.create_tween()
	for k in 6:                                                   # pisca branco/preto
		tw.tween_property(fundo, "color", Color.BLACK, 0.09)
		tw.tween_property(fundo, "color", Color.WHITE, 0.09)
	tw.tween_property(fundo, "color", Color.BLACK, 0.15)
	tw.tween_property(img, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(img, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(f: float) -> void:
		img.position = Vector2(v.x * 0.05, v.y * 0.2) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 30.0 * f, 0.0, 1.0, 2.2)
	tw.tween_callback(func() -> void:
		txt.text = "CEPÉ!"
		txt.add_theme_font_size_override("font_size", 110)
		txt.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
		fundo.color = Color.WHITE
		_virar_cepe())
	tw.tween_property(fundo, "color", Color.BLACK, 0.25)
	tw.tween_interval(1.4)
	tw.tween_method(func(a: float) -> void:
		fundo.modulate.a = a
		img.modulate.a = a
		txt.modulate.a = a, 1.0, 0.0, 0.5)
	tw.tween_callback(func() -> void:
		fase.get_tree().paused = false
		fase._mensagem("O CEPÉ VEIO! CHOQUE NELE DE NOVO!", Color(0.5, 0.95, 1.0))
		cena.queue_free())

func _virar_cepe() -> void:
	segunda = true
	vida = vida_max
	_prox_ataque = 2.5
	_chuva_t = 3.0
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = NEGATIVO
	mat.shader = sh
	tronco.material = mat
	cabeca.material = mat
	for m in maos:
		(m["no"] as Sprite2D).material = mat
		(m["braco"] as Line2D).default_color = Color(0.87, 0.78, 0.38)
		(m["listra"] as Line2D).default_color = Color(0.05, 0.05, 0.05)
		(m["contorno"] as Line2D).default_color = Color(0.6, 0.85, 1.0)
	_rotulo.text = "CEPÉ"
	_rotulo.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	_barra.color = Color(0.3, 0.85, 1.0)
	_posicionar_barra()

# ---------- laser negativo (só o Cepé) ----------
## sai dos olhos em linha reta até o chão onde você vai estar: linha fina piscando é o
## aviso, depois vem o feixe (largura constante, miolo branco e brilho azul) e desintegra
const LASER_AVISO := 0.9
const LASER_FOGO := 0.5
const LASER_LARGURA := 150.0

var _tex_cache: Dictionary = {}
func _brilho_tex() -> Texture2D:                     # bola de luz (olhos e ponto de impacto)
	if not _tex_cache.has("bola"):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.25, Color(0.6, 0.95, 1.0, 0.8))
		g.set_color(g.get_point_count() - 1, Color(0.1, 0.5, 1.0, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_tex_cache["bola"] = t
	return _tex_cache["bola"]

func _feixe_tex() -> Texture2D:                      # corte do feixe: borda some, miolo branco
	if not _tex_cache.has("feixe"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.44, 0.5, 0.56, 0.7, 1.0])
		g.colors = PackedColorArray([Color(0.1, 0.4, 1.0, 0.0), Color(0.2, 0.7, 1.0, 0.55), Color(0.7, 0.97, 1.0, 1.0),
			Color(1, 1, 1, 1), Color(0.7, 0.97, 1.0, 1.0), Color(0.2, 0.7, 1.0, 0.55), Color(0.1, 0.4, 1.0, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 128
		_tex_cache["feixe"] = t
	return _tex_cache["feixe"]

func _aditivo() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _olhos() -> Vector2:
	return cabeca.global_position + Vector2(0, -330).rotated(cabeca.global_rotation)

## aviso: faixa vermelha da largura do feixe na mesma diagonal, bordas marcadas,
## linha do meio e alvo no chão; pisca cada vez mais rápido até disparar
func _laser(x: float, remoto := false) -> void:
	if Online.ativo and Online.host and not remoto:
		Online.enviar("lz", {"x": x})
	var aviso := Node2D.new()
	aviso.z_index = 8
	var faixa := Polygon2D.new()
	faixa.color = Color(1, 0.1, 0.1, 0.38)
	aviso.add_child(faixa)
	for k in 3:                                      # borda, borda, meio
		var l := Line2D.new()
		l.width = 30.0 if k < 2 else 16.0
		l.default_color = Color(1, 0.2, 0.15, 0.95) if k < 2 else Color(1, 0.85, 0.3, 0.9)
		aviso.add_child(l)
	var alvo := Polygon2D.new()
	var anel := PackedVector2Array()
	for k in 24:
		anel.append(Vector2(LASER_LARGURA + 90.0, 0).rotated(TAU * k / 24.0) * Vector2(1, 0.22))
	alvo.polygon = anel
	alvo.color = Color(1, 0.1, 0.1, 0.55)
	aviso.add_child(alvo)
	var sinal := Label.new()
	sinal.text = "!"
	sinal.add_theme_font_size_override("font_size", 420)
	sinal.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	sinal.add_theme_color_override("font_outline_color", Color(0.6, 0.05, 0.0))
	sinal.add_theme_constant_override("outline_size", 44)
	sinal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sinal.size = Vector2(500, 500)
	aviso.add_child(sinal)
	fase.add_child(aviso)
	_lasers.append({"x": x, "t": 0.0, "aviso": aviso, "luz": null})
	Audio.tocar("turbo", 0.5, 0.0)

func _lasers_passo(dt: float) -> void:
	for l in _lasers.duplicate():
		l["t"] += dt
		var t: float = l["t"]
		var de := _olhos()
		var ate := Vector2(float(l["x"]), chao)
		if t < LASER_AVISO:
			var aviso: Node2D = l["aviso"]
			var lado := (ate - de).orthogonal().normalized() * LASER_LARGURA
			(aviso.get_child(0) as Polygon2D).polygon = PackedVector2Array([de + lado, ate + lado, ate - lado, de - lado])
			(aviso.get_child(1) as Line2D).points = PackedVector2Array([de + lado, ate + lado])
			(aviso.get_child(2) as Line2D).points = PackedVector2Array([de - lado, ate - lado])
			(aviso.get_child(3) as Line2D).points = PackedVector2Array([de, ate])
			(aviso.get_child(4) as Node2D).position = ate
			(aviso.get_child(5) as Control).position = ate + Vector2(-250, -820)
			var ritmo := lerpf(0.22, 0.08, t / LASER_AVISO)       # pisca cada vez mais rápido
			aviso.modulate.a = 1.0 if fmod(t, ritmo) < ritmo * 0.6 else 0.35
			continue
		if l["luz"] == null:
			(l["aviso"] as Node).queue_free()
			var luz := Node2D.new()
			luz.z_index = 10
			luz.material = _aditivo()
			fase.add_child(luz)
			var feixe := Line2D.new()
			feixe.texture = _feixe_tex()
			feixe.texture_mode = Line2D.LINE_TEXTURE_STRETCH
			feixe.use_parent_material = true
			luz.add_child(feixe)
			for tam in [7.0, 12.0]:                          # olhos e chão
				var g := Sprite2D.new()
				g.texture = _brilho_tex()
				g.scale = Vector2.ONE * tam
				g.use_parent_material = true
				luz.add_child(g)
			var faisca := CPUParticles2D.new()
			faisca.amount = 60
			faisca.lifetime = 0.5
			faisca.direction = Vector2(0, -1)
			faisca.spread = 75.0
			faisca.initial_velocity_min = 900.0
			faisca.initial_velocity_max = 2400.0
			faisca.gravity = Vector2(0, 4000)
			faisca.scale_amount_min = 10.0
			faisca.scale_amount_max = 22.0
			faisca.color = Color(0.7, 0.97, 1.0)
			faisca.use_parent_material = true
			faisca.position = ate
			luz.add_child(faisca)
			l["luz"] = luz
			fase._clarao(Color(0.6, 0.95, 1.0), 0.3)
			Audio.tocar("metal", 1.0, 0.0)
			Audio.tocar("impacto_forte", 0.7)
			_tremor = 0.25
			fase.pecas.poeira(ate, 1.4)
		var luz: Node2D = l["luz"]
		var f := (t - LASER_AVISO) / LASER_FOGO
		var k := minf(1.0, f / 0.08) * minf(1.0, (1.0 - f) / 0.2)       # acende rápido, apaga no fim
		var tremida := 1.0 + 0.06 * sin(t * 120.0)
		var feixe: Line2D = luz.get_child(0)
		feixe.points = PackedVector2Array([de, ate])
		feixe.width = LASER_LARGURA * 2.6 * k * tremida
		(luz.get_child(1) as Node2D).global_position = de
		(luz.get_child(2) as Node2D).global_position = ate
		(luz.get_child(1) as Node2D).modulate.a = k
		(luz.get_child(2) as Node2D).modulate.a = k
		if k > 0.5:
			_laser_acerta(de, ate)
		if t >= LASER_AVISO + LASER_FOGO:
			luz.queue_free()
			_lasers.erase(l)

func _laser_acerta(de: Vector2, ate: Vector2) -> void:
	var pl: Player = fase.player
	if morto or not fase.ativo or not is_instance_valid(pl) or (pl.imortal_t > 0.0 and pl.montado):
		return
	var corpos: Array = [pl.chassi] if pl.montado and is_instance_valid(pl.chassi) else pl.corpos.values()
	for b in corpos:
		var p: Vector2 = (b as Node2D).global_position
		if absf(p.x - ate.x) < LASER_LARGURA + 90.0 and p.y > ate.y - 1300.0:   # só onde ele bate no chão (o alvo)
			if pl.repelir(p):
				return
			fase._on_perigo(b, "laser")
			return
