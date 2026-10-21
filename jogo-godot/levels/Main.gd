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
var _hud: Array = []
var painel: HBoxContainer
var pecas: Pecas
var cps: Array = []                         # checkpoints da fase: [x, chão]

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
	_construir_fundo(["campo", "obra", "montanha"][clampi(Game.fase, 1, 3) - 1])
	_mat = PhysicsMaterial.new()
	_mat.friction = 1.0
	_mat.bounce = 0.0
	pecas = Pecas.new(self, _mat, _on_perigo)
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
	sangue.escala = 3.2
	add_child(sangue)
	player.sangue = sangue
	player.morreu.connect(_on_morreu)
	player.bateu_chao.connect(func(pos: Vector2, forca: float) -> void: pecas.poeira(pos, forca))

	camera = FollowCamera.new()
	camera.zoom = Vector2(0.18, 0.18)         # boneco ~30% da altura da tela (visual-quality §2)
	camera.offset = Vector2(1100, -300)       # mostra bastante fase à frente, pista acima dos botões
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
	for p in _pendulos:
		var bola: Node2D = p["bola"]
		var gancho: Vector2 = bola.global_position + (p["ancora"] - bola.global_position).normalized() * float(p["raio"]) * 0.95
		(p["corrente"] as Line2D).points = PackedVector2Array([p["ancora"], gancho])
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

## bola de demolição: pêndulo CINEMÁTICO (AnimatableBody2D) — segue θ(t)=θ0·cos(ωt),
## nunca estica nem perde energia, e empurra corpos com massa "infinita"
func _bola_demolicao(ancora: Vector2, comprimento: float, angulo_ini: float, raio := 560.0, w := -1.0) -> void:
	var bola := AnimatableBody2D.new()
	bola.sync_to_physics = false
	bola.collision_layer = 0b11000           # objeto + perigo: empurra e o sensor do piloto sente
	bola.collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = raio
	cs.shape = c
	bola.add_child(cs)
	# já nasce no lugar: criada na origem, varria o mundo até a âncora no 1º passo e
	# arremessava quem estivesse perto de (0,0) — era a "bola acertando na largada"
	bola.position = ancora + Vector2(sin(angulo_ini), cos(angulo_ini)) * comprimento
	add_child(bola)
	bola.add_to_group("pendulo")
	bola.set_meta("ancora", ancora)
	bola.set_meta("alcance", comprimento * sin(angulo_ini))
	bola.set_meta("raio", raio)
	bola.set_meta("vel", Vector2.ZERO)
	var corrente := pecas.vestir_bola(bola, raio)
	var som := _area(Vector2.ZERO, Vector2(raio * 2.1, raio * 2.1))
	remove_child(som)
	som.position = Vector2.ZERO
	bola.add_child(som)
	som.body_entered.connect(func(b: Node2D) -> void:
		if (b.is_in_group("veiculo") or b.is_in_group("piloto")) and (bola.get_meta("vel") as Vector2).length() > 150.0:
			Audio.tocar("metal", 0.9))
	_pendulos.append({"bola": bola, "ancora": ancora, "L": comprimento, "th0": angulo_ini,
		"w": w if w > 0.0 else sqrt(980.0 / comprimento), "corrente": corrente, "raio": raio})
	_mover_pendulos(0.0)

func _physics_process(delta: float) -> void:
	_t_fisica += delta
	_mover_pendulos(_t_fisica)
	pecas.mover_pistoes(_t_fisica)

func _mover_pendulos(t: float) -> void:
	for p in _pendulos:
		var th: float = p["th0"] * cos(p["w"] * t)
		var dth: float = -p["th0"] * p["w"] * sin(p["w"] * t)
		var L: float = p["L"]
		var bola: AnimatableBody2D = p["bola"]
		bola.global_position = (p["ancora"] as Vector2) + Vector2(L * sin(th), L * cos(th))
		bola.set_meta("vel", Vector2(L * cos(th), -L * sin(th)) * dth)

