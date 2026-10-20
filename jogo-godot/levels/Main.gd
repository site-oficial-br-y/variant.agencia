extends Node2D
## Nível de teste: chão + rampa, instancia o Player, câmera que segue e HUD tocável.
## Com o argumento "--test" roda uma checagem de física automatizada e sai.

const CHAO_Y := 1000.0
const SPAWN_X := 600.0

var player: Player
var sangue: Sangue
var aviso: Label
var camera: FollowCamera
var dist_label: Label
var recorde := 0
var _mat: PhysicsMaterial

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.56, 0.77, 0.91))
	_mat = PhysicsMaterial.new()
	_mat.friction = 1.0
	_mat.bounce = 0.0
	_construir_chao()

	player = Player.new()
	player.chao_y = CHAO_Y
	player.spawn_x = SPAWN_X
	add_child(player)
	sangue = Sangue.new()
	add_child(sangue)
	player.sangue = sangue
	player.morreu.connect(_on_morreu)

	camera = FollowCamera.new()
	camera.zoom = Vector2(0.48, 0.48)
	add_child(camera)
	camera.alvo = player.foco()

	_construir_hud()

	if "autoteste" in OS.get_cmdline_user_args():
		_rodar_teste()
	elif "screenshot" in OS.get_cmdline_user_args():
		_rodar_screenshots()

func _process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(player.chassi):
		var f := player.foco()
		if f:
			camera.alvo = f
		var alvo_x: float = player.foco().global_position.x
		recorde = maxi(recorde, int(maxf(0.0, (alvo_x - SPAWN_X) / 40.0)))
		if dist_label:
			dist_label.text = "%d m" % recorde

# ---------- terreno ----------
func _bloco(centro: Vector2, tamanho: Vector2, ang_graus: float, cor := Color(0.42, 0.35, 0.27)) -> void:
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
	var poly := Polygon2D.new()
	var hx := tamanho.x / 2.0
	var hy := tamanho.y / 2.0
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	poly.color = cor
	sb.add_child(poly)
	var grama := Polygon2D.new()
	grama.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy + 14), Vector2(-hx, -hy + 14)])
	grama.color = Color(0.35, 0.56, 0.23)
	sb.add_child(grama)
	add_child(sb)

func _construir_chao() -> void:
	_bloco(Vector2(1000, CHAO_Y + 150), Vector2(3000, 300), 0.0)      # pista inicial
	_bloco(Vector2(2720, CHAO_Y - 40), Vector2(760, 150), -20.0)      # rampa de salto
	_bloco(Vector2(3900, CHAO_Y + 230), Vector2(1700, 300), 0.0)      # pouso
	_bloco(Vector2(4560, CHAO_Y - 170), Vector2(140, 500), 0.0, Color(0.55, 0.22, 0.16))   # parede
	_bloco(Vector2(5600, CHAO_Y + 230), Vector2(2000, 300), 0.0)      # depois da parede

# ---------- HUD ----------
func _botao(texto: String, pos: Vector2, tam: Vector2, acao: String) -> void:
	var b := Button.new()
	b.text = texto
	b.position = pos
	b.custom_minimum_size = tam
	b.focus_mode = Control.FOCUS_NONE
	$HUD.add_child(b)
	if acao == "eject":
		b.pressed.connect(func(): if is_instance_valid(player): player.soltar_ragdoll(player.chassi.linear_velocity, true))
	elif acao == "reset":
		b.pressed.connect(func(): get_tree().reload_current_scene())
	else:
		b.button_down.connect(func(): Input.action_press(acao))
		b.button_up.connect(func(): Input.action_release(acao))

func _construir_hud() -> void:
	var cl := CanvasLayer.new()
	cl.name = "HUD"
	add_child(cl)
	dist_label = Label.new()
	dist_label.position = Vector2(20, 16)
	dist_label.add_theme_font_size_override("font_size", 28)
	cl.add_child(dist_label)
	var vp := get_viewport().get_visible_rect().size
	_botao("GÁS", Vector2(vp.x - 150, vp.y - 150), Vector2(120, 90), "accelerate")
	_botao("RÉ", Vector2(vp.x - 150, vp.y - 250), Vector2(120, 70), "brake")
	_botao("<", Vector2(30, vp.y - 120), Vector2(90, 90), "lean_back")
	_botao(">", Vector2(140, vp.y - 120), Vector2(90, 90), "lean_fwd")
	_botao("PULA", Vector2(vp.x - 150, vp.y - 340), Vector2(120, 70), "eject")
	_botao("R", Vector2(vp.x - 90, 12), Vector2(70, 56), "reset")
	aviso = Label.new()
	aviso.text = "VOCÊ MORREU\naperta R"
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 52)
	aviso.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 10)
	aviso.size = Vector2(vp.x, 160)
	aviso.position = Vector2(0, vp.y * 0.06)
	aviso.visible = false
	cl.add_child(aviso)

func _on_morreu() -> void:
	if aviso:
		aviso.visible = true

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

	var ok := rot_spawn < 0.35 and dx > 150.0 and player.corpos.size() == 4 and vmax < 8000.0 \
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
