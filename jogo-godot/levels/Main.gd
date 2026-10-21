extends Node2D
## Nível de teste: chão + rampa, instancia o Player, câmera que segue e HUD tocável.
## Com o argumento "--test" roda uma checagem de física automatizada e sai.

signal venceu(tempo: float)
signal perdeu(motivo: String)

const CHAO_Y := 1000.0
const SPAWN_X := 600.0
const CHECKPOINT_X := 3600.0
const META_X := 6300.0
const TOPO_POUSO := CHAO_Y + 80.0          # topo dos blocos depois da rampa

var ativo := true
var tempo := 0.0
var _caiu_em := -1.0
var _correntes: Array = []
var _hud: Array = []                      # [controle, Callable(tamanho_tela) -> posição]                # [Line2D, âncora, bola] da bola de demolição

var player: Player
var sangue: Sangue
var aviso: Label
var camera: FollowCamera
var dist_label: Label
var recorde := 0
var _mat: PhysicsMaterial

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.33, 0.55, 0.93))
	_construir_fundo()
	_mat = PhysicsMaterial.new()
	_mat.friction = 1.0
	_mat.bounce = 0.0
	_construir_chao()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("p="):
			Game.personagem = a.substr(2)
	player = Player.new()
	player.personagem = Game.personagem
	player.chao_y = CHAO_Y
	player.spawn_x = SPAWN_X
	if Game.checkpoint_x > 0.0:               # renasce no checkpoint depois de morrer
		player.spawn_x = Game.checkpoint_x
		player.chao_y = Game.checkpoint_chao
	add_child(player)
	sangue = Sangue.new()
	add_child(sangue)
	player.sangue = sangue
	player.morreu.connect(_on_morreu)

	camera = FollowCamera.new()
	camera.zoom = Vector2(0.44, 0.44)
	camera.offset = Vector2(260, -170)        # olha pra frente e mostra a cabeça
	add_child(camera)
	camera.alvo = player.foco()

	_construir_hud()

	if "autoteste" in OS.get_cmdline_user_args():
		_rodar_teste()
	elif "screenshot" in OS.get_cmdline_user_args():
		_rodar_screenshots()

func _process(delta: float) -> void:
	for c in _correntes:
		(c[0] as Line2D).points = PackedVector2Array([c[1], (c[2] as Node2D).global_position])
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
		pts.append(Vector2(x + 14, chao - 110))
		pts.append(Vector2(x + 28, chao))
		x += 28
	vis.polygon = pts
	vis.color = Color(0.78, 0.8, 0.86)
	add_child(vis)
	var a := _area(Vector2((x0 + x1) / 2.0, chao - 55), Vector2(x1 - x0, 110))
	a.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"):
			Audio.tocar("splat")
			_fim(false, "espetos"))

## bola de demolição: pêndulo físico (PinJoint2D) que derruba quem passar na hora errada
func _bola_demolicao(ancora: Vector2, comprimento: float, angulo_ini: float) -> void:
	var pino := StaticBody2D.new()
	pino.position = ancora
	pino.collision_layer = 0
	add_child(pino)
	var bola := RigidBody2D.new()
	bola.mass = 40.0                          # pesada: o golpe empurra/capota de verdade
	bola.collision_layer = 0b1000            # objeto: bate fisicamente (não é "encostou, morreu")
	bola.collision_mask = 0b1110
	bola.linear_damp = 0.0
	bola.angular_damp = 0.0
	bola.contact_monitor = true
	bola.max_contacts_reported = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 95.0
	cs.shape = c
	bola.add_child(cs)
	var vis := Polygon2D.new()
	var circ := PackedVector2Array()
	for k in 32:
		circ.append(Vector2(95, 0).rotated(TAU * k / 32.0))
	vis.polygon = circ
	vis.color = Color(0.3, 0.26, 0.33)
	bola.add_child(vis)
	bola.position = ancora + Vector2(0, comprimento).rotated(-angulo_ini)
	add_child(bola)
	bola.add_to_group("pendulo")
	bola.set_meta("ancora", ancora)
	bola.set_meta("alcance", comprimento * sin(angulo_ini))
	var j := PinJoint2D.new()
	add_child(j)
	j.global_position = ancora
	j.node_a = pino.get_path()
	j.node_b = bola.get_path()
	var corrente := Line2D.new()
	corrente.width = 8.0
	corrente.default_color = Color(0.12, 0.12, 0.12)
	corrente.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	add_child(corrente)
	bola.body_entered.connect(func(_b: Node) -> void:
		if bola.linear_velocity.length() > 200.0: Audio.tocar("metal", 0.8))
	_correntes.append([corrente, ancora, bola])

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
	c.radius = 42.0
	cs.shape = c
	b.add_child(cs)
	var vis := Polygon2D.new()
	var circ := PackedVector2Array()
	for k in 24:
		circ.append(Vector2(42, 0).rotated(TAU * k / 24.0))
	vis.polygon = circ
	vis.color = Color.WHITE
	b.add_child(vis)
	for k in 5:
		var gomo := Polygon2D.new()
		var cen := Vector2(24, 0).rotated(TAU * k / 5.0)
		var pent := PackedVector2Array()
		for q in 5:
			pent.append(cen + Vector2(10, 0).rotated(TAU * q / 5.0))
		gomo.polygon = pent
		gomo.color = Color.BLACK
		b.add_child(gomo)
	b.position = pos
	add_child(b)