func _construir_chao() -> void:
	match Game.fase:
		2: _fase_2()
		3: _fase_3()
		_: _fase_1()

## marcos comuns: zona de morte, checkpoints (lista de Vector2: x, chão) e chegada
func _marcos(checkpoints: Array, chegada: Vector2, morte_y: float, bandeiras := true) -> void:
	var morte := _area(Vector2(chegada.x / 2.0, morte_y), Vector2(absf(chegada.x) * 2.0 + 12000.0, 400))
	morte.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(false, "buraco"))
	for c in checkpoints:
		var ck: Vector2 = c
		cps.append(ck)
		_bandeira(ck.x, ck.y, Color(0.3, 0.85, 0.35))
		var cp := _area(Vector2(ck.x, ck.y - 600), Vector2(60, 1200))
		cp.body_entered.connect(_on_checkpoint.bind(ck))
	if checkpoints.size() > 0:
		cp_x = (checkpoints[0] as Vector2).x
		cp_chao = (checkpoints[0] as Vector2).y
	if bandeiras:
		_bandeira(chegada.x, chegada.y, Color.WHITE, true)
	var meta := _area(Vector2(chegada.x, chegada.y - 600), Vector2(80, 1200))
	meta.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(true, "meta"))

# ---------- FASE 1: Primeiro Rolê (campo) ----------
## largada no platô -> ponte de madeira descendo sobre espinhos -> morro -> guindaste
## com bola de demolição -> rampa sobre o lago -> passarela de vigas com caixas e TNT
## -> subida até a chegada. Dois checkpoints.
func _fase_1() -> void:
	var P := pecas
	var fundo := CHAO_Y + 1700.0
	P.terreno(PackedVector2Array([Vector2(-2600, CHAO_Y), Vector2(1300, CHAO_Y)]), fundo)
	P.placa(Vector2(-900, CHAO_Y), "LARGADA")
	P.cerca(-2600, -1300, CHAO_Y)
	P.sprite("arvore1", Vector2(-2000, CHAO_Y), 2.6, -4)
	P.sprite("arvore2", Vector2(500, CHAO_Y), 2.3, -4, true)
	P.sprite("pedra2", Vector2(1050, CHAO_Y), 1.3, -2)
	# ponte descendo sobre o fosso de espinhos
	P.terreno(PackedVector2Array([Vector2(1300, CHAO_Y + 1100), Vector2(3460, CHAO_Y + 1100)]), fundo, false)
	P.espinhos(1340, 3440, CHAO_Y + 1100)
	P.ponte_madeira(Vector2(1250, CHAO_Y), Vector2(3560, CHAO_Y + 350), CHAO_Y + 1100)
	# morro e reta da bola de demolição
	var reta := CHAO_Y + 100.0
	P.terreno(PackedVector2Array([Vector2(3460, CHAO_Y + 350), Vector2(3950, CHAO_Y + 360), Vector2(4650, reta + 40),
		Vector2(5200, reta), Vector2(9800, reta)]), fundo)
	P.sprite("arvore2", Vector2(4300, CHAO_Y + 300), 2.0, -4)
	P.sprite("pedra1", Vector2(4900, reta), 1.1, -2)
	P.cerca(5600, 6400, reta)
	# bola passa na altura do peito (700 acima do chão) e sobe alto nas pontas (85°):
	# brecha de ~1,2–1,9 s por balanço para os 3 veículos (simulado e testado no bot)
	var piv := Vector2(7800, reta - 700.0 - 450.0 - 1300.0)
	P.guindaste(10000, reta, piv.y - 480.0, 7650, 7800, piv)
	_bola_demolicao(piv, 1300.0, deg_to_rad(85.0), 450.0, 0.6)
	# rampa e lago
	var dx := 500.0
	P.rampa(9000 + dx, 9800 + dx, reta, 280)
	P.terreno(PackedVector2Array([Vector2(9800 + dx, CHAO_Y + 1300), Vector2(10800 + dx, CHAO_Y + 1300)]), fundo, false)
	P.agua(9800 + dx, 10800 + dx, CHAO_Y + 500, CHAO_Y + 1300)
	var pouso := CHAO_Y + 260.0
	P.terreno(PackedVector2Array([Vector2(10800 + dx, CHAO_Y + 180), Vector2(11400 + dx, pouso), Vector2(12200 + dx, pouso)]), fundo)
	P.sprite("arvore1", Vector2(11900 + dx, pouso), 2.2, -4, true)
	# passarela de vigas sobre a ravina, com caixas e TNT
	P.terreno(PackedVector2Array([Vector2(12200 + dx, CHAO_Y + 1400), Vector2(14200 + dx, CHAO_Y + 1400)]), fundo, false)
	P.espinhos(12240 + dx, 14160 + dx, CHAO_Y + 1400)
	P.passarela(12160 + dx, 14240 + dx, pouso, CHAO_Y + 1400, [12800 + dx, 13650 + dx])
	P.caixa(Vector2(12750 + dx, pouso - 200), 400)
	P.caixa(Vector2(12750 + dx, pouso - 600), 400)
	P.tnt(Vector2(13550 + dx, pouso))
	# subida final
	var alto := CHAO_Y - 40.0
	P.terreno(PackedVector2Array([Vector2(14200 + dx, pouso), Vector2(14700 + dx, pouso - 20), Vector2(15500 + dx, alto),
		Vector2(19000, alto)]), fundo)
	P.placa(Vector2(16900, alto), "CHEGADA", true)
	P.sprite("arvore2", Vector2(17800, alto), 2.5, -4)
	P.sprite("pedra2", Vector2(16400, alto), 1.0, -2, true)
	_marcos([Vector2(5400, reta), Vector2(12200, pouso)], Vector2(16900, alto), CHAO_Y + 2200, false)

