extends Node2D
## Nível de teste: chão + rampa, instancia o Player, câmera que segue e HUD tocável.
## Com o argumento "--test" roda uma checagem de física automatizada e sai.

signal venceu(tempo: float)
signal perdeu(motivo: String)

const CHAO_Y := 1000.0
const SPAWN_X := -100.0                   # largada recuada: longe do alcance da bola
const TOPO_POUSO := CHAO_Y + 80.0          # topo dos blocos depois da rampa (fase 1)

var do_inicio := true                       # recorde só vale para a fase inteira (sem checkpoint)
var cp_x := -1.0                            # checkpoint da fase atual (definido por cada fase)
var cp_chao := CHAO_Y

var ativo := true
var tempo := 0.0
var _caiu_em := -1.0
var _pendulos: Array = []                 # bolas de demolição cinemáticas
var _t_fisica := 0.0
var _serras: Array = []
var _hud: Array = []
var painel: HBoxContainer                      # [controle, Callable(tamanho_tela) -> posição]                # [Line2D, âncora, bola] da bola de demolição

var player: Player
var sangue: Sangue
var aviso: Label
var camera: FollowCamera
var dist_label: Label
var recorde := 0
var _mat: PhysicsMaterial

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("p="):
			Game.personagem = a.substr(2)
		if a.begins_with("f="):
			Game.fase = int(a.substr(2))
	RenderingServer.set_default_clear_color(Color(0.33, 0.55, 0.93))
	_construir_fundo()
	_mat = PhysicsMaterial.new()
	_mat.friction = 1.0
	_mat.bounce = 0.0
	_construir_chao()

	player = Player.new()
	player.personagem = Game.personagem
	player.chao_y = CHAO_Y
	player.spawn_x = SPAWN_X
	do_inicio = Game.checkpoint_x <= 0.0
	if Game.checkpoint_x > 0.0:               # renasce no checkpoint depois de morrer
		player.spawn_x = Game.checkpoint_x
		player.chao_y = Game.checkpoint_chao
	add_child(player)
	sangue = Sangue.new()
	add_child(sangue)
	player.sangue = sangue
	player.morreu.connect(_on_morreu)

	camera = FollowCamera.new()
	camera.zoom = Vector2(0.24, 0.24)         # boneco ~1/3 da tela, como no gênero
	camera.offset = Vector2(700, -420)        # olha pra frente e mostra a cabeça
	add_child(camera)
	camera.alvo = player.foco()

	_construir_hud()

	if "sem_hud" in OS.get_cmdline_user_args():      # capturas para miniatura
		$HUD.visible = false
	if "autoteste" in OS.get_cmdline_user_args():
		_rodar_teste()
	elif "screenshot" in OS.get_cmdline_user_args():
		_rodar_screenshots()

func _process(delta: float) -> void:
	for sr in _serras:
		(sr as Node2D).rotation += delta * 9.0
	for p in _pendulos:
		(p["corrente"] as Line2D).points = PackedVector2Array([p["ancora"], (p["bola"] as Node2D).global_position])
	if ativo:
		tempo += delta
		# caiu do veículo: a tentativa acaba 2,5 s depois (dá tempo de rolar até a chegada)
		if is_instance_valid(player) and not player.montado:
			if _caiu_em < 0.0:
				_caiu_em = tempo
			elif tempo - _caiu_em > 2.5:
				_fim(false, "caiu")
	if is_instance_valid(player) and is_instance_valid(player.chassi):
		var f := player.foco()
		if f:
			camera.alvo = f
		var alvo_x: float = player.foco().global_position.x
		recorde = maxi(recorde, int(maxf(0.0, (alvo_x - SPAWN_X) / 40.0)))
		if dist_label:
			dist_label.text = "%d m   %.1f s" % [recorde, tempo]

# ---------- terreno ----------
func _bloco(centro: Vector2, tamanho: Vector2, ang_graus: float, cor := Color(0.42, 0.23, 0.09)) -> void:
	var sb := StaticBody2D.new()
	sb.position = centro
	sb.rotation = deg_to_rad(ang_graus)
	sb.collision_layer = 0b01
	sb.collision_mask = 0
	sb.physics_material_override = _mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tamanho
	cs.shape = r
	sb.add_child(cs)
	var hx := tamanho.x / 2.0
	var hy := tamanho.y / 2.0
	var terra := Polygon2D.new()
	terra.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	terra.color = cor
	sb.add_child(terra)
	var faixa := Polygon2D.new()                # faixa escura de "asfalto" no topo
	faixa.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy + 30), Vector2(-hx, -hy + 30)])
	faixa.color = Color(0.2, 0.18, 0.19)
	sb.add_child(faixa)
	add_child(sb)

