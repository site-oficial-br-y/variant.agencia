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
var mec: Mecanicas
var _carga: Label
var _botao_especial: TouchScreenButton
var cps: Array = []                         # checkpoints da fase: [x, chão]
var morte_y := CHAO_Y + 2200.0
var _meta_pos := Vector2.ZERO
var _explosoes := 0
var _sorteio := RandomNumberGenerator.new()  # decoração: mesma fase, mesma arrumação

var player: Player
var sangue: Sangue
var aviso: Label
var camera: FollowCamera
var dist_label: Label
var recorde := 0
var _mat: PhysicsMaterial

func _ready() -> void:
	Audio.musica_menu(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("p="):
			Game.personagem = a.substr(2)
		if a.begins_with("f="):
			Game.fase = int(a.substr(2))
	Engine.time_scale = Game.RITMO           # física a 180 Hz x 3 = mesmo passo de 1/60 s de jogo
	RenderingServer.set_default_clear_color(Color(0.33, 0.55, 0.93))
	tema = ["campo", "obra", "montanha", "lab", "boss", "mercado", "escola", "colorido", "julgamento"][clampi(Game.fase, 1, 9) - 1]
	_construir_fundo("hw" if tema == "campo" else tema)
	_mat = PhysicsMaterial.new()
	_mat.friction = 1.0
	_mat.bounce = 0.0
	pecas = Pecas.new(self, _mat, _on_perigo)
	mec = Mecanicas.new(self, pecas, func() -> Player: return player)
	pecas.ao_explodir = _ao_explodir
	_construir_chao()
	if "ultimo_cp" in OS.get_cmdline_user_args() and cps.size() > 0:    # teste: começa perto da chegada
		Game.checkpoint_x = (cps[cps.size() - 1] as Vector2).x
		Game.checkpoint_chao = (cps[cps.size() - 1] as Vector2).y

	_criar_jogador(SPAWN_X, CHAO_Y)
	sangue = Sangue.new()
	sangue.escala = 3.2
	add_child(sangue)
	player.sangue = sangue
	camera = FollowCamera.new()
	camera.zoom = Vector2(0.26, 0.26)         # câmera perto como no gênero: boneco ~metade da tela
	camera.offset = Vector2(800, -150)
	add_child(camera)
	camera.alvo = player.foco()
	_construir_hud()
	if Online.ativo:
		_iniciar_online()
	_pos_jogador()

func _criar_jogador(x: float, y: float) -> void:
	player = Player.new()
	player.personagem = Game.personagem
	player.pasta = Game.pasta(Game.personagem)
	player.chao_y = y
	player.spawn_x = x
	player.morreu.connect(_on_morreu)
	player.bateu_chao.connect(func(pos: Vector2, forca: float) -> void: pecas.poeira(pos, forca))
	player.explodir_cb = func(pos: Vector2, raio: float, dv: float) -> void: mec.explosao(pos, raio, dv)

func _pos_jogador() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("queda="):                    # teste: nasce lá no alto e despenca
			player.chao_y = CHAO_Y - float(a.substr(6))
	player.fundo_y = morte_y - 300.0
	do_inicio = Game.checkpoint_x <= 0.0
	if Game.checkpoint_x > 0.0:               # renasce no checkpoint depois de morrer
		player.spawn_x = Game.checkpoint_x
		player.chao_y = Game.checkpoint_chao
	add_child(player)
	move_child(player, sangue.get_index())
	camera.alvo = player.foco()

	if "teste_queda" in OS.get_cmdline_user_args():
		_teste_queda()
	if "contar" in OS.get_cmdline_user_args():       # tamanho da fase: nós e comprimento
		var n := 0
		var pilha: Array = [self]
		while pilha.size() > 0:
			var x: Node = pilha.pop_back()
			n += 1
			pilha.append_array(x.get_children())
		print("[FASE] nos=%d comprimento=%.0f" % [n, _meta_pos.x])
		get_tree().quit()
	if "sem_hud" in OS.get_cmdline_user_args():      # capturas para miniatura
		$HUD.visible = false
	if Game.fase == 7:
		_inicio_7.call_deferred()
	if Game.fase == 8:
		_inicio_8.call_deferred()
	if Game.fase == 9:
		_inicio_9.call_deferred()
	if "autoteste" in OS.get_cmdline_user_args():
		_rodar_teste()
	elif "screenshot" in OS.get_cmdline_user_args():
		_rodar_screenshots()


func _process(delta: float) -> void:
	if Online.ativo:
		_process_online(delta)
	for p in _pendulos:
		var bola: Node2D = p["bola"]
		var gancho: Vector2 = bola.global_position + (p["ancora"] - bola.global_position).normalized() * float(p["raio"]) * 0.95
		(p["corrente"] as Line2D).points = PackedVector2Array([p["ancora"], gancho])
	if ativo:
		tempo += delta / Engine.time_scale      # cronômetro em segundos de verdade
		if Online.ativo and Online.corrida.get("largou", false):   # online: relógio desde a largada (vale depois de morrer)
			tempo = (Time.get_ticks_msec() - int(Online.corrida["inicio_ms"])) / 1000.0
		# caiu do veículo: a tentativa acaba 2,5 s depois (dá tempo de rolar até a chegada)
		if is_instance_valid(player) and not player.montado:
			if _caiu_em < 0.0:
				_caiu_em = tempo
			elif tempo - _caiu_em > 2.5:
				_fim(false, "caiu")
	if is_instance_valid(player) and is_instance_valid(player.chassi):
		var f := player.foco()
		if f and not has_meta("cam_base"):             # arena do Çtamandura: câmera parada
			camera.alvo = f
		var alvo_x: float = player.foco().global_position.x
		recorde = maxi(recorde, int(maxf(0.0, (alvo_x - SPAWN_X) / 40.0)))
		_atualizar_carga()
		if dist_label:
			dist_label.text = "%s   %d m   %.1f s" % [Game.NOMES.get(Game.personagem, ""), recorde, tempo]

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
	bola.set_meta("L", comprimento)                 # para quem quiser prever o balanço (bot)
	bola.set_meta("th0", angulo_ini)
	bola.set_meta("w", w if w > 0.0 else sqrt(980.0 / comprimento))
	var corrente := pecas.vestir_bola(bola, raio)
	var som := _area(Vector2.ZERO, Vector2(raio * 2.1, raio * 2.1))
	remove_child(som)
	som.position = Vector2.ZERO
	bola.add_child(som)
	som.body_entered.connect(func(b: Node2D) -> void:
		if (b.is_in_group("veiculo") or b.is_in_group("piloto")) and (bola.get_meta("vel") as Vector2).length() > 150.0:
			pecas.som("metal", bola.global_position, 0.9))
	_pendulos.append({"bola": bola, "ancora": ancora, "L": comprimento, "th0": angulo_ini,
		"w": w if w > 0.0 else sqrt(980.0 / comprimento), "corrente": corrente, "raio": raio})
	_mover_pendulos(0.0)

func _physics_process(delta: float) -> void:
	_t_fisica += delta
	_mover_pendulos(_t_fisica)
	pecas.mover_pistoes(_t_fisica)
	mec.atualizar(delta)
	if Game.fase == 4:
		_atualizar_lab(delta)
	if Game.fase == 6:
		_atualizar_mercado(delta)
	if Game.fase == 7:
		_atualizar_escola(delta)
	if Game.fase == 8 and geresch:
		geresch.atualizar(delta)
		_mover_esmagadores(delta)
		if not geresch.ativo:                          # fase normal: peças caindo em você
			var px := player.foco().global_position.x if is_instance_valid(player) and is_instance_valid(player.chassi) else 0.0
			geresch.chuva(delta, 2.4 if px > 1500.0 and px < _chuva8_x1 and not _cena8 else 0.0)
		if _palco8 and not _palco8.get("camera"):
			_palco8.set("camera", camera)
	if Game.fase == 9 and julgamento:
		julgamento.atualizar(delta, camera)
		var px9 := player.foco().global_position.x if is_instance_valid(player) and is_instance_valid(player.chassi) else 0.0
		julgamento.chuva(delta, 2.6 if px9 > 1500.0 and px9 < _chuva9_x1 and not _cena9 else 0.0)
		ctamandura.atualizar(delta)
	if boss:
		boss.atualizar(delta)
		_rodada_boss(delta)

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
		4: _fase_4()
		5: _fase_5()
		6: _fase_6()
		7: _fase_7()
		8: _fase_8()
		9: _fase_9()
		_: _fase_1()

## marcos comuns: zona de morte, checkpoints (lista de Vector2: x, chão) e chegada
func _marcos(checkpoints: Array, chegada: Vector2, y_morte: float, bandeiras := true) -> void:
	morte_y = y_morte
	var morte := _area(Vector2(chegada.x / 2.0, morte_y), Vector2(absf(chegada.x) * 2.0 + 12000.0, 400))
	morte.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(false, "buraco"))
	var usar_cp := Game.CHECKPOINTS or "com_cp" in OS.get_cmdline_user_args()   # teste: liga só pra medir trecho a trecho
	for c in (checkpoints if usar_cp else []):
		var ck: Vector2 = c
		cps.append(ck)
		_bandeira(ck.x, ck.y, Color(0.3, 0.85, 0.35))
		var cp := _area(Vector2(ck.x, ck.y - 600), Vector2(60, 1200))
		cp.body_entered.connect(_on_checkpoint.bind(ck))
	if usar_cp and checkpoints.size() > 0:
		cp_x = (checkpoints[0] as Vector2).x
		cp_chao = (checkpoints[0] as Vector2).y
	if bandeiras:
		_bandeira(chegada.x, chegada.y, Color.WHITE, true)
	var meta := _area(Vector2(chegada.x, chegada.y - 600), Vector2(80, 1200))
	meta.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _fim(true, "meta"))

# ---------- trechos reutilizáveis ----------
## Cada trecho começa em `p` (onde o chão do trecho anterior termina, na mesma altura)
## e devolve o ponto onde o próximo começa. As fases são sequências de trechos.
const DECOR := {"campo": ["arvore1", "arvore2", "pedra1", "pedra2"], "obra": ["cone", "cone", "pedra1"],
	"montanha": ["pinheiro1", "pinheiro2", "pinheiro2", "pedra1"]}
var tema := "campo"

func _enfeitar(x0: float, x1: float, y: float) -> void:
	if tema != "":                                  # visual chapado do gênero: pista limpa, sem enfeite
		return
	var x := x0 + _sorteio.randf_range(150, 700)
	while x < x1 - 200:
		var nome: String = DECOR[tema][_sorteio.randi() % DECOR[tema].size()]
		if nome == "cone":
			pecas.cone(Vector2(x, y))
		elif nome.begins_with("pedra"):
			pecas.sprite(nome, Vector2(x, y), _sorteio.randf_range(0.9, 1.3), -2, _sorteio.randf() < 0.5)
		else:
			pecas.sprite(nome, Vector2(x, y), _sorteio.randf_range(2.0, 2.6), -4, _sorteio.randf() < 0.5)
		x += _sorteio.randf_range(1100, 2200)

func _t_plano(p: Vector2, comp: float, enfeite := true) -> Vector2:
	pecas.terreno(PackedVector2Array([p, p + Vector2(comp, 0)]), p.y + 2600.0)
	if enfeite:
		_enfeitar(p.x, p.x + comp, p.y)
	return p + Vector2(comp, 0)

## subida (dy < 0) ou descida (dy > 0) com começo e fim retos
func _t_ladeira(p: Vector2, comp: float, dy: float, cerca := false) -> Vector2:
	pecas.terreno(PackedVector2Array([p, p + Vector2(250, 0), p + Vector2(comp - 250, dy), p + Vector2(comp, dy)]),
		maxf(p.y, p.y + dy) + 1700.0)
	if cerca:
		_cerca(p + Vector2(250, 0), p + Vector2(comp - 250, dy))
	return p + Vector2(comp, dy)

## ponte de madeira sobre fosso de espinhos
func _t_ponte(p: Vector2, comp: float, dy: float) -> Vector2:
	var fundo := maxf(p.y, p.y + dy) + 1100.0
	pecas.terreno(PackedVector2Array([Vector2(p.x, fundo), Vector2(p.x + comp, fundo)]), fundo + 600.0, false)
	pecas.espinhos(p.x + 40, p.x + comp - 40, fundo)
	pecas.ponte_madeira(p + Vector2(-50, 0), p + Vector2(comp + 60, dy), fundo)
	return p + Vector2(comp, dy)

## guindaste com bola de demolição numa reta (a bola passa na altura do peito
## e sobe alto nas pontas: brecha de ~1,2–1,9 s por balanço, ver level-design §8)
func _t_bola(p: Vector2) -> Vector2:
	_t_plano(p, 4300, false)
	var piv := Vector2(p.x + 2600, p.y - 700.0 - 450.0 - 1300.0)
	pecas.guindaste(piv.x + 2200, p.y, piv.y - 480.0, piv.x - 150, piv.x, piv)
	_bola_demolicao(piv, 1300.0, deg_to_rad(85.0), 450.0, 0.38)
	return p + Vector2(4300, 0)

## rampa de madeira saltando um lago
func _t_lago(p: Vector2) -> Vector2:
	pecas.terreno(PackedVector2Array([p, p + Vector2(800, 0)]), p.y + 2600.0)
	pecas.rampa(p.x, p.x + 800, p.y, 280)
	pecas.terreno(PackedVector2Array([p + Vector2(800, 1200), p + Vector2(1800, 1200)]), p.y + 2600.0, false)
	pecas.agua(p.x + 800, p.x + 1800, p.y + 400, p.y + 1200)
	pecas.terreno(PackedVector2Array([p + Vector2(1800, 80), p + Vector2(2400, 160), p + Vector2(3200, 160)]), p.y + 2600.0)
	return p + Vector2(3200, 160)

## passarela de vigas sobre ravina de espinhos, com caixas e (opcional) TNT
func _t_passarela(p: Vector2, comp := 2000.0, com_tnt := true, caixas := true) -> Vector2:
	var fundo := p.y + 1140.0
	pecas.terreno(PackedVector2Array([Vector2(p.x, fundo), Vector2(p.x + comp, fundo)]), fundo + 600.0, false)
	pecas.espinhos(p.x + 40, p.x + comp - 40, fundo)
	pecas.passarela(p.x - 40, p.x + comp + 40, p.y, fundo, [p.x + comp * 0.3, p.x + comp * 0.72])
	if com_tnt:
		mec.serra_trilho(p + Vector2(comp * 0.68, 0), 3.2, _sorteio.randf_range(0.0, 3.2))
	return p + Vector2(comp, 0)

func _t_gangorra(p: Vector2) -> Vector2:
	_t_plano(p, 1300, false)
	_gangorra(p + Vector2(650, -95), 1100.0)
	return p + Vector2(1300, 0)

## duas vigas com um vão de espinhos no meio
func _t_vigas(p: Vector2) -> Vector2:
	var poco := p.y + 1300.0
	pecas.terreno(PackedVector2Array([Vector2(p.x, poco), Vector2(p.x + 1800, poco)]), poco + 600.0, false)
	pecas.espinhos(p.x + 40, p.x + 1760, poco)
	pecas.passarela(p.x, p.x + 800, p.y, poco, [p.x + 400])
	pecas.passarela(p.x + 1000, p.x + 1800, p.y, poco, [p.x + 1400])
	return p + Vector2(1800, 0)

func _t_tabuas(p: Vector2, comp := 1000.0) -> Vector2:
	var poco := p.y + 1300.0
	_tabuas_que_caem(p.x, p.x + comp, p.y)
	pecas.terreno(PackedVector2Array([Vector2(p.x, poco), Vector2(p.x + comp, poco)]), poco + 600.0, false)
	pecas.espinhos(p.x + 40, p.x + comp - 40, poco)
	return p + Vector2(comp, 0)

func _t_prensa(p: Vector2) -> Vector2:
	_t_plano(p, 3400, false)
	pecas.prensa(p.x + 2700, p.y, 6.0, _sorteio.randf_range(0.0, 6.0))
	return p + Vector2(3400, 0)

## rampinha e salto sobre o fosso das serras (vem embalado de uma descida)
func _t_serras(p: Vector2) -> Vector2:
	pecas.terreno(PackedVector2Array([p, p + Vector2(400, 0), p + Vector2(900, -200)]), p.y + 2600.0)
	pecas.terreno(PackedVector2Array([p + Vector2(900, 600), p + Vector2(2000, 600)]), p.y + 2600.0, false)
	pecas.espinhos(p.x + 940, p.x + 1960, p.y + 600)
	pecas.serra(p + Vector2(1230, 360), 330.0)
	pecas.serra(p + Vector2(1720, 360), 330.0)
	pecas.terreno(PackedVector2Array([p + Vector2(2000, -100), p + Vector2(2800, 100), p + Vector2(3400, 100)]), p.y + 2600.0)
	return p + Vector2(3400, 100)

## obstáculo de reta (antes era TNT): alterna serra no trilho e mina com lombada,
## os dois dá pra passar com qualquer personagem
var _reta_n := 0
func _t_tnt(p: Vector2) -> Vector2:
	_reta_n += 1
	if _reta_n % 2 == 1:
		_t_plano(p, 2000, false)
		mec.serra_trilho(p + Vector2(1100, 0), 3.2, _sorteio.randf_range(0.0, 3.2))
		return p + Vector2(2000, 0)
	_t_plano(p, 2200, false)
	pecas.rampa(p.x + 400, p.x + 1000, p.y, 170)
	mec.mina(p + Vector2(1450, 0))
	pecas.placa_perigo(p + Vector2(250, 0))
	return p + Vector2(2200, 0)

## penhasco: anda reto e despenca `queda` px para o próximo patamar
func _t_degrau(p: Vector2, queda: float) -> Vector2:
	_t_plano(p, 700, false)
	return _t_plano(p + Vector2(700, queda), 900)

## chão ondulado (lombadas)
func _t_ondas(p: Vector2, n := 4, amp := 110.0) -> Vector2:   # lombada baixa e longa: rodinha não trava
	var pts := PackedVector2Array([p])
	for i in n:
		pts.append(p + Vector2(i * 1000 + 500, -amp))
		pts.append(p + Vector2(i * 1000 + 1000, 0))
	pts.append(p + Vector2(n * 1000 + 300, 0))
	pecas.terreno(pts, p.y + 2600.0)
	return p + Vector2(n * 1000 + 300, 0)

## rampinha de madeira e salto por cima de um fosso de espinhos
func _t_salto(p: Vector2) -> Vector2:
	pecas.terreno(PackedVector2Array([p, p + Vector2(800, 0)]), p.y + 2600.0)
	pecas.rampa(p.x, p.x + 800, p.y, 260)
	pecas.terreno(PackedVector2Array([p + Vector2(800, 1100), p + Vector2(1600, 1100)]), p.y + 2600.0, false)
	pecas.espinhos(p.x + 840, p.x + 1560, p.y + 1100)
	pecas.terreno(PackedVector2Array([p + Vector2(1600, 60), p + Vector2(2200, 140), p + Vector2(2800, 140)]), p.y + 2600.0)
	return p + Vector2(2800, 140)

## ladeira de concreto sobe até o telhado de um prédio, atravessa e cai do outro lado
func _t_predio(p: Vector2, altura := 520.0) -> Vector2:
	var sobe := altura * 2.6
	pecas.terreno(PackedVector2Array([p, p + Vector2(250, 0), p + Vector2(250 + sobe, -altura),
		p + Vector2(350 + sobe, -altura)]), p.y + 2600.0)
	var xb := p.x + 350 + sobe
	pecas.predio(xb, xb + 1800, p.y, altura)
	pecas.terreno(PackedVector2Array([Vector2(xb, p.y), Vector2(xb + 1800, p.y)]), p.y + 2600.0, false)
	var xd := xb + 1800                             # desce do telhado por rampa (queda seca derrubava a cadeira)
	pecas.terreno(PackedVector2Array([Vector2(xd - 100, p.y - altura), Vector2(xd, p.y - altura),
		Vector2(xd + sobe, p.y), Vector2(xd + sobe + 250, p.y)]), p.y + 2600.0)
	return _t_plano(Vector2(xd + sobe + 250, p.y), 1200)