# ---------- FASE 2: Obra (gangorra, vigas sobre o fosso, tábuas que caem, prensa) ----------
func _fase_2() -> void:
	var P := pecas
	P.chao_tex = "concreto"
	P.topo_tex = "asfalto"
	P.contorno_chao = Pecas.CONTORNO_METAL
	var fundo := CHAO_Y + 1700.0
	var poco := CHAO_Y + 1300.0
	P.terreno(PackedVector2Array([Vector2(-2600, CHAO_Y), Vector2(3000, CHAO_Y)]), fundo)   # largada + chão da gangorra
	P.placa(Vector2(-900, CHAO_Y), "LARGADA")
	P.guindaste(1200, CHAO_Y, CHAO_Y - 3000, -1300, -400)
	for x in [300.0, 650.0, 1900.0]:
		P.cone(Vector2(x, CHAO_Y))
	_gangorra(Vector2(2350, CHAO_Y - 95), 1100.0)
	P.passarela(3000, 3800, CHAO_Y, poco, [3400])                                         # viga 1
	P.caixa(Vector2(3500, CHAO_Y - 150), 300)
	P.caixa(Vector2(3500, CHAO_Y - 450), 300)
	P.terreno(PackedVector2Array([Vector2(3800, poco), Vector2(4000, poco)]), fundo, false)
	P.espinhos(3800, 4000, poco)
	P.passarela(4000, 4800, CHAO_Y, poco, [4400])                                         # viga 2
	_tabuas_que_caem(4800.0, 5800.0, CHAO_Y)                                              # ponte que despenca
	P.terreno(PackedVector2Array([Vector2(4800, poco), Vector2(5800, poco)]), fundo, false)
	P.espinhos(4840, 5760, poco)
	P.terreno(PackedVector2Array([Vector2(5800, CHAO_Y), Vector2(9500, CHAO_Y)]), fundo)  # chegada
	P.prensa(6500, CHAO_Y)
	P.cone(Vector2(7100, CHAO_Y))
	P.placa(Vector2(7700, CHAO_Y), "CHEGADA", true)
	_marcos([Vector2(4400, CHAO_Y)], Vector2(7700, CHAO_Y), CHAO_Y + 2000, false)