## viga de aço (ponte/plataforma) com listras e colunas de apoio até `base_y`
func _viga(centro: Vector2, tamanho: Vector2, base_y: float) -> void:
	var sb := StaticBody2D.new()
	sb.position = centro
	sb.collision_layer = 0b01
	sb.physics_material_override = _mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tamanho
	cs.shape = r
	sb.add_child(cs)
	var hx := tamanho.x / 2.0
	var hy := tamanho.y / 2.0
	for k in 2:                                # colunas (só visual, atrás)
		var col := Polygon2D.new()
		var cx := -hx * 0.6 + k * hx * 1.2
		col.polygon = PackedVector2Array([Vector2(cx - 22, hy), Vector2(cx + 22, hy), Vector2(cx + 22, base_y - centro.y), Vector2(cx - 22, base_y - centro.y)])
		col.color = Color(0.62, 0.64, 0.68)
		col.z_index = -1
		sb.add_child(col)
	var corpo := Polygon2D.new()
	corpo.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	corpo.color = Color(0.24, 0.24, 0.26)
	sb.add_child(corpo)
	for k in 3:                                # listras
		var l := Polygon2D.new()
		var y := -hy + (k + 1) * tamanho.y / 4.0
		l.polygon = PackedVector2Array([Vector2(-hx + 14, y - 3), Vector2(hx - 14, y - 3), Vector2(hx - 14, y + 3), Vector2(-hx + 14, y + 3)])
		l.color = Color(0.12, 0.12, 0.13)
		sb.add_child(l)
	add_child(sb)

## fileira de espetos letais (visual + Area2D que mata)
func _espetos(x0: float, x1: float, chao: float) -> void:
	var vis := Polygon2D.new()
	var pts := PackedVector2Array([Vector2(x0, chao)])
	var x := x0
	while x < x1:
		pts.append(Vector2(x + 24, chao - 190))
		pts.append(Vector2(x + 48, chao))
		x += 48
	vis.polygon = pts
	vis.color = Color(0.78, 0.8, 0.86)
	add_child(vis)
	var a := _area(Vector2((x0 + x1) / 2.0, chao - 95), Vector2(x1 - x0, 190))
	a.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"):
			Audio.tocar("splat")
			_fim(false, "espetos"))

## bola de demolição: pêndulo CINEMÁTICO (AnimatableBody2D) — segue θ(t)=θ0·cos(ωt),
## nunca estica nem perde energia, e empurra corpos com massa "infinita"
func _bola_demolicao(ancora: Vector2, comprimento: float, angulo_ini: float, raio := 560.0) -> void:
	var bola := AnimatableBody2D.new()
	bola.sync_to_physics = false
	bola.collision_layer = 0b11000           # objeto + perigo: empurra e o sensor do piloto sente
	bola.collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = raio
	cs.shape = c
	bola.add_child(cs)
	var circ := PackedVector2Array()
	for k in 48:
		circ.append(Vector2(raio, 0).rotated(TAU * k / 48.0))
	var vis := Polygon2D.new()
	vis.polygon = circ
	vis.color = Color(0.29, 0.25, 0.32)
	bola.add_child(vis)
	var brilho := Polygon2D.new()               # reflexo para dar volume
	var b2 := PackedVector2Array()
	for k in 24:
		b2.append(Vector2(-raio * 0.35, -raio * 0.35) + Vector2(raio * 0.32, 0).rotated(TAU * k / 24.0))
	brilho.polygon = b2
	brilho.color = Color(0.42, 0.37, 0.46)
	bola.add_child(brilho)
	var argola := Polygon2D.new()
	argola.polygon = PackedVector2Array([Vector2(-40, -raio - 70), Vector2(40, -raio - 70), Vector2(40, -raio + 10), Vector2(-40, -raio + 10)])
	argola.color = Color(0.2, 0.2, 0.22)
	bola.add_child(argola)
	add_child(bola)
	bola.add_to_group("pendulo")
	bola.set_meta("ancora", ancora)
	bola.set_meta("alcance", comprimento * sin(angulo_ini))
	bola.set_meta("raio", raio)
	bola.set_meta("vel", Vector2.ZERO)
	var corrente := Line2D.new()
	corrente.width = 26.0
	corrente.default_color = Color(0.12, 0.12, 0.12)
	corrente.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	add_child(corrente)
	var som := _area(Vector2.ZERO, Vector2(raio * 2.1, raio * 2.1))
	remove_child(som)
	som.position = Vector2.ZERO
	bola.add_child(som)
	som.body_entered.connect(func(b: Node2D) -> void:
		if (b.is_in_group("veiculo") or b.is_in_group("piloto")) and (bola.get_meta("vel") as Vector2).length() > 150.0:
			Audio.tocar("metal", 0.9))
	_pendulos.append({"bola": bola, "ancora": ancora, "L": comprimento, "th0": angulo_ini,
		"w": sqrt(980.0 / comprimento), "corrente": corrente})
	_mover_pendulos(0.0)