## pista elevada descendo (queda > 0) ou subindo (queda < 0) sobre treliça
func _t_mega(p: Vector2, comp: float, queda: float) -> Vector2:
	var fim := p + Vector2(comp, queda)
	var pts := PackedVector2Array([p - Vector2(60, 0)])
	for i in 15:                                    # perfil suave (smoothstep): sem quina em alta velocidade
		var t := i / 14.0
		pts.append(p + Vector2(comp * t, queda * smoothstep(0.0, 1.0, t)))
	pts.append(fim + Vector2(60, 0))
	pecas.pista_elevada(pts, maxf(p.y, fim.y) + 2600.0)
	return fim

## salto gigante: rampinha de 31°, abismo com espinhos e pouso numa descida longa
## de 25° (pouso em descida não quebra; calculado para 1000–1300 px/s)
func _t_mega_salto(p: Vector2) -> Vector2:
	pecas.pista_elevada(PackedVector2Array([p - Vector2(60, 0), p + Vector2(500, 0), p + Vector2(1100, -150),
		p + Vector2(1400, -330)]), p.y + 2600.0)
	pecas.terreno(PackedVector2Array([p + Vector2(1450, 1900), p + Vector2(2250, 1900)]), p.y + 2500.0, false)
	pecas.espinhos(p.x + 1490, p.x + 2210, p.y + 1900)
	var fim := p + Vector2(7700, 2400)
	pecas.pista_elevada(PackedVector2Array([p + Vector2(2300, 100), p + Vector2(2700, 290), p + Vector2(6800, 2200),
		p + Vector2(7400, 2400), fim + Vector2(60, 0)]), p.y + 4800.0)
	return fim

## voo: rampinha de 15°, vão com perigo (espinhos, água ou serras) e pouso numa
## descida longa de 26° — aterrissa de 900 a 3300 px/s sempre ~25° de ângulo
## (calculado; ver level-design §8). Depois do pouso, curva e reta.
const POUSO := 9500.0                               # pista de pouso: pega de 900 a ~2400 px/s

func _t_voo(p: Vector2, perigo := "espinhos") -> Vector2:
	pecas.pista_elevada(PackedVector2Array([p - Vector2(60, 0), p + Vector2(200, 0), p + Vector2(500, -30),
		p + Vector2(800, -110)]), p.y + 2600.0)
	var fosso := p.y + 1500.0
	if perigo == "agua":
		pecas.terreno(PackedVector2Array([p + Vector2(820, 2300), p + Vector2(1480, 2300)]), p.y + 2900.0, false)
		pecas.agua(p.x + 820, p.x + 1480, p.y + 700, p.y + 2300)
	else:
		pecas.terreno(PackedVector2Array([Vector2(p.x + 820, fosso), Vector2(p.x + 1480, fosso)]), fosso + 700.0, false)
		pecas.espinhos(p.x + 860, p.x + 1440, fosso)
		if perigo == "serras":
			pecas.serra(Vector2(p.x + 1150, fosso - 500), 330.0)
	var inc := tan(deg_to_rad(26.0))
	var desce := POUSO * inc
	var saida := 2600.0                             # saída longa: a inclinação vai a zero aos poucos
	var pts := PackedVector2Array([p + Vector2(1500, 100), p + Vector2(1500 + POUSO, 100 + desce)])
	for i in range(1, 9):
		var u := i / 8.0
		pts.append(p + Vector2(1500 + POUSO + saida * u, 100 + desce + inc * saida * (u - u * u / 2.0)))
	var fim: Vector2 = pts[pts.size() - 1]
	pts.append(fim + Vector2(60, 0))
	pecas.pista_elevada(pts, fim.y + 2600.0)
	return fim

func _largada() -> Vector2:
	var p := _t_plano(Vector2(-2600, CHAO_Y), 1100, false)
	pecas.placa(Vector2(-900, CHAO_Y), "LARGADA")
	return _t_plano(p, 2800)

func _chegada(p: Vector2, cps_fase: Array) -> void:
	_t_plano(p, 5000)
	pecas.portal_chegada(p + Vector2(1500, 0))
	_meta_pos = p + Vector2(2200, 0)
	_marcos(cps_fase, p + Vector2(1500, 0), pecas.y_max + 600.0, false)

func _cp(lista: Array, p: Vector2, dx := 200.0) -> void:
	lista.append(p + Vector2(dx, 0))

# ---------- trechos com as mecânicas novas (armadilhas, plataformas, impulsos) ----------
func _fosso(x0: float, x1: float, y: float) -> void:
	pecas.terreno(PackedVector2Array([Vector2(x0, y + 1400), Vector2(x1, y + 1400)]), y + 2100.0, false)
	pecas.espinhos(x0 + 40, x1 - 40, y + 1400)

## minas com saída: cada uma tem uma lombadinha de pulo antes. Embalado você salta
## por cima; devagar, encosta e leva o tranco (pode perder perna, não morre na hora)
func _t_minas(p: Vector2) -> Vector2:
	_t_plano(p, 4600, false)
	for dx in [1200.0, 3200.0]:
		pecas.rampa(p.x + dx - 900, p.x + dx - 300, p.y, 170)
		mec.mina(p + Vector2(dx + 150, 0))
		pecas.placa_perigo(p + Vector2(dx - 1100, 0))
	return p + Vector2(4600, 0)

## drone-bomba pairando: acorda quando você chega e te persegue; corra
func _t_drone(p: Vector2) -> Vector2:
	_t_plano(p, 4200, false)
	mec.bomba_perseguidora(p + Vector2(2600, -1500), 2600.0)
	return p + Vector2(4200, 0)

## plataformas que somem em sequência ("onda"): sai quando a primeira acabou de aparecer
func _t_temporarias(p: Vector2) -> Vector2:
	_t_plano(p, 700, false)
	_fosso(p.x + 700, p.x + 3700, p.y)
	for k in 3:
		mec.plataforma_temporaria(p + Vector2(1200 + k * 1000, 0), 980.0, 3.6, -k * 0.2)
	return _t_plano(p + Vector2(3700, 0), 800, false)

## aparecem quando você chega perto e somem logo depois: não dá pra parar no meio
func _t_retrateis(p: Vector2) -> Vector2:
	_t_plano(p, 600, false)
	_fosso(p.x + 600, p.x + 3600, p.y)
	for k in 3:
		mec.plataforma_retratil(p + Vector2(1100 + k * 1000, 0), 980.0, 4.0)
	return _t_plano(p + Vector2(3600, 0), 800, false)

## lajes que sobem e descem fora de fase sobre o fosso
func _t_moveis(p: Vector2) -> Vector2:
	_t_plano(p, 600, false)
	_fosso(p.x + 600, p.x + 3600, p.y)
	for k in 3:
		var c := p + Vector2(1100 + k * 1000, 0)
		mec.plataforma_movel(c + Vector2(0, -220), c + Vector2(0, 220), 980.0, 3.0 + k * 0.4)
	return _t_plano(p + Vector2(3600, 0), 800, false)

## ponte de lajes rachadas: cedem pouco depois de receber o peso (passa quem não para)
func _t_quebraveis(p: Vector2) -> Vector2:
	_t_plano(p, 900, false)
	_fosso(p.x + 900, p.x + 4400, p.y)
	for k in 5:
		mec.plataforma_quebravel(p + Vector2(1250 + k * 700, 0), 690.0)
	return _t_plano(p + Vector2(4400, 0), 900, false)

## trampolim antes de um muro: a mola joga por cima
func _t_trampolim(p: Vector2) -> Vector2:
	# a mola joga pra cima de um patamar comprido (pousa fácil, qualquer veículo) e desce por rampa
	_t_plano(p, 1700, false)
	mec.trampolim(p + Vector2(950, 0), 1650.0, 750.0)
	pecas.terreno(PackedVector2Array([p + Vector2(1700, -650), p + Vector2(4600, -650), p + Vector2(6200, 0),
		p + Vector2(6500, 0)]), p.y + 2600.0)
	return p + Vector2(6500, 0)

## painel de aceleração na reta antes de um voo: salto bem mais longo
func _t_turbo_salto(p: Vector2) -> Vector2:
	_t_plano(p, 1600, false)
	mec.painel_aceleracao(p + Vector2(700, 0), 900.0, 650.0, 2400.0)   # pouso do voo aguenta até ~3300
	return _t_voo(p + Vector2(1600, 0), "espinhos")

## túnel de vento por cima do abismo: empurra pra frente e um pouco pra cima
func _t_tunel(p: Vector2) -> Vector2:
	_t_plano(p, 700, false)
	_fosso(p.x + 700, p.x + 3300, p.y)
	mec.tunel_vento(p + Vector2(300, -450), p + Vector2(3700, -500), 1100.0, 2400.0)
	return _t_plano(p + Vector2(3300, 0), 900, false)

## prédio por dentro, de cima pra baixo (estilo Happy Wheels): cada andar é uma laje;
## no fim dela tem um buraco e você cai pro andar de baixo, que continua pra frente.
## Obstáculos dentro: serra no teto, TNT, mina, prensa. Devolve o ponto no térreo.
const ANDAR := 1700.0
func _t_andares(p: Vector2, n := 4) -> Vector2:
	var larg := 4200.0
	var x0 := p.x
	var topo := p.y
	var fundo := p.y + n * ANDAR
	var parede_x1 := x0 + n * (larg - 500.0) + 1400.0
	# fachada de fundo: concreto escuro com janelas, do teto ao térreo
	pecas.poligono(Pecas.retangulo(Vector2((x0 + parede_x1) / 2.0, (topo - 900.0 + fundo) / 2.0),
		Vector2(parede_x1 - x0, fundo - topo + 900.0)), Color(0.36, 0.34, 0.36), -4)
	for k in n + 1:
		var y := topo + k * ANDAR - 700.0
		var xj := x0 + 300.0
		while xj < parede_x1 - 300.0:
			pecas.poligono(Pecas.retangulo(Vector2(xj, y), Vector2(260, 360)), Color(0.55, 0.72, 0.85, 0.85), -3)
			pecas.poligono(Pecas.retangulo(Vector2(xj - 40, y - 40), Vector2(70, 220)), Color(0.8, 0.9, 0.97, 0.6), -3)
			xj += 700.0
	var obst := ["serra", "tnt", "mina", "prensa", "serra", "tnt"]
	for k in n:
		var a := Vector2(x0 + k * (larg - 500.0), topo + k * ANDAR)
		# laje do andar (o buraco é o espaço até a próxima laje, que começa embaixo do fim desta)
		pecas.terreno(PackedVector2Array([a, a + Vector2(larg, 0)]), a.y + 160.0)
		pecas.poligono(Pecas.retangulo(a + Vector2(larg / 2.0, 220), Vector2(larg, 120)), Color(0.28, 0.27, 0.3), 1)
		# pilares entre os andares (atrás)
		for px in [a.x + 250.0, a.x + larg * 0.5, a.x + larg - 250.0]:
			pecas.poligono(Pecas.retangulo(Vector2(px, a.y + ANDAR / 2.0 + 150.0), Vector2(110, ANDAR - 300.0)), Color(0.45, 0.43, 0.45), -2)
		# placa com o número do andar
		var num := Label.new()
		num.text = "%dº" % (n - k)
		num.add_theme_font_size_override("font_size", 200)
		num.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		num.add_theme_color_override("font_outline_color", Color.BLACK)
		num.add_theme_constant_override("outline_size", 30)
		num.position = a + Vector2(500, -900)
		num.z_index = -1
		add_child(num)
		# borda do buraco: faixa de perigo
		pecas.poligono(Pecas.retangulo(a + Vector2(larg - 120, 12), Vector2(240, 30)), Color.WHITE, 3, pecas.tex("perigo"), 0.6)
		if k == 0:
			continue
		var meio := a + Vector2(larg * 0.55, 0)
		match obst[(k - 1) % obst.size()]:
			"serra":                                    # serra presa no teto: passa por baixo
				pecas.serra(meio + Vector2(0, -ANDAR + 160.0), 240.0)   # sobra ~250 px acima da cabeça
			"tnt":
				pecas.rampa(meio.x - 900, meio.x - 300, meio.y, 170)   # no prédio não cabe prateleira: mina com lombada
				mec.mina(meio + Vector2(150, 0))
			"mina":
				pecas.rampa(meio.x - 900, meio.x - 300, meio.y, 170)
				mec.mina(meio + Vector2(150, 0))
			"prensa":
				pecas.prensa(meio.x, meio.y, 6.0, _sorteio.randf_range(0.0, 6.0))
	var saida := Vector2(x0 + (n - 1) * (larg - 500.0) + larg, fundo - ANDAR)
	return _t_plano(saida, 1200, false)

## bloco de mecânicas novas: cada volta da fase usa uma combinação diferente
func _bloco_novo(p: Vector2, c: Array, combinacao: Array) -> Vector2:
	for nome in combinacao:
		_cp(c, p)
		p = call("_t_" + nome, p)
		p = _t_plano(p, 500, false)
	return p

## quanto o voo desce (rampa + descida de 26° + saída); a subida seguinte devolve isso
func _queda_voo() -> float:
	var inc := tan(deg_to_rad(26.0))
	return 100.0 + POUSO * inc + inc * 2600.0 * 0.5

# ---------- FASE 6: Atacadão (mercado + chefe Vendedor) ----------
var vendedor: Vendedor
var _carrinhos: Array = []
var _portao6: StaticBody2D
var MERC_CP := 23500.0
var MERC_ARENA := 25500.0
var MERC_FIM := 37000.0
var mercado_x0 := 0.0

func _fase_6() -> void:
	var y := CHAO_Y
	pecas.cor_chao = Color(0.72, 0.7, 0.66)
	_parede_arena(-2700.0, y)
	# 1ª parte: fase normal (obstáculos de sempre) dentro do mercado
	var p := _largada()
	for nome in ["ondas", "prensa", "bola", "gangorra", "temporarias", "tnt", "quebraveis", "moveis"]:
		p = call("_t_" + nome, p)
		p = _t_plano(p, 500, false)
	mercado_x0 = p.x
	MERC_CP = mercado_x0 + 800.0
	MERC_ARENA = mercado_x0 + 2600.0
	MERC_FIM = mercado_x0 + 15000.0
	# chão reto até o fim (checkpoint, arena e saída) e o fundo de mercado inteiro
	pecas.terreno(PackedVector2Array([p, Vector2(MERC_FIM + 6000.0, y)]), y + 2600.0, false)
	_mercado_cenario(y)
	# checkpoint e arena do chefe logo depois da parte normal
	_cp_forcado(Vector2(MERC_CP, y))
	_portao6 = StaticBody2D.new()
	_portao6.collision_layer = 0b01
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(260, 30000)
	cs.shape = r
	cs.position = Vector2(0, -13200)
	_portao6.add_child(cs)
	pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(260, 3600)), Color(0.45, 0.47, 0.5), 3, null, 1.0, _portao6)
	pecas.poligono(Pecas.retangulo(Vector2(0, 1500), Vector2(260, 160)), Color.WHITE, 3, pecas.tex("perigo"), 0.8, _portao6)
	_portao6.position = Vector2(MERC_FIM - 2500.0, y - 1800.0)
	add_child(_portao6)
	pecas.portal_chegada(Vector2(MERC_FIM, y))
	_meta_pos = Vector2(MERC_FIM + 700, y)
	_marcos([], Vector2(MERC_FIM, y), y + 3200.0, false)
	vendedor = Vendedor.new()
	add_child(vendedor)
	vendedor.global_position = Vector2(MERC_ARENA + 2000.0, y + 80.0)
	vendedor.montar(self, y)
	vendedor.cansou.connect(func() -> void:
		var tw := _portao6.create_tween()
		tw.tween_property(_portao6, "position:y", _portao6.position.y - 3700.0, 1.2)
		tw.tween_callback(func() -> void: _portao6.queue_free()))
	var gat := _area(Vector2(MERC_ARENA, y - 700), Vector2(200, 1600))
	gat.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): vendedor.comecar())

## checkpoint desta fase (mesmo com os checkpoints gerais desligados)
func _cp_forcado(ck: Vector2) -> void:
	_bandeira(ck.x, ck.y, Color(0.3, 0.85, 0.35))
	var cp := _area(Vector2(ck.x, ck.y - 600), Vector2(60, 1200))
	cp.body_entered.connect(_on_checkpoint.bind(ck))

func _carrinho_solto(base: Vector2) -> void:
	var c := RigidBody2D.new()
	c.mass = 3.0
	c.collision_layer = 0b1000
	c.collision_mask = 0b1011
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(800, 600)
	cs.shape = r
	c.add_child(cs)
	var s := Sprite2D.new()
	s.texture = load("res://assets/bicho/veiculo.png")
	s.scale = Vector2.ONE * 0.62
	c.add_child(s)
	c.position = base + Vector2(0, -330)
	c.freeze = true
	c.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	add_child(c)
	_carrinhos.append(c)

func _atualizar_mercado(_dt: float) -> void:
	if not is_instance_valid(player):
		return
	var px := player.foco().global_position.x
	for c in _carrinhos.duplicate():
		if not is_instance_valid(c):
			_carrinhos.erase(c)
			continue
		var rc := c as RigidBody2D
		if rc.freeze and rc.global_position.x - px < 3600.0:   # chegou perto: o carrinho desce
			rc.freeze = false
			rc.linear_velocity = Vector2(-1100, 0)
			Audio.tocar("caixa", 0.6)
	if vendedor:
		vendedor.atualizar(_dt)

## fundo do mercado: parede, gôndolas cheias de produto, placas penduradas
func _mercado_cenario(y: float) -> void:
	var teto := y - 3000.0
	pecas.poligono(Pecas.retangulo(Vector2(MERC_FIM / 2.0, (teto + y) / 2.0), Vector2(MERC_FIM + 12000.0, y - teto)), Color(0.93, 0.9, 0.82), -7)
	pecas.poligono(Pecas.retangulo(Vector2(MERC_FIM / 2.0, teto + 150.0), Vector2(MERC_FIM + 12000.0, 300)), Color(0.4, 0.42, 0.45), -6)
	var cores := [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(1, 0.8, 0.2), Color(0.3, 0.75, 0.3), Color(1, 0.5, 0.1), Color(0.8, 0.3, 0.8)]
	var x := -3000.0
	var m := 0
	while x < MERC_FIM + 4000.0:
		# gôndola
		var gx := x + 1000.0
		pecas.poligono(Pecas.retangulo(Vector2(gx, y - 1000), Vector2(1700, 2000)), Color(0.62, 0.65, 0.7), -6)
		for f in 5:
			var fy := y - 1850.0 + f * 380.0
			pecas.poligono(Pecas.retangulo(Vector2(gx, fy + 160), Vector2(1700, 36)), Color(0.4, 0.42, 0.46), -5)
			for i in 9:
				var c: Color = cores[(m + f * 2 + i) % cores.size()]
				var h := 200.0 + float((i * 37 + f * 13 + m) % 3) * 30.0
				pecas.poligono(Pecas.retangulo(Vector2(gx - 720 + i * 180, fy + 140 - h / 2.0), Vector2(150, h)), c, -5)
				pecas.poligono(Pecas.retangulo(Vector2(gx - 720 + i * 180, fy + 140 - h * 0.6), Vector2(110, 40)), c.lightened(0.5), -5)
		# placa pendurada
		var px := x + 2600.0
		pecas.linha(PackedVector2Array([Vector2(px - 350, teto + 300), Vector2(px - 350, teto + 700)]), 10.0, Color(0.3, 0.3, 0.32), -5)
		pecas.linha(PackedVector2Array([Vector2(px + 350, teto + 300), Vector2(px + 350, teto + 700)]), 10.0, Color(0.3, 0.3, 0.32), -5)
		pecas.poligono(Pecas.retangulo(Vector2(px, teto + 800), Vector2(1000, 260)), Color(1, 0.5, 0.1), -5)
		var l := Label.new()
		l.text = ["ATACADÃO", "OFERTA!", "LEVE 3 PAGUE 2", "CORREDOR %d" % (m + 1)][m % 4]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = Vector2(1000, 260)
		l.position = Vector2(px - 500, teto + 670)
		l.add_theme_font_size_override("font_size", 130)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.4, 0.2))
		l.add_theme_constant_override("outline_size", 22)
		l.z_index = -5
		add_child(l)
		pecas.poligono(Pecas.retangulo(Vector2(px, teto + 400), Vector2(500, 40)), Color(1, 1, 0.9), -5)
		x += 3600.0
		m += 1