# ---------- FASE 3: Descidão (montanha: ladeira, salto sobre as serras, ponte sobre a ravina, TNT) ----------
func _fase_3() -> void:
	var P := pecas
	P.chao_tex = "rocha"
	P.topo_tex = "grama_alpina"
	P.contorno_chao = Color(0.13, 0.12, 0.15)
	var fundo := CHAO_Y + 3200.0
	P.terreno(PackedVector2Array([Vector2(-2600, CHAO_Y), Vector2(1200, CHAO_Y),
		Vector2(4000, CHAO_Y + 900), Vector2(4400, CHAO_Y + 900), Vector2(4900, CHAO_Y + 700)]), fundo)
	P.placa(Vector2(-900, CHAO_Y), "LARGADA")
	_cerca(Vector2(1200, CHAO_Y), Vector2(4000, CHAO_Y + 900))
	P.sprite("pinheiro2", Vector2(-2000, CHAO_Y), 2.4, -4)
	P.sprite("pinheiro1", Vector2(500, CHAO_Y), 2.2, -4)
	P.sprite("pinheiro2", Vector2(2600, CHAO_Y + 450), 2.0, -4)
	P.sprite("pedra1", Vector2(3300, CHAO_Y + 680), 1.3, -2)
	P.sprite("pinheiro1", Vector2(4200, CHAO_Y + 900), 2.3, -4)
	P.terreno(PackedVector2Array([Vector2(4900, CHAO_Y + 1500), Vector2(6000, CHAO_Y + 1500)]), fundo, false)
	P.espinhos(4940, 5960, CHAO_Y + 1500)
	P.serra(Vector2(5230, CHAO_Y + 1260), 330.0)
	P.serra(Vector2(5720, CHAO_Y + 1260), 330.0)
	var pouso := CHAO_Y + 1000.0
	P.terreno(PackedVector2Array([Vector2(6000, CHAO_Y + 800), Vector2(6800, pouso),
		Vector2(8000, pouso)]), fundo)
	P.sprite("pedra2", Vector2(6900, pouso), 1.1, -2)
	P.sprite("pinheiro2", Vector2(7700, pouso), 2.5, -4)
	# ponte de madeira subindo sobre a ravina de espinhos
	var ravina := CHAO_Y + 1800.0
	P.terreno(PackedVector2Array([Vector2(8000, ravina), Vector2(9800, ravina)]), fundo, false)
	P.espinhos(8040, 9760, ravina)
	P.ponte_madeira(Vector2(7950, pouso), Vector2(9850, pouso - 150), ravina)
	# trilha dos barris de TNT e subida até a chegada
	var trilha := pouso - 150.0
	var topo := CHAO_Y + 500.0
	P.terreno(PackedVector2Array([Vector2(9800, trilha), Vector2(10900, trilha), Vector2(11700, topo),
		Vector2(14500, topo)]), fundo)
	P.tnt(Vector2(10350, trilha), 500.0)
	P.caixa(Vector2(10650, trilha - 170), 340)
	P.sprite("pinheiro1", Vector2(11200, trilha - 150), 2.2, -4)
	P.placa(Vector2(12600, topo), "CHEGADA", true)
	P.sprite("pinheiro2", Vector2(13400, topo), 2.5, -4)
	_marcos([Vector2(7200, pouso)], Vector2(12600, topo), CHAO_Y + 3500, false)

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
	pecas.poligono(cs.polygon, Color(0.62, 0.66, 0.72), 0, null, 1.0, calco)
	var cont := cs.polygon.duplicate()
	cont.append(cs.polygon[0])
	pecas.linha(cont, Pecas.LARG_CONTORNO, Pecas.CONTORNO_METAL, 0, calco)
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
	var h := comprimento / 2.0
	pecas.tabua(Vector2(-h, 0), Vector2(h, 0), 34.0, 1, prancha)
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
		pecas.tabua(Vector2(-98, 0), Vector2(98, 0), 40.0, 1, t)
		t.position = Vector2(x0 + 100 + i * 200, topo + 20)
		add_child(t)
		var sensor := _area(t.position - Vector2(0, 60), Vector2(196, 100))
		sensor.body_entered.connect(func(b: Node2D) -> void:
			if t.freeze and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
				Audio.tocar("caixa", 0.6)
				get_tree().create_timer(0.45).timeout.connect(func() -> void:
					if is_instance_valid(t): t.set_deferred("freeze", false)))