func _physics_process(delta: float) -> void:
	_t_fisica += delta
	_mover_pendulos(_t_fisica)

func _mover_pendulos(t: float) -> void:
	for p in _pendulos:
		var th: float = p["th0"] * cos(p["w"] * t)
		var dth: float = -p["th0"] * p["w"] * sin(p["w"] * t)
		var L: float = p["L"]
		var bola: AnimatableBody2D = p["bola"]
		bola.global_position = (p["ancora"] as Vector2) + Vector2(L * sin(th), L * cos(th))
		bola.set_meta("vel", Vector2(L * cos(th), -L * sin(th)) * dth)

func _bola_futebol(pos: Vector2) -> void:
	var b := RigidBody2D.new()
	b.mass = 0.3
	b.collision_layer = 0b1000
	b.collision_mask = 0b1111
	var m := PhysicsMaterial.new()
	m.bounce = 0.65
	m.friction = 0.6
	b.physics_material_override = m
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 80.0
	cs.shape = c
	b.add_child(cs)
	var vis := Polygon2D.new()
	var circ := PackedVector2Array()
	for k in 24:
		circ.append(Vector2(80, 0).rotated(TAU * k / 24.0))
	vis.polygon = circ
	vis.color = Color.WHITE
	b.add_child(vis)
	for k in 5:
		var gomo := Polygon2D.new()
		var cen := Vector2(46, 0).rotated(TAU * k / 5.0)
		var pent := PackedVector2Array()
		for q in 5:
			pent.append(cen + Vector2(19, 0).rotated(TAU * q / 5.0))
		gomo.polygon = pent
		gomo.color = Color.BLACK
		b.add_child(gomo)
	b.position = pos
	add_child(b)

func _construir_chao() -> void:
	match Game.fase:
		2: _fase_2()
		3: _fase_3()
		_: _fase_1()

## marcos comuns: zona de morte, checkpoint e chegada
func _marcos(checkpoint: Vector2, chegada: Vector2, morte_y: float) -> void:
	var morte := _area(Vector2(4000, morte_y), Vector2(20000, 400))
	morte.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(false, "buraco"))
	if checkpoint.x > 0.0:
		cp_x = checkpoint.x
		cp_chao = checkpoint.y
		_bandeira(checkpoint.x, checkpoint.y, Color(0.3, 0.85, 0.35))
		var cp := _area(Vector2(checkpoint.x, checkpoint.y - 600), Vector2(60, 1200))
		cp.body_entered.connect(_on_checkpoint)
	_bandeira(chegada.x, chegada.y, Color.WHITE, true)
	var meta := _area(Vector2(chegada.x, chegada.y - 600), Vector2(80, 1200))
	meta.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(true, "meta"))

# ---------- FASE 1: Primeiro Rolê ----------
func _fase_1() -> void:
	_bloco(Vector2(1000, CHAO_Y + 150), Vector2(3000, 300), 0.0)      # pista inicial
	_bloco(Vector2(2720, CHAO_Y - 40), Vector2(760, 150), -20.0)      # rampa de salto
	_espetos(3060, 3360, CHAO_Y + 520)                                # fundo do 1º fosso
	_bloco(Vector2(3210, CHAO_Y + 670), Vector2(400, 300), 0.0)       # chão do 1º fosso
	_bloco(Vector2(4050, CHAO_Y + 230), Vector2(1400, 300), 0.0)      # pouso (3350..4750)
	_bloco(Vector2(5000, CHAO_Y + 230), Vector2(800, 300), 0.0)       # depois das caixas
	_viga(Vector2(5650, TOPO_POUSO + 30), Vector2(560, 60), CHAO_Y + 620)   # ponte de aço
	_espetos(5400, 5900, CHAO_Y + 620)                                # fundo do 2º fosso
	_bloco(Vector2(5650, CHAO_Y + 770), Vector2(560, 300), 0.0)       # chão do 2º fosso
	_bloco(Vector2(6400, CHAO_Y + 230), Vector2(1000, 300), 0.0)      # reta final (5900..6900)
	_bola_demolicao(Vector2(1800, CHAO_Y - 3000), 2400.0, deg_to_rad(16.0))  # fundo da bola a 40 px do chão; balanço de ~9,8 s
	_bola_futebol(Vector2(1400, CHAO_Y - 85))
	_pilha_de_caixas(Vector2(4440, TOPO_POUSO), 3, 2)                 # no lugar da parede: derruba no embalo
	_marcos(Vector2(3600, TOPO_POUSO), Vector2(6300, TOPO_POUSO), CHAO_Y + 1100)