# ---------- FASE 5: Chefão ----------
## pista no escuro com o chefe gigante no fundo. Passar nos botões vermelhos dá
## choque nele (5 de vida). O portão do fim só abre com ele derrotado.
var boss: Boss
var _portao: StaticBody2D
const BOSS_FIM := 13000.0
const ARENA_X0 := -1900.0
const ARENA_X1 := 9600.0
var _botoes: Array = []
var _botoes_x := [5800.0, 600.0, 4000.0, 8800.0, 1300.0]   # ordem em que acendem: espalhados pela arena
var _botao_ativo := -1
var _rodada_t := 7.0
var _msg: Label

func _fase_5() -> void:
	# arena fechada: parede atrás e portão na frente. Não dá pra passar correndo:
	# os botões acendem um por vez, só depois de sobreviver a uma rodada de ataques
	var y := CHAO_Y
	var bruto := PackedVector2Array([Vector2(ARENA_X0 - 2000.0, y), Vector2(1800, y), Vector2(2600, y - 220),
		Vector2(3400, y), Vector2(6400, y), Vector2(7200, y - 220), Vector2(8000, y), Vector2(BOSS_FIM + 6000.0, y)])
	pecas.pista_elevada(bruto, y + 2600.0)
	_parede_arena(ARENA_X0, y)
	for i in _botoes_x.size():
		_botoes.append(_botao_choque(Vector2(_botoes_x[i], y)))
	_portao = StaticBody2D.new()
	_portao.collision_layer = 0b01
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(260, 30000)                       # alto até o céu: o mega pulo do Lima não passa por cima
	cs.shape = r
	cs.position = Vector2(0, -13200)
	_portao.add_child(cs)
	pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(260, 3600)), Color(0.4, 0.42, 0.46), 3, null, 1.0, _portao)
	pecas.poligono(Pecas.retangulo(Vector2(0, 1500), Vector2(260, 160)), Color.WHITE, 3, pecas.tex("perigo"), 0.8, _portao)
	_portao.position = Vector2(ARENA_X1, y - 1800.0)
	add_child(_portao)
	pecas.portal_chegada(Vector2(BOSS_FIM, y))
	_meta_pos = Vector2(BOSS_FIM + 700, y)
	_marcos([], Vector2(BOSS_FIM, y), y + 3200.0, false)
	boss = Boss.new()
	add_child(boss)
	boss.global_position = Vector2(1200, y - 690.0)
	boss.montar(self, y)
	if "matar_chefe" in OS.get_cmdline_user_args():      # teste: chefe cai sozinho em 4 s (quem criou a sala)
		get_tree().create_timer(4.0 * Engine.time_scale).timeout.connect(func() -> void:
			if Online.host or not Online.ativo:
				boss.vida = 1
				boss.segunda = true
				boss.levar_choque())
	boss.derrotado.connect(func() -> void:
		if Online.ativo:                                  # online: o time todo vence junto, na mesma hora
			_vitoria_online()
			return
		_mensagem("O PORTÃO ABRIU! CORRE!", Color(0.5, 1, 0.5))
		var tw := _portao.create_tween()
		tw.tween_property(_portao, "position:y", _portao.position.y - 3700.0, 1.2)
		tw.tween_callback(func() -> void: _portao.queue_free()))

func _parede_arena(x: float, y: float) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(400, 30000)
	cs.shape = r
	cs.position = Vector2(0, -13000)
	sb.add_child(cs)
	if Game.fase in [8, 9]:                             # parede neon (combina com o palco)
		pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(400, 4000)), Color(0.1, 0.07, 0.2), 3, null, 1.0, sb)
		for dx in [-200.0, 200.0]:
			pecas.linha(PackedVector2Array([Vector2(dx, -2000), Vector2(dx, 2000)]), 60.0, Color(1, 0.35, 0.8, 0.2), 3, sb)
			pecas.linha(PackedVector2Array([Vector2(dx, -2000), Vector2(dx, 2000)]), 18.0, Color(1, 0.45, 0.85), 3, sb)
	else:
		pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(400, 4000)), Color(0.4, 0.42, 0.46), 3, null, 1.0, sb)
	sb.position = Vector2(x, y - 2000.0)
	add_child(sb)

## rodadas: sobrevive X segundos de ataque, aí um botão acende num canto da arena
func _rodada_boss(dt: float) -> void:
	_seta_botao()
	if not is_instance_valid(boss) or boss.morto or not ativo:
		return
	if _botao_ativo >= 0:
		var b: Dictionary = _botoes[_botao_ativo]
		if Online.ativo and Online.host and b["ligado"] and not (b.get("quem", {}) as Dictionary).is_empty():
			_conferir_botao(b)
			if not b["ligado"]:
				return
		for c in (b["area"] as Area2D).get_overlapping_bodies():
			if c.is_in_group("veiculo") or c.is_in_group("piloto"):
				_apertar(b)
				break
		return
	if Online.ativo and not Online.host:                   # online: botão acende quando quem criou a sala manda
		return
	_rodada_t -= dt / Engine.time_scale
	if _rodada_t > 0.0:
		return
	_botao_ativo = (boss.vida_max - boss.vida) % _botoes.size()   # próximo da lista
	_ligar_botao(_botoes[_botao_ativo])
	_mensagem("BOTÃO LIGADO! VAI LÁ!", Color(1, 0.9, 0.3))
	if Online.ativo:
		Online.enviar("bt", {"i": _botao_ativo})

## clarão rápido na tela inteira (laser, explosão de chefe)
func _clarao(cor: Color, forca: float) -> void:
	var c := ColorRect.new()
	c.color = Color(cor, forca)
	c.size = get_viewport().get_visible_rect().size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(c)
	$HUD.move_child(c, 0)
	var tw := c.create_tween()
	tw.tween_property(c, "color:a", 0.0, 0.35)
	tw.tween_callback(c.queue_free)

func _mensagem(t: String, cor: Color) -> void:
	if _msg == null:
		_msg = Label.new()
		_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_msg.add_theme_font_size_override("font_size", 56)
		_msg.add_theme_color_override("font_outline_color", Color.BLACK)
		_msg.add_theme_constant_override("outline_size", 12)
		$HUD.add_child(_msg)
	var v := get_viewport().get_visible_rect().size
	_msg.size = Vector2(v.x, 90)
	_msg.position = Vector2(0, v.y * 0.3)
	_msg.text = t
	_msg.add_theme_color_override("font_color", cor)
	_msg.visible = true
	_msg.modulate.a = 1.0
	var tw := _msg.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.5)

## botão no chão: desligado (cinza) até a rodada acabar; ligado, passou por cima = raio
func _botao_choque(base: Vector2) -> Dictionary:
	pecas.poligono(Pecas.retangulo(base + Vector2(0, -20), Vector2(420, 40)), Color(0.25, 0.25, 0.28), 3)
	var cupula := pecas.poligono(Pecas.retangulo(base + Vector2(0, -70), Vector2(300, 70)), Color(0.35, 0.35, 0.38), 3)
	var luz := pecas.poligono(Pecas.retangulo(base + Vector2(0, -900), Vector2(60, 1500)), Color(1, 0.85, 0.2, 0.0), 2)
	var b := {"cupula": cupula, "luz": luz, "base": base, "ligado": false}
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 0b110
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(500, 1400)
	cs.shape = r
	a.add_child(cs)
	a.position = base + Vector2(0, -700)
	add_child(a)
	b["area"] = a
	return b

func _apertar(b: Dictionary, remoto := false) -> void:
	if not b["ligado"] or not is_instance_valid(boss):
		return
	if Online.ativo and not remoto:              # online: TODO MUNDO vivo tem que apertar
		if _morto_online:
			return
		if Online.host:
			_registrar_aperto(b, Online.id)
		elif not b.get("pedido", false):
			b["pedido"] = true
			Online.enviar("ap", {"i": _botoes.find(b)})
			_mensagem("APERTOU! FALTA O TIME", Color(0.5, 1, 0.6))
		return
	b["ligado"] = false
	(b["cupula"] as Polygon2D).color = Color(0.3, 0.3, 0.33)
	if b.has("sinal"):
		(b["sinal"] as Node).queue_free()
		b.erase("sinal")
	(b["luz"] as Polygon2D).color.a = 0.0
	_raio(b["base"] + Vector2(0, -80), boss.cabeca.global_position)
	boss.levar_choque()
	_botao_ativo = -1
	_rodada_t = maxf(5.0, 9.0 - 1.0 * float(boss.vida_max - boss.vida) * 5.0 / float(boss.vida_max))

## botão aceso: verde, com coluna de luz verde e seta pulando em cima.
## Fora da tela, uma seta na borda aponta pra ele (_seta_botao)
func _ligar_botao(b: Dictionary) -> void:
	b["ligado"] = true
	b.erase("quem")                              # botão acendendo de novo: ninguém apertou ainda
	b.erase("pedido")
	(b["cupula"] as Polygon2D).color = Color(0.2, 1.0, 0.35)
	var sinal := Node2D.new()
	sinal.position = b["base"]
	sinal.z_index = 6
	add_child(sinal)
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 1.0, 0.35, 0.0))
	g.set_color(1, Color(0.3, 1.0, 0.45, 0.5))
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
	coluna.size = Vector2(460, 3200)
	coluna.position = Vector2(-230, -3200)
	sinal.add_child(coluna)
	var seta := Node2D.new()
	sinal.add_child(seta)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(-170, -150), Vector2(170, -150), Vector2(0, 60)])
	tri.color = Color(0.25, 1.0, 0.4)
	seta.add_child(tri)
	var borda := Line2D.new()
	borda.points = tri.polygon + PackedVector2Array([tri.polygon[0]])
	borda.width = 22.0
	borda.default_color = Color(0.02, 0.25, 0.05)
	seta.add_child(borda)
	seta.position = Vector2(0, -700)
	var tw := seta.create_tween().set_loops()
	tw.tween_property(seta, "position:y", -560.0, 0.18 * Engine.time_scale).set_trans(Tween.TRANS_SINE)
	tw.tween_property(seta, "position:y", -700.0, 0.18 * Engine.time_scale).set_trans(Tween.TRANS_SINE)
	b["sinal"] = sinal
	b["quem"] = {}
	b.erase("pedido")
	if Online.ativo:                                  # contador de quem já apertou
		var cont := Label.new()
		cont.add_theme_font_size_override("font_size", 170)
		cont.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
		cont.add_theme_color_override("font_outline_color", Color(0.02, 0.2, 0.05))
		cont.add_theme_constant_override("outline_size", 34)
		cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cont.size = Vector2(1000, 220)
		cont.position = Vector2(-500, -1250)
		cont.text = "0/%d" % maxi(1, _vivos_online().size())
		sinal.add_child(cont)
		b["contador"] = cont
	Audio.tocar("checkpoint", 0.8)

var _seta_hud: Label
func _seta_botao() -> void:
	if _seta_hud == null:
		_seta_hud = Label.new()
		_seta_hud.add_theme_font_size_override("font_size", 46)
		_seta_hud.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		_seta_hud.add_theme_color_override("font_outline_color", Color(0.02, 0.2, 0.05))
		_seta_hud.add_theme_constant_override("outline_size", 12)
		$HUD.add_child(_seta_hud)
	if _botao_ativo < 0 or not ativo:
		_seta_hud.visible = false
		return
	var v := get_viewport().get_visible_rect().size
	var na_tela: Vector2 = get_viewport().get_canvas_transform() * Vector2(float(_botoes_x[_botao_ativo]), CHAO_Y)
	_seta_hud.visible = na_tela.x < 40.0 or na_tela.x > v.x - 40.0
	var direita := na_tela.x > v.x / 2.0
	_seta_hud.text = "BOTÃO >>>" if direita else "<<< BOTÃO"
	_seta_hud.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 150.0))
	_seta_hud.position = Vector2(v.x - 330.0 if direita else 30.0, v.y * 0.26)

func _raio(de: Vector2, para: Vector2) -> void:
	for camada in 2:
		var l := Line2D.new()
		var pts := PackedVector2Array([de])
		for i in range(1, 12):
			pts.append(de.lerp(para, i / 12.0) + Vector2(randf_range(-220, 220), randf_range(-120, 120)))
		pts.append(para)
		l.points = pts
		l.width = 90.0 if camada == 0 else 30.0
		l.default_color = Color(0.4, 0.8, 1.0, 0.6) if camada == 0 else Color(1, 1, 1)
		l.z_index = 9
		add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.5)
		tw.tween_callback(l.queue_free)
	Audio.tocar("metal", 1.0)

# ---------- FASE 4: Laboratório (boss: cientista) ----------
## reto, mais curto. Começa com o aviso "você esqueceu o jaleco", toca o alarme e o
## cientista vem correndo atrás. Portas que abrem e fecham e espinhos baixos com
## rampinha pra pular. Se ele te alcançar, morreu.
var _portas: Array = []
var _boss: Node2D
var _boss_x := -4000.0
var _boss_vel := 0.0
var _boss_t := 0.0
var _alarme: AudioStreamPlayer
var _alerta: Label
var _vermelho: ColorRect
var _passo_ant := 0.0
const LAB_FIM := 36000.0

func _fase_4() -> void:
	var y := CHAO_Y
	var teto := y - 2700.0
	pecas.terreno(PackedVector2Array([Vector2(-6000, y), Vector2(LAB_FIM + 6000, y)]), y + 2600.0, false)
	pecas.poligono(Pecas.retangulo(Vector2(LAB_FIM / 2.0, y + 1300.0), Vector2(LAB_FIM + 12000.0, 2600)), Color(0.42, 0.44, 0.47), 1)
	pecas.poligono(Pecas.retangulo(Vector2(LAB_FIM / 2.0, y + 25.0), Vector2(LAB_FIM + 12000.0, 50)), Color(0.62, 0.64, 0.67), 1)
	# parede do fundo: azulejo branco-azulado, faixa verde, prateleiras com frascos
	pecas.poligono(Pecas.retangulo(Vector2(LAB_FIM / 2.0, (teto + y) / 2.0), Vector2(LAB_FIM + 12000.0, y - teto)), Color(0.82, 0.88, 0.9), -6)
	var x := -6000.0
	while x < LAB_FIM + 6000.0:
		pecas.linha(PackedVector2Array([Vector2(x, teto), Vector2(x, y)]), 6.0, Color(0.7, 0.77, 0.8), -5)
		x += 300.0
	var yy := teto
	while yy < y:
		pecas.linha(PackedVector2Array([Vector2(-6000, yy), Vector2(LAB_FIM + 6000, yy)]), 6.0, Color(0.7, 0.77, 0.8), -5)
		yy += 300.0
	pecas.poligono(Pecas.retangulo(Vector2(LAB_FIM / 2.0, y - 600.0), Vector2(LAB_FIM + 12000.0, 90)), Color(0.25, 0.65, 0.45), -5)
	var cores := [Color(0.3, 0.95, 0.4, 0.85), Color(0.3, 0.7, 1.0, 0.85), Color(1.0, 0.4, 0.8, 0.85), Color(1.0, 0.85, 0.2, 0.85)]
	x = -3000.0
	var k := 0
	while x < LAB_FIM + 3000.0:
		var py := y - 1700.0
		pecas.poligono(Pecas.retangulo(Vector2(x, py), Vector2(900, 40)), Color(0.45, 0.47, 0.5), -4)
		for i in 4:
			var c: Color = cores[(k + i) % 4]
			var fx := x - 330.0 + i * 220.0
			pecas.poligono(PackedVector2Array([Vector2(fx - 60, py - 20), Vector2(fx + 60, py - 20), Vector2(fx + 22, py - 150), Vector2(fx - 22, py - 150)]), c, -4)
			pecas.poligono(Pecas.retangulo(Vector2(fx, py - 190), Vector2(44, 80)), Color(0.85, 0.92, 0.95, 0.8), -4)
		x += 5200.0
		k += 1
	_lab_cenario(y, teto)
	# teto com luminárias
	pecas.poligono(Pecas.retangulo(Vector2(LAB_FIM / 2.0, teto - 200.0), Vector2(LAB_FIM + 12000.0, 400)), Color(0.35, 0.37, 0.4), 2)
	x = -5000.0
	while x < LAB_FIM + 5000.0:
		pecas.poligono(Pecas.retangulo(Vector2(x, teto + 30.0), Vector2(500, 50)), Color(1, 1, 0.85), 2)
		x += 2000.0
	var bancada := 2500.0
	# sequência: portas e espinhos alternando, ficando mais apertado no fim
	var obst := [["porta", 4200.0, 3.2], ["espinho", 8200.0], ["porta", 11800.0, 2.8], ["porta", 14200.0, 3.0],
		["espinho", 17800.0], ["porta", 21200.0, 2.6], ["espinho", 24600.0], ["porta", 28000.0, 2.4],
		["espinho", 31000.0], ["porta", 33600.0, 2.2]]
	for o in obst:
		if o[0] == "porta":
			_porta(Vector2(o[1], y), teto, o[2])
		else:
			pecas.rampa(o[1] - 700.0, o[1] - 100.0, y, 230)
			pecas.espinhos(o[1] + 60.0, o[1] + 380.0, y, 150.0)
		bancada += 0.0
	pecas.portal_chegada(Vector2(LAB_FIM, y))
	_meta_pos = Vector2(LAB_FIM + 700, y)
	_marcos([], Vector2(LAB_FIM, y), y + 3000.0, false)
	# chefe
	_boss = Sprite2D.new()
	(_boss as Sprite2D).texture = load("res://assets/arte/cientista.png")
	(_boss as Sprite2D).offset = Vector2(0, -575)
	_boss.scale = Vector2.ONE * 1.3
	_boss.z_index = 6
	_boss.position = Vector2(_boss_x, y)
	add_child(_boss)
	_alarme = AudioStreamPlayer.new()
	var st := load("res://assets/audio/sfx/alarme.wav") as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = int(st.get_length() * st.mix_rate)
	_alarme.stream = st
	_alarme.volume_db = -19.0
	add_child(_alarme)
	_iniciar_alerta.call_deferred()