func _construir_chao() -> void:
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
	_bola_demolicao(Vector2(1900, CHAO_Y - 1400), 1100.0, deg_to_rad(25.0))  # janela de ~3,3 s: passável até pela cadeira
	_bola_futebol(Vector2(1500, CHAO_Y - 45))
	_pilha_de_caixas(Vector2(4440, TOPO_POUSO), 4, 3)                 # no lugar da parede: derruba no embalo
	var morte := _area(Vector2(3000, CHAO_Y + 1100), Vector2(14000, 400))
	morte.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(false, "buraco"))
	_bandeira(CHECKPOINT_X, TOPO_POUSO, Color(0.3, 0.85, 0.35))
	var cp := _area(Vector2(CHECKPOINT_X, TOPO_POUSO - 600), Vector2(60, 1200))
	cp.body_entered.connect(_on_checkpoint)
	_bandeira(META_X, TOPO_POUSO, Color.WHITE, true)
	var meta := _area(Vector2(META_X, TOPO_POUSO - 600), Vector2(80, 1200))
	meta.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(true, "meta"))

## céu, nuvens e morros em paralaxe (arte gerada, original)
func _construir_fundo() -> void:
	var pb := ParallaxBackground.new()
	add_child(pb)
	var ceu := ParallaxLayer.new()
	ceu.motion_scale = Vector2.ZERO
	pb.add_child(ceu)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.27, 0.47, 0.92))
	grad.set_color(1, Color(0.62, 0.78, 0.98))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var ceu_s := Sprite2D.new()
	ceu_s.texture = gt
	ceu_s.centered = false
	ceu_s.scale = Vector2(1200, 22)
	ceu_s.position = Vector2(-4000, -3200)
	ceu.add_child(ceu_s)
	for camada in [["nuvem", 0.12, -350.0, 2.6], ["morros_longe", 0.25, 720.0, 2.2], ["morros_perto", 0.45, 980.0, 2.4]]:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(camada[1], camada[1] * 0.35)
		pb.add_child(pl)
		if camada[0] == "nuvem":
			pl.motion_mirroring = Vector2(5200, 0)
			for k in 4:
				var n := Sprite2D.new()
				n.texture = load("res://assets/ui/nuvem%d.png" % (k % 3))
				n.scale = Vector2.ONE * camada[3]
				n.position = Vector2(k * 1300 + 300 * (k % 2), camada[2] + 260 * (k % 3))
				pl.add_child(n)
		else:
			var tex: Texture2D = load("res://assets/ui/%s.png" % camada[0])
			pl.motion_mirroring = Vector2(tex.get_width() * camada[3], 0)
			var m := Sprite2D.new()
			m.texture = tex
			m.centered = false
			m.scale = Vector2.ONE * camada[3]
			m.position = Vector2(-tex.get_width(), camada[2] - tex.get_height() * camada[3] * 0.5)
			pl.add_child(m)
			var chao := Polygon2D.new()            # preenche abaixo do morro (sem céu aparecendo)
			var y0: float = camada[2] + tex.get_height() * camada[3] * 0.5 - 4.0
			chao.polygon = PackedVector2Array([Vector2(-tex.get_width(), y0), Vector2(tex.get_width() * (camada[3] + 1), y0), Vector2(tex.get_width() * (camada[3] + 1), y0 + 3000), Vector2(-tex.get_width(), y0 + 3000)])
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
	var lado := 110.0
	for i in colunas:
		for j in linhas:
			var c := RigidBody2D.new()
			c.mass = 0.6
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
			tabua.polygon = PackedVector2Array([Vector2(-h, -10), Vector2(h, -10), Vector2(h, 10), Vector2(-h, 10)])
			tabua.color = Color(0.55, 0.36, 0.17)
			c.add_child(tabua)
			c.position = base + Vector2(i * lado + lado / 2.0, -j * lado - lado / 2.0)
			c.contact_monitor = true
			c.max_contacts_reported = 2
			c.body_entered.connect(func(_b: Node) -> void:
				if c.linear_velocity.length() > 250.0: Audio.tocar("caixa", c.linear_velocity.length() / 900.0))
			add_child(c)

func _on_checkpoint(b: Node2D) -> void:
	if Game.checkpoint_x < CHECKPOINT_X and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
		Game.checkpoint_x = CHECKPOINT_X
		Game.checkpoint_chao = TOPO_POUSO
		Audio.tocar("checkpoint")
		print("[FASE] checkpoint")

func _fim(ganhou: bool, motivo: String) -> void:
	if not ativo:
		return
	ativo = false
	if ganhou:
		aviso.text = "CHEGOU!\n%.1f s" % tempo
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
	get_viewport().size_changed.connect(_posicionar_hud)
	_posicionar_hud()

func _posicionar_hud() -> void:
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