# ---------- FASE 2: Obra (gangorra, vigas, tábuas que caem) ----------
func _fase_2() -> void:
	_bloco(Vector2(600, CHAO_Y + 150), Vector2(2200, 300), 0.0)       # largada (-500..1700)
	_bloco(Vector2(2350, CHAO_Y + 150), Vector2(1300, 300), 0.0)      # chão sob a gangorra (1700..3000)
	_gangorra(Vector2(2350, CHAO_Y - 95), 1100.0)
	_viga(Vector2(3400, CHAO_Y + 30), Vector2(800, 60), CHAO_Y + 700)       # viga 1 (3000..3800)
	_pilha_de_caixas(Vector2(3450, CHAO_Y), 2, 1)
	_espetos(3800, 4000, CHAO_Y + 650)
	_bloco(Vector2(3900, CHAO_Y + 800), Vector2(200, 300), 0.0)
	_viga(Vector2(4400, CHAO_Y + 30), Vector2(800, 60), CHAO_Y + 700)       # viga 2 (4000..4800)
	_tabuas_que_caem(4800.0, 5800.0, CHAO_Y)                               # ponte que despenca
	_espetos(4800, 5800, CHAO_Y + 650)
	_bloco(Vector2(5300, CHAO_Y + 800), Vector2(1000, 300), 0.0)
	_bloco(Vector2(6400, CHAO_Y + 150), Vector2(1200, 300), 0.0)      # chegada (5800..7000)
	_marcos(Vector2(4400, CHAO_Y), Vector2(6500, CHAO_Y), CHAO_Y + 1300)

# ---------- FASE 3: Descidão (ladeira, cerca de espetos, salto, serras) ----------
func _fase_3() -> void:
	var sup := PackedVector2Array([Vector2(-500, CHAO_Y), Vector2(1200, CHAO_Y),
		Vector2(4000, CHAO_Y + 900), Vector2(4400, CHAO_Y + 900), Vector2(4900, CHAO_Y + 700)])
	_terreno(sup, CHAO_Y + 1500)
	_cerca(Vector2(1200, CHAO_Y), Vector2(4000, CHAO_Y + 900))
	_espetos(4900, 6000, CHAO_Y + 1500)
	_bloco(Vector2(5450, CHAO_Y + 1650), Vector2(1100, 300), 0.0)
	_serra(Vector2(5230, CHAO_Y + 1260), 240.0)
	_serra(Vector2(5720, CHAO_Y + 1260), 240.0)
	_terreno(PackedVector2Array([Vector2(6000, CHAO_Y + 800), Vector2(6800, CHAO_Y + 1000),
		Vector2(8200, CHAO_Y + 1000)]), CHAO_Y + 1500)
	_marcos(Vector2(-1.0, 0.0), Vector2(7500, CHAO_Y + 1000), CHAO_Y + 2100)

## terreno por polilinha de superfície (ladeiras de verdade), preenchido até `fundo_y`.
## As quinas são arredondadas (Chaikin): roda pequena não "agarra" em canto seco.
func _terreno(bruto: PackedVector2Array, fundo_y: float) -> void:
	var sup := bruto
	for it in 3:
		var nova := PackedVector2Array([sup[0]])
		for i in sup.size() - 1:
			nova.append(sup[i].lerp(sup[i + 1], 0.25))
			nova.append(sup[i].lerp(sup[i + 1], 0.75))
		nova.append(sup[sup.size() - 1])
		sup = nova
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	sb.physics_material_override = _mat
	var pts := sup.duplicate()
	pts.append(Vector2(sup[sup.size() - 1].x, fundo_y))
	pts.append(Vector2(sup[0].x, fundo_y))
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	sb.add_child(col)
	var terra := Polygon2D.new()
	terra.polygon = pts
	terra.color = Color(0.42, 0.23, 0.09)
	sb.add_child(terra)
	var faixa := Line2D.new()                 # faixa escura acompanhando a superfície
	var desl := PackedVector2Array()
	for p in sup:
		desl.append(p + Vector2(0, 15))
	faixa.points = desl
	faixa.width = 30.0
	faixa.default_color = Color(0.2, 0.18, 0.19)
	faixa.joint_mode = Line2D.LINE_JOINT_ROUND
	sb.add_child(faixa)
	add_child(sb)