## fundo rico do laboratório: tubos de vidro com líquido e bolhas, canos, armários,
## monitores, placas de risco; repete a cada módulo de 5200 px
func _lab_cenario(y: float, teto: float) -> void:
	var x := -4000.0
	var m := 0
	var liquidos := [Color(0.3, 0.95, 0.35, 0.75), Color(0.25, 0.75, 1.0, 0.75), Color(0.95, 0.35, 0.85, 0.75)]
	while x < LAB_FIM + 4000.0:
		var liq: Color = liquidos[m % 3]
		# tubo de vidro grande com algo dentro
		var tx := x + 700.0
		var topo_t := y - 2050.0
		pecas.poligono(Pecas.retangulo(Vector2(tx, y - 90), Vector2(620, 180)), Color(0.3, 0.32, 0.36), -4)
		pecas.poligono(Pecas.retangulo(Vector2(tx, topo_t - 60), Vector2(620, 140)), Color(0.3, 0.32, 0.36), -4)
		pecas.poligono(Pecas.retangulo(Vector2(tx, (topo_t + y - 180) / 2.0), Vector2(500, y - 180 - topo_t)), Color(0.85, 0.95, 1.0, 0.35), -4)
		pecas.poligono(Pecas.retangulo(Vector2(tx, (topo_t + 300 + y - 180) / 2.0), Vector2(480, y - 180 - topo_t - 300)), liq, -4)
		pecas.poligono(Pecas.retangulo(Vector2(tx - 170, (topo_t + y) / 2.0), Vector2(40, y - topo_t - 300)), Color(1, 1, 1, 0.35), -4)
		var silhueta := PackedVector2Array([Vector2(tx - 60, y - 300), Vector2(tx + 60, y - 300), Vector2(tx + 90, y - 900),
			Vector2(tx + 50, y - 1150), Vector2(tx, y - 1250), Vector2(tx - 50, y - 1150), Vector2(tx - 90, y - 900)])
		pecas.poligono(silhueta, liq.darkened(0.55), -4)                 # coisa estranha flutuando
		for b in 5:                                                        # bolhas subindo
			var bolha := pecas.poligono(_circulo_lab(20.0 + (b % 3) * 10.0), Color(1, 1, 1, 0.55), -4)
			var bx := tx - 180.0 + b * 90.0
			bolha.position = Vector2(bx, y - 220)
			var tw := bolha.create_tween().set_loops()
			tw.tween_interval(b * 0.45)
			tw.tween_property(bolha, "position:y", topo_t + 330.0, 2.6 + (b % 2) * 0.8).from(y - 220.0)
		# canos no alto
		pecas.linha(PackedVector2Array([Vector2(x, teto + 260), Vector2(x + 5200, teto + 260)]), 70.0, Color(0.5, 0.52, 0.56), -4)
		pecas.linha(PackedVector2Array([Vector2(x, teto + 380), Vector2(x + 5200, teto + 380)]), 40.0, Color(0.75, 0.45, 0.2), -4)
		pecas.linha(PackedVector2Array([Vector2(tx, teto + 260), Vector2(tx, topo_t - 130)]), 50.0, Color(0.5, 0.52, 0.56), -4)
		pecas.poligono(Pecas.retangulo(Vector2(x + 2600, teto + 260), Vector2(110, 110)), Color(0.85, 0.2, 0.15), -4)
		# armário de metal
		var ax := x + 1900.0
		pecas.poligono(Pecas.retangulo(Vector2(ax, y - 650), Vector2(700, 1300)), Color(0.55, 0.6, 0.66), -4)
		for i in 3:
			pecas.linha(PackedVector2Array([Vector2(ax - 350 + 233 * (i + 1), y - 1300), Vector2(ax - 350 + 233 * (i + 1), y)]), 8.0, Color(0.35, 0.38, 0.42), -4)
			for v in 3:
				pecas.poligono(Pecas.retangulo(Vector2(ax - 233 + 233 * i, y - 1180 + v * 26), Vector2(110, 10)), Color(0.35, 0.38, 0.42), -4)
		# bancada com monitores
		var bx2 := x + 3400.0
		pecas.poligono(Pecas.retangulo(Vector2(bx2, y - 520), Vector2(1300, 70)), Color(0.32, 0.34, 0.38), -4)
		pecas.poligono(Pecas.retangulo(Vector2(bx2, y - 250), Vector2(1200, 470)), Color(0.42, 0.45, 0.5), -4)
		for i in 2:
			var mx := bx2 - 300.0 + i * 600.0
			pecas.poligono(Pecas.retangulo(Vector2(mx, y - 820), Vector2(460, 320)), Color(0.12, 0.13, 0.15), -4)
			var tela := pecas.poligono(Pecas.retangulo(Vector2(mx, y - 820), Vector2(410, 270)), Color(0.1, 0.35, 0.2), -4)
			for l in 4:
				pecas.linha(PackedVector2Array([Vector2(mx - 170, y - 900 + l * 50), Vector2(mx - 170 + 80 + ((m + l * 37) % 5) * 50, y - 900 + l * 50)]), 12.0, Color(0.4, 1.0, 0.5), -4)
			var tw2 := tela.create_tween().set_loops()
			tw2.tween_property(tela, "color", Color(0.15, 0.5, 0.28), 0.7)
			tw2.tween_property(tela, "color", Color(0.1, 0.35, 0.2), 0.7)
			pecas.poligono(Pecas.retangulo(Vector2(mx, y - 620), Vector2(60, 80)), Color(0.12, 0.13, 0.15), -4)
		# placa de risco biológico
		var px := x + 4600.0
		var tri := PackedVector2Array([Vector2(px, y - 1700), Vector2(px + 200, y - 1350), Vector2(px - 200, y - 1350)])
		pecas.poligono(tri, Pecas.AMARELO, -4)
		pecas.linha(tri + PackedVector2Array([tri[0]]), 18.0, Color(0.1, 0.1, 0.1), -4)
		for k in 3:
			pecas.poligono(_circulo_lab(38.0, Vector2(px, y - 1480) + Vector2(0, -50).rotated(TAU * k / 3.0)), Color(0.1, 0.1, 0.1), -4)
		pecas.poligono(_circulo_lab(22.0, Vector2(px, y - 1480)), Pecas.AMARELO, -4)
		# giroflex do alarme
		var gx := x + 2600.0
		pecas.poligono(Pecas.retangulo(Vector2(gx, teto + 120), Vector2(120, 60)), Color(0.25, 0.25, 0.28), -3)
		var gir := pecas.poligono(_circulo_lab(70.0, Vector2(gx, teto + 200)), Color(1, 0.15, 0.1), -3)
		var tw3 := gir.create_tween().set_loops()
		tw3.tween_property(gir, "modulate:a", 0.25, 0.3)
		tw3.tween_property(gir, "modulate:a", 1.0, 0.3)
		x += 5200.0
		m += 1

func _circulo_lab(r: float, c := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		pts.append(c + Vector2(r, 0).rotated(TAU * k / 16.0))
	return pts

func _iniciar_alerta() -> void:
	_alerta = Label.new()
	_alerta.text = "!! ALERTA !!\nVOCÊ ESQUECEU O JALECO!"
	_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alerta.add_theme_font_size_override("font_size", 64)
	_alerta.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	_alerta.add_theme_color_override("font_outline_color", Color.BLACK)
	_alerta.add_theme_constant_override("outline_size", 14)
	var v := get_viewport().get_visible_rect().size
	_alerta.size = Vector2(v.x, 200)
	_alerta.position = Vector2(0, v.y * 0.18)
	$HUD.add_child(_alerta)
	_alarme.play()
	_vermelho = ColorRect.new()
	_vermelho.color = Color(1, 0, 0, 0.0)
	_vermelho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vermelho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_vermelho)
	$HUD.move_child(_vermelho, 0)

## porta corrediça: sobe e desce num ciclo; aberta ~55% do tempo
func _porta(base: Vector2, teto: float, periodo: float, armario := false) -> void:
	var alt := base.y - teto
	var ab := AnimatableBody2D.new()
	ab.sync_to_physics = false
	ab.collision_layer = 0b01
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(220, alt)
	cs.shape = r
	ab.add_child(cs)
	pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(220, alt)), Color(0.55, 0.6, 0.66), 3, null, 1.0, ab)
	pecas.poligono(Pecas.retangulo(Vector2(0, alt / 2.0 - 80.0), Vector2(220, 100)), Color.WHITE, 3, pecas.tex("perigo"), 0.8, ab)
	pecas.poligono(Pecas.retangulo(Vector2(0, -alt * 0.25), Vector2(120, 160)), Color(0.75, 0.9, 1.0, 0.7), 3, null, 1.0, ab)
	if armario:                                       # porta de armário verde (escola)
		pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(220, alt)), Color(0.45, 0.72, 0.12), 3, null, 1.0, ab)
		for k in 6:
			pecas.poligono(Pecas.retangulo(Vector2(0, -alt / 2.0 + 220 + k * 70), Vector2(120, 14)), Color(0.28, 0.45, 0.08), 3, null, 1.0, ab)
		pecas.poligono(Pecas.retangulo(Vector2(70, 0), Vector2(26, 90)), Color(0.85, 0.85, 0.85), 3, null, 1.0, ab)
		pecas.poligono(Pecas.retangulo(Vector2(0, alt / 2.0 - 80.0), Vector2(220, 100)), Color.WHITE, 3, pecas.tex("perigo"), 0.8, ab)
	ab.position = Vector2(base.x, base.y - alt / 2.0)
	add_child(ab)
	pecas.poligono(Pecas.retangulo(Vector2(base.x, teto + 40.0), Vector2(320, 80)), Color(0.25, 0.27, 0.3), 4)
	var luz := pecas.poligono(Pecas.retangulo(Vector2(base.x + 200, teto + 200.0), Vector2(60, 60)), Color(1, 0.2, 0.2), 4)
	_portas.append({"no": ab, "fechada": ab.position.y, "aberta": ab.position.y - alt + 120.0, "T": periodo,
		"atraso": _sorteio.randf_range(0.0, periodo), "luz": luz, "meia": alt / 2.0})

func _atualizar_lab(dt: float) -> void:
	_mover_portas()
	if _boss == null or not ativo or not is_instance_valid(player):
		return
	_atualizar_boss_lab(dt)

## portas que abrem e fecham (laboratório e armários da escola); fechando, esmaga
func _mover_portas() -> void:
	for p in _portas:
		var f := fposmod(_t_fisica + float(p["atraso"]), float(p["T"])) / float(p["T"])
		var k := 0.0                                  # 0 fechada, 1 aberta
		if f < 0.15: k = f / 0.15
		elif f < 0.70: k = 1.0
		elif f < 0.85: k = 1.0 - (f - 0.70) / 0.15
		(p["no"] as AnimatableBody2D).position.y = lerpf(p["fechada"], p["aberta"], smoothstep(0.0, 1.0, k))
		(p["luz"] as Polygon2D).color = Color(0.2, 1, 0.3) if k > 0.9 else Color(1, 0.2, 0.2)
		if f >= 0.70 and f < 0.88 and ativo and is_instance_valid(player):   # descendo: quem estiver embaixo é esmagado
			var porta: AnimatableBody2D = p["no"]
			var baixo := porta.position.y + float(p["meia"])
			var alvos: Array = [player.chassi] + player.membros.values() if player.montado else player.corpos.values()
			for b in alvos:
				var bp: Vector2 = (b as Node2D).global_position
				if absf(bp.x - porta.position.x) < 150.0 and bp.y < baixo + 60.0 and bp.y > baixo - 500.0:
					_on_perigo(b, "esmagado")
					break

func _atualizar_boss_lab(dt: float) -> void:
	_boss_t += dt / Engine.time_scale
	if _boss_t < 2.5:                                # tempo do aviso antes dele sair correndo
		return
	if _alerta and _boss_t > 4.0:
		_alerta.visible = false
	var alvo := player.foco().global_position.x
	_boss_vel = minf(_boss_vel + 900.0 * dt, 1050.0 + 6.0 * (_boss_t - 2.5))   # vai apertando com o tempo
	_boss_x = minf(_boss_x + _boss_vel * dt, LAB_FIM - 200.0)
	_boss.position = Vector2(_boss_x, CHAO_Y + absf(sin(_boss_t * 9.0)) * -40.0)
	_boss.rotation = sin(_boss_t * 9.0) * 0.06
	# passos: um a cada pisada; mais alto e mais rápido quanto mais perto ele está
	var dist := alvo - _boss_x
	var perto := clampf(1.0 - dist / 9000.0, 0.0, 1.0)
	var fase_passo := fposmod(_boss_t * 9.0 * (1.0 + perto * 0.6), PI)
	if fase_passo < _passo_ant:
		Audio.tocar("passo", 0.15 + 0.85 * perto, 0.05)
	_passo_ant = fase_passo
	if _vermelho:
		_vermelho.color.a = (0.06 + 0.16 * perto) * (0.5 + 0.5 * sin(_boss_t * (6.0 + 8.0 * perto)))
	if alvo - _boss_x < 250.0 and player.repelir(player.foco().global_position):
		_boss_x -= 2500.0                                   # Chefe sem camisa: empurra o Maurício pra trás
		_boss_vel = 0.0
	elif alvo - _boss_x < 250.0:
		_fim(false, "pego")
		if player.montado:
			player.soltar_ragdoll.call_deferred(Vector2(1500, -900), false)

# ---------- FASE 1 ----------
## ritmo do gênero: voa, pousa descendo, sobe no embalo, obstáculo no alto, voa de novo.
## Cada bloco desce e sobe a mesma altura: a fase cresce sem afundar.
func _fase_1() -> void:
	_sorteio.seed = 101
	var c: Array = []
	var qv := _queda_voo()
	var p := _largada()
	p = _t_ponte(p, 2300, 350)
	p = _t_plano(p, 800)
	for volta in 3:
		if volta == 1:
			p = _t_andares(p, 4)
			p = _t_mega(p, 16000.0, -4 * ANDAR)
		p = _bloco_novo(p, c, [["minas", "temporarias"], ["drone", "quebraveis", "trampolim"], ["tunel", "moveis", "turbo_salto"]][volta])
		_cp(c, p)
		p = _t_bola(p)
		p = _t_voo(p, "agua")
		p = _t_mega(p, qv * 3.0, -qv)
		_cp(c, p)
		p = _t_passarela(p)
		p = _t_gangorra(p)
		p = _t_vigas(p)
		p = _t_tnt(p)
		p = _t_plano(p, 500)
		p = _t_voo(p, "espinhos")
		p = _t_mega(p, qv * 3.0, -qv)
		_cp(c, p)
		p = _t_prensa(p)
		p = _t_ondas(p)
		p = _t_ponte(p, 2300, 250)
		p = _t_ladeira(p, 1500, -250)
	_cp(c, p)
	p = _t_passarela(p)
	p = _t_plano(p, 1000)
	p = _t_voo(p, "agua")
	p = _t_plano(p, 1500)
	_chegada(p, c)

# ---------- FASE 2 ----------
func _fase_2() -> void:
	_sorteio.seed = 202
	var c: Array = []
	var qv := _queda_voo()
	var p := _largada()
	pecas.guindaste(1200, CHAO_Y, CHAO_Y - 3000, -1300, -400)
	p = _t_plano(p, 400, false)
	p = _t_gangorra(p)
	p = _t_vigas(p)
	p = _t_tabuas(p)
	for volta in 3:
		if volta == 1:
			p = _t_andares(p, 4)
			p = _t_mega(p, 16000.0, -4 * ANDAR)
		p = _bloco_novo(p, c, [["drone", "quebraveis"], ["trampolim", "temporarias", "minas"], ["retrateis", "tunel"]][volta])
		_cp(c, p)
		p = _t_prensa(p)
		p = _t_predio(p)
		p = _t_plano(p, 600)
		p = _t_voo(p, "espinhos")
		p = _t_mega(p, qv * 3.0, -qv)
		_cp(c, p)
		p = _t_bola(p)
		p = _t_passarela(p)
		p = _t_tabuas(p, 1400)
		p = _t_plano(p, 500)
		p = _t_voo(p, "serras")
		p = _t_mega(p, qv * 3.0, -qv)
		_cp(c, p)
		p = _t_vigas(p)
		p = _t_tnt(p)
		p = _t_gangorra(p)
	_cp(c, p)
	p = _t_prensa(p)
	p = _t_plano(p, 1500)
	_chegada(p, c)

# ---------- FASE 3 ----------
func _fase_3() -> void:
	_sorteio.seed = 303
	var c: Array = []
	var qv := _queda_voo()
	var p := _largada()
	p = _t_ladeira(p, 2800, 900)
	p = _t_plano(p, 1200)                           # reta antes do 1º salto: vindo da descida batia na rampa
	for volta in 3:
		p = _bloco_novo(p, c, [["retrateis", "minas"], ["moveis", "turbo_salto"], ["drone", "temporarias", "trampolim"]][volta])
		p = _t_voo(p, "serras")
		p = _t_mega(p, qv * 3.0, -qv)
		_cp(c, p)
		p = _t_andares(p, 4 + volta)
		p = _t_mega(p, 16000.0, -(4 + volta) * ANDAR)  # sobe de volta o que desceu no prédio
		p = _t_ponte(p, 1900, -150)
		p = _t_tnt(p)
		p = _t_plano(p, 500)
		p = _t_voo(p, "espinhos")
		p = _t_mega(p, qv * 3.0, -qv + 150.0)
		_cp(c, p)
		p = _t_bola(p)
		p = _t_lago(p)
		p = _t_ladeira(p, 1500, -160)
		_cp(c, p)
		p = _t_ondas(p)
		p = _t_plano(p, 800)
	p = _t_voo(p, "espinhos")
	p = _t_plano(p, 1500)
	_chegada(p, c)

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
	cs.polygon = PackedVector2Array([Vector2(-70, 100.0), Vector2(70, 100.0), Vector2(0, 0)])
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
	prancha.rotation = -atan2(78.0, h)    # ponta de cá (esquerda) encostada no chão
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
			if t.freeze and is_inside_tree() and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
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
	grad.set_color(0, {"julgamento": Color(0.02, 0.01, 0.05), "colorido": Color(0.36, 0.18, 0.6), "mercado": Color(0.9, 0.85, 0.75), "boss": Color(0.01, 0.01, 0.02), "obra": Color(0.36, 0.52, 0.78), "montanha": Color(0.2, 0.38, 0.78)}.get(tema, Color(0.27, 0.47, 0.92)))
	grad.set_color(1, {"julgamento": Color(0.1, 0.04, 0.16), "colorido": Color(0.15, 0.5, 0.82), "mercado": Color(0.95, 0.9, 0.8), "boss": Color(0.05, 0.03, 0.07), "lab": Color(0.6, 0.65, 0.7), "campo": Color(0.86, 0.93, 0.98), "obra": Color(0.95, 0.85, 0.72), "montanha": Color(0.78, 0.88, 0.98)}.get(tema, Color(0.62, 0.78, 0.98)))
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
	if tema in ["lab", "boss", "mercado", "julgamento"]:
		camadas = []
	if tema == "escola":
		camadas = [["nuvem", 0.12, -1300.0, 4.8]]
	if tema == "colorido":
		camadas = []
	if tema in ["campo", "obra", "montanha", "hw"]:
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
	if not ativo or _queda7:                     # caindo do terraço pra luta: ninguém morre
		return
	if Online.ativo and not ganhou:
		if Game.fase == 5:                       # co-op: renasce enquanto alguém do time estiver vivo
			_morte_online(motivo)
		else:                                    # corrida: volta pro começo
			_morte_corrida(motivo)
		return
	if Online.ativo and Game.fase != 5:          # corrida: chegou (ou derrotou o chefe)
		_chegou_online()
		return
	ativo = false
	Audio.parar_chefe()
	if ganhou:
		_esconder_barras_chefe()
		var novo := do_inicio and Game.registrar_vitoria(Game.fase, tempo)
		if not Online.ativo:                          # ranking público (se tiver conta)
			_mandar_ranking()
		aviso.text = "CHEGOU!\n%.1f s%s" % [tempo, "  NOVO RECORDE!" if novo else ""]
		aviso.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
		Game.checkpoint_x = -1.0
		Audio.motor(false)
		Audio.tocar("vitoria")
		pecas.festa(_meta_pos, player.foco().global_position)
		print("[FASE] venceu %.2f" % tempo)
		venceu.emit(tempo)
	else:
		if _alarme:
			_alarme.stop()
		aviso.text = {"esmagado": "ESMAGADO!", "agarrado": "TE PEGOU!", "laser": "DESINTEGRADO!", "pedra": "ESMAGADO!", "pego": "TE PEGOU!", "agua": "AFOGOU!", "buraco": "CAIU!", "caiu": "CAIU!"}.get(motivo, "MORREU!") + "\naperta R"
		Audio.motor(false)
		Audio.tocar("morte")
		print("[FASE] perdeu %s x=%.0f" % [motivo, player.foco().global_position.x if is_instance_valid(player) else 0.0])
		perdeu.emit(motivo)
	aviso.visible = true
	if painel:
		painel.get_node("proxima").visible = ganhou and Game.proxima_fase(Game.fase) > 0
		painel.visible = true
		_posicionar_hud.call_deferred()