## céu, nuvens e morros em paralaxe (arte gerada, original). `tema` escolhe as camadas.
func _construir_fundo(tema: String) -> void:
	var fundo_ceu := CanvasLayer.new()
	fundo_ceu.layer = -101
	add_child(fundo_ceu)
	var pb := ParallaxBackground.new()
	add_child(pb)
	var grad := Gradient.new()
	grad.set_color(0, {"obra": Color(0.36, 0.52, 0.78), "montanha": Color(0.2, 0.38, 0.78)}.get(tema, Color(0.27, 0.47, 0.92)))
	grad.set_color(1, {"campo": Color(0.86, 0.93, 0.98), "obra": Color(0.95, 0.85, 0.72), "montanha": Color(0.78, 0.88, 0.98)}.get(tema, Color(0.62, 0.78, 0.98)))
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
	var camadas: Array = [["nuvem", 0.12, -1300.0, 4.8], ["ui/morros_longe", 0.25, 720.0, 4.1], ["ui/morros_perto", 0.45, 980.0, 4.4]]
	if tema in ["campo", "obra", "montanha"]:
		camadas = [["nuvem", 0.1, -1500.0, 5.5], ["arte/fundo_%s_longe" % tema, 0.18, 380.0, 3.4],
			["arte/fundo_%s_meio" % tema, 0.32, 700.0, 3.2], ["arte/fundo_%s_perto" % tema, 0.5, 1000.0, 3.0]]
	for camada in camadas:
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
			var tex: Texture2D = load("res://assets/%s.png" % camada[0])
			# 2 cópias por ciclo: com a câmera afastada uma cópia só não cobre a tela e abre uma faixa
			var lw: float = tex.get_width() * camada[3] * 2.0
			pl.motion_mirroring = Vector2(lw, 0)
			for k in 2:
				var m := Sprite2D.new()
				m.texture = tex
				m.centered = false
				m.scale = Vector2.ONE * camada[3]
				m.position = Vector2(k * lw / 2.0, camada[2] - tex.get_height() * camada[3] * 0.5)
				pl.add_child(m)
			var chao := Polygon2D.new()            # preenche abaixo do morro (sem céu aparecendo)
			var y0: float = camada[2] + tex.get_height() * camada[3] * 0.5 - 4.0
			chao.polygon = PackedVector2Array([Vector2(0, y0), Vector2(lw, y0), Vector2(lw, y0 + 3000), Vector2(0, y0 + 3000)])
			var img := tex.get_image()
			chao.color = img.get_pixel(img.get_width() / 2, img.get_height() - 1)
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

func _on_checkpoint(b: Node2D, ck: Vector2) -> void:
	if Game.checkpoint_x < ck.x and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
		Game.checkpoint_x = ck.x
		Game.checkpoint_chao = ck.y
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
		aviso.text = {"agua": "AFOGOU!", "buraco": "CAIU!", "caiu": "CAIU!"}.get(motivo, "MORREU!") + "\naperta R"
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

func _on_perigo(b: Node2D, motivo: String) -> void:
	if b is RigidBody2D:
		sangue.jorrar(b.global_position, 90, 1400.0, Vector2.ZERO, (b as RigidBody2D).linear_velocity * 0.2)
	if motivo != "agua":
		Audio.tocar("splat")
		Audio.tocar("metal" if motivo == "serra" else "impacto_forte")
	if is_instance_valid(player) and player.montado:
		player.soltar_ragdoll.call_deferred(player.chassi.linear_velocity * 0.5, false)
	_fim(false, motivo)

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
	if "fotos" in OS.get_cmdline_user_args():
		for k in 4:
			await _esperar(0.5)
			await _captura("teste_sangue_%d" % k)
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