## cerca de espetos decorativa ao longo de uma ladeira (atrás de tudo)
func _cerca(a: Vector2, b: Vector2) -> void:
	var n := int(a.distance_to(b) / 70.0)
	for i in n:
		var p := a.lerp(b, float(i) / n)
		var haste := Polygon2D.new()
		haste.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(7, -300), Vector2(0, -345), Vector2(-7, -300)])
		haste.color = Color(0.82, 0.84, 0.9)
		haste.position = p
		haste.z_index = -2
		add_child(haste)

## gangorra: prancha física presa num pino sobre um calço
func _gangorra(pivo: Vector2, comprimento: float) -> void:
	var calco := StaticBody2D.new()
	calco.collision_layer = 0b01
	var cs := CollisionPolygon2D.new()
	cs.polygon = PackedVector2Array([Vector2(-70, CHAO_Y - pivo.y + 5), Vector2(70, CHAO_Y - pivo.y + 5), Vector2(0, 0)])
	calco.add_child(cs)
	var vis := Polygon2D.new()
	vis.polygon = cs.polygon
	vis.color = Color(0.45, 0.47, 0.52)
	calco.add_child(vis)
	calco.position = pivo
	add_child(calco)
	var prancha := RigidBody2D.new()
	prancha.mass = 3.0
	prancha.collision_layer = 0b0001
	prancha.collision_mask = 0b1111
	prancha.physics_material_override = _mat
	var r := RectangleShape2D.new()
	r.size = Vector2(comprimento, 34)
	var cp := CollisionShape2D.new()
	cp.shape = r
	prancha.add_child(cp)
	var madeira := Polygon2D.new()
	var h := comprimento / 2.0
	madeira.polygon = PackedVector2Array([Vector2(-h, -17), Vector2(h, -17), Vector2(h, 17), Vector2(-h, 17)])
	madeira.color = Color(0.66, 0.44, 0.2)
	prancha.add_child(madeira)
	prancha.position = pivo
	prancha.rotation = -atan2(CHAO_Y - pivo.y - 17.0, h)    # ponta de cá (esquerda) encostada no chão
	add_child(prancha)
	var j := PinJoint2D.new()
	add_child(j)
	j.global_position = pivo
	j.node_a = calco.get_path()
	j.node_b = prancha.get_path()

## ponte de tábuas que despencam pouco depois de pisar (passa quem vem embalado)
func _tabuas_que_caem(x0: float, x1: float, topo: float) -> void:
	var n := int((x1 - x0) / 200.0)
	for i in n:
		var t := RigidBody2D.new()
		t.mass = 1.0
		t.freeze = true
		t.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		t.collision_layer = 0b0001
		t.collision_mask = 0b1111
		t.physics_material_override = _mat
		var r := RectangleShape2D.new()
		r.size = Vector2(196, 40)
		var cs := CollisionShape2D.new()
		cs.shape = r
		t.add_child(cs)
		var vis := Polygon2D.new()
		vis.polygon = PackedVector2Array([Vector2(-98, -20), Vector2(98, -20), Vector2(98, 20), Vector2(-98, 20)])
		vis.color = Color(0.6, 0.4, 0.18)
		t.add_child(vis)
		t.position = Vector2(x0 + 100 + i * 200, topo + 20)
		add_child(t)
		var sensor := _area(t.position - Vector2(0, 60), Vector2(196, 100))
		sensor.body_entered.connect(func(b: Node2D) -> void:
			if t.freeze and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
				Audio.tocar("caixa", 0.6)
				get_tree().create_timer(0.45).timeout.connect(func() -> void:
					if is_instance_valid(t): t.set_deferred("freeze", false)))

## serra girando: visual + Area2D letal
func _serra(centro: Vector2, raio: float) -> void:
	var n := Node2D.new()
	n.position = centro
	add_child(n)
	var dentes := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 48:
		pts.append(Vector2(raio if k % 2 == 0 else raio * 0.84, 0).rotated(TAU * k / 48.0))
	dentes.polygon = pts
	dentes.color = Color(0.78, 0.8, 0.86)
	n.add_child(dentes)
	var miolo := Polygon2D.new()
	var c := PackedVector2Array()
	for k in 16:
		c.append(Vector2(raio * 0.25, 0).rotated(TAU * k / 16.0))
	miolo.polygon = c
	miolo.color = Color(0.3, 0.3, 0.33)
	n.add_child(miolo)
	_serras.append(n)
	var a := _area(centro, Vector2(raio * 1.8, raio * 1.8))
	a.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"):
			Audio.tocar("metal")
			_fim(false, "serra"))