## manda o tempo pro ranking e mostra embaixo dos botões se foi
func _mandar_ranking() -> void:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	var v := get_viewport().get_visible_rect().size
	l.size = Vector2(v.x, 40)
	l.position = Vector2(0, v.y * 0.06 + 280.0)
	$HUD.add_child(l)
	var cinza := Color(0.85, 0.85, 0.9)
	if not do_inicio:
		l.text = "Ranking: só vale começando a fase do início."
		l.add_theme_color_override("font_color", cinza)
		return
	if not Conta.logado():
		l.text = "Cria uma conta no RANKING (menu) pra esse tempo aparecer lá."
		l.add_theme_color_override("font_color", cinza)
		return
	l.text = "Mandando pro ranking..."
	l.add_theme_color_override("font_color", cinza)
	var cod := await Conta.enviar_recorde(Game.fase, tempo, Game.personagem)
	if not is_instance_valid(l):
		return
	if cod == 200:
		l.text = "Tempo enviado pro ranking!"
		l.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
	else:
		l.text = {-1: "Ranking: você saiu da conta.", -2: "Ranking: o servidor recusou esse tempo.", 0: "Ranking: sem conexão, não deu pra mandar."}.get(cod, "Ranking: erro %d ao mandar o tempo." % cod)
		l.add_theme_color_override("font_color", Color(1, 0.55, 0.45))

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
		b.pressed.connect(func(): _reiniciar())
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
		[_toque_especial(), func(v: Vector2) -> Vector2: return Vector2(v.x - 195, v.y - 410)],
		[_rotulo_carga(), func(v: Vector2) -> Vector2: return Vector2(v.x - 213, v.y - 452)],
		[_rotulo_ult(), func(v: Vector2) -> Vector2: return Vector2(v.x - 405, v.y - 400) if Game.personagem in Game.ULT_DASH else Vector2(-9999, 0)],
		[_toque_bomba(), func(v: Vector2) -> Vector2: return Vector2(v.x - 370, v.y - 360) if (Game.personagem in Game.BOMBA_EXTRA or Game.personagem in Game.NITRO_EXTRA or Game.personagem in Game.ULT_DASH) else Vector2(-9999, 0)],
		[_botao("R", Vector2.ZERO, Vector2(80, 64), "reset"), func(v: Vector2) -> Vector2: return Vector2(v.x - 96, 14)],
		[_botao("TROCAR", Vector2.ZERO, Vector2(180, 64), "menu"), func(v: Vector2) -> Vector2: return Vector2(v.x - 290, 14)],
		[_volume(cl), func(v: Vector2) -> Vector2: return Vector2(v.x - 386, 14)],
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
	_hud.append([painel, func(v: Vector2) -> Vector2: return Vector2((v.x - painel.size.x) / 2.0, v.y * 0.06 + 175.0)])
	get_viewport().size_changed.connect(_posicionar_hud)
	_posicionar_hud()

func _volume(cl: CanvasLayer) -> Volume:
	var vol := Volume.new()
	cl.add_child(vol)
	return vol

func _acao_fim(acao: String) -> void:
	Audio.tocar("clique")
	match acao:
		"proxima":
			Game.fase = maxi(1, Game.proxima_fase(Game.fase))
			Game.checkpoint_x = -1.0
			_reiniciar()
		"denovo":
			_reiniciar()
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

const ICONES := {"baloes": "baloes", "estrela": "estrela", "pulo_duplo": "pula", "salto": "pula", "turbo": "turbo", "bomba": "bomba", "equilibrio": "equilibrio", "arpao": "arpao", "rapido": "rapido", "dash": "dash", "mega_pulo": "mega_pulo", "repele": "repele"}

func _toque_especial() -> TouchScreenButton:
	_botao_especial = _toque(ICONES.get(Game.HABILIDADES.get(Game.personagem, "salto"), "pula"), Vector2.ZERO, 165, "especial")
	return _botao_especial

func _toque_bomba() -> TouchScreenButton:
	var icone := "nitro" if Game.personagem in Game.NITRO_EXTRA else ("dash" if Game.personagem in Game.ULT_DASH else "bomba")
	return _toque(icone, Vector2.ZERO, 130, "bomba")

## carga da habilidade embaixo do botão: PRONTO, segundos ou % do turbo
func _rotulo_carga() -> Label:
	_carga = Label.new()
	_carga.custom_minimum_size = Vector2(200, 40)
	_carga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carga.add_theme_font_size_override("font_size", 26)
	_carga.add_theme_color_override("font_outline_color", Color.BLACK)
	_carga.add_theme_constant_override("outline_size", 8)
	$HUD.add_child(_carga)
	return _carga

## Gorisch: estado da ult em cima do segundo botão
var _carga_ult: Label
func _rotulo_ult() -> Label:
	_carga_ult = Label.new()
	_carga_ult.custom_minimum_size = Vector2(200, 40)
	_carga_ult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carga_ult.add_theme_font_size_override("font_size", 24)
	_carga_ult.add_theme_color_override("font_outline_color", Color.BLACK)
	_carga_ult.add_theme_constant_override("outline_size", 8)
	$HUD.add_child(_carga_ult)
	return _carga_ult

func _atualizar_carga() -> void:
	if _carga_ult and is_instance_valid(player) and Game.personagem in Game.ULT_DASH:
		if player.ult_t > 0.0:
			_carga_ult.text = "ULT!"
			_carga_ult.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
		elif player.recarga_ult > 0.0:
			_carga_ult.text = "ULT %d s" % ceili(player.recarga_ult)
			_carga_ult.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		else:
			_carga_ult.text = "ULT PRONTA"
			_carga_ult.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	if not _carga or not is_instance_valid(player) or not player.montado:
		return
	var f := player.pronto()
	if player.habilidade == "turbo":
		_carga.text = "INFINITO" if Game.personagem in Game.TURBO_INFINITO else "%d%%" % int(f * 100.0)
	elif player.habilidade == "pulo_duplo":
		_carga.text = "PULOS: %d" % player.pulos
	elif f >= 1.0:
		_carga.text = "PRONTO"
	else:
		_carga.text = "%.1f s" % player.recarga
	_carga.add_theme_color_override("font_color", Color(0.5, 1, 0.55) if f >= 1.0 or (player.habilidade == "turbo" and f > 0.2) else Color(1, 0.8, 0.35))
	_botao_especial.modulate.a = 1.0 if f >= 1.0 or player.habilidade == "turbo" else 0.45

## toda explosão: o jogador reage (membros, queda) e plataformas frágeis quebram
func _ao_explodir(pos: Vector2, raio: float) -> void:
	_explosoes += 1
	if is_instance_valid(player):
		player.explosao(pos, raio)
	mec.quebrar_perto(pos, raio)

func _on_perigo(b: Node2D, motivo: String) -> void:
	if is_instance_valid(player) and player.montado and player.imortal_t > 0.0 and motivo != "agua":
		return                                   # Wendell com estrela: passa por tudo
	if motivo == "espetos":
		_espetar(b)
		return
	if b is RigidBody2D:
		sangue.jorrar(b.global_position, 40, 1400.0, Vector2.ZERO, (b as RigidBody2D).linear_velocity * 0.2)
	if motivo != "agua":
		Audio.tocar("splat")
		Audio.tocar("metal" if motivo == "serra" else "impacto_forte")
		if is_instance_valid(player):                   # espinho, serra e prensa estouram o que pegam
			var parte := "cabeca"
			for k in player.corpos:
				if player.corpos[k] == b:
					parte = k
			player.explodir.call_deferred(parte)
	elif is_instance_valid(player) and player.montado:
		player.soltar_ragdoll.call_deferred(player.chassi.linear_velocity * 0.5, false)
	_fim(false, motivo)

## espinho (estilo Happy Wheels): o corpo que cai neles fica espetado e preso; quem
## estava montado é arrancado do veículo e os pedaços que tocarem também espetam
func _espetar(b: Node2D) -> void:
	if not is_instance_valid(player):
		return
	if player.montado:
		player.soltar_ragdoll.call_deferred(player.chassi.linear_velocity * 0.6, false)
		_fim(false, "espetos")
		return
	if not (b.is_in_group("piloto") and b is RigidBody2D) or b.has_meta("espetado"):
		return
	b.set_meta("espetado", true)
	_prender_no_espinho.call_deferred(b)
	_fim(false, "espetos")

func _prender_no_espinho(b: RigidBody2D) -> void:
	if not is_instance_valid(b):
		return
	var ancora := StaticBody2D.new()
	ancora.collision_layer = 0
	ancora.collision_mask = 0
	add_child(ancora)
	ancora.global_position = b.global_position
	var pj := PinJoint2D.new()
	add_child(pj)
	pj.global_position = b.global_position
	pj.node_a = ancora.get_path()
	pj.node_b = b.get_path()
	pj.softness = 0.0
	b.linear_velocity *= 0.1
	b.angular_damp = 6.0
	Audio.tocar("splat", 1.0)
	Audio.tocar("osso", 0.7)
	sangue.jorrar(b.global_position, 30, 700.0, Vector2.UP)
	sangue.esguichar(b, Vector2.ZERO, Vector2.UP, 2.5)

func _on_morreu() -> void:
	_fim(false, "cabeca")

# ---------- teste automatizado de física (headless) ----------
## monociclo não se equilibra sozinho: no teste, um controle simples segura ele
## (prova que dá pra equilibrar com os botões de girar)
func _equilibrar_mono() -> void:
	while is_instance_valid(player) and player.montado and _equilibrando:
		await get_tree().physics_frame
		if Engine.get_physics_frames() % 45 != 0:        # ritmo de gente: corrige a cada 0,25 s reais
			continue
		var u := player.chassi.rotation + 0.3 * player.chassi.angular_velocity
		Input.action_release("lean_fwd")
		Input.action_release("lean_back")
		if u < -0.08:
			Input.action_press("lean_fwd")
		elif u > 0.08:
			Input.action_press("lean_back")

var _equilibrando := false

func _rodar_teste() -> void:
	if player.D["chassi"].get("monociclo", false):
		_equilibrando = true
		_equilibrar_mono()
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

	await _testar_especial()
	var montado_antes := player.montado
	_equilibrando = false
	player.soltar_ragdoll(player.chassi.linear_velocity, true)
	await _esperar(1.3)
	var vmax := 0.0
	for k in player.corpos:
		vmax = maxf(vmax, player.corpos[k].linear_velocity.length())
	print("[RAGDOLL] pecas=%d  vel_max=%.1f (finita = nao explodiu)" % [player.corpos.size(), vmax])
	var pecas_ok: bool = player.corpos.size() == player.D["piloto"].size() - player.perdeu.size() or not montado_antes

	player.arrancar("braco")
	await _esperar(1.0)
	player.explodir("cabeca")
	if "fotos" in OS.get_cmdline_user_args():
		for k in 4:
			await _esperar(0.35)
			await _captura("teste_sangue_%d" % k)
	await _esperar(2.5)
	print("[EXPLODE] cabeca_existe=%s morto=%s" % [player.corpos.has("cabeca"), player.morto])
	print("[SANGUE] manchas=%d  gotas_no_ar=%d  juntas_restantes=%d" % [sangue.manchas.size(), sangue.gotas.size(), player.juntas.size()])

	var ok: bool = rot_spawn < 0.35 and dx > 150.0 and pecas_ok and vmax < 8000.0 \
		and sangue.manchas.size() > 10 and not player.juntas.has("braco") and not player.corpos.has("cabeca") and player.morto
	print("[RESULTADO] ", "PASS" if ok else "FALHA")
	get_tree().quit()

## botão especial: cada habilidade faz o que promete
func _testar_especial() -> void:
	match player.habilidade:
		"salto":
			await _esperar(1.0)
			var y0 := player.chassi.global_position.y
			Input.action_press("especial")
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release("especial")
			var topo := y0
			for k in 60:
				await get_tree().physics_frame
				topo = minf(topo, player.chassi.global_position.y)
				if k == 22 and "fotos" in OS.get_cmdline_user_args():
					await _captura("hab_" + Game.personagem)
			print("[ESPECIAL] salto subiu %.0f px (montado=%s, recarga=%.1f)" % [y0 - topo, player.montado, player.recarga])
		"turbo":
			Input.action_press("accelerate")
			await _esperar(1.0)
			var v0 := player.chassi.linear_velocity.length()
			Input.action_press("especial")
			var vmax_t := 0.0
			for k in 30:
				await get_tree().physics_frame
				vmax_t = maxf(vmax_t, player.chassi.linear_velocity.length())
				if k == 20 and "fotos" in OS.get_cmdline_user_args():
					await _captura("hab_" + Game.personagem)
			print("[ESPECIAL] turbo: %.0f -> %.0f px/s, combustivel=%.2f" % [v0, vmax_t, player.combustivel])
			Input.action_release("especial")
			Input.action_release("accelerate")
			Input.action_press("brake")
			await _esperar(1.5)
			Input.action_release("brake")
		"bomba":
			var n0 := _explosoes
			Input.action_press("especial")
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release("especial")
			for k in 40:
				await get_tree().physics_frame
				if k == 20 and "fotos" in OS.get_cmdline_user_args():
					await _captura("hab_" + Game.personagem)
			await _esperar(2.4)
			print("[ESPECIAL] bomba: explosoes %d -> %d, recarga=%.1f" % [n0, _explosoes, player.recarga])
		"baloes":
			await _esperar(1.0)
			Input.action_press("especial")
			await get_tree().physics_frame
			Input.action_release("especial")
			var y0 := player.chassi.global_position.y
			var antes := player._baloes_t
			for k in 3:
				await _esperar(1.0)
			var tinha := is_instance_valid(player._baloes)
			print("[ESPECIAL] baloes: ativou=%s, apos 3s ainda tem baloes=%s, subiu/desceu %.0f px, montado=%s" % [player._baloes_t > 0.0 or antes > 0.0, tinha, y0 - player.chassi.global_position.y, player.montado])
			await _esperar(8.0)
			print("[ESPECIAL] baloes depois de 10s: estouraram=%s" % (not is_instance_valid(player._baloes)))
		"estrela":
			Input.action_press("especial")
			await get_tree().physics_frame
			Input.action_release("especial")
			await get_tree().physics_frame
			var t0 := player.imortal_t
			player.chassi.apply_central_impulse(Vector2(0, 6000) * player.chassi.mass)   # pancada forte: sem estrela derruba
			await _esperar(1.0)
			print("[ESPECIAL] estrela: imortal=%.1f s, depois da pancada montado=%s" % [t0, player.montado])
			await _esperar(9.5)
		"pulo_duplo":
			await _esperar(1.0)
			var y0 := player.chassi.global_position.y
			Input.action_press("especial")
			await get_tree().physics_frame
			Input.action_release("especial")
			for k in 25:
				await get_tree().physics_frame
			var y1 := player.chassi.global_position.y
			Input.action_press("especial")
			await get_tree().physics_frame
			Input.action_release("especial")
			var topo := y0
			for k in 90:
				await get_tree().physics_frame
				topo = minf(topo, player.chassi.global_position.y)
			print("[ESPECIAL] pulo duplo: 1o pulo ate %.0f px, total %.0f px, pulos=%d, montado=%s" % [y0 - y1, y0 - topo, player.pulos, player.montado])
			await _esperar(1.5)
		"equilibrio":
			_equilibrando = false                      # larga os botões: só a habilidade segura
			await get_tree().physics_frame
			Input.action_release("lean_fwd")
			Input.action_release("lean_back")
			Input.action_press("especial")
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release("especial")
			var pior := 0.0
			for k in 150:
				await get_tree().physics_frame
				pior = maxf(pior, absf(player.chassi.rotation))
			print("[ESPECIAL] equilibrio: 2,5 s sem botao, inclinacao max %.2f rad, montado=%s" % [pior, player.montado])
			_equilibrando = true
			_equilibrar_mono()
		"arpao":
			var alvo := StaticBody2D.new()                # bloco de teste à frente e acima
			alvo.collision_layer = 0b01
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(800, 200)
			cs.shape = r
			alvo.add_child(cs)
			pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(800, 200)), Pecas.CINZA, 2, null, 1.0, alvo)
			add_child(alvo)
			alvo.global_position = player.chassi.global_position + Vector2(1500, -2300)
			await get_tree().physics_frame
			var p0 := player.chassi.global_position
			Input.action_press("especial")
			for k in 90:
				await get_tree().physics_frame
				if k == 45 and "fotos" in OS.get_cmdline_user_args():
					await _captura("hab_" + Game.personagem)
			var preso := not player._arpao.is_empty()
			Input.action_release("especial")
			print("[ESPECIAL] arpao: preso=%s, subiu %.0f px, andou %.0f px" % [preso, p0.y - player.chassi.global_position.y, player.chassi.global_position.x - p0.x])
			await _esperar(1.0)
			alvo.queue_free()

func _teste_queda() -> void:
	await _esperar(3.0)
	print("[QUEDA] %s: montado=%s" % [Game.personagem, player.montado])
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
	if Online.ativo and not _recomecando:     # saiu da luta online: fecha a sala
		Online.sair()
	Audio.motor(false)                        # sair da fase cala o motor
	Engine.time_scale = 1.0

# ---------- FASE 7: Escola Americana (boss: Adriano) ----------
## corredor de armários (portas de armário que abrem e fecham, serras, carteiras e
## minas), depois o terraço com a bola gigante rolando atrás. Pulou do terraço:
## tela preta "ALGUÉM CAIU DO 5º COM VOCÊ!", salva o checkpoint e começa a queda
## infinita com o Adriano.
const ARENA7_X := 150000.0
var adriano: Adriano
var _queda7 := false
var _bola7: AnimatableBody2D
var _bola7_v := 0.0
var _bola7_r := 950.0
var _terraco_y := 1000.0
var _borda7 := 0.0

func _fase_7() -> void:
	var y := CHAO_Y
	pecas.cor_chao = Color(0.42, 0.47, 0.47)
	_parede_arena(-2700.0, y)
	var p := _t_plano(Vector2(-2600, y), 3900, false)
	pecas.placa(Vector2(-900, y), "LARGADA")
	p = _armarios7(p, 2)
	p = _t_serras(p)
	p = _t_plano(p, 500, false)
	p = _carteiras7(p)
	p = _t_tnt(p)
	p = _armarios7(p, 3)
	p = _t_tnt(p)
	p = _t_plano(p, 700, false)
	_corredor7(-6000.0, p.x, y)
	# terraço: céu aberto, bola gigante atrás e a borda lá na frente
	var t0 := p.x
	_terraco_y = p.y
	p = _t_plano(p, 9000, false)
	_borda7 = p.x
	_terraco7(t0, _borda7, _terraco_y)
	var gat := _area(Vector2(t0 + 600.0, _terraco_y - 700), Vector2(200, 1600))
	gat.body_entered.connect(func(b: Node2D) -> void:
		if (b.is_in_group("veiculo") or b.is_in_group("piloto")) and _bola7 == null: _soltar_bola7.call_deferred())
	var pulo := _area(Vector2(_borda7 + 5000.0, _terraco_y + 1300.0), Vector2(11000, 400))
	pulo.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _iniciar_queda7.call_deferred())
	adriano = Adriano.new()
	add_child(adriano)
	adriano.montar(self, ARENA7_X, y)
	adriano.derrotado.connect(func() -> void:
		_meta_pos = player.foco().global_position
		_fim(true, "venceu"))
	_marcos([], Vector2(ARENA7_X + 14000.0, y), y + 5000.0, false)

func _armarios7(p: Vector2, n: int) -> Vector2:
	var comp := 900.0 + n * 2400.0
	_t_plano(p, comp, false)
	for k in n:
		_porta(Vector2(p.x + 1200.0 + k * 2400.0, p.y), p.y - 2700.0, [3.0, 2.6, 2.8][k % 3], true)
	return p + Vector2(comp, 0)

## pilhas de carteiras: rampinha, carteira e desce
func _carteiras7(p: Vector2) -> Vector2:
	_t_plano(p, 3400, false)
	for k in 2:
		var x := p.x + 500.0 + k * 1600.0
		pecas.rampa(x, x + 600.0, p.y, 260)
		var sb := StaticBody2D.new()
		sb.collision_layer = 0b01
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(520, 260)
		cs.shape = r
		sb.add_child(cs)
		sb.position = Vector2(x + 860.0, p.y - 130.0)
		pecas.poligono(Pecas.retangulo(Vector2(0, -110), Vector2(560, 50)), Color(0.62, 0.42, 0.24), 1, null, 1.0, sb)
		for lx in [-220.0, 220.0]:
			pecas.poligono(Pecas.retangulo(Vector2(lx, 30), Vector2(30, 220)), Color(0.35, 0.36, 0.4), 1, null, 1.0, sb)
		pecas.poligono(Pecas.retangulo(Vector2(0, 40), Vector2(440, 26)), Color(0.35, 0.36, 0.4), 1, null, 1.0, sb)
		add_child(sb)
	return p + Vector2(3400, 0)

## fundo do corredor: a foto dos armários repetida na altura certa (chão da foto = chão do jogo)
func _corredor7(xa: float, xb: float, y: float) -> void:
	var tex: Texture2D = load("res://assets/adriano/corredor.jpg")
	var esc := 2900.0 / 640.0
	var larg := tex.get_width() * esc
	var x := xa
	while x < xb:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2.ONE * esc
		s.position = Vector2(x, y - 640.0 * esc + 20.0)
		if x + larg > xb:                             # último pedaço: corta pra não entrar no terraço
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, (xb - x) / esc, tex.get_height())
		s.z_index = -7
		add_child(s)
		x += larg - 4.0
	pecas.placa_perigo(Vector2(xb - 400.0, y))

## terraço: muretinha, caixas d'água, ar-condicionado e antena, céu aberto
func _terraco7(xa: float, xb: float, y: float) -> void:
	pecas.poligono(Pecas.retangulo(Vector2((xa + xb) / 2.0, y - 140.0), Vector2(xb - xa, 280)), Color(0.78, 0.74, 0.68), -6)
	pecas.poligono(Pecas.retangulo(Vector2((xa + xb) / 2.0, y - 290.0), Vector2(xb - xa, 40)), Color(0.6, 0.57, 0.52), -6)
	var x := xa + 800.0
	var k := 0
	while x < xb - 600.0:
		match k % 3:
			0:
				pecas.poligono(Pecas.retangulo(Vector2(x, y - 600.0), Vector2(700, 900)), Color(0.35, 0.45, 0.6), -5)
				pecas.poligono(Pecas.retangulo(Vector2(x, y - 1080.0), Vector2(760, 60)), Color(0.25, 0.3, 0.4), -5)
			1:
				pecas.poligono(Pecas.retangulo(Vector2(x, y - 300.0), Vector2(900, 500)), Color(0.82, 0.83, 0.86), -5)
				for g in 5:
					pecas.poligono(Pecas.retangulo(Vector2(x - 300 + g * 150, y - 300.0), Vector2(60, 380)), Color(0.6, 0.62, 0.66), -5)
			2:
				pecas.linha(PackedVector2Array([Vector2(x, y - 300.0), Vector2(x, y - 2600.0)]), 30.0, Color(0.4, 0.4, 0.44), -5)
				for g in 3:
					pecas.linha(PackedVector2Array([Vector2(x - 300 + g * 60, y - 2200.0 + g * 200), Vector2(x + 300 - g * 60, y - 2200.0 + g * 200)]), 18.0, Color(0.4, 0.4, 0.44), -5)
		x += 2400.0
		k += 1
	# placa do prédio na borda
	var l := Label.new()
	l.text = "ESCOLA AMERICANA"
	l.add_theme_font_size_override("font_size", 260)
	l.add_theme_color_override("font_color", Color(0.12, 0.2, 0.45))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 30)
	l.position = Vector2(xb - 3200.0, y - 1500.0)
	l.z_index = -5
	add_child(l)
	pecas.placa_perigo(Vector2(xb - 500.0, y))

## a bola gigante: rola atrás de você no terraço e esmaga
func _soltar_bola7() -> void:
	_bola7 = AnimatableBody2D.new()
	_bola7.sync_to_physics = false
	_bola7.collision_layer = 0b1000
	_bola7.collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = _bola7_r
	cs.shape = c
	_bola7.add_child(cs)
	var s := Sprite2D.new()
	s.texture = load("res://assets/adriano/bola.png")
	s.scale = Vector2.ONE * (_bola7_r * 2.0 / 1073.0)
	_bola7.add_child(s)
	_bola7.position = Vector2(player.foco().global_position.x - 3600.0, _terraco_y - _bola7_r)
	_bola7.z_index = 6
	add_child(_bola7)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 0b110
	var ca := CollisionShape2D.new()
	var cc := CircleShape2D.new()
	cc.radius = _bola7_r * 0.95
	ca.shape = cc
	a.add_child(ca)
	_bola7.add_child(a)
	a.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _on_perigo(b, "esmagado"))
	_bola7_v = 500.0
	_mensagem("CORRE!!!", Color(1, 0.4, 0.2))
	Audio.tocar("impacto_forte", 1.0)

func _atualizar_escola(delta: float) -> void:
	_mover_portas()
	if is_instance_valid(_bola7):
		_bola7_v = minf(_bola7_v + 900.0 * delta, 1150.0)
		_bola7.position.x += _bola7_v * delta
		_bola7.rotation += _bola7_v * delta / _bola7_r
		if _bola7.position.x > _borda7 + _bola7_r * 0.6:      # passou da borda: despenca
			_bola7.position.y += 2500.0 * delta
			if _bola7.position.y > _terraco_y + 8000.0:
				_bola7.queue_free()
				_bola7 = null
		elif int(_t_fisica * 60.0) % 18 == 0:
			pecas.poeira(_bola7.position + Vector2(-_bola7_r * 0.5, _bola7_r), 1.2)
	if adriano:
		adriano.atualizar(delta)

## pulou do terraço: tela preta com o aviso, música da queda, salva e vai pra luta
func _iniciar_queda7() -> void:
	if _queda7 or not ativo:
		return
	_queda7 = true
	Audio.parar_chefe()
	Audio.musica_chefe("adriano")
	var cena := CanvasLayer.new()
	cena.layer = 80
	cena.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cena)
	var preto := ColorRect.new()
	preto.color = Color(0, 0, 0, 0)
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	cena.add_child(preto)
	var txt := Label.new()
	txt.text = "ALGUÉM CAIU DO 5º\nCOM VOCÊ!"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.set_anchors_preset(Control.PRESET_FULL_RECT)
	txt.add_theme_font_size_override("font_size", 84)
	txt.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	txt.add_theme_color_override("font_outline_color", Color.BLACK)
	txt.add_theme_constant_override("outline_size", 14)
	txt.modulate.a = 0.0
	cena.add_child(txt)
	var tw := cena.create_tween()
	tw.tween_property(preto, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: get_tree().paused = true)
	tw.tween_property(txt, "modulate:a", 1.0, 0.4)
	tw.tween_interval(4.6)
	tw.tween_callback(func() -> void:
		get_tree().paused = false
		var ini := adriano.piso_inicial()
		Game.checkpoint_x = ini.x
		Game.checkpoint_chao = ini.y
		Game.queda_fade = true
		_recomecando = true                   # online: recarrega sem sair da sala
		get_tree().reload_current_scene.call_deferred())

## começo da fase 7: no corredor toca a música da escola; no checkpoint da queda começa a luta
func _inicio_7() -> void:
	if Game.checkpoint_x < ARENA7_X - 1000.0:
		Audio.musica_chefe("escola")
		return
	do_inicio = true
	camera.zoom = Vector2(0.22, 0.22)
	adriano.comecar()
	Audio.musica_chefe("adriano")
	if Game.queda_fade:                              # veio da tela preta: clareia pra luta
		Game.queda_fade = false
		var cena := CanvasLayer.new()
		cena.layer = 80
		add_child(cena)
		var preto := ColorRect.new()
		preto.color = Color.BLACK
		preto.set_anchors_preset(Control.PRESET_FULL_RECT)
		preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cena.add_child(preto)
		var tw := cena.create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(preto, "color:a", 0.0, 1.2)
		tw.tween_callback(cena.queue_free)

# ---------- ONLINE: Chefão em grupo ----------
## cada um manda o próprio boneco ~10x/s; os outros aparecem como "fantasma" (sem
## colisão). Quem criou a sala comanda o chefe (ataques, números, lasers, botões);
## qualquer um aperta botão. Morreu: renasce em 6 s se alguém do time estiver vivo.
const RENASCE := 6.0
var _fantasmas: Dictionary = {}          # id -> {no, de, para, t, rot, vivo, visto}
var _envio_t := 0.0
var _morto_online := false
var _renasce_t := -1.0
var _rotulo_online: Label

func _reiniciar() -> void:
	if Online.ativo:
		if Game.fase == 5:                    # co-op: o chefe é de todo mundo, volta pra sala (sem sair dela)
			_ir_pra_sala()
		else:                                 # corrida: volta pro começo e o relógio continua
			_recarregar()
		return
	get_tree().reload_current_scene()

## recarrega a fase sem sair da sala online
func _recarregar() -> void:
	_recomecando = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func _ir_pra_sala() -> void:
	_recomecando = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://levels/Sala.tscn")

func _iniciar_online() -> void:
	var c := Online.corrida
	if Online.host and not c.get("largou", false):   # reenvia o aviso de começar (celular pode perder uma mensagem)
		for k in 3:
			get_tree().create_timer(0.5 + k * 1.0, true, false, true).timeout.connect(func() -> void:
				Online.enviar("comecar", {"ids": c.get("ids", []), "r": Online.rodada, "fase": Game.fase}))
	Online.recebeu.connect(_online_msg)
	Online.caiu.connect(func() -> void: _mensagem("CONEXÃO CAIU!", Color(1, 0.4, 0.3)))
	_rotulo_online = Label.new()
	_rotulo_online.add_theme_font_size_override("font_size", 22)
	_rotulo_online.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_rotulo_online.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo_online.add_theme_constant_override("outline_size", 6)
	_rotulo_online.position = Vector2(24, 165)
	$HUD.add_child(_rotulo_online)
	if not c.get("largou", false):
		_esperar_largada.call_deferred()
	for arg in OS.get_cmdline_user_args():       # teste: chega sozinho N s depois da largada
		if arg.begins_with("chegar="):
			_teste_chegar.call_deferred(float(arg.substr(7)))

func _teste_chegar(s: float) -> void:
	while is_inside_tree() and not Online.corrida.get("largou", false):
		await get_tree().create_timer(0.2, true, false, true).timeout
	await get_tree().create_timer(s, true, false, true).timeout
	if is_inside_tree():
		_fim(true, "meta")

# ---------- largada junto: espera todo mundo carregar, aí 3, 2, 1, VAI ----------
const ESPERA_CARREGAR := 12.0         # quem demora mais que isso pra carregar larga atrasado
var _carregados: Dictionary = {}
var _contagem: Label
var _contando := false
var _espera_ms := 0
var _decidiu := false

func _esperar_largada() -> void:
	get_tree().paused = true
	_contagem = Label.new()
	_contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contagem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_contagem.add_theme_font_size_override("font_size", 64)
	_contagem.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_contagem.add_theme_color_override("font_outline_color", Color.BLACK)
	_contagem.add_theme_constant_override("outline_size", 18)
	_contagem.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contagem.text = "ESPERANDO TODO MUNDO\nCARREGAR..."
	$HUD.add_child(_contagem)
	_carregados[Online.id] = true
	_espera_ms = Time.get_ticks_msec()
	while is_inside_tree() and not _contando:
		Online.enviar("carregou", {"r": Online.rodada})
		if Online.host:
			_conferir_largada()
		await get_tree().create_timer(1.0, true, false, true).timeout

## quem criou a sala solta a largada quando todo mundo carregou (ou cansou de esperar)
func _conferir_largada() -> void:
	if _decidiu:
		return
	for k in Online.corrida.get("ids", []):
		if (k == Online.id or Online.jogadores.has(k)) and not _carregados.has(k) \
				and Time.get_ticks_msec() - _espera_ms < ESPERA_CARREGAR * 1000.0:
			return
	_decidiu = true
	var vai := Time.get_ticks_msec() + 3000
	_contagem_ate(vai)
	while is_inside_tree() and Time.get_ticks_msec() < vai + 20000:   # reenvia: quem carregar atrasado larga junto
		Online.enviar("largada", {"r": Online.rodada, "atraso": (Time.get_ticks_msec() - vai) / 1000.0})
		await get_tree().create_timer(1.5, true, false, true).timeout

func _contagem_ate(vai: int) -> void:
	if _contando:
		return
	_contando = true
	var ult := -1
	while is_inside_tree() and Time.get_ticks_msec() < vai:
		var n := ceili((vai - Time.get_ticks_msec()) / 1000.0)
		if n != ult:
			ult = n
			_contagem.add_theme_font_size_override("font_size", 200)
			_contagem.text = str(n)
			Audio.tocar("clique")
		await get_tree().create_timer(0.05, true, false, true).timeout
	if not is_inside_tree():
		return
	Online.corrida["largou"] = true
	Online.corrida["inicio_ms"] = vai
	get_tree().paused = false
	_contagem.text = "VAI!"
	_contagem.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
	Audio.tocar("confirma")
	await get_tree().create_timer(0.8, true, false, true).timeout
	if is_instance_valid(_contagem):
		_contagem.queue_free()

# ---------- corrida (todas as fases menos a do Péce) ----------
const ESPERA_CORRIDA := 30.0          # depois que o primeiro chega, os outros têm 30 s
var _resultado_ok := false

func _morte_corrida(motivo: String) -> void:
	if _morto_online:
		return
	_morto_online = true
	aviso.text = {"esmagado": "ESMAGADO!", "agarrado": "TE PEGOU!", "laser": "DESINTEGRADO!", "pedra": "ESMAGADO!", "agua": "AFOGOU!", "buraco": "CAIU!", "caiu": "CAIU!"}.get(motivo, "MORREU!") + "\nvoltando pro começo..."
	aviso.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	aviso.visible = true
	Audio.tocar("morte")
	_envio_t = 0.0
	await get_tree().create_timer(2.0, true, false, true).timeout
	if is_inside_tree() and not _resultado_ok:
		_recarregar()

func _lugar(quem: String) -> int:
	var ch: Dictionary = Online.corrida.get("chegadas", {})
	var t := float(ch.get(quem, INF))
	var n := 1
	for k in ch:
		if k != quem and float(ch[k]) < t:
			n += 1
	return n

func _chegou_online() -> void:
	if _morto_online or not ativo:
		return
	ativo = false
	Audio.parar_chefe()
	Audio.motor(false)
	Audio.tocar("vitoria")
	_esconder_barras_chefe()
	if is_instance_valid(player):
		pecas.festa(_meta_pos, player.foco().global_position)
	var c := Online.corrida
	(c["chegadas"] as Dictionary)[Online.id] = tempo
	if int(c.get("primeiro_ms", -1)) < 0:
		c["primeiro_ms"] = Time.get_ticks_msec()
	var t := tempo
	for k in 3:
		get_tree().create_timer(0.05 + k * 0.7, true, false, true).timeout.connect(func() -> void:
			Online.enviar("chegou", {"t": t, "r": Online.rodada}))
	aviso.text = "CHEGOU EM %dº!\n%.1f s" % [_lugar(Online.id), t]
	aviso.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
	aviso.visible = true
	print("[ONLINE] chegou %.2f lugar %d" % [t, _lugar(Online.id)])

func _conferir_fim_corrida() -> void:
	var c := Online.corrida
	if _resultado_ok or not c.get("largou", false):
		return
	var ch: Dictionary = c.get("chegadas", {})
	var todos := true
	for k in c.get("ids", []):
		if (k == Online.id or Online.jogadores.has(k)) and not ch.has(k):
			todos = false
	var p := int(c.get("primeiro_ms", -1))
	var resta := (ESPERA_CORRIDA - (Time.get_ticks_msec() - p) / 1000.0) if p >= 0 else INF
	if todos or resta <= 0.0:
		_resultado_corrida()
	elif p >= 0 and ch.has(Online.id):
		aviso.text = "CHEGOU EM %dº!\nesperando os outros... %d s" % [_lugar(Online.id), ceili(resta)]
	elif p >= 0 and _rotulo_online:
		_rotulo_online.text = "ALGUÉM JÁ CHEGOU! A CORRIDA ACABA EM %d s" % ceili(resta)
		_rotulo_online.add_theme_color_override("font_color", Color(1, 0.4, 0.3))

func _resultado_corrida() -> void:
	_resultado_ok = true
	ativo = false
	Audio.motor(false)
	Audio.parar_chefe()
	var c := Online.corrida
	var ch: Dictionary = c.get("chegadas", {})
	var lista: Array = []
	for k in c.get("ids", []):
		if k == Online.id or Online.jogadores.has(k) or ch.has(k):
			lista.append([k, float(ch.get(k, INF))])
	lista.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	var txt := ""
	for i in lista.size():
		var nome := Online.nome_de(lista[i][0]) + (" (você)" if lista[i][0] == Online.id else "")
		txt += ("%dº   %s   %.1f s\n" % [i + 1, nome, lista[i][1]]) if lista[i][1] < INF else ("—   %s   não chegou\n" % nome)
	aviso.text = ("%s VENCEU!" % Online.nome_de(lista[0][0])) if not lista.is_empty() and lista[0][1] < INF else "NINGUÉM CHEGOU!"
	aviso.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	aviso.visible = true
	print("[ONLINE] resultado: ", txt.replace("\n", " | "))
	_fim_online(true, txt.strip_edges())
	if Online.host and "denovo" in OS.get_cmdline_user_args() and Online.rodada < 2:   # teste: o líder joga de novo
		await get_tree().create_timer(2.0, true, false, true).timeout
		_nova_rodada(Game.fase)

func _process_online(delta: float) -> void:
	var dt := delta / Engine.time_scale
	_envio_t -= dt
	if _envio_t <= 0.0 and is_instance_valid(player) and is_instance_valid(player.chassi):
		_envio_t = 0.1
		var f := player.foco()
		var v: Vector2 = player.chassi.linear_velocity if player.montado else Vector2.ZERO
		var pe := f.global_position                     # manda o ponto do chão (embaixo das rodas)
		if player.montado and player.rodas.size() > 0:
			var baixo := -INF
			for rd in player.rodas:
				var cs := (rd as Node).get_child(0) as CollisionShape2D
				var raio: float = (cs.shape as CircleShape2D).radius if cs and cs.shape is CircleShape2D else 0.0
				baixo = maxf(baixo, (rd as Node2D).global_position.y + raio)
			pe = Vector2(player.chassi.global_position.x, baixo)
		Online.enviar("p", {"x": int(pe.x), "y": int(pe.y), "r": snappedf(player.chassi.rotation, 0.01),
			"vx": int(v.x), "vy": int(v.y), "v": not _morto_online and player.montado, "pers": Game.pasta(Game.personagem),
			"nome": Online.meu_nome()})
	var agora := Time.get_ticks_msec()
	var vivos := 0
	for k in _fantasmas.keys():
		var g: Dictionary = _fantasmas[k]
		if agora - int(g["visto"]) > 6000 or not Online.jogadores.has(k):   # saiu da sala
			(g["no"] as Node).queue_free()
			_fantasmas.erase(k)
			continue
		g["t"] = minf(1.0, float(g["t"]) + dt / 0.1)
		var no: Node2D = g["no"]
		no.global_position = (g["de"] as Vector2).lerp(g["para"], g["t"])
		no.rotation = lerp_angle(no.rotation, float(g["rot"]), 0.3)
		no.modulate = Color(1, 1, 1, 0.8) if g["vivo"] else Color(0.4, 0.4, 0.45, 0.35)
		if g["vivo"]:
			vivos += 1
	if _rotulo_online:
		_rotulo_online.visible = not aviso.visible
		if Game.fase == 5:
			if Online.host and ativo:
				_mandar_vida_chefe(dt)
			_rotulo_online.text = "ONLINE · SALA %s · %d jogadores · %d vivos" % [Online.sala, Game.online_n, vivos + (0 if _morto_online else 1)]
		else:
			_rotulo_online.text = "CORRIDA · SALA %s · %d jogadores" % [Online.sala, Game.online_n]
			_conferir_fim_corrida()
	if _renasce_t >= 0.0:
		_renasce_t -= dt
		aviso.text = "MORREU!\nrenasce em %d s" % ceili(_renasce_t)
		if vivos == 0:                                    # todo mundo morto: acabou
			_renasce_t = -1.0
			_morto_online = false
			ativo = false
			Audio.parar_chefe()
			aviso.text = "O TIME TODO MORREU!"
			Audio.tocar("morte")
			_fim_online()
		elif _renasce_t <= 0.0:
			_renasce_t = -1.0
			_renascer()