## céu, nuvens e morros em paralaxe (arte gerada, original)
func _construir_fundo() -> void:
	var fundo_ceu := CanvasLayer.new()
	fundo_ceu.layer = -101
	add_child(fundo_ceu)
	var pb := ParallaxBackground.new()
	add_child(pb)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.27, 0.47, 0.92))
	grad.set_color(1, Color(0.62, 0.78, 0.98))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var ceu_s := TextureRect.new()
	ceu_s.texture = gt
	ceu_s.set_anchors_preset(Control.PRESET_FULL_RECT)
	ceu_s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ceu_s.stretch_mode = TextureRect.STRETCH_SCALE
	fundo_ceu.add_child(ceu_s)
	for camada in [["nuvem", 0.12, -1300.0, 4.8], ["morros_longe", 0.25, 720.0, 4.1], ["morros_perto", 0.45, 980.0, 4.4]]:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(camada[1], camada[1] * 0.35)
		pb.add_child(pl)
		if camada[0] == "nuvem":
			pl.motion_mirroring = Vector2(9600, 0)
			for k in 4:
				var n := Sprite2D.new()
				n.texture = load("res://assets/ui/nuvem%d.png" % (k % 3))
				n.scale = Vector2.ONE * camada[3]
				n.position = Vector2(k * 2400 + 550 * (k % 2), camada[2] + 480 * (k % 3))
				pl.add_child(n)
		else:
			var tex: Texture2D = load("res://assets/ui/%s.png" % camada[0])
			pl.motion_mirroring = Vector2(tex.get_width() * camada[3], 0)
			var m := Sprite2D.new()
			m.texture = tex
			m.centered = false
			m.scale = Vector2.ONE * camada[3]
			m.position = Vector2(0, camada[2] - tex.get_height() * camada[3] * 0.5)   # repete a cada W·escala
			pl.add_child(m)
			var chao := Polygon2D.new()            # preenche abaixo do morro (sem céu aparecendo)
			var y0: float = camada[2] + tex.get_height() * camada[3] * 0.5 - 4.0
			var lw: float = tex.get_width() * camada[3]
			chao.polygon = PackedVector2Array([Vector2(0, y0), Vector2(lw, y0), Vector2(lw, y0 + 3000), Vector2(0, y0 + 3000)])
			chao.color = Color(0.48, 0.69, 0.33) if camada[0] == "morros_longe" else Color(0.34, 0.59, 0.21)
			pl.add_child(chao)

func _area(centro: Vector2, tamanho: Vector2) -> Area2D:
	var a := Area2D.new()
	a.position = centro
	a.collision_layer = 0
	a.collision_mask = 0b110                  # veículo + piloto
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tamanho
	cs.shape = r
	a.add_child(cs)
	add_child(a)
	return a

func _bandeira(x: float, chao: float, cor: Color, xadrez := false) -> void:
	var mastro := Polygon2D.new()
	mastro.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(8, -560), Vector2(-8, -560)])
	mastro.color = Color(0.92, 0.92, 0.95)
	mastro.position = Vector2(x, chao)
	add_child(mastro)
	for i in 8:
		for j in 4:
			var q := Polygon2D.new()
			q.polygon = PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 40), Vector2(0, 40)])
			q.position = Vector2(8 + i * 40, -560 + j * 40)
			q.color = (Color.BLACK if (i + j) % 2 == 1 else cor) if xadrez else cor
			mastro.add_child(q)

func _pilha_de_caixas(base: Vector2, colunas: int, linhas: int) -> void:
	var lado := 240.0
	for i in colunas:
		for j in linhas:
			var c := RigidBody2D.new()
			c.mass = 2.0
			c.collision_layer = 0b1000            # objetos
			c.collision_mask = 0b1111
			c.physics_material_override = _mat
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(lado - 4, lado - 4)
			cs.shape = r
			c.add_child(cs)
			var vis := Polygon2D.new()
			var h := lado / 2.0 - 2.0
			vis.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
			vis.color = Color(0.72, 0.5, 0.26)
			c.add_child(vis)
			var tabua := Polygon2D.new()
			tabua.polygon = PackedVector2Array([Vector2(-h, -20), Vector2(h, -20), Vector2(h, 20), Vector2(-h, 20)])
			tabua.color = Color(0.55, 0.36, 0.17)
			c.add_child(tabua)
			c.position = base + Vector2(i * lado + lado / 2.0, -j * lado - lado / 2.0)
			c.contact_monitor = true
			c.max_contacts_reported = 2
			c.body_entered.connect(func(_b: Node) -> void:
				if c.linear_velocity.length() > 250.0: Audio.tocar("caixa", c.linear_velocity.length() / 900.0))
			add_child(c)