func _fantasma(de: String, d: Dictionary) -> void:
	if not _fantasmas.has(de):
		var no := Node2D.new()
		no.z_index = 3
		var s := Sprite2D.new()
		var pers := str(d.get("pers", "segway"))
		if ResourceLoader.exists("res://assets/menu/%s.png" % pers):
			s.texture = load("res://assets/menu/%s.png" % pers)
			var alt := 1300.0                             # altura real do boneco (arte do parts.json)
			var f := FileAccess.open("res://assets/%s/parts.json" % pers, FileAccess.READ)
			if f:
				var pj = JSON.parse_string(f.get_as_text())
				if typeof(pj) == TYPE_DICTIONARY and pj.has("src_h"):
					alt = float(pj["src_h"]) * 0.95
			s.scale = Vector2.ONE * alt / float(s.texture.get_height())
			s.centered = false                            # pé (embaixo do desenho) no ponto recebido
			s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
		no.add_child(s)
		var l := Label.new()
		l.text = str(d.get("nome", "?"))
		l.add_theme_font_size_override("font_size", 130)
		l.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(1200, 160)
		var topo := (s.texture.get_height() * s.scale.y) if s.texture else 1300.0
		l.position = Vector2(-600, -topo - 200.0)
		no.add_child(l)
		add_child(no)
		var p0 := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		no.global_position = p0
		_fantasmas[de] = {"no": no, "de": p0, "para": p0, "t": 1.0, "rot": 0.0, "vivo": true, "visto": 0, "vel": Vector2.ZERO}
	var g: Dictionary = _fantasmas[de]
	g["de"] = (g["no"] as Node2D).global_position
	g["para"] = Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
	g["t"] = 0.0
	g["rot"] = float(d.get("r", 0.0))
	g["vivo"] = bool(d.get("v", true))
	g["vel"] = Vector2(float(d.get("vx", 0)), float(d.get("vy", 0)))
	g["visto"] = Time.get_ticks_msec()

## chefe (quem criou a sala) mira num jogador vivo sorteado: [posição, velocidade]
func alvo_online() -> Array:
	var c: Array = []
	if not _morto_online and is_instance_valid(player) and is_instance_valid(player.chassi) and player.montado:
		c.append([player.foco().global_position, player.chassi.linear_velocity])
	for k in _fantasmas:
		var g: Dictionary = _fantasmas[k]
		if g["vivo"] and Time.get_ticks_msec() - int(g["visto"]) < 1500:
			c.append([g["para"], g["vel"]])
	if c.is_empty():
		return []
	return c[randi() % c.size()]

func _online_msg(e: String, d: Dictionary, de: String) -> void:
	match e:
		"p":
			_fantasma(de, d)
		"atk":
			if is_instance_valid(boss) and not Online.host:
				var i := int(d.get("i", 0))
				if i < boss.maos.size():
					boss._iniciar(boss.maos[i], str(d.get("s", "tapa_sobe")), Vector2(float(d.get("x", 0)), 0), true)
		"pd":
			if is_instance_valid(boss) and not Online.host:
				boss.soltar_pedra(float(d.get("x", 0)), true)
		"lz":
			if is_instance_valid(boss) and not Online.host:
				boss._laser(float(d.get("x", 0)), true)
		"bt":                                        # quem criou a sala acendeu um botão
			if not Online.host:
				var i := int(d.get("i", 0))
				if i >= 0 and i < _botoes.size():
					_botao_ativo = i
					(_botoes[i] as Dictionary).erase("pedido")
					_ligar_botao(_botoes[i])
					_mensagem("BOTÃO LIGADO! VAI LÁ!", Color(1, 0.9, 0.3))
		"ap":                                        # alguém apertou: quem criou a sala conta
			if Online.host:
				var i := int(d.get("i", -1))
				if i >= 0 and i < _botoes.size():
					_registrar_aperto(_botoes[i], de)
		"apc":                                       # placar de quem já apertou
			var i := int(d.get("i", -1))
			if i >= 0 and i < _botoes.size() and (_botoes[i] as Dictionary).has("contador"):
				var c: Label = _botoes[i]["contador"]
				if is_instance_valid(c):
					c.text = str(d.get("t", ""))
		"comecar":                                   # o líder começou outra partida
			if not Online.host and Online.id in (d.get("ids", []) as Array) and int(d.get("r", 0)) > Online.rodada:
				Online.rodada = int(d.get("r", 0))
				_recomecar(d.get("ids", []), int(d.get("fase", Game.fase)))
		"sala":                                      # o líder voltou pra sala: todo mundo volta
			if not Online.host and int(d.get("r", 0)) == Online.rodada:
				_ir_pra_sala()
		"carregou":
			if Online.host and int(d.get("r", 0)) == Online.rodada:
				_carregados[de] = true
				_conferir_largada()
		"largada":
			if not Online.host and int(d.get("r", 0)) == Online.rodada and not _contando and is_instance_valid(_contagem):
				_contagem_ate(Time.get_ticks_msec() - int(float(d.get("atraso", 0.0)) * 1000.0))
		"chegou":
			var c := Online.corrida
			var ch: Dictionary = c.get("chegadas", {})
			if int(d.get("r", 0)) == Online.rodada and not ch.has(de) and c.has("chegadas"):
				ch[de] = float(d.get("t", 0.0))
				if int(c.get("primeiro_ms", -1)) < 0:
					c["primeiro_ms"] = Time.get_ticks_msec()
				if de != Online.id:
					_mensagem("%s CHEGOU EM %dº!" % [Online.nome_de(de), _lugar(de)], Color(1, 0.85, 0.3))
		"vit":                                       # quem criou a sala derrotou o chefe: o time venceu
			if not Online.host and int(d.get("r", 0)) == Online.rodada:
				_vitoria_online()
		"ch":                                        # choque confirmado: todo mundo aplica
			if not Online.host:
				var i := int(d.get("i", -1))
				if i >= 0 and i < _botoes.size():
					(_botoes[i] as Dictionary)["ligado"] = true
					_apertar(_botoes[i], true)
				_sinc_chefe(d)
		"hp":                                        # vida do chefe segundo quem criou a sala
			if not Online.host and int(d.get("r", 0)) == Online.rodada:
				_sinc_chefe(d)

func _morte_online(motivo: String) -> void:
	if _morto_online:
		return
	_morto_online = true
	_renasce_t = RENASCE
	aviso.text = {"esmagado": "ESMAGADO!", "agarrado": "TE PEGOU!", "laser": "DESINTEGRADO!", "pedra": "ESMAGADO!"}.get(motivo, "MORREU!")
	aviso.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	aviso.visible = true
	Audio.tocar("morte")
	_envio_t = 0.0

func _renascer() -> void:
	_morto_online = false
	aviso.visible = false
	var velho := player
	_criar_jogador(ARENA_X0 + 1600.0, CHAO_Y)
	player.fundo_y = morte_y - 300.0
	player.sangue = sangue
	add_child(player)
	move_child(player, sangue.get_index())
	camera.alvo = player.foco()
	_caiu_em = -1.0
	if is_instance_valid(velho):
		velho.queue_free()
	Audio.tocar("checkpoint", 1.0)
	_mensagem("VOLTOU!", Color(0.5, 1, 0.5))

## vida do chefe: quem criou a sala manda, os outros corrigem (mensagem perdida não deixa vida diferente)
var _hp_t := 0.0

func _estado_chefe(d: Dictionary) -> Dictionary:
	d["r"] = Online.rodada
	d["v"] = boss.vida
	d["s"] = boss.segunda or boss.transformando
	d["m"] = boss.morto
	return d

func _mandar_vida_chefe(dt: float) -> void:
	_hp_t -= dt
	if _hp_t > 0.0 or not is_instance_valid(boss):
		return
	_hp_t = 1.5
	Online.enviar("hp", _estado_chefe({}))

func _sinc_chefe(d: Dictionary) -> void:
	if not is_instance_valid(boss) or not d.has("v") or boss.morto or boss.transformando:
		return
	var s := bool(d.get("s", false))
	if bool(d.get("m", false)) and boss.segunda:     # líder já matou o Cepé
		boss.vida = 1
		boss.levar_choque()
	elif s and not boss.segunda:                     # líder já virou Cepé: transforma aqui também
		boss.vida = 1
		boss.levar_choque()
	elif s == boss.segunda and boss.vida != int(d["v"]):
		boss.vida = int(d["v"])
		boss._posicionar_barra()

## ids dos jogadores vivos agora (eu + quem mandou estado vivo há pouco)
func _vivos_online() -> Array:
	var v: Array = []
	if not _morto_online:
		v.append(Online.id)
	for k in _fantasmas:
		var g: Dictionary = _fantasmas[k]
		if g["vivo"] and Time.get_ticks_msec() - int(g["visto"]) < 2500:
			v.append(k)
	return v

## quem criou a sala conta os apertos; quando todos os vivos apertaram, o choque sai pra todos
func _registrar_aperto(b: Dictionary, quem: String) -> void:
	if not b["ligado"]:
		return
	var q: Dictionary = b.get("quem", {})
	if not q.has(quem):
		q[quem] = true
		b["quem"] = q
		Audio.tocar("clique", 1.0)
	_conferir_botao(b)

func _conferir_botao(b: Dictionary) -> void:
	var vivos := _vivos_online()
	var q: Dictionary = b.get("quem", {})
	var feitos := 0
	for k in vivos:
		if q.has(k):
			feitos += 1
	var i := _botoes.find(b)
	var txt := "%d/%d" % [feitos, maxi(1, vivos.size())]
	if b.has("contador") and (b["contador"] as Label).text != txt:
		(b["contador"] as Label).text = txt
		Online.enviar("apc", {"i": i, "t": txt})
	if vivos.size() > 0 and feitos >= vivos.size():
		_apertar(b, true)
		Online.enviar("ch", _estado_chefe({"i": i}))

## online: chefe derrotado = todo mundo vence junto (quem criou a sala confirma pros outros)
func _vitoria_online() -> void:
	if Online.host:
		for k in 4:
			get_tree().create_timer((0.05 + k * 0.6) * Engine.time_scale, true).timeout.connect(func() -> void:
				Online.enviar("vit", {"r": Online.rodada}))
	if not ativo:
		return
	ativo = false
	_renasce_t = -1.0
	_morto_online = false
	Audio.parar_chefe()
	Audio.motor(false)
	Audio.tocar("vitoria")
	Game.registrar_vitoria(Game.fase, tempo)
	Game.checkpoint_x = -1.0
	aviso.text = "O TIME VENCEU!\n%.1f s" % tempo
	aviso.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
	aviso.visible = true
	if is_instance_valid(player):
		pecas.festa(player.foco().global_position + Vector2(900, 0), player.foco().global_position)
	print("[FASE] time venceu %.2f" % tempo)
	_fim_online(true)
	venceu.emit(tempo)

## esconde barra de vida e nome do chefe (tela de fim fica limpa)
func _esconder_barras_chefe() -> void:
	for c in [boss, adriano, geresch, ctamandura]:
		if is_instance_valid(c):
			for n in [c._barra, c._barra_fundo, c._rotulo]:
				if n:
					(n as CanvasItem).visible = false

## fim online (corrida acabou, time venceu ou morreu): o líder escolhe jogar de novo ou voltar pra sala
var _recomecando := false
var _painel_on: Control
var _info_fim: Label

func _fim_online(ganhou := false, resultado := "") -> void:
	if painel:
		painel.visible = false
	_painel_on = Control.new()
	_painel_on.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(_painel_on)
	$HUD.move_child(_painel_on, aviso.get_index())     # escurece o jogo, título por cima
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.6)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel_on.add_child(escuro)
	_esconder_barras_chefe()
	if _rotulo_online:
		_rotulo_online.visible = false
	var v := get_viewport().get_visible_rect().size
	if resultado != "":
		var r := Label.new()
		r.text = resultado
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_theme_font_size_override("font_size", 36)
		r.add_theme_color_override("font_outline_color", Color.BLACK)
		r.add_theme_constant_override("outline_size", 10)
		r.size = Vector2(v.x, 200)
		r.position = Vector2(0, v.y * 0.06 + 100)
		_painel_on.add_child(r)
	var y := v.y * (0.62 if resultado != "" else 0.55)
	if Online.host:
		var b_denovo := _botao_fim("JOGAR DE NOVO", Vector2(v.x / 2.0 - 440, y), Color(0.4, 1, 0.5))
		b_denovo.pressed.connect(func() -> void:
			Audio.tocar("confirma")
			_nova_rodada(Game.fase))
	var b_sala := _botao_fim("VOLTAR PRA SALA", Vector2(v.x / 2.0 + 40 if Online.host else v.x / 2.0 - 200, y), Color(1, 0.8, 0.3))
	b_sala.pressed.connect(func() -> void:
		Audio.tocar("clique")
		if Online.host:                           # o líder leva todo mundo
			for k in 3:
				Online.enviar("sala", {"r": Online.rodada})
		_ir_pra_sala())
	_info_fim = Label.new()
	_info_fim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_fim.add_theme_font_size_override("font_size", 26)
	_info_fim.add_theme_color_override("font_outline_color", Color.BLACK)
	_info_fim.add_theme_constant_override("outline_size", 8)
	_info_fim.size = Vector2(v.x, 40)
	_info_fim.position = Vector2(0, y + 104)
	_info_fim.text = ("JOGAR DE NOVO recomeça com todo mundo que está na sala; VOLTAR PRA SALA pra trocar de fase." if Online.host
		else "Esperando o líder: jogar de novo ou voltar pra sala.")
	_painel_on.add_child(_info_fim)

func _botao_fim(texto: String, pos: Vector2, cor: Color) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.custom_minimum_size = Vector2(400, 84)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.05, 0.15, 0.9)
	st.set_corner_radius_all(16)
	st.set_border_width_all(4)
	st.border_color = cor
	for k in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(k, st)
	b.position = pos
	_painel_on.add_child(b)
	return b

## o líder começa outra partida na mesma fase com todo mundo que está na sala
func _nova_rodada(fase: int) -> void:
	var ids: Array = [Online.id] + Online.jogadores.keys()
	Online.rodada += 1
	Online.enviar("comecar", {"ids": ids, "r": Online.rodada, "fase": fase})
	_recomecar(ids, fase)

## recomeça a partida online com essas pessoas (sem fechar a sala)
func _recomecar(ids: Array, fase: int) -> void:
	_recomecando = true
	Online.corrida = {"r": Online.rodada, "fase": fase, "ids": ids, "largou": false, "chegadas": {}, "primeiro_ms": -1}
	Game.online_n = clampi(ids.size(), 1, Online.MAX_JOGADORES)
	Game.fase = fase
	Game.checkpoint_x = -1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://levels/Main.tscn")

# ---------- FASE 8: Block Blast (boss: Geresch) ----------
## fase colorida: blocos de Block Blast como obstáculo (degraus, pontes de peças sobre
## espinhos), espinhos e minas. No fim toca o vídeo do Geresch levantando da cadeira
## com a batida da música sincronizada, salva e começa a luta.
const ARENA8_X := 200000.0
const ARENA8_LARG := 10000.0
const MUSICA8_LOOP := 15.28          # onde começa a parte forte (loop da luta)
const VIDEO8_LEVANTA := 12.0         # segundo do vídeo em que ele levanta
var geresch: Geresch
var _palco8: Control
var _chuva8_x1 := 0.0
var _esmagadores: Array = []
var _cena8 := false
const CORES8 := [Color(1.0, 0.6, 0.15), Color(0.95, 0.3, 0.42), Color(0.3, 0.82, 0.45), Color(0.18, 0.8, 0.68),
	Color(0.25, 0.65, 0.98), Color(0.55, 0.45, 0.98), Color(1.0, 0.82, 0.2)]

func _fase_8() -> void:
	var y := CHAO_Y
	pecas.cor_chao = Color(0.1, 0.07, 0.2)
	pecas.borda_neon = Color(1.0, 0.35, 0.8)
	_parede_arena(-2700.0, y)
	var palco := CanvasLayer.new()                     # fundo vivo (holofotes, peças flutuando, faíscas)
	palco.layer = -70
	add_child(palco)
	var pc: Control = load("res://levels/Palco8.gd").new()
	palco.add_child(pc)
	_palco8 = pc
	var p := _t_plano(Vector2(-2600, y), 3900, false)
	pecas.placa(Vector2(-900, y), "LARGADA")
	p = _degraus8(p)
	p = _t_plano(p, 600, false)
	p = _ponte8(p, 3)
	p = _t_plano(p, 600, false)
	p = _esmagadores8(p, 2)
	p = _t_minas(p)
	p = _espinhos8(p)
	p = _degraus8(p)
	p = _esmagadores8(p, 3)
	p = _ponte8(p, 4)
	p = _t_plano(p, 600, false)
	p = _t_tnt(p)
	p = _esmagadores8(p, 3)
	p = _espinhos8(p)
	p = _t_plano(p, 2500, false)
	_chuva8_x1 = p.x - 3500.0
	var fim := _area(Vector2(p.x - 800.0, y - 700), Vector2(200, 1600))
	fim.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _cutscene8.call_deferred())
	pecas.poligono(Pecas.retangulo(Vector2(p.x - 800.0, y - 1200.0), Vector2(60, 2400)), Color(1, 1, 1, 0.25), -2)
	# arena da luta (chão reto colorido, paredes nas pontas)
	pecas.terreno(PackedVector2Array([Vector2(ARENA8_X - 3000.0, y), Vector2(ARENA8_X + ARENA8_LARG + 3000.0, y)]), y + 2600.0, false)
	_parede_arena(ARENA8_X, y)
	_parede_arena(ARENA8_X + ARENA8_LARG, y)
	_chao_grade8(ARENA8_X, ARENA8_X + ARENA8_LARG, y)
	geresch = Geresch.new()
	add_child(geresch)
	geresch.montar(self, ARENA8_X, ARENA8_X + ARENA8_LARG, y)
	geresch.derrotado.connect(func() -> void:
		_meta_pos = player.foco().global_position
		_fim(true, "venceu"))
	_marcos([], Vector2(ARENA8_X + ARENA8_LARG, y), y + 3000.0, false)

## bloco de Block Blast sólido: w x h células (base em `chao`, x = canto esquerdo)
func _bloco8(x: float, chao: float, w: int, h: int, cel := 240.0) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w * cel, h * cel)
	cs.shape = r
	sb.add_child(cs)
	sb.position = Vector2(x + w * cel / 2.0, chao - h * cel / 2.0)
	var cor: Color = CORES8[_sorteio.randi() % CORES8.size()]
	for i in w:
		for j in h:
			_celula8(sb, Vector2(-w * cel / 2.0 + i * cel, -h * cel / 2.0 + j * cel), cel, cor)
	add_child(sb)

func _celula8(pai: Node, canto: Vector2, cel: float, cor: Color, z := 1) -> void:
	var r := cel * 0.94
	var o := canto + Vector2(cel * 0.03, cel * 0.03)
	pecas.poligono(PackedVector2Array([o, o + Vector2(r, 0), o + Vector2(r, r), o + Vector2(0, r)]), cor.darkened(0.22), z, null, 1.0, pai)
	pecas.poligono(PackedVector2Array([o, o + Vector2(r, 0), o + Vector2(r, r * 0.86), o + Vector2(0, r * 0.86)]), cor, z, null, 1.0, pai)
	pecas.poligono(PackedVector2Array([o + Vector2(r * 0.18, r * 0.1), o + Vector2(r * 0.82, r * 0.1), o + Vector2(r * 0.82, r * 0.2), o + Vector2(r * 0.18, r * 0.2)]), Color(1, 1, 1, 0.5), z, null, 1.0, pai)