func _on_checkpoint(b: Node2D) -> void:
	if Game.checkpoint_x < cp_x and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
		Game.checkpoint_x = cp_x
		Game.checkpoint_chao = cp_chao
		Audio.tocar("checkpoint")
		print("[FASE] checkpoint")

func _fim(ganhou: bool, motivo: String) -> void:
	if not ativo:
		return
	ativo = false
	if ganhou:
		var novo := do_inicio and Game.registrar_vitoria(Game.fase, tempo)
		aviso.text = "CHEGOU!\n%.1f s%s" % [tempo, "  NOVO RECORDE!" if novo else ""]
		aviso.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
		Game.checkpoint_x = -1.0
		Audio.motor(false)
		Audio.tocar("vitoria")
		print("[FASE] venceu %.2f" % tempo)
		venceu.emit(tempo)
	else:
		aviso.text = "MORREU!\naperta R" if motivo in ["cabeca", "espetos"] else "CAIU!\naperta R"
		Audio.motor(false)
		Audio.tocar("morte")
		print("[FASE] perdeu %s x=%.0f" % [motivo, player.foco().global_position.x if is_instance_valid(player) else 0.0])
		perdeu.emit(motivo)
	aviso.visible = true
	if painel:
		painel.get_node("proxima").visible = ganhou and Game.fase < Game.FASES.size()
		painel.visible = true
		_posicionar_hud.call_deferred()

# ---------- HUD ----------
func _estilo_botao() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.35)
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = Color(1, 1, 1, 0.5)
	return st

func _botao(texto: String, pos: Vector2, tam: Vector2, acao: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.position = pos
	b.custom_minimum_size = tam
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _estilo_botao())
	$HUD.add_child(b)
	b.pressed.connect(func(): Audio.tocar("clique"))
	if acao == "reset":
		b.pressed.connect(func(): get_tree().reload_current_scene())
	elif acao == "menu":
		b.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/Menu.tscn"))
	return b

## botão de toque (multitoque de verdade) que dispara a ação direto no Input
func _toque(icone: String, pos: Vector2, tam: float, acao: String) -> TouchScreenButton:
	var t := TouchScreenButton.new()
	t.texture_normal = load("res://assets/ui/%s.png" % icone)
	t.position = pos
	t.scale = Vector2.ONE * tam / 200.0
	t.action = acao
	var sh := CircleShape2D.new()
	sh.radius = 100.0
	t.shape = sh
	t.shape_centered = true
	$HUD.add_child(t)
	return t

func _construir_hud() -> void:
	var cl := CanvasLayer.new()
	cl.name = "HUD"
	add_child(cl)
	dist_label = Label.new()
	dist_label.position = Vector2(24, 14)
	dist_label.add_theme_font_size_override("font_size", 40)
	dist_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dist_label.add_theme_constant_override("outline_size", 10)
	cl.add_child(dist_label)
	# posição de cada controle relativa às bordas: recalculada quando a tela muda
	_hud = [
		[_toque("gira_tras", Vector2.ZERO, 180, "lean_back"), func(v: Vector2) -> Vector2: return Vector2(36, v.y - 210)],
		[_toque("gira_frente", Vector2.ZERO, 180, "lean_fwd"), func(v: Vector2) -> Vector2: return Vector2(236, v.y - 210)],
		[_toque("re", Vector2.ZERO, 155, "brake"), func(v: Vector2) -> Vector2: return Vector2(v.x - 400, v.y - 185)],
		[_toque("gas", Vector2.ZERO, 200, "accelerate"), func(v: Vector2) -> Vector2: return Vector2(v.x - 225, v.y - 225)],
		[_toque("pula", Vector2.ZERO, 145, "eject"), func(v: Vector2) -> Vector2: return Vector2(v.x - 185, v.y - 390)],
		[_botao("R", Vector2.ZERO, Vector2(80, 64), "reset"), func(v: Vector2) -> Vector2: return Vector2(v.x - 96, 14)],
		[_botao("TROCAR", Vector2.ZERO, Vector2(180, 64), "menu"), func(v: Vector2) -> Vector2: return Vector2(v.x - 290, 14)],
	]
	var vp := get_viewport().get_visible_rect().size
	aviso = Label.new()
	aviso.text = "MORREU!\naperta R"
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 72)
	aviso.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 10)
	aviso.size = Vector2(vp.x, 160)
	aviso.position = Vector2(0, vp.y * 0.06)
	aviso.visible = false
	cl.add_child(aviso)
	painel = HBoxContainer.new()
	painel.add_theme_constant_override("separation", 22)
	painel.visible = false
	cl.add_child(painel)
	for item in [["PRÓXIMA", "proxima"], ["DE NOVO", "denovo"], ["FASES", "fases"]]:
		var b := Button.new()
		b.text = item[0]
		b.name = item[1]
		b.custom_minimum_size = Vector2(230, 84)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 34)
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, _estilo_botao())
		b.pressed.connect(_acao_fim.bind(item[1]))
		painel.add_child(b)
	_hud.append([painel, func(v: Vector2) -> Vector2: return Vector2((v.x - painel.size.x) / 2.0, v.y * 0.52)])
	get_viewport().size_changed.connect(_posicionar_hud)
	_posicionar_hud()

func _acao_fim(acao: String) -> void:
	Audio.tocar("clique")
	match acao:
		"proxima":
			Game.fase = mini(Game.fase + 1, Game.FASES.size())
			Game.checkpoint_x = -1.0
			get_tree().reload_current_scene()
		"denovo":
			get_tree().reload_current_scene()
		"fases":
			Game.checkpoint_x = -1.0
			get_tree().change_scene_to_file("res://levels/Fases.tscn")

func _posicionar_hud() -> void:
	if not is_inside_tree():                  # chamada adiada pode chegar depois do reload
		return
	var v := get_viewport().get_visible_rect().size
	for item in _hud:
		(item[0] as Node).set("position", (item[1] as Callable).call(v))
	if aviso:
		aviso.size = Vector2(v.x, 160)
		aviso.position = Vector2(0, v.y * 0.06)

func _on_morreu() -> void:
	_fim(false, "cabeca")

# ---------- teste automatizado de física (headless) ----------
func _rodar_teste() -> void:
	await _esperar(1.0)
	print("[SPAWN 1s] rotacao=%.3f" % absf(player.chassi.rotation))
	await _esperar(5.0)
	var rot_spawn := absf(player.chassi.rotation)
	var y_spawn := player.chassi.global_position.y
	print("[SPAWN 6s] rotacao=%.3f rad  y=%.1f (esperado ~0 e estavel)" % [rot_spawn, y_spawn])

	var x0 := player.chassi.global_position.x
	Input.action_press("accelerate")
	await _esperar(2.5)
	Input.action_release("accelerate")
	var dx := player.chassi.global_position.x - x0
	var rot_drive := absf(player.chassi.rotation)
	print("[DRIVE] avancou dx=%.1f  rotacao=%.3f" % [dx, rot_drive])

	player.soltar_ragdoll(player.chassi.linear_velocity, true)
	await _esperar(1.3)
	var vmax := 0.0
	for k in player.corpos:
		vmax = maxf(vmax, player.corpos[k].linear_velocity.length())
	print("[RAGDOLL] pecas=%d  vel_max=%.1f (finita = nao explodiu)" % [player.corpos.size(), vmax])

	player.arrancar("braco")
	await _esperar(2.5)
	print("[SANGUE] manchas=%d  gotas_no_ar=%d  juntas_restantes=%d" % [sangue.manchas.size(), sangue.gotas.size(), player.juntas.size()])

	var ok: bool = rot_spawn < 0.35 and dx > 150.0 and player.corpos.size() == player.D["piloto"].size() and vmax < 8000.0 \
		and sangue.manchas.size() > 10 and not player.juntas.has("braco")
	print("[RESULTADO] ", "PASS" if ok else "FALHA")
	get_tree().quit()

func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout

# ---------- captura de telas (render por software) ----------
func _rodar_screenshots() -> void:
	print("USERDIR ", OS.get_user_data_dir())
	await _esperar(1.0)
	await _captura("g00_parado")
	Input.action_press("accelerate")
	var t := 0.0
	var i := 1
	while t < 9.0:                               # corrida inteira: rampa, pouso, parede
		await _esperar(0.75)
		t += 0.75
		await _captura("g%02d_t%.1f" % [i, t])
		i += 1
	Input.action_release("accelerate")
	if player.juntas.has("perna"):
		player.arrancar("perna")
	await _esperar(1.0)
	await _captura("g%02d_arrancou" % i)
	print("[FIM] montado=%s morto=%s manchas=%d juntas=%d" % [player.montado, player.morto, sangue.manchas.size(), player.juntas.size()])
	get_tree().quit()

func _captura(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://%s.png" % nome)
	print("SHOT ", nome)

func _exit_tree() -> void:
	Audio.motor(false)                        # sair da fase cala o motor