## degraus de blocos: rampa, sobe 1 bloco, anda por cima, desce em rampa
func _degraus8(p: Vector2) -> Vector2:
	_t_plano(p, 4200, false)
	pecas.rampa(p.x + 300, p.x + 1000, p.y, 240)
	_bloco8(p.x + 1000, p.y, 4, 1)
	pecas.rampa(p.x + 1300, p.x + 1960, p.y - 240, 240)     # rampa em cima do 1º bloco até o 2º
	_bloco8(p.x + 1960, p.y, 3, 2)
	var desce := PackedVector2Array([Vector2(p.x + 2680, p.y - 460), Vector2(p.x + 3500, p.y)])
	pecas.terreno(PackedVector2Array([desce[0], desce[1]]), p.y + 10.0, false)
	return p + Vector2(4200, 0)

## ponte de peças sobre fosso de espinhos (peças flutuando com pequenos vãos)
func _ponte8(p: Vector2, n: int) -> Vector2:
	pecas.rampa(p.x - 700, p.x - 100, p.y, 200)
	var comp := 300.0 + n * 960.0
	_fosso(p.x, p.x + comp, p.y)
	for k in n:                                       # vão de 80 entre as peças: dá a sensação de ponte sem travar roda
		_bloco8(p.x + 150.0 + k * 960.0, p.y + 120.0, 4, 1, 220.0)
	return _t_plano(p + Vector2(comp, 0), 400, false)

## espinhos com rampinha de pulo antes (dá pra passar com todos)
func _espinhos8(p: Vector2) -> Vector2:
	_t_plano(p, 2600, false)
	pecas.rampa(p.x + 400, p.x + 1000, p.y, 230)
	pecas.espinhos(p.x + 1060, p.x + 1380, p.y, 150.0)
	pecas.placa_perigo(p + Vector2(200, 0))
	return p + Vector2(2600, 0)

## chão da arena: grade neon em perspectiva (linhas abrindo pra frente)
func _chao_grade8(xa: float, xb: float, y: float) -> void:
	var cor := Color(0.95, 0.35, 0.85, 0.35)
	var x := xa
	while x <= xb:
		pecas.linha(PackedVector2Array([Vector2(x, y + 20), Vector2(x + (x - (xa + xb) / 2.0) * 0.35, y + 1400)]), 10.0, cor, 1)
		x += 500.0
	var dy := 70.0
	var yy := y + 90.0
	while yy < y + 1400:
		pecas.linha(PackedVector2Array([Vector2(xa - 600, yy), Vector2(xb + 600, yy)]), 8.0, Color(cor, cor.a * (1.0 - (yy - y) / 1600.0)), 1)
		yy += dy
		dy *= 1.35

## fundo colorido: blocos de Block Blast flutuando em várias distâncias
func _fundo8(xa: float, xb: float, y: float) -> void:
	var x := xa
	while x < xb:
		var cor: Color = CORES8[_sorteio.randi() % CORES8.size()]
		var cel := _sorteio.randf_range(140.0, 260.0)
		var forma: Array = Geresch.FORMAS[_sorteio.randi() % Geresch.FORMAS.size()]
		var base := Vector2(x, y - _sorteio.randf_range(1200.0, 3600.0))
		for c in forma:
			_celula8(self, base + Vector2(int(c[0]), int(c[1])) * cel, cel, Color(cor, 0.55), -8)
		x += _sorteio.randf_range(900.0, 1700.0)

## fim da parte normal: vídeo do Geresch levantando, música sincronizada, salva e luta
func _cutscene8() -> void:
	if _cena8 or not ativo:
		return
	_cena8 = true
	_queda7 = true                                # ninguém morre durante o vídeo
	var cena := CanvasLayer.new()
	cena.layer = 80
	cena.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cena)
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	cena.add_child(preto)
	var video := VideoStreamPlayer.new()
	video.stream = load("res://assets/geresch/intro.ogv")
	video.expand = true
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.process_mode = Node.PROCESS_MODE_ALWAYS
	video.volume_db = -80.0
	cena.add_child(video)
	get_tree().paused = true
	Engine.time_scale = 1.0                       # o vídeo anda em tempo normal
	Audio.parar_chefe()
	Audio.musica_chefe("geresch", MUSICA8_LOOP - VIDEO8_LEVANTA, MUSICA8_LOOP)   # batida cai quando ele levanta
	video.play()
	var ir := func() -> void:
		if not is_instance_valid(video) or video.get_meta("foi", false):
			return
		video.set_meta("foi", true)
		video.stop()
		get_tree().paused = false
		Game.checkpoint_x = ARENA8_X + 1600.0
		Game.checkpoint_chao = CHAO_Y
		Game.queda_fade = true
		_recomecando = true                   # online: recarrega sem sair da sala
		get_tree().reload_current_scene.call_deferred()
	video.finished.connect(ir, CONNECT_ONE_SHOT)
	_botao_pular(cena, ir)

## começo da fase 8: no checkpoint da arena começa a luta (música já tocando)
func _inicio_8() -> void:
	if Game.checkpoint_x < ARENA8_X - 1000.0:
		return
	do_inicio = true
	Audio.musica_chefe("geresch", MUSICA8_LOOP, MUSICA8_LOOP)
	geresch.comecar()
	if Game.queda_fade:
		Game.queda_fade = false
		var cena := CanvasLayer.new()
		cena.layer = 80
		add_child(cena)
		var preto := ColorRect.new()
		preto.color = Color.BLACK
		preto.set_anchors_preset(Control.PRESET_FULL_RECT)
		preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cena.add_child(preto)
		var tw := cena.create_tween()
		tw.tween_property(preto, "color:a", 0.0, 0.5)
		tw.tween_callback(cena.queue_free)

## impacto de bloco caindo: tela treme, poeira dos dois lados, cubinhos voando e pancada
func impacto8(onde: Vector2, forca: float) -> void:
	var f := clampf(forca, 0.6, 3.0)
	var perto := 1.0
	if is_instance_valid(player) and is_instance_valid(player.chassi):
		perto = clampf(1.0 - absf(player.chassi.global_position.x - onde.x) / 6000.0, 0.15, 1.0)
	pecas.poeira(onde + Vector2(-200 * f, -10), 1.0 + 0.5 * f)
	pecas.poeira(onde + Vector2(200 * f, -10), 1.0 + 0.5 * f)
	var cub := CPUParticles2D.new()
	cub.one_shot = true
	cub.explosiveness = 1.0
	cub.amount = int(10 + 6 * f)
	cub.lifetime = 0.55 * Engine.time_scale
	cub.direction = Vector2(0, -1)
	cub.spread = 75.0
	cub.initial_velocity_min = 900.0
	cub.initial_velocity_max = 2400.0
	cub.gravity = Vector2(0, 5000)
	cub.scale_amount_min = 20.0
	cub.scale_amount_max = 45.0
	cub.angular_velocity_min = -500.0
	cub.angular_velocity_max = 500.0
	cub.color = CORES8[randi() % CORES8.size()]
	cub.global_position = onde
	cub.z_index = 7
	add_child(cub)
	cub.emitting = true
	get_tree().create_timer(1.5 * Engine.time_scale).timeout.connect(cub.queue_free)
	var base := Vector2(800, -150)
	var tw := camera.create_tween()
	for k in 6:
		tw.tween_property(camera, "offset", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 90.0 * f * perto * (1.0 - k / 6.0), 0.035 * Engine.time_scale)
	tw.tween_property(camera, "offset", base, 0.035 * Engine.time_scale)
	Audio.tocar("impacto_forte", clampf(0.5 + 0.25 * f, 0.0, 1.0) * perto, 0.1)
	Audio.tocar("caixa", 0.8 * perto)

## esmagadores: blocos de Block Blast que sobem, tremem, despencam e sobem de novo
func _esmagadores8(p: Vector2, n: int) -> Vector2:
	var comp := 1000.0 + n * 2700.0                    # espaço entre eles cabe até o carrinho do Bicho
	_t_plano(p, comp, false)
	for k in n:
		var x := p.x + 1300.0 + k * 2700.0
		var cel := 230.0
		var w := 3
		var h := 3
		var ab := AnimatableBody2D.new()
		ab.sync_to_physics = false
		ab.collision_layer = 0b01
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(w * cel, h * cel)
		cs.shape = r
		ab.add_child(cs)
		var cor: Color = CORES8[(k + n) % CORES8.size()]
		for i in w:
			for j in h:
				_celula8(ab, Vector2(-w * cel / 2.0 + i * cel, -h * cel / 2.0 + j * cel), cel, cor, 3)
		for lado in [-1.0, 1.0]:                          # carinha brava: olho e sobrancelha
			var cxo: float = lado * 150.0
			pecas.poligono(Pecas.retangulo(Vector2(cxo, 20), Vector2(70, 90)), Color(0.08, 0.04, 0.12), 4, null, 1.0, ab)
			pecas.poligono(Pecas.retangulo(Vector2(cxo + lado * -12, 6), Vector2(22, 26)), Color(1, 1, 1, 0.9), 4, null, 1.0, ab)
			pecas.linha(PackedVector2Array([Vector2(cxo - lado * 70, -80), Vector2(cxo + lado * 70, -40)]), 30.0, Color(0.08, 0.04, 0.12), 4, ab)
		pecas.linha(PackedVector2Array([Vector2(-70, 140), Vector2(0, 115), Vector2(70, 140)]), 22.0, Color(0.08, 0.04, 0.12), 4, ab)
		var baixo := p.y - h * cel / 2.0
		var alto := baixo - 1400.0
		ab.position = Vector2(x, alto)
		add_child(ab)
		var sombra := Geresch.marcador(w * cel / 2.0)
		sombra.position = Vector2(x, p.y)
		add_child(sombra)
		var periodo: float = [7.5, 6.6, 8.4][k % 3]       # ~2,2-2,8 s de verdade por ciclo
		_esmagadores.append({"no": ab, "alto": alto, "baixo": baixo, "meia": h * cel / 2.0, "largura": w * cel / 2.0,
			"T": periodo, "atraso": _sorteio.randf_range(0.0, periodo), "chao": p.y, "sombra": sombra, "bateu": false})
	return p + Vector2(comp, 0)

func _mover_esmagadores(_delta: float) -> void:
	for e in _esmagadores:
		var f := fposmod(_t_fisica + float(e["atraso"]), float(e["T"])) / float(e["T"])
		var no: AnimatableBody2D = e["no"]
		var sombra: Polygon2D = e["sombra"]
		var y := float(e["alto"])
		var treme := 0.0
		# 0-0.5 em cima | 0.5-0.64 tremendo (aviso) | 0.64-0.69 despenca | 0.69-0.8 no chão | 0.8-0.88 sobe rápido | em cima
		if f < 0.5 or f >= 0.88:
			sombra.modulate.a = 0.25
		elif f < 0.64:
			treme = 14.0
			sombra.modulate.a = 1.0 if fmod(f * 40.0, 1.0) < 0.5 else 0.7
		elif f < 0.69:
			var k := (f - 0.64) / 0.05
			y = lerpf(float(e["alto"]), float(e["baixo"]), k * k)
			sombra.modulate.a = 1.0
		elif f < 0.8:
			y = float(e["baixo"])
			sombra.modulate.a = 0.0
			if not e["bateu"]:
				e["bateu"] = true
				impacto8(Vector2(no.position.x, float(e["chao"])), 2.2)
		else:
			y = lerpf(float(e["baixo"]), float(e["alto"]), smoothstep(0.0, 1.0, (f - 0.8) / 0.08))
			sombra.modulate.a = 0.2
		if f < 0.69:
			e["bateu"] = false
		no.position = Vector2(no.position.x, y) + Vector2(randf_range(-1, 1) * treme, 0)
		if f >= 0.64 and f < 0.71 and ativo and is_instance_valid(player):      # descendo: esmaga quem está embaixo
			var fundo := y + float(e["meia"])
			var alvos: Array = [player.chassi] + player.membros.values() if player.montado else player.corpos.values()
			for b in alvos:
				var bp: Vector2 = (b as Node2D).global_position
				if absf(bp.x - no.position.x) < float(e["largura"]) - 40.0 and bp.y < fundo + 80.0 and bp.y > fundo - 700.0:
					if player.repelir(bp):
						break
					_on_perigo(b, "esmagado")
					break

# ---------- FASE 9: O Julgamento (boss: Çtamandura) ----------
## espaço cheio de olhos: corpos vagando no fundo, cristais cósmicos caindo do céu e
## portões de laser roxo. No fim toca o vídeo do martelo do juiz e começa a luta.
const ARENA9_X := 250000.0
const ARENA9_LARG := 9000.0
var julgamento: Julgamento
var ctamandura: Ctamandura
var _chuva9_x1 := 0.0
var _cena9 := false

func _fase_9() -> void:
	var y := CHAO_Y
	pecas.cor_chao = Color(0.07, 0.03, 0.12)
	pecas.borda_neon = Color(0.75, 0.35, 1.0)
	_parede_arena(-2700.0, y)
	julgamento = Julgamento.new()
	add_child(julgamento)
	julgamento.montar(self, y)
	var p := _t_plano(Vector2(-2600, y), 3900, false)
	pecas.placa(Vector2(-900, y), "LARGADA")
	p = _t_plano(p, 1200, false)
	p = _portoes9(p, 2, 3.6)
	p = _t_ladeira(p, 2600, -500)
	p = _t_ladeira(p, 2600, 500)
	p = _espinhos8(p)
	p = _portoes9(p, 3, 3.5)
	p = _t_ondas(p, 3, 130.0)
	p = _t_minas(p)
	p = _portoes9(p, 4, 3.4)
	p = _espinhos8(p)
	p = _t_ladeira(p, 2400, -400)
	p = _portoes9(p, 3, 3.3)
	p = _t_ladeira(p, 2400, 400)
	p = _t_plano(p, 2500, false)
	_chuva9_x1 = p.x - 3500.0
	var fim := _area(Vector2(p.x - 800.0, p.y - 700), Vector2(200, 1600))
	fim.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"): _cutscene9.call_deferred())
	pecas.poligono(Pecas.retangulo(Vector2(p.x - 800.0, p.y - 1200.0), Vector2(60, 2400)), Color(0.8, 0.5, 1.0, 0.3), -2)
	# arena da luta
	pecas.terreno(PackedVector2Array([Vector2(ARENA9_X - 3000.0, y), Vector2(ARENA9_X + ARENA9_LARG + 3000.0, y)]), y + 2600.0, false)
	_parede_arena(ARENA9_X, y)
	_parede_arena(ARENA9_X + ARENA9_LARG, y)
	ctamandura = Ctamandura.new()
	add_child(ctamandura)
	ctamandura.montar(self, ARENA9_X + 200.0, ARENA9_X + ARENA9_LARG - 200.0, y)
	ctamandura.martelo_caiu.connect(_video_martelo)
	ctamandura.derrotado.connect(func() -> void:
		_meta_pos = player.foco().global_position
		_fim(true, "venceu"))
	_marcos([], Vector2(ARENA9_X + ARENA9_LARG, y), y + 3000.0, false)

## reta com portões de laser roxo (cada um num tempo diferente)
func _portoes9(p: Vector2, n: int, periodo: float) -> Vector2:
	var comp := 2400.0 + n * 2700.0                     # reta antes do 1º: dá pra frear; entre eles cabe o carro do Vitinho
	_t_plano(p, comp, false)
	for k in n:
		julgamento.portao(p.x + 2400.0 + k * 2700.0, p.y, periodo, k * periodo * 0.37)
	return p + Vector2(comp, 0)

## fim da parte normal: vídeo do martelo do juiz, aí salva na arena e a luta começa
func _cutscene9() -> void:
	if _cena9 or not ativo:
		return
	_cena9 = true
	_queda7 = true                                # ninguém morre durante o vídeo
	var ir := func() -> void:
		Game.checkpoint_x = ARENA9_X + 1600.0
		Game.checkpoint_chao = CHAO_Y
		Game.queda_fade = true
		_recomecando = true
		get_tree().reload_current_scene.call_deferred()
	if Game.get_meta("viu_entrada9", false):        # vídeo só na primeira vez
		ir.call()
		return
	Game.set_meta("viu_entrada9", true)
	_tocar_video("res://assets/julgamento/entrada.ogv", ir)

## vídeo por cima de tudo, com o jogo pausado; `depois` roda quando acaba
func _tocar_video(arq: String, depois: Callable) -> void:
	var cena := CanvasLayer.new()
	cena.layer = 80
	cena.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cena)
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	cena.add_child(preto)
	var video := VideoStreamPlayer.new()
	video.stream = load(arq)
	video.expand = true
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.process_mode = Node.PROCESS_MODE_ALWAYS
	cena.add_child(video)
	video.volume_db = -80.0                       # vídeo sem som: a música continua tocando
	get_tree().paused = true
	Engine.time_scale = 1.0                       # o vídeo anda em tempo normal
	video.play()
	var acabou := func() -> void:
		if not is_instance_valid(cena) or cena.is_queued_for_deletion():
			return
		video.stop()
		get_tree().paused = false
		Engine.time_scale = Game.RITMO
		cena.queue_free()
		depois.call()
	video.finished.connect(acabou, CONNECT_ONE_SHOT)
	_botao_pular(cena, acabou)

## botão PULAR no canto da cutscene
func _botao_pular(cena: CanvasLayer, acao: Callable) -> void:
	var b := Button.new()
	b.text = "PULAR ›"
	b.focus_mode = Control.FOCUS_NONE
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.add_theme_font_size_override("font_size", 30)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.55)
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = Color(1, 1, 1, 0.6)
	st.content_margin_left = 22
	st.content_margin_right = 22
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, st)
	var v := get_viewport().get_visible_rect().size
	b.size = Vector2(190, 66)
	b.position = Vector2(v.x - 220, v.y - 96)
	b.pressed.connect(func() -> void:
		Audio.tocar("clique")
		acao.call())
	cena.add_child(b)

## "o martelo caiu...", depois o martelo de juiz, e começa a luta 2 (Çtamandura + Périne)
func _video_martelo() -> void:
	if Game.get_meta("viu_martelo9", false):        # vídeo só na primeira vez
		ctamandura.luta_2()
		return
	Game.set_meta("viu_martelo9", true)
	_tocar_video("res://assets/julgamento/martelo.ogv", func() -> void:
		ctamandura.luta_2())

## começo da fase 9: música da fase; no checkpoint da arena começa a luta
func _inicio_9() -> void:
	if Game.checkpoint_x < ARENA9_X - 1000.0:
		Audio.musica_chefe("julgamento")
		return
	do_inicio = true
	Audio.musica_chefe("ctamandura", 119.0)      # já entra na metade da música
	ctamandura.comecar()
	var meio := Node2D.new()                       # câmera aberta e parada: dá pra ver todas as faixas
	meio.position = Vector2(ARENA9_X + ARENA9_LARG / 2.0, CHAO_Y - 1500.0)
	add_child(meio)
	camera.alvo = meio
	camera.zoom = Vector2(0.135, 0.135)
	camera.offset = Vector2.ZERO
	camera.global_position = meio.position
	set_meta("cam_base", Vector2.ZERO)
	if Game.queda_fade:
		Game.queda_fade = false
		var cena := CanvasLayer.new()
		cena.layer = 80
		add_child(cena)
		var preto := ColorRect.new()
		preto.color = Color.BLACK
		preto.set_anchors_preset(Control.PRESET_FULL_RECT)
		preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cena.add_child(preto)
		var tw := cena.create_tween()
		tw.tween_property(preto, "color:a", 0.0, 0.5)
		tw.tween_callback(cena.queue_free)
